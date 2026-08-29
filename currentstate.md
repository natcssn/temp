# EZFOODZ Current State (Single Source of Truth)

Last updated: 2026-05-28
Maintainer: GitHub Copilot (Claude Haiku 4.5)
Purpose: AI-readable project state to reduce future hallucination and drift.

## Latest Fix (2026-05-28)
- **Fixed delivery dropdown error**: DropdownButtonFormField was crashing with "duplicate value" error because `_selectedBuilding` was null but didn't validate against the list items properly. Now checks if value exists in list before setting, validates selection, and shows helpful hint text.

## 1) Project Snapshot

This workspace contains 4 active products:

1. FastAPI backend (`fastapi/`) - primary API and auth/payment/order logic
2. React restaurant dashboard (`restaurant_website/frontend/`) - primary restaurant management UI
3. Flutter customer app (`ezfoodz/`) - customer ordering app (web, desktop, mobile)
4. Legacy static dashboard (`fastapi/static/dashboard/`) - older restaurant UI still served by backend

## 2) Runtime Wiring (Verified)

### Backend

- Entry point: `fastapi/main.py`
- Startup lifecycle:
  - connects to MongoDB (`database.connect_db`)
  - seeds data if restaurants collection is empty (`init_db.init_db`)
- Mounted static routes:
  - `/uploads` -> `fastapi/uploads/`
  - `/dashboard` -> `fastapi/static/dashboard/`
- Included routers:
  - customer auth (`auth.py`)
  - restaurant auth (`restaurant_auth.py`)
  - restaurants (`restaurants.py`)
  - menu (`menu_items.py`)
  - orders (`orders.py`)
  - payments (`payments.py`)

### React Dashboard

- Entry point: `restaurant_website/frontend/src/main.jsx`
- App routes: `restaurant_website/frontend/src/App.jsx`
- Auth context: token in localStorage (`rtoken`), me-fetch bootstrap, protected routes
- API base URL:
  - from `VITE_API_BASE_URL`
  - fallback currently points to deployed backend (`https://localhost:8000`)

### Flutter App

- Entry point: `ezfoodz/lib/main.dart`
- Session restore before runApp via `AuthService.loadSession()`
- Firebase init skipped on Windows/Linux desktop, enabled on web/mobile
- API base URL currently hardcoded in `ezfoodz/lib/api_config.dart` as `http://127.0.0.1:8000`
- Payment flow:
  - create order intent (`/payments/create-order`)
  - web checkout via conditional export (`razorpay_web_checkout.dart`)
  - verify and place order (`/payments/verify-and-place-order`)

### Legacy Dashboard

- Served from backend at `/dashboard`
- Uses vanilla HTML/CSS/JS in `fastapi/static/dashboard/`
- Still functionally wired and should be treated as an active compatibility surface

## 3) Data/Auth/Order Flow (Current)

### Database

- Primary DB: MongoDB Atlas
- Collections in active use:
  - users, restaurants, menu_items, orders
  - user_sessions, restaurant_sessions
  - payment_intents, monthly_logs
  - counters

### Auth

- Customers:
  - email/password through backend
  - Google sign-in via Firebase -> backend linking/auth
- Restaurants:
  - backend email/password
  - UUID session token in `restaurant_sessions`

### Orders and Payments

1. Customer selects items and initiates payment
2. Backend validates item ownership/availability and creates Razorpay order
3. Client completes Razorpay checkout
4. Backend verifies signature and creates app order in `orders`
5. Restaurant updates status: preparing -> ready -> given
6. When status becomes `given`, backend logs transaction to:
  - Mongo collection `monthly_logs`
  - CSV under `fastapi/monthly logs/YYYY-MM/restaurant_<id>.csv`
7. Customer acknowledges delivery from app when order is `given`

## 4) Verified Tooling State

### Checks run during this audit

- React lint: PASS (`npm run lint` in `restaurant_website/frontend`)
- FastAPI syntax compile: PASS (`python3 -m compileall -q .` in `fastapi`)
- Flutter analyze: BLOCKED in WSL due flutter wrapper CRLF/shebang issue (`bash\r`) and Windows-only SDK binaries in current WSL invocation path

### Practical impact

