"""Database initialization and seeding for MongoDB."""
import asyncio
import os
from database import connect_db, close_db, get_db, get_next_id
from Databases.hashing import hash_password


async def init_db():
    """Initialize the database with seed data if empty."""
    db = get_db()

    # Seed admin accounts if none exist
    admins_count = await db.admins.count_documents({})
    if admins_count == 0:
        print("[DB] Seeding admin accounts...")
        seed_admins = [
            {
                "email": "ssnadmin@ssn.in",
                "password": hash_password("admin123"),
                "college_name": "SSN/SNU"
            },
            {
                "email": "recadmin@rec.in",
                "password": hash_password("admin123"),
                "college_name": "REC"
            },
            {
                "email": "vitadmin@vit.in",
                "password": hash_password("admin123"),
                "college_name": "VITC"
            }
        ]
        await db.admins.insert_many(seed_admins)

    # Check and seed colleges/buildings list
    colleges_count = await db.colleges.count_documents({})
    if colleges_count == 0:
        print("[DB] Seeding colleges and buildings...")
        seed_colleges = [
            {
                "name": "SSN/SNU",
                "buildings": [
                    { "name": "LH1", "gender": "Female" },
                    { "name": "LH2", "gender": "Female" },
                    { "name": "LH3", "gender": "Female" },
                    { "name": "LH4", "gender": "Female" },
                    { "name": "LH5", "gender": "Female" },
                    { "name": "GH1", "gender": "Male" },
                    { "name": "GH2", "gender": "Male" },
                    { "name": "GH3", "gender": "Male" },
                    { "name": "GH4", "gender": "Male" },
                    { "name": "GH5", "gender": "Male" },
                    { "name": "GH6", "gender": "Male" },
                    { "name": "GH7", "gender": "Male" },
                    { "name": "GH8", "gender": "Male" },
                    { "name": "GH9", "gender": "Male" },
                    { "name": "CSE", "gender": "Neutral" },
                    { "name": "IT", "gender": "Neutral" },
                    { "name": "ANNEXURE", "gender": "Neutral" },
                    { "name": "ECE", "gender": "Neutral" },
                    { "name": "EEE", "gender": "Neutral" },
                    { "name": "CHEM", "gender": "Neutral" },
                    { "name": "MECH", "gender": "Neutral" },
                    { "name": "BIOMED", "gender": "Neutral" }
                ]
            },
            {
                "name": "VITC",
                "buildings": [
                    { "name": "Main Block", "gender": "Neutral" },
                    { "name": "Hostel 1", "gender": "Neutral" },
                    { "name": "Hostel 2", "gender": "Neutral" }
                ]
            },
            {
                "name": "REC",
                "buildings": [
                    { "name": "Main Block", "gender": "Neutral" },
                    { "name": "Hostel 1", "gender": "Neutral" },
                    { "name": "Hostel 2", "gender": "Neutral" }
                ]
            }
        ]
        await db.colleges.insert_many(seed_colleges)

    # Check if restaurants already seeded
    count = await db.restaurants.count_documents({})
    if count > 0:
        print("[DB] Database already initialized")
        # Backfill college_name for legacy restaurants
        await db.restaurants.update_many({"college_name": {"$exists": False}}, {"$set": {"college_name": "SSN/SNU"}})
        return

    print("[DB] Seeding database...")
    os.makedirs("uploads", exist_ok=True)

    # Seed restaurants
    seed_restaurants = [
        {
            "name": "Rishabs FoodCourt",
            "email": "rfcssn@ssncanteen.in",
            "description": "The best food court on campus",
            "cuisine_type": "Multi-Cuisine",
            "address": "Main Block, Ground Floor",
            "phone": "9876543210",
            "password": hash_password("rfcssn@ezfoodz"),
            "image_path": "",
            "is_open": True,
            "rating": 4.2,
        },
        {
            "name": "Main Canteen",
            "email": "mcssn@ssncanteen.in",
            "description": "The main campus canteen with a wide variety of meals",
            "cuisine_type": "Indian",
            "address": "Main Block, First Floor",
            "phone": "9876543211",
            "password": hash_password("mcssn@ezfoodz"),
            "image_path": "",
            "is_open": True,
            "rating": 4.5,
        },
        {
            "name": "Ashwins FoodCourt",
            "email": "afcssn@ssncanteen.in",
            "description": "Delicious food and snacks",
            "cuisine_type": "South Indian",
            "address": "South Block, Ground Floor",
            "phone": "9876543212",
            "password": hash_password("afcssn@ezfoodz"),
            "image_path": "",
            "is_open": True,
            "rating": 4.0,
        },
        {
            "name": "Snow Cube",
            "email": "scssn@ssncanteen.in",
            "description": "Cool drinks, shakes and frozen treats",
            "cuisine_type": "Beverages",
            "address": "Near Library",
            "phone": "9876543213",
            "password": hash_password("scssn@ezfoodz"),
            "image_path": "",
            "is_open": True,
            "rating": 4.6,
        },
    ]

    for rest in seed_restaurants:
        rest["id"] = await get_next_id("restaurants")
        rest["college_name"] = "SSN/SNU"
        await db.restaurants.insert_one(rest)

    # Seed menu items
    items = [
        (1, "Chicken Biryani", "non-veg", "Indian", 120),
        (1, "Veg Biryani", "veg", "Indian", 90),
        (1, "Chicken Fried Rice", "non-veg", "Chinese", 100),
        (1, "Paneer Butter Masala", "veg", "Indian", 110),
        (1, "Chapati (2 pcs)", "veg", "Indian", 30),
        (1, "Notebook", "stationary", "", 40),
        (2, "Masala Dosa", "veg", "South Indian", 50),
        (2, "Idli (3 pcs)", "veg", "South Indian", 30),
        (2, "Chicken Samosa", "non-veg", "South Indian", 25),
        (2, "Filter Coffee", "veg", "Beverages", 20),
        (2, "Vada (2 pcs)", "veg", "South Indian", 25),
        (3, "Maggi", "veg", "Quick Bites", 30),
        (3, "Egg Maggi", "non-veg", "Quick Bites", 40),
        (3, "Bread Omelette", "non-veg", "Quick Bites", 35),
        (3, "Tea", "veg", "Beverages", 10),
        (3, "Pen", "stationary", "", 10),
        (4, "Mango Juice", "veg", "Beverages", 40),
        (4, "Watermelon Juice", "veg", "Beverages", 35),
        (4, "Banana Shake", "veg", "Beverages", 50),
        (4, "Peanut Butter Sandwich", "veg", "Quick Bites", 45),
    ]

    for restaurant_id, name, category, cuisine, price in items:
        item_id = await get_next_id("menu_items")
        await db.menu_items.insert_one({
            "id": item_id,
            "restaurant_id": restaurant_id,
            "name": name,
            "category": category,
            "cuisine": cuisine,
            "price": price,
            "is_available": True,
        })

    print("[DB] Database initialized with seed data")


async def main():
    await connect_db()
    await init_db()
    await close_db()


if __name__ == "__main__":
    asyncio.run(main())
