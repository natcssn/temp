import os
import random
from datetime import datetime, timezone, timedelta
from typing import List

import razorpay
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel
from pymongo.errors import DuplicateKeyError

from database import get_db, get_next_id
from orders import get_user_from_token

router = APIRouter(tags=["Payments"])

RAZORPAY_KEY_ID = os.getenv("RAZORPAY_KEY_ID", "")
RAZORPAY_KEY_SECRET = os.getenv("RAZORPAY_KEY_SECRET", "")
ALLOWED_FULFILLMENT_MODES = {"pickup", "delivery"}


class OrderItem(BaseModel):
    item_id: int
    quantity: int


class CreatePaymentOrderRequest(BaseModel):
    restaurant_id: int
    items: List[OrderItem]
    fulfillment_mode: str = "pickup"


class VerifyAndPlaceOrderRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


def _order_response(order_doc: dict):
    if not order_doc:
        return None
    return {
        "order_id": order_doc["id"],
        "secret_code": order_doc["secret_code"],
        "total": order_doc["total"],
        "status": order_doc["status"],
    }


def _rzp_client() -> razorpay.Client:
    if not RAZORPAY_KEY_ID or not RAZORPAY_KEY_SECRET:
        raise HTTPException(
            status_code=500,
            detail="Razorpay keys are missing on server. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET.",
        )
    return razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))


async def _validate_and_price_items(restaurant_id: int, items: List[OrderItem]):
    db = get_db()
    rest = await db.restaurants.find_one({"id": restaurant_id})
    if not rest:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not rest["is_open"]:
        raise HTTPException(status_code=400, detail="Restaurant is currently closed")

    total = 0.0
    order_items_data = []
    for item in items:
        if item.quantity <= 0:
            raise HTTPException(status_code=400, detail="Quantity must be at least 1")
        menu_item = await db.menu_items.find_one({"id": item.item_id})
        if not menu_item:
            raise HTTPException(status_code=404, detail=f"Item {item.item_id} not found")
        if menu_item["restaurant_id"] != restaurant_id:
            raise HTTPException(
                status_code=400,
                detail=f"Item {menu_item['name']} does not belong to this restaurant",
            )
        if not menu_item["is_available"]:
            raise HTTPException(
                status_code=400,
                detail=f"Item {menu_item['name']} is currently unavailable",
            )

        item_total = float(menu_item["price"]) * item.quantity
        total += item_total
        order_items_data.append(
            {
                "item_id": menu_item["id"],
                "item_name": menu_item["name"],
                "quantity": item.quantity,
                "price": float(menu_item["price"]),
            }
        )

    amount_paise = int(round(total * 100))
    if amount_paise <= 0:
        raise HTTPException(status_code=400, detail="Order amount must be greater than zero")

    return order_items_data, total, amount_paise


