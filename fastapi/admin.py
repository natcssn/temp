import uuid
from typing import List
from fastapi import APIRouter, HTTPException, Header, Body
from datetime import datetime
from pydantic import BaseModel
from pymongo.errors import DuplicateKeyError

from database import get_db, get_next_id
from Databases.hashing import hash_password

router = APIRouter(prefix="/admin-api", tags=["Admin Dashboard"])

class AdminLoginRequest(BaseModel):
    email: str
    password: str

class BuildingItem(BaseModel):
    name: str
    gender: str  # Male, Female, Neutral

class BuildingsUpdateRequest(BaseModel):
    buildings: List[BuildingItem]

class RestaurantCreateRequest(BaseModel):
    name: str
    email: str
    description: str
    cuisine_type: str
    address: str
    phone: str
    password: str

class RestaurantUpdateRequest(BaseModel):
    name: str
    description: str
    cuisine_type: str
    address: str
    phone: str
    is_open: bool


async def _get_admin_from_token(token: str):
    db = get_db()
    session = await db.admin_sessions.find_one({"token": token})
    if not session:
        raise HTTPException(status_code=401, detail="Invalid admin session token")
    return session


from Databases.hashing import verify_password

@router.post("/login")
async def admin_login(payload: AdminLoginRequest):
    email = payload.email.strip().lower()
    password = payload.password
    
    db = get_db()
    admin_doc = await db.admins.find_one({"email": email})
    if not admin_doc:
        raise HTTPException(status_code=401, detail="Invalid admin email or password")
        
    if not verify_password(password, admin_doc["password"]):
        raise HTTPException(status_code=401, detail="Invalid admin email or password")
        
    college_name = admin_doc["college_name"]
    
    # Generate admin session
    token = str(uuid.uuid4())
    await db.admin_sessions.insert_one({
        "token": token,
        "email": email,
        "college_name": college_name
    })
    
    return {
        "token": token,
        "email": email,
        "college_name": college_name,
        "status": "success"
    }


