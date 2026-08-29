from fastapi import APIRouter, Form, HTTPException, Header, Body, UploadFile, File
from database import get_db, get_next_id
from Databases.hashing import hash_password, verify_password
import uuid
import os
import shutil
from datetime import datetime, timezone
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/auth", tags=["Authentication"])

ALLOWED_DOMAINS = {
    "ssn.edu.in": "SSN/SNU",
    "snu.edu.in": "SSN/SNU",
    "rajalakshmi.edu.in": "REC",
    "vit.ac.in": "VITC",
}

class DeliveryDetailsUpdate(BaseModel):
    username: str
    phone: str
    hostel: str
    gender: str
    identification: Optional[str] = ""

async def _get_user_from_token(token: str):
    db = get_db()
    session = await db.user_sessions.find_one({"token": token})
    if not session:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = await db.users.find_one({"id": session["user_id"]})
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user


@router.post("/login")
async def login(email: str = Form(...), password: str = Form(...)):
    db = get_db()

    user = await db.users.find_one({"email": email, "auth_provider": "email"})
    if not user or not verify_password(password, user["password"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token = str(uuid.uuid4())
    await db.user_sessions.insert_one({"token": token, "user_id": user["id"]})

    return {
        "user_id": user["id"],
        "token": token,
        "username": user.get("username", ""),
        "email": email,
        "college_name": user.get("college_name", ""),
        "gender": user.get("gender", ""),
        "hostel": user.get("hostel", ""),
        "phone": user.get("phone", ""),
        "identification": user.get("identification", ""),
        "id_card_verified": user.get("id_card_verified", False),
        "id_card_verification_message": user.get("id_card_verification_message", ""),
    }


@router.post("/google")
async def google_auth(
    email: str = Form(...),
    firebase_uid: str = Form(...),
    username: str = Form(""),
):
    db = get_db()

    # Domain validation
    domain = email.split("@")[-1].lower() if "@" in email else ""
    if domain not in ALLOWED_DOMAINS:
        raise HTTPException(status_code=403, detail=f"Domain @{domain} is not allowed. Please use your college email.")
    
    college_name = ALLOWED_DOMAINS[domain]

    user = await db.users.find_one({"firebase_uid": firebase_uid})

    if user:
        user_id = user["id"]
        # Update username if provided
        profile_updates = {"college_name": college_name}
        if username and not user.get("username"):
            profile_updates["username"] = username
        await db.users.update_one({"id": user_id}, {"$set": profile_updates})
        
        uname = profile_updates.get("username", user.get("username", ""))
        user_college = college_name
        user_gender = user.get("gender", "")
        user_hostel = user.get("hostel", "")
        user_phone = user.get("phone", "")
        user_ident = user.get("identification", "")
    else:
        # Check if email exists with different provider
        existing = await db.users.find_one({"email": email, "auth_provider": "email"})
        if existing:
            # Link accounts
            updates = {"firebase_uid": firebase_uid, "auth_provider": "google", "college_name": college_name}
            await db.users.update_one(
                {"id": existing["id"]},
                {"$set": updates}
            )
            user_id = existing["id"]
            uname = existing.get("username", username)
            user_college = college_name
            user_gender = existing.get("gender", "")
            user_hostel = existing.get("hostel", "")
            user_phone = existing.get("phone", "")
            user_ident = existing.get("identification", "")
        else:
            # Create new user
            user_id = await get_next_id("users")
            await db.users.insert_one({
                "id": user_id,
                "firebase_uid": firebase_uid,
                "email": email,
                "username": username,
                "password": "",
                "address": "",
                "auth_provider": "google",
                "college_name": college_name,
                "gender": "",
                "hostel": "",
                "phone": "",
                "identification": "",
                "id_card_verified": True, # implicitly verified via domain
                "id_card_verification_message": "Domain Verified",
            })
            uname = username
            user_college = college_name
            user_gender = ""
            user_hostel = ""
            user_phone = ""
            user_ident = ""

    token = str(uuid.uuid4())
    await db.user_sessions.insert_one({"token": token, "user_id": user_id})

    # Fetch updated user to get verification fields
    db_user = await db.users.find_one({"id": user_id})
    id_card_verified = db_user.get("id_card_verified", False) if db_user else False
    id_card_verification_message = db_user.get("id_card_verification_message", "") if db_user else ""

    return {
        "user_id": user_id,
        "token": token,
        "username": uname,
        "email": email,
        "college_name": user_college,
        "gender": user_gender,
        "hostel": user_hostel,
        "phone": user_phone,
        "identification": user_ident,
        "id_card_verified": id_card_verified,
        "id_card_verification_message": id_card_verification_message,
    }


@router.get("/colleges")
async def list_colleges():
    return {"colleges": list(set(ALLOWED_DOMAINS.values()))}


@router.put("/me/delivery-details")
async def update_delivery_details(
    details: DeliveryDetailsUpdate,
    authorization: str = Header(...)
):
    token = authorization.replace("Bearer ", "")
    user = await _get_user_from_token(token)
    
    db = get_db()
    await db.users.update_one(
        {"id": user["id"]},
        {"$set": {
            "username": details.username,
            "phone": details.phone,
            "hostel": details.hostel,
            "gender": details.gender,
            "identification": details.identification,
        }}
    )
    return {"status": "success"}


@router.get("/me")
async def get_me(authorization: str = Header(...)):
    token = authorization.replace("Bearer ", "")
    user = await _get_user_from_token(token)
    user.pop("_id", None)
    user.pop("password", None)
    return user


@router.post("/register")
async def register(
    email: str = Form(...),
    password: str = Form(...),
    username: str = Form(...),
    college_name: str = Form(...),
    gender: str = Form(...),
    hostel: str = Form(...),
    phone: str = Form(...),
):
    db = get_db()
    domain = email.split("@")[-1].lower() if "@" in email else ""
    if domain not in ALLOWED_DOMAINS:
        raise HTTPException(status_code=403, detail=f"Domain @{domain} is not allowed. Please use your college email.")
    
    expected_college = ALLOWED_DOMAINS[domain]
    if college_name != expected_college:
        raise HTTPException(status_code=400, detail="Selected college does not match email domain")

    existing = await db.users.find_one({"email": email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user_id = await get_next_id("users")
    user_doc = {
        "id": user_id,
        "email": email,
        "password": hash_password(password),
        "username": username,
        "college_name": college_name,
        "gender": gender,
        "hostel": hostel,
        "phone": phone,
        "identification": "",
        "auth_provider": "email",
        "id_card_verified": False,
        "id_card_verification_message": "Awaiting verification",
        "id_card_image": "",
    }
    await db.users.insert_one(user_doc)

    token = str(uuid.uuid4())
    await db.user_sessions.insert_one({"token": token, "user_id": user_id})

    return {
        "user_id": user_id,
        "token": token,
        "username": username,
        "email": email,
        "college_name": college_name,
        "gender": gender,
        "hostel": hostel,
        "phone": phone,
        "identification": "",
        "id_card_verified": False,
        "id_card_verification_message": "Awaiting verification",
    }


@router.post("/id-card")
async def upload_id_card(
    file: UploadFile = File(...),
    authorization: str = Header(...)
):
    token = authorization.replace("Bearer ", "")
    user = await _get_user_from_token(token)
    
    file_ext = os.path.splitext(file.filename)[1]
    filename = f"user_{user['id']}{file_ext}"
    file_path = os.path.join("uploads", filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    db = get_db()
    image_url = f"/uploads/{filename}"
    await db.users.update_one(
        {"id": user["id"]},
        {"$set": {"id_card_image": image_url}}
    )
    return {"status": "success", "id_card_image": image_url}


@router.post("/verify-id-card")
async def verify_id_card_endpoint(
    authorization: str = Header(...)
):
    token = authorization.replace("Bearer ", "")
    user = await _get_user_from_token(token)
    
    if not user.get("id_card_image"):
        raise HTTPException(status_code=400, detail="No ID card image uploaded")
        
    image_relative_path = user["id_card_image"].lstrip("/")
    if not os.path.exists(image_relative_path):
        raise HTTPException(status_code=400, detail="Uploaded ID card file not found on server")
        
    from id_card_verification import verify_college_from_id_card
    success, message, extracted_text, provider = verify_college_from_id_card(
        image_relative_path, user["college_name"]
    )
    
    db = get_db()
    await db.users.update_one(
        {"id": user["id"]},
        {
            "$set": {
                "id_card_verified": success,
                "id_card_verification_message": message,
            }
        }
    )
    
    if not success:
        raise HTTPException(status_code=400, detail=message)
        
    return {
        "status": "success",
        "message": message,
        "extracted_text": extracted_text,
        "provider": provider,
    }


@router.get("/colleges-with-buildings")
async def get_colleges_with_buildings():
    db = get_db()
    cursor = db.colleges.find({}, {"_id": 0})
    colleges_list = []
    async for col in cursor:
        colleges_list.append(col)
    return {"colleges": colleges_list}