@router.post("/payments/create-order")
async def create_payment_order(payload: CreatePaymentOrderRequest, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    user_id = await get_user_from_token(token)
    db = get_db()

    if payload.fulfillment_mode not in ALLOWED_FULFILLMENT_MODES:
        raise HTTPException(status_code=400, detail="Invalid fulfillment mode")

    order_items_data, total, amount_paise = await _validate_and_price_items(
        payload.restaurant_id, payload.items
    )

    # Add delivery fee if delivery mode is selected
    delivery_fee = 20.0 if payload.fulfillment_mode == "delivery" else 0.0
    total += delivery_fee
    amount_paise = int(round(total * 100))

    receipt = f"ezf_{user_id}_{random.randint(10000, 99999)}"
    client = _rzp_client()
    try:
        razorpay_order = client.order.create(
            {
                "amount": amount_paise,
                "currency": "INR",
                "receipt": receipt,
                "notes": {
                    "user_id": str(user_id),
                    "restaurant_id": str(payload.restaurant_id),
                },
            }
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Razorpay order creation failed: {exc}") from exc

    await db.payment_intents.update_one(
        {"razorpay_order_id": razorpay_order["id"]},
        {
            "$set": {
                "razorpay_order_id": razorpay_order["id"],
                "user_id": user_id,
                "restaurant_id": payload.restaurant_id,
                "fulfillment_mode": payload.fulfillment_mode,
                "items": order_items_data,
                "total": total,
                "amount_paise": amount_paise,
                "currency": "INR",
                "status": "created",
                "verification_attempts": 0,
                "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
            }
        },
        upsert=True,
    )

    return {
        "key_id": RAZORPAY_KEY_ID,
        "razorpay_order_id": razorpay_order["id"],
        "amount": amount_paise,
        "currency": "INR",
        "total": total,
        "restaurant_id": payload.restaurant_id,
        "fulfillment_mode": payload.fulfillment_mode,
    }


@router.post("/payments/verify-and-place-order")
async def verify_and_place_order(payload: VerifyAndPlaceOrderRequest, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    user_id = await get_user_from_token(token)
    db = get_db()

    intent = await db.payment_intents.find_one(
        {"razorpay_order_id": payload.razorpay_order_id, "user_id": user_id}
    )
    if not intent:
        raise HTTPException(status_code=404, detail="Payment intent not found")

    if intent.get("status") == "paid" and intent.get("order_id"):
        already_paid_order = await db.orders.find_one({"id": intent["order_id"]}, {"_id": 0})
        if already_paid_order:
            return _order_response(already_paid_order)

    existing_order = await db.orders.find_one(
        {"payment_id": payload.razorpay_payment_id}, {"_id": 0}
    )
    if existing_order:
        return _order_response(existing_order)

    client = _rzp_client()
    signature_payload = {
        "razorpay_order_id": payload.razorpay_order_id,
        "razorpay_payment_id": payload.razorpay_payment_id,
        "razorpay_signature": payload.razorpay_signature,
    }
    try:
        client.utility.verify_payment_signature(signature_payload)
    except Exception as exc:
        print(f"Payment signature verification failed: {exc}")
        raise HTTPException(status_code=400, detail="Payment signature verification failed")

    now_dt = datetime.now(timezone.utc)
    now = now_dt.strftime("%Y-%m-%d %H:%M:%S")
    cutoff = (now_dt - timedelta(seconds=60)).strftime("%Y-%m-%d %H:%M:%S")

    lock_result = await db.payment_intents.update_one(
        {
            "razorpay_order_id": payload.razorpay_order_id,
            "user_id": user_id,
            "$or": [
                {"status": "created"},
                {"status": "verifying", "last_verification_attempt_at": {"$lte": cutoff}}
            ]
        },
        {
            "$set": {
                "status": "verifying",
                "last_verification_attempt_at": now,
            },
            "$inc": {"verification_attempts": 1},
        },
    )
    if lock_result.matched_count == 0:
        locked_intent = await db.payment_intents.find_one(
            {"razorpay_order_id": payload.razorpay_order_id, "user_id": user_id}
        )
        if locked_intent and locked_intent.get("status") == "paid" and locked_intent.get("order_id"):
            already_paid_order = await db.orders.find_one({"id": locked_intent["order_id"]}, {"_id": 0})
            if already_paid_order:
                return _order_response(already_paid_order)
        raise HTTPException(status_code=409, detail="Payment verification is already in progress")

    order_id = await get_next_id("orders")
    secret_code = f"#{random.randint(1000, 9999)}"

    # Look up customer gender for delivery partner matching
    customer = await db.users.find_one({"id": user_id}, {"gender": 1})
    customer_gender = customer.get("gender", "") if customer else ""

    order_doc = {
        "id": order_id,
        "user_id": user_id,
        "restaurant_id": intent["restaurant_id"],
        "secret_code": secret_code,
        "status": "preparing",
        "fulfillment_mode": intent.get("fulfillment_mode", "pickup"),
        "customer_gender": customer_gender,
        "delivery_partner_id": None,
        "delivery_stage": "awaiting_assignment"
        if intent.get("fulfillment_mode") == "delivery"
        else "not_required",
        "delivery_fee": 20.0 if intent.get("fulfillment_mode") == "delivery" else 0.0,
        "total": intent["total"],
        "items": intent["items"],
        "created_at": now,
        "payment_status": "paid",
        "payment_id": payload.razorpay_payment_id,
        "razorpay_order_id": payload.razorpay_order_id,
        "payment_verified_at": now,
        "user_acknowledged": False,
    }

    try:
        await db.orders.insert_one(order_doc)
    except DuplicateKeyError:
        duplicate_order = await db.orders.find_one(
            {"payment_id": payload.razorpay_payment_id}, {"_id": 0}
        )
        if duplicate_order:
            await db.payment_intents.update_one(
                {"razorpay_order_id": payload.razorpay_order_id, "user_id": user_id},
                {
                    "$set": {
                        "status": "paid",
                        "payment_id": payload.razorpay_payment_id,
                        "razorpay_signature": payload.razorpay_signature,
                        "verified_at": now,
                        "order_id": duplicate_order["id"],
                    }
                },
            )
            return _order_response(duplicate_order)
        raise HTTPException(status_code=409, detail="Payment already processed")
    except Exception as exc:
        await db.payment_intents.update_one(
            {"razorpay_order_id": payload.razorpay_order_id, "user_id": user_id},
            {
                "$set": {
                    "status": "created",
                    "last_error": f"order_insert_failed: {exc}",
                }
            },
        )
        raise HTTPException(status_code=500, detail="Order creation failed after payment verification")

    await db.payment_intents.update_one(
        {"razorpay_order_id": payload.razorpay_order_id},
        {
            "$set": {
                "status": "paid",
                "payment_id": payload.razorpay_payment_id,
                "razorpay_signature": payload.razorpay_signature,
                "verified_at": now,
                "order_id": order_id,
            }
        },
    )

    return _order_response(order_doc)


@router.get("/payments/status/{razorpay_order_id}")
async def payment_status(razorpay_order_id: str, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    user_id = await get_user_from_token(token)
    db = get_db()

    intent = await db.payment_intents.find_one(
        {"razorpay_order_id": razorpay_order_id, "user_id": user_id}
    )
    if not intent:
        raise HTTPException(status_code=404, detail="Payment intent not found")

    # Hardening: If status is not 'paid', check Razorpay API directly
    if intent.get("status") != "paid":
        client = _rzp_client()
        try:
            order_details = client.order.fetch(razorpay_order_id)
            if order_details.get("status") == "paid":
                # Get the payment ID associated with the paid order
                payments = client.order.payments(razorpay_order_id)
                payment_id = None
                if payments and payments.get("items"):
                    for p in payments["items"]:
                        if p.get("status") in ("captured", "authorized"):
                            payment_id = p["id"]
                            break

                if payment_id:
                    existing_order = await db.orders.find_one({"payment_id": payment_id})
                    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
                    if existing_order:
                        await db.payment_intents.update_one(
                            {"razorpay_order_id": razorpay_order_id},
                            {
                                "$set": {
                                    "status": "paid",
                                    "payment_id": payment_id,
                                    "verified_at": now,
                                    "order_id": existing_order["id"],
                                }
                            }
                        )
                        intent["status"] = "paid"
                        intent["order_id"] = existing_order["id"]
                    else:
                        order_id = await get_next_id("orders")
                        secret_code = f"#{random.randint(1000, 9999)}"
                        customer = await db.users.find_one({"id": user_id}, {"gender": 1})
                        customer_gender = customer.get("gender", "") if customer else ""

                        order_doc = {
                            "id": order_id,
                            "user_id": user_id,
                            "restaurant_id": intent["restaurant_id"],
                            "secret_code": secret_code,
                            "status": "preparing",
                            "fulfillment_mode": intent.get("fulfillment_mode", "pickup"),
                            "customer_gender": customer_gender,
                            "delivery_partner_id": None,
                            "delivery_stage": "awaiting_assignment" if intent.get("fulfillment_mode") == "delivery" else "not_required",
                            "delivery_fee": 20.0 if intent.get("fulfillment_mode") == "delivery" else 0.0,
                            "total": intent["total"],
                            "items": intent["items"],
                            "created_at": now,
                            "payment_status": "paid",
                            "payment_id": payment_id,
                            "razorpay_order_id": razorpay_order_id,
                            "payment_verified_at": now,
                            "user_acknowledged": False,
                        }

                        try:
                            await db.orders.insert_one(order_doc)
                            await db.payment_intents.update_one(
                                {"razorpay_order_id": razorpay_order_id},
                                {
                                    "$set": {
                                        "status": "paid",
                                        "payment_id": payment_id,
                                        "verified_at": now,
                                        "order_id": order_id,
                                    }
                                }
                            )
                            intent["status"] = "paid"
                            intent["order_id"] = order_id
                        except DuplicateKeyError:
                            existing_order = await db.orders.find_one({"payment_id": payment_id})
                            if existing_order:
                                intent["status"] = "paid"
                                intent["order_id"] = existing_order["id"]
        except Exception as exc:
            print(f"Error checking order status on Razorpay API: {exc}")

    order_payload = None
    if intent.get("status") == "paid":
        if intent.get("order_id"):
            paid_order = await db.orders.find_one({"id": intent["order_id"]}, {"_id": 0})
            order_payload = _order_response(paid_order)
        elif intent.get("payment_id"):
            paid_order = await db.orders.find_one({"payment_id": intent["payment_id"]}, {"_id": 0})
            order_payload = _order_response(paid_order)

    return {
        "status": intent.get("status", "unknown"),
        "order": order_payload,
        "verification_attempts": intent.get("verification_attempts", 0),
    }