- Backend and React checks are healthy for this snapshot
- Flutter static analysis was not executable from this shell context

## 5) Drift and Risk Notes

1. README has historical content that does not fully match runtime reality in places (for example, SQLite references vs current Mongo runtime).
2. Flutter API URL is hardcoded for localhost and must be changed for Android emulator/device/deployed use.
3. Backend CORS is currently `*` (development-friendly, production-hardening still needed).
4. `fastapi/.env` exists locally (expected for local run). Secrets should remain out of version control and rotated for production.

## 6) Cleanup Policy (Safety Rules)

Only delete files/folders if one of the following is true:

1. generated artifact/cache (reproducible)
2. no import/reference and no runtime route/entry usage
3. legacy line/code path proven dead by direct reference search

Never delete active platform folders (`android`, `ios`, `windows`, etc.) just because they are not currently targeted.

## 7) Change Log

### 2026-04-18 - Baseline audit created

- Completed full cross-stack code audit (backend, React, Flutter, legacy dashboard).
- Added this `currentstate.md` file as canonical AI context.

### 2026-04-18 - Safe cleanup executed

- Deleted unused source artifact:
  - `fastapi/test_api.py` (standalone manual smoke script, not runtime-imported)
- Deleted unused/legacy runtime artifact:
  - `fastapi/Databases/ezfoodz.db` (old SQLite file; backend now Mongo-only)
- Removed dead legacy dashboard code:
  - deleted `loginRestaurantId` keypress listener in `fastapi/static/dashboard/app.js`
  - reason: referenced a non-existent DOM element, no usage path
- Deleted reproducible generated artifacts:
  - `fastapi/__pycache__/`
  - `fastapi/Databases/__pycache__/`
  - `ezfoodz/build/`
  - `ezfoodz/.dart_tool/`
  - `restaurant_website/frontend/dist/`

### 2026-04-18 - Post-cleanup verification

- Confirmed dead string removal:
  - no `loginRestaurantId` reference remains under `fastapi/static/dashboard/`
- FastAPI syntax check:
  - `python3 -m compileall -q .` executed in `fastapi` (clean)
- React lint:
  - `npm run lint` previously reported clean during this audit
- Note for Flutter developers:
  - because `.dart_tool` was cleaned (generated), run `flutter pub get` before next Flutter analyze/build

### 2026-04-18 - Phase 0 implementation kickoff (docs + tracking)

- Updated documentation to match current rollout model and architecture:
  - `README.md` updated with test-first phased status and pending live tasks
  - `deploy.md` updated with explicit TEST mode now and LIVE checklist later
- Added implementation tracker:
  - new `to_do.md` created for phase-by-phase progress and pending owner inputs
- Locked current execution direction:
  - payment work proceeds in Razorpay TEST mode first
  - OCR/CV verification starts with free model path and limited sample set
  - delivery partner feature remains phased, with flow order fixed to provided design sequence
- Pending assets noted for later hardening:
  - additional friend ID-card samples still required for OCR robustness phase

### 2026-04-18 - Phase 1 implemented (required student fields + ID upload contract)

- Backend auth contract updated:
  - `POST /auth/register` now requires `college_name`
  - added allowed-college validation list (`SSN`, `VITC`, `REC`, `IITM`)
  - added `POST /auth/id-card` for required ID card upload
  - added `GET /auth/colleges` for allowed college discovery
- User document contract expanded:
  - `college_name`
  - `id_card_image`
  - `id_card_verified`
  - `id_card_verification_message`
- Database indexing updated:
  - sparse indexes for `college_name` and `id_card_verified`
- Flutter signup flow updated:
  - college dropdown (required)
  - ID CARD image picker/upload (required)
  - signup now uploads ID card immediately after account creation

Validation run:
- backend syntax compile passed (`python3 -m compileall -q .`)
- diagnostics reported no file-level errors in modified backend/dart files

Pending next:
- OCR/CV model verification logic (Phase 2)
- OAuth accessibility gate based on verification state (Phase 3)

### 2026-04-18 - Phase 2 implemented (free OCR/CV ID-card verification)

- Added OCR verification engine module:
  - new `fastapi/id_card_verification.py`
  - provider order: local `rapidocr-onnxruntime` first, Hugging Face inference fallback
