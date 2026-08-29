from fastapi import APIRouter, HTTPException, Header, Body
from database import get_db, get_next_id
from restaurant_auth import get_restaurant_from_token
import random
from pydantic import BaseModel
from typing import List
from datetime import datetime, timezone
from transaction_logger import log_completed_order

router = APIRouter(tags=["Orders"])


class OrderItem(BaseModel):
    item_id: int
    quantity: int


class PlaceOrderRequest(BaseModel):
    restaurant_id: int
    items: List[OrderItem]
    fulfillment_mode: str = "pickup"


async def get_user_from_token(token: str):
    db = get_db()
    session = await db.user_sessions.find_one({"token": token})
    if not session:
        raise HTTPException(status_code=401, detail="Invalid token")
    return session["user_id"]


@router.post("/orders")
async def place_order(order: PlaceOrderRequest, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    user_id = await get_user_from_token(token)

    db = get_db()

    if order.fulfillment_mode not in {"pickup", "delivery"}:
        raise HTTPException(status_code=400, detail="Invalid fulfillment mode")

    # Check restaurant is open
    rest = await db.restaurants.find_one({"id": order.restaurant_id})
    if not rest:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if not rest["is_open"]:
        raise HTTPException(status_code=400, detail="Restaurant is currently closed")

    # Generate secret code
    secret_code = f"#{random.randint(1000, 9999)}"

    # Calculate total and validate items
    total = 0.0
    order_items_data = []
    for item in order.items:
        menu_item = await db.menu_items.find_one({"id": item.item_id})
        if not menu_item:
            raise HTTPException(status_code=404, detail=f"Item {item.item_id} not found")
        if menu_item["restaurant_id"] != order.restaurant_id:
            raise HTTPException(status_code=400, detail=f"Item {menu_item['name']} does not belong to this restaurant")
        if not menu_item["is_available"]:
            raise HTTPException(status_code=400, detail=f"Item {menu_item['name']} is currently unavailable")

        item_total = menu_item["price"] * item.quantity
        total += item_total
        order_items_data.append({
            "item_id": menu_item["id"],
            "item_name": menu_item["name"],
            "quantity": item.quantity,
            "price": menu_item["price"],
        })

    # Create order
    order_id = await get_next_id("orders")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    # Add delivery fee to total if applicable
    delivery_fee = 20.0 if order.fulfillment_mode == "delivery" else 0.0
    total += delivery_fee

    # Look up customer gender for delivery partner matching
    customer = await db.users.find_one({"id": user_id}, {"gender": 1})
    customer_gender = customer.get("gender", "") if customer else ""

    await db.orders.insert_one({
        "id": order_id,
        "user_id": user_id,
        "restaurant_id": order.restaurant_id,
        "secret_code": secret_code,
        "status": "preparing",
        "fulfillment_mode": order.fulfillment_mode,
        "customer_gender": customer_gender,
        "delivery_partner_id": None,
        "delivery_stage": "awaiting_assignment" if order.fulfillment_mode == "delivery" else "not_required",
        "delivery_fee": delivery_fee,
        "total": total,
        "items": order_items_data,
        "created_at": now,
    })

    return {
        "order_id": order_id,
        "secret_code": secret_code,
        "total": total,
        "status": "preparing"
    }


@router.get("/orders/user/active")
async def get_user_active_orders(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    user_id = await get_user_from_token(token)

    db = get_db()
    cursor = db.orders.find(
        {
            "user_id": user_id,
            "$or": [
                {"status": {"$ne": "given"}},
                {"status": "given", "user_acknowledged": False},
            ],
        },
        {"_id": 0}
    ).sort("created_at", -1)

    orders = []
    async for order in cursor:
        # Add restaurant name
        rest = await db.restaurants.find_one({"id": order["restaurant_id"]}, {"name": 1})
        order["restaurant_name"] = rest["name"] if rest else ""

        # Add delivery partner details if one has been assigned
        dp_id = order.get("delivery_partner_id")
        if dp_id is not None:
            partner = await db.delivery_partners.find_one(
                {"id": dp_id},
                {"name": 1, "phone": 1, "email": 1, "gender": 1},
            )
            if partner:
                order["delivery_partner_name"] = partner.get("name", "")
                order["delivery_partner_phone"] = partner.get("phone", "")
                order["delivery_partner_email"] = partner.get("email", "")
                order["delivery_partner_gender"] = partner.get("gender", "")

        orders.append(order)

    return {"orders": orders}


@router.get("/orders/user/history")
async def get_user_order_history(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    user_id = await get_user_from_token(token)

    db = get_db()
    cursor = db.orders.find(
        {
            "user_id": user_id,
            "status": "given",
            "$or": [{"user_acknowledged": True}, {"user_acknowledged": {"$exists": False}}],
        },
        {"_id": 0}
    ).sort("created_at", -1).limit(50)

    orders = []
    async for order in cursor:
        rest = await db.restaurants.find_one({"id": order["restaurant_id"]}, {"name": 1})
        order["restaurant_name"] = rest["name"] if rest else ""
        orders.append(order)

    return {"orders": orders}


@router.get("/orders/restaurant/{restaurant_id}")
async def get_restaurant_orders(restaurant_id: int, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    rid = await get_restaurant_from_token(token)
    if rid != restaurant_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    db = get_db()
    cursor = db.orders.find(
        {"restaurant_id": restaurant_id, "status": {"$ne": "given"}},
        {"_id": 0}
    ).sort("created_at", 1)

    orders = []
    async for order in cursor:
        user = await db.users.find_one(
            {"id": order["user_id"]},
            {"username": 1, "phone": 1, "hostel": 1, "college_name": 1, "identification": 1}
        )
        if user:
            order["customer_name"] = user.get("username", "")
            order["customer_phone"] = user.get("phone", "")
            order["customer_hostel"] = user.get("hostel", "")
            order["customer_college"] = user.get("college_name", "")
            order["customer_identification"] = user.get("identification", "")
        else:
            order["customer_name"] = ""
            order["customer_phone"] = ""
            order["customer_hostel"] = ""
            order["customer_college"] = ""
            order["customer_identification"] = ""
        orders.append(order)

    return {"orders": orders}


@router.get("/orders/restaurant/{restaurant_id}/history")
async def get_restaurant_order_history(restaurant_id: int, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    rid = await get_restaurant_from_token(token)
    if rid != restaurant_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    db = get_db()
    cursor = db.orders.find(
        {"restaurant_id": restaurant_id, "status": "given"},
        {"_id": 0}
    ).sort("created_at", -1).limit(100)

    orders = []
    async for order in cursor:
        user = await db.users.find_one(
            {"id": order["user_id"]},
            {"username": 1, "phone": 1, "hostel": 1, "college_name": 1, "identification": 1}
        )
        if user:
            order["customer_name"] = user.get("username", "")
            order["customer_phone"] = user.get("phone", "")
            order["customer_hostel"] = user.get("hostel", "")
            order["customer_college"] = user.get("college_name", "")
            order["customer_identification"] = user.get("identification", "")
        else:
            order["customer_name"] = ""
            order["customer_phone"] = ""
            order["customer_hostel"] = ""
            order["customer_college"] = ""
            order["customer_identification"] = ""
        orders.append(order)

    return {"orders": orders}


@router.put("/orders/{order_id}/status")
async def update_order_status(order_id: int, authorization: str = Header(...), status: str = Body(..., embed=True)):
    token = authorization.replace("Bearer ", "")

    valid_statuses = ["preparing", "ready", "given"]
    if status not in valid_statuses:
        raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {valid_statuses}")

    db = get_db()
    order = await db.orders.find_one({"id": order_id})
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    rid = await get_restaurant_from_token(token)
    if rid != order["restaurant_id"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    if order.get("fulfillment_mode") == "delivery" and status == "given":
        raise HTTPException(status_code=400, detail="Delivery orders must be completed by delivery partner")

    # Enforce status flow
    status_flow = {"preparing": "ready", "ready": "given"}
    current = order["status"]
    if current in status_flow and status != status_flow[current]:
        raise HTTPException(status_code=400, detail=f"Cannot change from '{current}' to '{status}'. Next status should be '{status_flow[current]}'")

    await db.orders.update_one({"id": order_id}, {"$set": {"status": status}})

    if status == "given":
        updated_order = await db.orders.find_one({"id": order_id}, {"_id": 0})
        if updated_order:
            await log_completed_order(updated_order)

    return {"status": status}


@router.post("/orders/{order_id}/acknowledge")
async def acknowledge_order(order_id: int, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    user_id = await get_user_from_token(token)

    db = get_db()
    order = await db.orders.find_one({"id": order_id})
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    if order["status"] != "given":
        raise HTTPException(status_code=400, detail="Order is not delivered yet")

    await db.orders.update_one(
        {"id": order_id},
        {
            "$set": {
                "user_acknowledged": True,
                "acknowledged_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
            }
        },
    )

    return {"status": "acknowledged"}
