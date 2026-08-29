# EZFOODZ — Campus Food Ordering System

A complete multi-platform food ordering system for college campuses, featuring a **FastAPI backend**, a **React Restaurant Dashboard**, a **Vanilla HTML Dashboard**, and a **Flutter Customer App** (Windows, Web, Android, iOS).

---

## Current Build Status (2026-04-19)

- **Phase strategy active**: implementation is being delivered in multiple phases (not big-bang).
- **Already implemented in code**:
  - Required college selection at signup (fixed allowed colleges)
  - Required ID CARD upload flow at signup
  - Backend support for ID-card upload endpoint and profile verification fields
  - Free OCR/CV college-name verification path (rapidocr local + Hugging Face fallback)
  - Google OAuth button gating (disabled until college + ID CARD prerequisites are provided)
  - Razorpay TEST-mode reliability hardening (idempotent verify flow + payment-status recovery endpoint)
  - Razorpay checkout error normalization (clean CVV/cancel/fallback messages without raw exception leakage)
  - Order-status misclick-safe acknowledgment flow (two-step confirm with timeout)
  - Customer top app-bar Order Status shortcut (icon action with direct-entry empty state)
  - Add-item route resilience and session-expiry redirect handling in both React and legacy dashboards
  - Delivery-aware ready-order action guard in both restaurant dashboards (delivery orders no longer show direct Mark Given)
  - Web Google OAuth popup flow on Flutter web to reduce repeated GSI different-origin log noise
  - Delivery partner backend APIs (auth, order accept/pickup/complete, active queue, earnings summary)
  - Delivery partner Flutter flow (partner auth + available/active/earnings screens + action buttons)
  - Phase 9 automated backend E2E verification (14/14 checkpoints pass)
- **Current focus**:
  - Razorpay payment reliability in **TEST mode first**
  - Mandatory student profile completion (college + ID card) before Google OAuth access
  - Free OCR/CV model-based college-name matching from ID card
  - Delivery partner end-to-end flow (final screen order already locked)
  - Phase 9 verification: automated checks done, manual runtime E2E still pending
- **Tracking files**:
  - `currentstate.md` for factual runtime state and change log
  - `to_do.md` for phase checklist, blockers, and pending assets
- **Not finished yet**:
  - Razorpay **LIVE** rollout and production API keys
  - Manual Razorpay TEST-card end-to-end run confirmation in app runtime
  - OCR robustness hardening with more ID-card samples
  - Manual delivery-partner runtime end-to-end confirmation

---

## Features

### Backend (FastAPI)
- **RESTful API** with fully documented endpoints for authentication, restaurants, menu items, and orders.
- **MongoDB Atlas Database** with indexed collections (users, restaurants, menu_items, orders, sessions, payment_intents).
- **Dual Authentication**:
  - **Customers**: Firebase Auth (Google Sign-In) + Email/Password with bcrypt hashing.
  - **Restaurants**: Email/Password session-based auth with UUID tokens.
- **Static File Serving**: Serves the legacy HTML dashboard and uploaded restaurant images.
- **CORS**: Fully open (`*`) for development.

### Restaurant Dashboard — React (Primary)
- **Real-time Order Management**: Auto-refreshing order list (polls every 5 seconds).
- **Status Workflow**: Mark orders as *Preparing* → *Ready* → *Given*.
- **Menu Management**: Add / Edit / Delete items, toggle availability instantly.
- **Restaurant Controls**: Open/Close restaurant, update details, upload cover image.
- **Modern UI**: Built with React 19, React Router, Axios, Lucide icons, and React Hot Toast.

### Restaurant Dashboard — Vanilla HTML (Legacy)
- Same features as the React dashboard, served at `/dashboard` by FastAPI.
- Dark mode "anti-gravity" aesthetic with glassmorphism and glow effects.
- Single-page app built with vanilla HTML/CSS/JS — no build step required.

