import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Form, Header, HTTPException

from Databases.hashing import hash_password, verify_password
from database import get_db, get_next_id
from transaction_logger import log_completed_order

router = APIRouter(prefix="/delivery", tags=["Delivery Partner"])

ALLOWED_FULFILLMENT_MODES = {"delivery"}
DEFAULT_DELIVERY_FEE = 20.0
ALLOWED_GENDERS = ["Male", "Female"]


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


async def _get_partner_from_token(token: str):
    db = get_db()
    session = await db.delivery_sessions.find_one({"token": token})
    if not session:
        raise HTTPException(status_code=401, detail="Invalid token")

    partner = await db.delivery_partners.find_one({"id": session["partner_id"]})
    if not partner:
        raise HTTPException(status_code=401, detail="Invalid token")

    if not partner.get("is_active", True):
        raise HTTPException(status_code=403, detail="Delivery partner account is inactive")

    return partner


def _partner_payload(partner: dict, token: str | None = None):
    payload = {
        "partner_id": partner["id"],
        "name": partner.get("name", ""),
        "email": partner.get("email", ""),
        "phone": partner.get("phone", ""),
        "gender": partner.get("gender", ""),
        "bank_id": partner.get("bank_id", ""),
        "is_active": bool(partner.get("is_active", True)),
        "deliveries_completed": int(partner.get("deliveries_completed", 0)),
        "total_earnings": float(partner.get("total_earnings", 0.0)),
    }
    if token:
        payload["token"] = token
    return payload