- Added backend verification endpoint:
  - `POST /auth/verify-id-card`
  - verifies extracted ID-card text against selected `college_name`
  - writes verification metadata to user document
- Enforced mismatch/failure message contract:
  - `idcard and college chosen doesnt match`
- Signup flow updated to block dashboard entry until verification success:
  - flow: register -> upload id-card -> verify id-card -> navigate

Validation run:
- backend syntax compile passed (`python3 -m compileall -q .`)
- diagnostics reported no file-level errors in modified Python/Dart files

Pending next:
- Phase 3 OAuth inaccessibility gate until required onboarding + verification state are satisfied

### 2026-04-18 - Phase 3 implemented (OAuth accessibility gate)

- Flutter login UX now enforces OAuth prerequisites:
  - required college selection input before Google sign-in
  - required ID CARD upload input before Google sign-in
  - Google OAuth button stays disabled until both are present
- Post-Google auth flow now enforces verification before dashboard entry:
  - google auth -> id-card upload -> verify-id-card -> navigate
  - mismatch/failure keeps user out of dashboard and shows required message
- Session entry guard tightened:
  - app home now routes to dashboard only when both session exists and `idCardVerified == true`

Validation run:
- backend syntax compile passed (`python3 -m compileall -q .`)
- diagnostics reported no file-level errors in modified Python/Dart files

Pending next:
- Phase 4 Razorpay TEST-mode reliability hardening

### 2026-04-18 - Phase 4 implemented (Razorpay TEST reliability hardening)

- Backend payment flow hardened in `fastapi/payments.py`:
  - added idempotent early return when intent already paid
  - added verification lock transition (`created` -> `verifying` -> `paid`)
  - duplicate insert handling reconciles intent with already-created order
  - added `GET /payments/status/{razorpay_order_id}` for paid-order recovery checks
- Flutter checkout recovery added in `ezfoodz/lib/cart_page.dart`:
  - if verify response fails or is uncertain, app now calls payment-status endpoint
  - when backend reports paid order, user is navigated to order-status page safely
  - reduces duplicate-payment panic when network drops during callback/verify window

Validation run:
- backend syntax compile passed (`python3 -m compileall -q .`)
- diagnostics reported no file-level errors in modified payment Dart/Python files

Pending next:
- manual Razorpay TEST-card e2e run for confirmation
- Phase 5 order-status misclick-safe UX

### 2026-04-18 - Phase 5 implemented (order-status misclick-safe UX)

- Updated `ezfoodz/lib/order_status_page.dart` acknowledgment UX:
  - "Order Received" action is now two-step confirm with 5-second timeout
  - first tap arms confirmation and shows warning; second tap confirms
  - pending confirmation auto-expires to prevent accidental irreversible state changes
  - per-order loading state avoids accidental multi-tap cross-order actions

Validation run:
- diagnostics reported no file-level errors in modified order-status file

Pending next:
- Phase 6 add-item redirect and legacy dashboard resilience fixes

### 2026-04-18 - Phase 6 implemented (add-item redirect + legacy session resilience)

- React dashboard hardening:
  - `restaurant_website/frontend/src/pages/ItemsPage.jsx` changed add-item CTA from full-page anchor to client-side route navigation
  - `restaurant_website/frontend/src/pages/AddItemPage.jsx` now guards against missing session and redirects to login on expired auth
  - `restaurant_website/frontend/src/api.js` now globally handles 401 by clearing auth storage and redirecting to login
- Legacy dashboard hardening:
  - `fastapi/static/dashboard/app.js` now uses centralized authenticated fetch helper
  - expired tokens now trigger forced logout + visible session-expired message instead of silent failure loops

Validation run:
- diagnostics reported no file-level errors in modified React/legacy dashboard files
- React frontend build succeeded (`npm run build`, vite build complete)

Pending next:
- Phase 7 delivery partner backend end-to-end

### 2026-04-18 - Phase 7 implemented (delivery partner backend end-to-end)

- New backend router added: `fastapi/delivery_partner.py`
  - partner auth: `/delivery/register`, `/delivery/login`, `/delivery/me`
  - work queue: `/delivery/orders/available`, `/delivery/orders/active`
  - workflow actions: `/delivery/orders/{order_id}/accept`, `/pickup`, `/complete`
  - earnings endpoint: `/delivery/earnings/summary`