### Customer App (Flutter)
- **Authentication**: Google Sign-In and Email/Password signup (with required college + ID-card onboarding in progress).
- **Live Restaurant Status**: See open/closed status and real-time menu availability.
- **Smart Cart**: Add items, adjust quantities, view subtotal.
- **Order Tracking**: Visual progress bar (Preparing → Ready → Given) with secret pickup code.
- **Order History**: View past orders and details.
- **Multi-platform**: Windows Desktop, Web (Chrome/Edge), Android, iOS.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Backend** | Python 3.10+, FastAPI, Uvicorn, MongoDB Atlas (Motor), bcrypt |
| **Restaurant Dashboard (React)** | React 19, Vite 7, React Router 7, Axios, Lucide React |
| **Restaurant Dashboard (Legacy)** | Vanilla HTML5 / CSS3 / JavaScript |
| **Customer App** | Flutter 3.x (Dart), Firebase Core, Firebase Auth, Google Sign-In |
| **Database** | MongoDB Atlas |
| **Auth** | Email/Password + Google OAuth (customer), UUID session tokens (customer + restaurant) |

---

## Project Structure

```
ezfoodz-flutter/
├── google-services.json             # Firebase config for Android
│
├── fastapi/                          # Backend API
│   ├── main.py                      # App entry point, CORS, static mounts, router includes
│   ├── auth.py                      # Customer auth: /auth/register, /auth/login, /auth/google, /auth/me
│   ├── restaurant_auth.py           # Restaurant auth: /restaurant/login, /restaurant/me
│   ├── restaurants.py               # Restaurant CRUD: GET/PUT /restaurants, toggle, image upload
│   ├── menu_items.py                # Menu CRUD: GET/POST/PUT/DELETE /menu
│   ├── orders.py                    # Order processing: place, track, update status
│   ├── init_db.py                   # Database schema creation + seed data
│   ├── requirements.txt             # Python dependencies
│   ├── Databases/
│   │   ├── hashing.py              # bcrypt password hashing utilities
│   ├── static/dashboard/            # Legacy vanilla HTML dashboard
│   │   ├── index.html
│   │   ├── app.js
│   │   └── style.css
│   └── uploads/                     # Uploaded restaurant images
│
├── restaurant_website/               # React Restaurant Dashboard
│   └── frontend/
│       ├── package.json
│       ├── vite.config.js
│       ├── index.html
│       └── src/
│           ├── App.jsx              # Routes & layout
│           ├── api.js               # Axios API client (base URL, interceptors)
│           ├── context/
│           │   └── AuthContext.jsx   # Auth state, login/logout, token management
│           ├── pages/
│           │   ├── LoginPage.jsx    # Restaurant email/password login
│           │   ├── DashboardPage.jsx # Summary stats & quick actions
│           │   ├── ItemsPage.jsx    # Menu item list with edit/toggle/delete
│           │   ├── AddItemPage.jsx  # Add new menu item form
│           │   ├── DetailsPage.jsx  # Edit restaurant info + image upload
│           │   ├── OrdersPage.jsx   # Live active orders (auto-refresh)
│           │   └── HistoryPage.jsx  # Completed order history
│           └── components/
│               ├── Sidebar.jsx      # Navigation sidebar
│               └── TopBar.jsx       # Page title + open/close toggle
│
├── ezfoodz/                          # Flutter Customer App
│   ├── pubspec.yaml                 # Flutter dependencies
│   ├── lib/
│   │   ├── main.dart               # App entry point, Firebase init, theme, routing
│   │   ├── firebase_options.dart    # Firebase config (web, android, iOS)
│   │   ├── api_config.dart          # Backend base URL config
│   │   ├── auth_service.dart        # Auth state management, login/register/google API calls
│   │   ├── login.dart               # Login screen (email/password + Google Sign-In)
│   │   ├── signup_mail.dart         # Signup screen (email/password registration)
│   │   ├── restaurants_page.dart    # Restaurant list with open/closed status
│   │   ├── menu_page.dart           # Menu display + cart functionality
│   │   ├── cart_page.dart           # Shopping cart and order placement
│   │   ├── order_status_page.dart   # Live order tracking with progress bar
│   │   └── order_history_page.dart  # Past order history
│   ├── android/
│   │   ├── app/
│   │   │   ├── build.gradle.kts    # App-level Gradle (plugins, Firebase, package name)
│   │   │   └── google-services.json # Firebase config (copy from root)
│   │   ├── build.gradle.kts         # Root Gradle
│   │   └── settings.gradle.kts      # Plugin versions (AGP, Kotlin, Google Services)
│   ├── windows/
│   │   └── CMakeLists.txt           # Windows build config (warning suppression)
│   ├── ios/
│   ├── linux/
│   ├── macos/
│   ├── web/
│   └── test/
```