@router.post("/register")
async def register_delivery_partner(
    name: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    phone: str = Form(""),
    gender: str = Form(...),
    bank_id: str = Form(""),
):
    db = get_db()

    if gender not in ALLOWED_GENDERS:
        raise HTTPException(status_code=400, detail="Invalid gender selected")

    existing = await db.delivery_partners.find_one({"email": email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    partner_id = await get_next_id("delivery_partners")
    now = _utc_now()
    await db.delivery_partners.insert_one(
        {
            "id": partner_id,
            "name": name,
            "email": email,
            "password": hash_password(password),
            "phone": phone,
            "gender": gender,
            "bank_id": bank_id,
            "is_active": True,
            "deliveries_completed": 0,
            "total_earnings": 0.0,
            "created_at": now,
        }
    )

    token = str(uuid.uuid4())
    await db.delivery_sessions.insert_one({"token": token, "partner_id": partner_id, "created_at": now})

    partner = await db.delivery_partners.find_one({"id": partner_id})
    return _partner_payload(partner, token)


@router.post("/login")
async def login_delivery_partner(email: str = Form(...), password: str = Form(...)):
    db = get_db()

    partner = await db.delivery_partners.find_one({"email": email})
    if not partner or not verify_password(password, partner.get("password", "")):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not partner.get("is_active", True):
        raise HTTPException(status_code=403, detail="Delivery partner account is inactive")

    token = str(uuid.uuid4())
    await db.delivery_sessions.insert_one(
        {
            "token": token,
            "partner_id": partner["id"],
            "created_at": _utc_now(),
        }
    )

    return _partner_payload(partner, token)


@router.get("/me")
async def delivery_me(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    partner = await _get_partner_from_token(token)
    return _partner_payload(partner)


@router.put("/bank-id")
async def update_bank_id(
    authorization: str = Header(...),
    bank_id: str = Form(...),
):
    token = authorization.replace("Bearer ", "")
    partner = await _get_partner_from_token(token)
    db = get_db()

    await db.delivery_partners.update_one(
        {"id": partner["id"]},
        {"$set": {"bank_id": bank_id}},
    )

    return {"status": "updated", "bank_id": bank_id}


@router.get("/orders/available")
async def list_available_delivery_orders(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    partner = await _get_partner_from_token(token)
    db = get_db()

    partner_gender = partner.get("gender", "")

    base_query = {
        "status": "ready",
        "fulfillment_mode": {"$in": list(ALLOWED_FULFILLMENT_MODES)},
        "$or": [
            {"delivery_partner_id": None},
            {"delivery_partner_id": {"$exists": False}},
        ],
    }
    # Gender-based filtering: show orders from same-gender customers,
    # but also include orders where customer gender is not set, or gender-neutral "Neutral"
    if partner_gender:
        query = {
            "$and": [
                base_query,
                {
                    "$or": [
                        {"customer_gender": partner_gender},
                        {"customer_gender": "Neutral"},
                        {"customer_gender": ""},
                        {"customer_gender": {"$exists": False}},
                    ]
                },
            ]
        }
    else:
        query = base_query

    cursor = db.orders.find(query, {"_id": 0}).sort("created_at", 1)

    orders = []
    async for order in cursor:
        rest = await db.restaurants.find_one({"id": order["restaurant_id"]}, {"name": 1, "address": 1})
        user = await db.users.find_one(
            {"id": order["user_id"]},
            {"username": 1, "phone": 1, "hostel": 1, "college_name": 1, "identification": 1}
        )
        order["restaurant_name"] = rest["name"] if rest else ""
        order["restaurant_address"] = rest.get("address", "") if rest else ""
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


@router.post("/orders/{order_id}/accept")
async def accept_delivery_order(order_id: int, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    partner = await _get_partner_from_token(token)
    db = get_db()

    order = await db.orders.find_one({"id": order_id})
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.get("fulfillment_mode") not in ALLOWED_FULFILLMENT_MODES:
        raise HTTPException(status_code=400, detail="Order is not marked for delivery")

    if order.get("status") != "ready":
        raise HTTPException(status_code=400, detail="Only ready orders can be accepted")

    if order.get("delivery_partner_id") not in (None, partner["id"]):
        raise HTTPException(status_code=409, detail="Order already accepted by another partner")

    now = _utc_now()
    result = await db.orders.update_one(
        {
            "id": order_id,
            "status": "ready",
            "fulfillment_mode": {"$in": list(ALLOWED_FULFILLMENT_MODES)},
            "$or": [
                {"delivery_partner_id": None},
                {"delivery_partner_id": partner["id"]},
                {"delivery_partner_id": {"$exists": False}},
            ],
        },
        {
            "$set": {
                "delivery_partner_id": partner["id"],
                "delivery_partner_name": partner.get("name", ""),
                "delivery_assigned_at": now,
                "delivery_stage": "assigned",
                "delivery_fee": float(order.get("delivery_fee", DEFAULT_DELIVERY_FEE)),
            }
        },
    )
    if result.modified_count == 0:
        raise HTTPException(status_code=409, detail="Order is no longer available")

    return {
        "status": "assigned",
        "order_id": order_id,
        "delivery_partner_id": partner["id"],
    }


@router.get("/orders/active")
async def list_active_delivery_orders(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    partner = await _get_partner_from_token(token)
    db = get_db()

    cursor = db.orders.find(
        {
            "delivery_partner_id": partner["id"],
            "fulfillment_mode": {"$in": list(ALLOWED_FULFILLMENT_MODES)},
            "status": {"$ne": "given"},
        },
        {"_id": 0},
    ).sort("created_at", -1)

    orders = []
    async for order in cursor:
        rest = await db.restaurants.find_one({"id": order["restaurant_id"]}, {"name": 1, "address": 1})
        user = await db.users.find_one(
            {"id": order["user_id"]},
            {"username": 1, "phone": 1, "hostel": 1, "gender": 1, "college_name": 1},
        )
        order["restaurant_name"] = rest["name"] if rest else ""
        order["restaurant_address"] = rest.get("address", "") if rest else ""
        order["customer_name"] = user.get("username", "") if user else ""
        order["customer_phone"] = user.get("phone", "") if user else ""
        order["customer_hostel"] = user.get("hostel", "") if user else ""
        order["customer_gender"] = user.get("gender", "") if user else ""
        order["customer_college"] = user.get("college_name", "") if user else ""
        orders.append(order)

    return {"orders": orders}


@router.post("/orders/{order_id}/pickup")
async def mark_order_picked_up(order_id: int, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    partner = await _get_partner_from_token(token)
    db = get_db()

    order = await db.orders.find_one({"id": order_id})
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.get("fulfillment_mode") not in ALLOWED_FULFILLMENT_MODES:
        raise HTTPException(status_code=400, detail="Order is not marked for delivery")

    if order.get("delivery_partner_id") != partner["id"]:
        raise HTTPException(status_code=403, detail="Order is not assigned to you")

    if order.get("status") != "ready":
        raise HTTPException(status_code=400, detail="Order cannot be picked up in current state")

    await db.orders.update_one(
        {"id": order_id},
        {
            "$set": {
                "delivery_stage": "picked_up",
                "delivery_picked_up_at": _utc_now(),
            }
        },
    )

    return {"status": "picked_up", "order_id": order_id}


@router.post("/orders/{order_id}/complete")
async def complete_delivery_order(order_id: int, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    partner = await _get_partner_from_token(token)
    db = get_db()

    order = await db.orders.find_one({"id": order_id})
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.get("fulfillment_mode") not in ALLOWED_FULFILLMENT_MODES:
        raise HTTPException(status_code=400, detail="Order is not marked for delivery")

    if order.get("delivery_partner_id") != partner["id"]:
        raise HTTPException(status_code=403, detail="Order is not assigned to you")

    if order.get("status") == "given":
        return {
            "status": "given",
            "order_id": order_id,
            "delivery_fee": float(order.get("delivery_fee", DEFAULT_DELIVERY_FEE)),
        }

    if order.get("status") != "ready":
        raise HTTPException(status_code=400, detail="Order cannot be completed in current state")

    now = _utc_now()
    delivery_fee = float(order.get("delivery_fee", DEFAULT_DELIVERY_FEE))

    await db.orders.update_one(
        {"id": order_id},
        {
            "$set": {
                "status": "given",
                "delivery_stage": "delivered",
                "delivery_completed_at": now,
                "delivery_fee": delivery_fee,
                "user_acknowledged": False,
            }
        },
    )

    await db.delivery_partners.update_one(
        {"id": partner["id"]},
        {
            "$inc": {
                "deliveries_completed": 1,
                "total_earnings": delivery_fee,
            },
            "$set": {
                "last_delivery_at": now,
            },
        },
    )

    updated_order = await db.orders.find_one({"id": order_id}, {"_id": 0})
    if updated_order:
        await log_completed_order(updated_order)

    return {
        "status": "given",
        "order_id": order_id,
        "delivery_fee": delivery_fee,
    }


@router.get("/earnings/summary")
async def delivery_earnings_summary(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    partner = await _get_partner_from_token(token)
    db = get_db()

    pipeline = [
        {
            "$match": {
                "delivery_partner_id": partner["id"],
                "fulfillment_mode": {"$in": list(ALLOWED_FULFILLMENT_MODES)},
                "status": "given",
            }
        },
        {
            "$group": {
                "_id": None,
                "deliveries": {"$sum": 1},
                "earnings": {"$sum": {"$ifNull": ["$delivery_fee", DEFAULT_DELIVERY_FEE]}},
            }
        },
    ]

    result = await db.orders.aggregate(pipeline).to_list(length=1)
    summary = result[0] if result else {"deliveries": 0, "earnings": 0.0}

    # Fetch completed orders details for this partner
    completed_cursor = db.orders.find(
        {
            "delivery_partner_id": partner["id"],
            "fulfillment_mode": {"$in": list(ALLOWED_FULFILLMENT_MODES)},
            "status": "given",
        },
        {"_id": 0}
    ).sort("delivery_completed_at", -1)

    completed_orders = []
    async for order in completed_cursor:
        rest = await db.restaurants.find_one({"id": order["restaurant_id"]}, {"name": 1})
        user = await db.users.find_one(
            {"id": order["user_id"]},
            {"username": 1, "phone": 1, "hostel": 1, "college_name": 1, "identification": 1}
        )
        order["restaurant_name"] = rest["name"] if rest else ""
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
        completed_orders.append(order)

    return {
        "partner_id": partner["id"],
        "deliveries": int(summary.get("deliveries", 0)),
        "earnings": float(summary.get("earnings", 0.0)),
        "orders": completed_orders,
    }