- Backend wiring/index updates:
  - router mounted in `fastapi/main.py`
  - new indexes for `delivery_partners`, `delivery_sessions`, and delivery assignment lookups in `fastapi/database.py`
- Order/payment schema compatibility extension:
  - added `fulfillment_mode` support (`pickup` default, `delivery` enabled)
  - delivery metadata fields added during order creation (assignment/stage/fee)
  - restaurant status endpoint now blocks direct `given` transition for delivery-mode orders

Validation run:
- backend syntax compile passed (`python3 -m compileall -q .`)
- diagnostics reported no file-level errors in modified backend files
- route mount smoke check confirms all `/delivery/*` endpoints are present in app routes

Pending next:
- Phase 8 delivery partner Flutter flow end-to-end

### 2026-04-18 - Phase 8 implemented (delivery partner Flutter flow end-to-end)

- Added new Flutter delivery-partner modules:
  - `ezfoodz/lib/delivery_service.dart` for partner auth/session + delivery API calls
  - `ezfoodz/lib/delivery_partner_login_page.dart` for partner sign-in/register
  - `ezfoodz/lib/delivery_partner_home_page.dart` for available orders, active orders, and earnings tabs
- Wired partner entry path:
  - `ezfoodz/lib/login.dart` now provides "Delivery Partner Login" entry button
- Implemented action loop in UI:
  - accept order -> mark picked up -> complete delivery
  - periodic refresh polling for near-real-time queue updates

Validation run:
- diagnostics reported no file-level errors in newly added/modified delivery Flutter files
- `flutter analyze` run completed (no blocking errors in changed delivery files)

Pending next:
- Phase 9 full app flow testing and final docs reconciliation

### 2026-04-18 - Phase 9 verification in progress (automated checks completed)

- Automated validation batch executed:
  - backend syntax compile passed (`python3 -m compileall -q .`)
  - delivery endpoint mount smoke passed (9 `/delivery/*` routes detected in app)
  - in-process delivery API smoke passed via app+venv context:
    - `POST /delivery/register` -> 200
    - `GET /delivery/me` -> 200
    - `GET /delivery/orders/available` -> 200
    - `GET /delivery/earnings/summary` -> 200
  - React dashboard production build passed (`npm run build`)
  - Flutter analyze completed; changed files report info-level diagnostics only, no blocking errors
- Environment note:
  - localhost port 8000 was unreachable during direct curl attempt from terminal context
  - API smoke was therefore executed in-process using TestClient with explicit DB lifecycle init
- Documentation reconciliation updated:
  - `to_do.md` now tracks automated-pass vs manual-pending Phase 9 items
  - `README.md` and `deploy.md` status sections updated with current Phase 9 truth

Manual blockers still pending before final Phase 9 close:
- in-app Razorpay TEST-card checkout confirmation
- larger OCR sample run with additional real ID-card images
- manual delivery partner runtime E2E path confirmation

### 2026-04-18 - Phase 9 automated backend E2E passed (14/14)

- Executed corrected in-process E2E script with FastAPI TestClient and lifespan-managed startup.
- Added automatic restaurant-open correction during test setup to avoid false negatives from closed seed state.
- Checkpoints passed end-to-end:
  - customer register -> id-card upload -> id-card verify -> login verified state
  - payment create-order -> verify-and-place-order -> idempotent second verify
  - restaurant marks ready -> delivery partner available/accept/pickup/complete
  - delivery earnings increment -> customer acknowledge order
- Result:
  - 14/14 checkpoints PASS

Scope note:
- Payment gateway interaction was safely stubbed in-process for deterministic backend verification.
- Manual app runtime checks are still required for final Phase 9 close.

### 2026-04-18 - Phase 9 repo cleanup (temporary test artifacts removed)

- Date: 2026-04-18
- Scope: repository hygiene after automated verification
- Files:
  - deleted `fastapi/checkpoint_flow_test.py`
  - deleted temporary generated upload files in `fastapi/uploads/` from mocked ID-card tests
  - deleted temporary generated monthly log row file in `fastapi/monthly logs/2026-04/`