---

## Setup Instructions

### Prerequisites
- **Python 3.10+** with pip
- **Flutter SDK 3.x** (Dart SDK ^3.10.4)
- **Node.js 18+** with npm (for React dashboard)
- **Google Chrome** or **Microsoft Edge** (for web testing)
- **Visual Studio 2022** with C++ Desktop workload (for Windows desktop build)
- **Android Studio** (for Android emulator/device testing)

### 0. One-Command Startup (recommended)

Use Git Bash or WSL on Windows:

```bash
cd ezfoodz-flutter
bash run.sh
```

Before first run:

1. Copy `fastapi/.env.example` to `fastapi/.env`
2. Fill `MONGO_URL`, `RAZORPAY_KEY_ID`, and `RAZORPAY_KEY_SECRET`
3. Keep Razorpay secret only in backend `.env` (never in Flutter app)

---
# create 1 wsl(restaurant) and 1 powershell terminal (fastapi, flutter app)
### 1. Backend Setup (FastAPI)

```bash
cd fastapi

# Create virtual environment (recommended)
python -m venv venv

# Activate it
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create local env file (backend auto-loads .env)
# Windows PowerShell: Copy-Item .env.example .env
# Linux/macOS: cp .env.example .env

# Configure MongoDB Atlas connection
# Linux/macOS:
export MONGO_URL="mongodb+srv://<user>:<password>@<cluster>.mongodb.net/?retryWrites=true&w=majority"
export MONGO_DB="ezfoodz"
export MONGO_AUTH_SOURCE="admin"

# Windows PowerShell:
# $env:MONGO_URL="mongodb+srv://<user>:<password>@<cluster>.mongodb.net/?retryWrites=true&w=majority"
# $env:MONGO_DB="ezfoodz"
# $env:MONGO_AUTH_SOURCE="admin"

# Initialize database (creates tables + seeds restaurant data)
python -c "from init_db import init_db; init_db()"

# Start the server
python -m uvicorn main:app --reload --port 8000
```

Server runs at: `http://127.0.0.1:8000`

API docs available at: `http://127.0.0.1:8000/docs` (Swagger UI)

---

### 2. Restaurant Dashboard — React (Primary)

```bash
cd restaurant_website/frontend

# Install dependencies
npm install

# Start dev server
npm run dev
```

Dashboard runs at: `http://localhost:5173` (or next available port)

**Login Credentials:**

| Restaurant | Email | Password |
|-----------|-------|----------|
| Rishabs FoodCourt | `rfcssn@ssncanteen.in` | `rfcssn@ezfoodz` |
| Main Canteen | `mcssn@ssncanteen.in` | `mcssn@ezfoodz` |
| Ashwins FoodCourt | `afcssn@ssncanteen.in` | `afcssn@ezfoodz` |
| Snow Cube | `scssn@ssncanteen.in` | `scssn@ezfoodz` |

---

### 3. Restaurant Dashboard — Legacy HTML

1. Ensure the backend is running.
2. Open: `http://127.0.0.1:8000/dashboard/`
3. Use the same email/password credentials listed above.

---

### 4. College Admin Dashboard

1. Ensure the backend is running (which automatically seeds the admin accounts into the MongoDB `admins` collection).
2. Open: `http://127.0.0.1:8000/admin/` in your web browser.
3. Log in with any of the following college admin accounts:

| College Admin Account | Email | Password | Assigned College |
|-----------------------|-------|----------|------------------|
| **SSN/SNU Admin** | `ssnadmin@ssn.in` | `admin123` | SSN/SNU |
| **REC Admin** | `recadmin@rec.in` | `admin123` | REC |
| **VIT Admin** | `vitadmin@vit.in` | `admin123` | VITC |