@router.post("/logout")
async def admin_logout(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    db = get_db()
    await db.admin_sessions.delete_one({"token": token})
    return {"status": "success"}


@router.get("/me")
async def get_admin_me(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    session = await _get_admin_from_token(token)
    return {
        "email": session["email"],
        "college_name": session["college_name"]
    }


@router.get("/stats")
async def get_admin_stats(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    session = await _get_admin_from_token(token)
    college_name = session["college_name"]
    
    db = get_db()
    
    # Total Users registered under this college
    users_count = await db.users.count_documents({"college_name": college_name})
    
    # Total Restaurants under this college
    restaurants_count = await db.restaurants.count_documents({"college_name": college_name})
    
    # Get all restaurant IDs for this college
    restaurant_cursor = db.restaurants.find({"college_name": college_name}, {"id": 1})
    restaurant_ids = [r["id"] async for r in restaurant_cursor]
    
    completed_orders_count = 0
    total_earnings = 0.0
    
    if restaurant_ids:
        # Total Completed Orders for these restaurants
        completed_orders_count = await db.orders.count_documents({
            "restaurant_id": {"$in": restaurant_ids},
            "status": "given"
        })
        
        # Total Earnings for these completed orders
        pipeline = [
            {"$match": {"restaurant_id": {"$in": restaurant_ids}, "status": "given"}},
            {"$group": {"_id": None, "total": {"$sum": "$total"}}}
        ]
        agg_result = await db.orders.aggregate(pipeline).to_list(length=1)
        if agg_result:
            total_earnings = agg_result[0].get("total", 0.0)
            
    return {
        "users": users_count,
        "restaurants": restaurants_count,
        "completed_orders": completed_orders_count,
        "total_earnings": round(total_earnings, 2)
    }


@router.get("/buildings")
async def get_admin_buildings(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    session = await _get_admin_from_token(token)
    college_name = session["college_name"]
    
    db = get_db()
    college_doc = await db.colleges.find_one({"name": college_name})
    if not college_doc:
        return {"buildings": []}
    return {"buildings": college_doc.get("buildings", [])}


@router.post("/buildings")
async def update_admin_buildings(payload: BuildingsUpdateRequest, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    session = await _get_admin_from_token(token)
    college_name = session["college_name"]
    
    db = get_db()
    buildings_data = [b.model_dump() for b in payload.buildings]
    
    await db.colleges.update_one(
        {"name": college_name},
        {"$set": {"buildings": buildings_data}},
        upsert=True
    )
    return {"status": "success", "buildings": buildings_data}


@router.get("/restaurants")
async def get_admin_restaurants(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    session = await _get_admin_from_token(token)
    college_name = session["college_name"]
    
    db = get_db()
    cursor = db.restaurants.find({"college_name": college_name}, {"_id": 0, "password": 0})
    restaurants_list = [r async for r in cursor]
    return {"restaurants": restaurants_list}


@router.post("/restaurants")
async def create_admin_restaurant(payload: RestaurantCreateRequest, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    session = await _get_admin_from_token(token)
    college_name = session["college_name"]
    
    db = get_db()
    existing = await db.restaurants.find_one({"email": payload.email.strip().lower()})
    if existing:
        raise HTTPException(status_code=400, detail="Restaurant email already registered")
        
    restaurant_id = await get_next_id("restaurants")
    
    restaurant_doc = {
        "id": restaurant_id,
        "name": payload.name.strip(),
        "email": payload.email.strip().lower(),
        "description": payload.description.strip(),
        "cuisine_type": payload.cuisine_type.strip(),
        "address": payload.address.strip(),
        "phone": payload.phone.strip(),
        "password": hash_password(payload.password),
        "image_path": "",
        "is_open": True,
        "rating": 4.0,
        "college_name": college_name
    }
    
    await db.restaurants.insert_one(restaurant_doc)
    return {"status": "success", "restaurant_id": restaurant_id}


@router.put("/restaurants/{restaurant_id}")
async def update_admin_restaurant(restaurant_id: int, payload: RestaurantUpdateRequest, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    session = await _get_admin_from_token(token)
    college_name = session["college_name"]
    
    db = get_db()
    
    # Double check restaurant belongs to this admin's college
    rest = await db.restaurants.find_one({"id": restaurant_id})
    if not rest:
        raise HTTPException(status_code=404, detail="Restaurant not found")
        
    if rest.get("college_name") != college_name:
        raise HTTPException(status_code=403, detail="Not authorized to edit restaurants in other colleges")
        
    await db.restaurants.update_one(
        {"id": restaurant_id},
        {"$set": {
            "name": payload.name.strip(),
            "description": payload.description.strip(),
            "cuisine_type": payload.cuisine_type.strip(),
            "address": payload.address.strip(),
            "phone": payload.phone.strip(),
            "is_open": payload.is_open
        }}
    )
    return {"status": "success"}


import os
from fastapi.responses import FileResponse

@router.get("/logs/months")
async def get_log_months(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    await _get_admin_from_token(token)
    
    log_dir = "monthly logs"
    months_set = set()
    
    # 1. Add current calendar month
    current_month = datetime.now().strftime("%Y-%m")
    months_set.add(current_month)
    
    # 2. Add subfolders on disk
    if os.path.exists(log_dir):
        for d in os.listdir(log_dir):
            if os.path.isdir(os.path.join(log_dir, d)):
                if len(d) == 7 and d[4] == '-':
                    months_set.add(d)
                    
    # 3. Add months present in MongoDB monthly_logs collection
    db = get_db()
    try:
        distinct_months = await db.monthly_logs.distinct("month")
        for m in distinct_months:
            if m:
                months_set.add(str(m))
    except Exception as e:
        print("Failed to fetch distinct months from db:", e)
        
    months = list(months_set)
    # Sort months descending
    months.sort(reverse=True)
    return {"months": months}


@router.get("/logs/payouts")
async def get_log_payouts(month: str, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    session = await _get_admin_from_token(token)
    college_name = session["college_name"]
    
    db = get_db()
    
    # 1. Fetch all restaurants in this college
    rest_cursor = db.restaurants.find({"college_name": college_name}, {"id": 1, "name": 1})
    restaurants_map = {r["id"]: r["name"] for r in await rest_cursor.to_list(length=100)}
    restaurant_ids = list(restaurants_map.keys())
    
    if not restaurant_ids:
        return {
            "canteen_payouts": [],
            "delivery_payouts": [],
            "raw_csv_files": []
        }
        
    # 2. Query monthly logs matching these restaurant IDs and the selected month
    logs_cursor = db.monthly_logs.find({
        "restaurant_id": {"$in": restaurant_ids},
        "month": month
    }, {"_id": 0})
    
    logs = await logs_cursor.to_list(length=100000)
    
    # 3. Calculate Canteen Payouts
    canteen_payouts_dict = {}
    for r_id, r_name in restaurants_map.items():
        canteen_payouts_dict[r_id] = {
            "restaurant_id": r_id,
            "name": r_name,
            "transactions_count": 0,
            "gross_amount": 0.0,
            "restaurant_share": 0.0
        }
        
    # 4. Calculate Delivery Partner Payouts
    delivery_payouts_dict = {}
    
    for log in logs:
        r_id = log.get("restaurant_id")
        if r_id in canteen_payouts_dict:
            canteen_payouts_dict[r_id]["transactions_count"] += 1
            canteen_payouts_dict[r_id]["gross_amount"] += log.get("gross_amount", 0.0)
            canteen_payouts_dict[r_id]["restaurant_share"] += log.get("restaurant_share", log.get("gross_amount", 0.0))
            
        dp_id = log.get("delivery_partner_id")
        dp_name = log.get("delivery_partner_name")
        dp_share = log.get("delivery_share", 0.0)
        
        # Only group delivery partner if they actually participated in this order
        if dp_id is not None and dp_share > 0:
            if dp_id not in delivery_payouts_dict:
                delivery_payouts_dict[dp_id] = {
                    "delivery_partner_id": dp_id,
                    "name": dp_name or f"Partner #{dp_id}",
                    "deliveries_count": 0,
                    "delivery_share": 0.0
                }
            delivery_payouts_dict[dp_id]["deliveries_count"] += 1
            delivery_payouts_dict[dp_id]["delivery_share"] += dp_share

    # Format payouts as sorted lists
    canteen_payouts = list(canteen_payouts_dict.values())
    for c in canteen_payouts:
        c["gross_amount"] = round(c["gross_amount"], 2)
        c["restaurant_share"] = round(c["restaurant_share"], 2)
        
    delivery_payouts = list(delivery_payouts_dict.values())
    for d in delivery_payouts:
        d["delivery_share"] = round(d["delivery_share"], 2)
        
    # 5. List raw CSV files that exist for this admin's college restaurants
    raw_csv_files = []
    month_folder = os.path.join("monthly logs", month)
    if os.path.exists(month_folder):
        for r_id, r_name in restaurants_map.items():
            filename = f"restaurant_{r_id}.csv"
            filepath = os.path.join(month_folder, filename)
            if os.path.exists(filepath):
                raw_csv_files.append({
                    "restaurant_id": r_id,
                    "restaurant_name": r_name,
                    "filename": filename,
                    "size_bytes": os.path.getsize(filepath)
                })
                
    return {
        "canteen_payouts": canteen_payouts,
        "delivery_payouts": delivery_payouts,
        "raw_csv_files": raw_csv_files
    }


@router.get("/logs/download")
async def download_log_file(month: str, restaurant_id: int, authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    session = await _get_admin_from_token(token)
    college_name = session["college_name"]
    
    db = get_db()
    
    # Security: Verify restaurant belongs to this admin's college
    rest = await db.restaurants.find_one({"id": restaurant_id})
    if not rest or rest.get("college_name") != college_name:
        raise HTTPException(status_code=403, detail="Not authorized to access log files for other colleges")
        
    filepath = os.path.join("monthly logs", month, f"restaurant_{restaurant_id}.csv")
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Log file not found")
        
    return FileResponse(
        filepath,
        media_type="text/csv",
        filename=f"transactions_{rest['name'].replace(' ', '_')}_{month}.csv"
    )