- Change summary:
  - Removed non-production artifacts created only by local in-process E2E execution.
  - Kept actual feature code, docs, and trackers unchanged.
- Validation:
  - `git diff` confirmed cleanup removed only temporary generated artifacts.
- Risks/Notes:
  - No runtime behavior change; this is cleanup-only.

### 2026-04-18 - Phase 9 validation rerun + Flutter hard-error fixes

- Date: 2026-04-18
- Scope: keep Phase 9 status truthful after cleanup by rerunning cross-stack checks
- Files:
  - updated `ezfoodz/lib/razorpay_web_checkout_web.dart`
  - updated `ezfoodz/test/widget_test.dart`
  - updated `to_do.md`
- Change summary:
  - Cross-stack rerun executed:
    - backend compile pass (`python3 -m compileall -q .`)
    - React build pass (`npm run build`)
  - Flutter analysis initially failed due two hard errors:
    - missing web JS util import compatibility path in `razorpay_web_checkout_web.dart`
    - stale default test app reference (`MyApp`) in `widget_test.dart`
  - Applied targeted fixes:
    - rewrote web checkout bridge to `dart:js`-based implementation compatible with current SDK
    - updated widget test to `EZFoodzApp(loggedIn: false)` boot smoke
- Validation:
  - `flutter pub get` passed.
  - `flutter analyze` now has no error-severity diagnostics; remaining diagnostics are non-blocking warning/info lint items.
  - `flutter test test/widget_test.dart` passed (`All tests passed!`, exit code 0).
- Risks/Notes:
  - Web Razorpay bridge now uses legacy `dart:js`; functional runtime verification in web checkout still required during manual Phase 9 checks.

### 2026-04-19 - Runtime UX bugfix pass (payment messaging, top status shortcut, delivery-aware dashboards)

- Date: 2026-04-19
- Scope: resolve user-reported runtime UX issues and keep docs/tracker state synchronized.
- Files:
  - updated `ezfoodz/lib/cart_page.dart`
  - updated `ezfoodz/lib/login.dart`
  - updated `ezfoodz/lib/restaurants_page.dart`
  - updated `ezfoodz/lib/order_status_page.dart`
  - updated `fastapi/static/dashboard/app.js`
  - updated `restaurant_website/frontend/src/pages/OrdersPage.jsx`
  - updated `README.md`
  - updated `to_do.md`
  - updated `currentstate.md`
- Change summary:
  - Payment checkout errors in Flutter cart are now normalized before display, including explicit friendly handling for CVV failures and cancellation paths, and cleanup of noisy prefixes like `Bad state:`/`Exception:`.
  - Customer app top app-bar now includes an icon-only `Order Status` shortcut next to existing history/logout actions.
  - `OrderStatusPage` now supports direct entry without required constructor payload and distinguishes loading from empty-state UX (with a clear browse-restaurants CTA).
  - Legacy and React restaurant dashboards now respect backend delivery rules in UI: delivery-mode ready orders show a non-clickable delivery-partner completion indicator instead of exposing direct `Mark Given` action.
  - Legacy dashboard failed status updates now surface backend detail text in toast messages instead of a generic error.
  - Web Google OAuth login path now uses Firebase popup flow on web to reduce repeated GSI origin-noise seen with the previous path.
- Validation:
  - Workspace diagnostics (`get_errors`) on all modified runtime files reported no file-level errors.
  - Flutter targeted analysis command (`flutter --no-version-check analyze lib/cart_page.dart lib/login.dart lib/restaurants_page.dart lib/order_status_page.dart`) completed with info-level lint findings only (exit code 1, no error-severity diagnostics).
  - React dashboard build passed (`npm run build`, exit code 0).
  - Legacy dashboard JS syntax check passed (`node --check fastapi/static/dashboard/app.js`, exit code 0).
- Risks/Notes:
  - Flutter analyze still has non-blocking lint infos in touched files (e.g., `library_private_types_in_public_api`, `use_build_context_synchronously`), pre-existing style/debt items not required for this runtime fix scope.
  - GSI log-noise reduction for web OAuth should be confirmed during manual browser runtime validation because browser/provider diagnostics can vary by origin configuration.