**Key Capabilities:**
* **Dashboard Stats**: View live statistics for your specific college (active users, registered outlets, total completed orders, and cumulative revenue).
* **Manage Buildings**: Add or delete hostel/academic buildings and configure their gender mapping (`Male`, `Female`, or `Neutral`). This dynamically populates the choices in the student app.
* **Manage Restaurants**: Register new restaurant outlets (with secure hashed credentials) or edit details and toggle their open/closed status. Only restaurants from your college will be visible and manageable.

---

### 5. Flutter Customer App

```bash
cd ezfoodz

# Get dependencies
flutter pub get

# Clean build (recommended on first run or after config changes)
flutter clean

# Run on Windows Desktop
flutter run -d windows

# Run on Web (Chrome)
flutter run -d chrome

# Run on Android Emulator
flutter run -d <emulator-id>
```

#### Platform-Specific Notes

**Windows Desktop:**
- Requires Visual Studio 2022 with "Desktop development with C++" workload.
- The CMakeLists.txt suppresses C4996 warnings from Firebase C++ SDK.

**Web:**
- Works out of the box with Chrome or Edge.
- Backend must be running on `http://127.0.0.1:8000`.

**Android:**
- The `google-services.json` is already placed at `ezfoodz/android/app/google-services.json`.
- The Android `applicationId` is `ezfoodz.com` (matches `google-services.json`).
- For Android Emulator: change `baseUrl` in `lib/api_config.dart` to `http://10.0.2.2:8000`.
- For physical device: use your PC's LAN IP (e.g., `http://192.168.1.x:8000`).

**iOS:**
- Bundle ID: `com.example.ezfoodz` (update `ios/Runner/Info.plist` if needed).

---

## Database Schema

| Table | Description | Key Columns |
|-------|------------|-------------|
| `restaurants` | Restaurant profiles | id, name, email (unique), password (bcrypt), description, cuisine_type, address, phone, image_path, is_open, rating |
| `menu_items` | Food/item catalog | id, restaurant_id (FK), name, category (veg/non-veg/stationary), cuisine, price, is_available |
| `users` | Customer accounts | id, firebase_uid (unique), email (unique), username, password, auth_provider (email/google) |
| `orders` | Customer orders | id, user_id (FK), restaurant_id (FK), secret_code, status (preparing/ready/given), total |
| `order_items` | Items in each order | id, order_id (FK CASCADE), item_id, item_name, quantity, price |
| `restaurant_sessions` | Restaurant auth tokens | token (PK), restaurant_id (FK) |
| `user_sessions` | Customer auth tokens | token (PK), user_id (FK) |

---

## API Endpoints

### Customer Authentication (`/auth`)
| Method | Endpoint | Description |
|--------|---------|-------------|
| POST | `/auth/register` | Email/password registration |
| POST | `/auth/login` | Email/password login |
| POST | `/auth/google` | Firebase Google Sign-In auth |
| GET | `/auth/me` | Get current user profile (Bearer token) |

### Restaurant Authentication
| Method | Endpoint | Description |
|--------|---------|-------------|
| POST | `/restaurant/login` | Restaurant email/password login |
| GET | `/restaurant/me` | Get restaurant profile (Bearer token) |

### Restaurants
| Method | Endpoint | Description |
|--------|---------|-------------|
| GET | `/restaurants` | List all restaurants (public) |
| GET | `/restaurants/{id}` | Get single restaurant (public) |
| PUT | `/restaurants/{id}` | Update restaurant details (auth required) |
| PUT | `/restaurants/{id}/toggle` | Toggle open/closed (auth required) |
| POST | `/restaurants/{id}/image` | Upload cover image (auth required) |

### Menu Items
| Method | Endpoint | Description |
|--------|---------|-------------|
| GET | `/menu/{restaurant_id}` | Get menu (add `?all=true` for unavailable items) |
| POST | `/menu/{restaurant_id}` | Add item (auth required) |
| PUT | `/menu/item/{item_id}` | Edit item (auth required) |
| DELETE | `/menu/item/{item_id}` | Delete item (auth required) |
| PUT | `/menu/item/{item_id}/toggle` | Toggle availability (auth required) |

