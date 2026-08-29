from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from database import connect_db, close_db
from init_db import init_db
from auth import router as auth_router
from restaurant_auth import router as restaurant_auth_router
from restaurants import router as restaurants_router
from menu_items import router as menu_items_router
from orders import router as orders_router
from payments import router as payments_router
from delivery_partner import router as delivery_partner_router
from admin import router as admin_router
import os


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await connect_db()
    await init_db()
    yield
    # Shutdown
    await close_db()


app = FastAPI(title="EZFOODZ API", version="3.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
os.makedirs("uploads", exist_ok=True)
os.makedirs("static/dashboard", exist_ok=True)
os.makedirs("admin_dashboard", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
app.mount("/dashboard", StaticFiles(directory="static/dashboard", html=True), name="dashboard")
app.mount("/admin", StaticFiles(directory="admin_dashboard", html=True), name="admin")

# Include routers
app.include_router(auth_router)
app.include_router(restaurant_auth_router)
app.include_router(restaurants_router)
app.include_router(menu_items_router)
app.include_router(orders_router)
app.include_router(payments_router)
app.include_router(delivery_partner_router)
app.include_router(admin_router)


@app.get("/")
def root():
    return {"status": "EZFOODZ backend running", "version": "3.0", "database": "MongoDB"}