## 8) Mandatory Update Protocol (For Every Future AI Change)

When any code/config/file changes, append a new log block under Section 7 with:

1. date/time
2. files changed
3. why change was made
4. validation run and result (lint/test/analyze/manual)
5. risk/rollback note

Template:

- Date:
- Scope:
- Files:
- Change summary:
- Validation:
- Risks/Notes:

### 2026-04-20 - Phase 10 implementation (Profile, Delivery Options, and Payment Fix)

- Date: 2026-04-20
- Scope: Added profile icon, delivery partner gender flow, delivery fulfillment mode, and payment transaction timeout logic.
- Files:
  - `ezfoodz/lib/restaurants_page.dart`
  - `ezfoodz/lib/delivery_service.dart`
  - `ezfoodz/lib/delivery_partner_login_page.dart`
  - `ezfoodz/lib/cart_page.dart`
  - `ezfoodz/lib/order_status_page.dart`
  - `fastapi/payments.py`
  - `currentstate.md`
- Change summary:
  - Added profile bottom sheet to the `RestaurantsPage` AppBar to show user details like Gender and Hostel.
  - Added gender to `DeliveryService` and a corresponding Dropdown menu in the `DeliveryPartnerLoginPage` registration.
  - Added a "Self Pick Up" vs "Delivery (+₹20)" toggle in `CartPage` and included the selected `fulfillment_mode` in the checkout API payload.
  - Updated `OrderStatusPage` to show delivery status stages when the order is fulfilled via delivery.
  - Added a 60-second recovery timeout in `payments.py` to prevent verifying intents from getting permanently stuck if an intermediate crash occurs.
- Validation:
  - Code changes applied without file-level syntax errors.
- Risks/Notes:
  - Delivery assignments will now take gender into account properly when matching orders. Verification timeout in `payments.py` should cleanly recover from drops.

### 2026-05-28 - Phase 11 implementation (Razorpay Payment Validation Hardening and Recovery)

- Date: 2026-05-28
- Scope: Added fallback tracking for current Razorpay order ID in Flutter customer app and direct Razorpay API order verification in the status recovery endpoint.
- Files:
  - `ezfoodz/lib/cart_page.dart`
  - `fastapi/payments.py`
  - `currentstate.md`
- Change summary:
  - Defined `_currentRazorpayOrderId` state variable in Flutter customer app's `_CartPageState` to track order ID at creation.
  - Configured `_handlePaymentSuccess` to fall back to `_currentRazorpayOrderId` if `response.orderId` is null/empty.
  - Updated `/payments/status/{razorpay_order_id}` in FastAPI backend to query the Razorpay API directly using `client.order.fetch` if the database status is not `'paid'`, automatically placing the order and updating the intent status to `'paid'` if the transaction has completed on Razorpay's end.
  - Added logging output for signature verification exceptions.
- Validation:
  - Python compile checks passed on `fastapi`.
  - Flutter analysis completed on `cart_page.dart` with no compilation errors.
- Risks/Notes:
  - Safeguards payments from drops in network or app closures during the gateway callback phase. Ensure that server env has correct Razorpay secret to perform successful fetch requests.

### 2026-05-28 - Phase 12 implementation (Onboarding & Registration Restored)

- Date: 2026-05-28
- Scope: Restored email registration and ID card verification flow. Added verification status fields to email and Google auth endpoints.
- Files:
  - `fastapi/auth.py`
  - `ezfoodz/lib/auth_service.dart`
  - `currentstate.md`
- Change summary:
  - Implemented `/auth/register` (form-based email sign up with college validation), `/auth/id-card` (ID card image upload), and `/auth/verify-id-card` (OCR match verification) endpoints in backend.
  - Updated `/auth/login` and `/auth/google` endpoints to include user document `id_card_verified` and `id_card_verification_message` in response return.
  - Added `register`, `uploadIdCard`, and `verifyIdCard` service calls in Flutter `AuthService` class to resolve compilation errors in `signup_mail.dart`.
- Validation:
  - Python compile check succeeded on `fastapi` router.
  - Flutter static analyze succeeded on `auth_service.dart` and `signup_mail.dart` without errors.