### Orders
| Method | Endpoint | Description |
|--------|---------|-------------|
| POST | `/orders` | Place order (user auth) — generates secret code |
| GET | `/orders/user/active` | User's active orders |
| GET | `/orders/user/history` | User's completed orders |
| GET | `/orders/restaurant/{id}` | Restaurant's active orders (restaurant auth) |
| GET | `/orders/restaurant/{id}/history` | Restaurant's order history |
| PUT | `/orders/{order_id}/status` | Update status: preparing → ready → given |
| POST | `/orders/{order_id}/acknowledge` | User confirms order received after delivery |

### Payments
| Method | Endpoint | Description |
|--------|---------|-------------|
| POST | `/payments/create-order` | Create Razorpay payment order from cart |
| POST | `/payments/verify-and-place-order` | Verify Razorpay signature and place app order |

### Settlement Logs
| Method | Endpoint | Description |
|--------|---------|-------------|
| GET | `/restaurants/{id}/export/monthly?month=YYYY-MM` | Download per-restaurant monthly CSV logs |

---

## Order Flow

1. **Customer** browses restaurants → selects items → taps **Place Order**.
2. App opens Razorpay checkout; payment must succeed first.
3. Backend verifies Razorpay signature and creates app order with **secret code**.
4. **Restaurant** sees the order in dashboard and marks: **Preparing** → **Ready** → **Given**.
5. Customer sees live status updates and, once **Given**, gets an **Order Received** button.
6. On acknowledgement, customer is redirected to restaurants home page.
7. Completed transaction is written to MongoDB `monthly_logs` and monthly CSV file for settlement.

---

## Firebase Configuration

- **Project**: `temp-bfe41`
- **Auth Providers**: Google Sign-In, Email/Password
- The Flutter app uses Firebase Auth for Google Sign-In on the customer side.
- Restaurant auth is entirely backend-managed (no Firebase).
- `google-services.json` in the repo root contains the Android Firebase config.
- `lib/firebase_options.dart` contains platform-specific Firebase configs (web, android, iOS).

---

## Environment & Config Files

| File | Purpose |
|------|---------|
| `fastapi/requirements.txt` | Python dependencies (fastapi, uvicorn, passlib, etc.) |
| `ezfoodz/pubspec.yaml` | Flutter dependencies (firebase_core, firebase_auth, google_sign_in, http, shared_preferences) |
| `restaurant_website/frontend/package.json` | React dependencies (react, axios, react-router-dom, lucide-react, react-hot-toast) |
| `ezfoodz/lib/api_config.dart` | Backend URL (`http://127.0.0.1:8000` — change for Android/LAN) |
| `google-services.json` | Firebase Android config (package: `ezfoodz.com`) |
| `ezfoodz/lib/firebase_options.dart` | Firebase options for all platforms |

---

## Troubleshooting

### Flutter Windows build fails with C4996 warning
The Firebase C++ SDK uses `strncpy` which triggers a deprecation warning treated as error. This is fixed by adding `/wd"4996"` to the warning suppression in `ezfoodz/windows/CMakeLists.txt`. Run `flutter clean` before rebuilding.

### Firebase not working on Android
1. Ensure `google-services.json` is at `ezfoodz/android/app/google-services.json`.
2. Ensure `applicationId` in `android/app/build.gradle.kts` matches the package name in `google-services.json` (`ezfoodz.com`).
3. Ensure the Google Services Gradle plugin is applied in both `settings.gradle.kts` and `app/build.gradle.kts`.

### Backend slow to start / Account creation slow
Bcrypt hashing uses reduced rounds (4) for faster performance in this campus app context.

### Android Emulator can't reach backend
Change `baseUrl` in `lib/api_config.dart` from `http://127.0.0.1:8000` to `http://10.0.2.2:8000`. The Android emulator maps `10.0.2.2` to the host machine's localhost.

### Database reset
Delete `fastapi/Databases/ezfoodz.db` and restart the server — `init_db()` will recreate tables and seed data automatically..