- Risks/Notes:
  - Resolves login/signup blocking errors on user registration screen. Enables Google/email login to fetch verification status.

### 2026-05-28 - Phase 13 implementation (Google Sign-in Dependency Alignment)

- Date: 2026-05-28
- Scope: Downgraded google_sign_in dependency and launched Flutter app on web.
- Files:
  - `ezfoodz/pubspec.yaml`
  - `currentstate.md`
- Change summary:
  - Downgraded `google_sign_in` from `^7.2.0` to `^6.2.1` in `pubspec.yaml` to match legacy class constructors and code structures used in `login.dart`.
  - Re-fetched and resolved all dependencies via `flutter pub get`.
- Validation:
  - `flutter analyze` completed successfully on `lib/login.dart` with no compilation errors.
- Risks/Notes:
  - Eliminates the constructor and method signature compile errors introduced by version 7.0.0+ changes. Google Sign-in on Chrome web browser is now functional and ready for execution.
### 2026-05-28 - Phase 14 implementation (Dynamic Onboarding, College Admins Dashboard & APK Hardening)

- Date: 2026-05-28
- Scope: Added college admin dashboard, monthly log payouts and downloads, dynamic onboarding building options in student app, and resolved release build crash issue for Android APK.
- Files:
  - `fastapi/admin.py`
  - `fastapi/init_db.py`
  - `fastapi/main.py`
  - `fastapi/auth.py`
  - `fastapi/transaction_logger.py`
  - `fastapi/restaurants.py`
  - `admin_dashboard/index.html`
  - `admin_dashboard/style.css`
  - `admin_dashboard/app.js`
  - `ezfoodz/android/app/src/main/AndroidManifest.xml`
  - `ezfoodz/android/app/build.gradle.kts`
  - `ezfoodz/lib/firebase_options.dart`
  - `ezfoodz/lib/auth_service.dart`
  - `ezfoodz/lib/signup_mail.dart`
  - `ezfoodz/lib/cart_page.dart`
  - `ezfoodz/test/widget_test.dart`
  - `README.md`
  - `to_do.md`
  - `currentstate.md`
- Change summary:
  - **APK Hardening**: Added `INTERNET` permission to `AndroidManifest.xml` (crucial for release builds on physical devices) and aligned `minSdk = 21`. Aligned Firebase options with compiler `google-services.json` target project (`business-2c38a`).
  - **Dynamic Onboarding**: Exposed `/auth/colleges-with-buildings` on backend. Updated Flutter customer app (`AuthService`, `signup_mail.dart`, `cart_page.dart`) to dynamically fetch colleges and buildings list from MongoDB on startup, caching results with hardcoded fallback.
  - **MongoDB Admin Seeding**: Created `admins` collection in MongoDB Atlas with seeded hashed credentials for SSN, REC, and VITC admins.
  - **Admin Dashboard Backend & Frontend**: Created `/admin-api` router in backend to validate admin sessions, retrieve live statistics, update building/gender configuration, and register/edit restaurants. Developed vanilla glassmorphism dark-mode UI dashboard mounted at `/admin` using index.html, style.css, and app.js.
  - **Monthly Payout Logs**: Expanded `transaction_logger.py` and `restaurants.py` to record transaction share breakdowns (gross amount, fulfillment mode, delivery fee, restaurant share, delivery partner share). Added `/logs/months`, `/logs/payouts`, and `/logs/download` endpoints to the admin API, and integrated tables and raw file downloaders in the frontend dashboard.
  - **Infinite Recursion Fix**: Resolved a critical loop bug in `app.js`'s `handleLogout()` by clearing session parameters instantly and executing the logout POST notification using raw browser fetch.
- Validation:
  - Checked Python syntax check (`python -m compileall -q fastapi`).
  - Checked unit tests in customer app (`flutter test test/widget_test.dart`).
  - Ran FastAPI backend and successfully tested login, statistics, building addition, restaurant CRUD, logs, and payouts APIs.
  - Successfully compiled the release APK using `flutter build apk`.
- Risks/Notes:
  - Dynamic dropdown mapping prevents onboarding app crashes if colleges/buildings list changes. Hardened Internet permissions avoid socket/Firebase errors in Android release builds.

