# EZFOODZ Deployment Guide

This file is aligned to your current Vercel setup flow and assumes you want:

1. Restaurant website on Vercel
2. Customer frontend on Vercel
3. FastAPI backend on Vercel

Google Cloud is documented separately as an exception path at the end.

## 0) Deployment Plan You Asked For

Create 3 separate Vercel projects from the same repository:

1. `ezfoodz-restaurant-web` -> `restaurant_website/frontend`
2. `ezfoodz-customer-web` -> `ezfoodz` (Flutter web output)
3. `ezfoodz-api` -> `fastapi`

Do not combine all three into one Vercel project.

---

## 1) Vercel Project #1: Restaurant Website (React + Vite)

Project details:

1. Root Directory: `restaurant_website/frontend`
2. Framework Preset: `Vite`

Use these exact Build and Output settings:

1. Build Command: `npm run build`
2. Output Directory: `dist`
3. Install Command: `npm install`
4. Development Command: `npm run dev`
5. Start Command: leave empty

Important note for your screenshot:

If Build Command is currently `npm install`, change it to `npm run build`.

Environment Variables (Vercel -> Project Settings -> Environment Variables):

1. `VITE_API_BASE_URL=https://<your-backend-vercel-domain>`

Required code alignment in `restaurant_website/frontend/src/api.js`:

```js
import axios from 'axios';

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';

const api = axios.create({ baseURL: BASE_URL });
```

---

## 2) Vercel Project #2: Customer Frontend (Flutter Web)

There are two ways. Use Option A for stable Vercel deploys.

## Option A (recommended for Vercel): Pre-build Flutter web and deploy static output

Vercel does not always provide Flutter SDK in build env by default. To avoid flaky builds:

1. Build locally or via CI:

```bash
cd ezfoodz
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://<your-backend-vercel-domain>
```

2. Deploy the generated `ezfoodz/build/web` as static site (separate Vercel project).

Vercel settings (if using `ezfoodz/build/web` published artifact repo/folder):

1. Framework Preset: `Other`
2. Build Command: leave empty
3. Output Directory: `.` (if root is already built web artifacts)
4. Install Command: leave empty

## Option B (direct from `ezfoodz` source on Vercel)

Use only if your Vercel build environment has Flutter installed via custom pipeline.

Vercel settings:

1. Root Directory: `ezfoodz`
2. Framework Preset: `Other`
3. Install Command: `flutter pub get`
4. Build Command: `flutter build web --release --dart-define=API_BASE_URL=https://<your-backend-vercel-domain>`
5. Output Directory: `build/web`
6. Start Command: leave empty

Required code alignment in `ezfoodz/lib/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
```

---

## 3) Vercel Project #3: Backend (FastAPI)

Project details:

1. Root Directory: `fastapi`
2. Framework Preset: `Other`

Vercel Python setup files required in `fastapi`:

`fastapi/api/index.py`

```python
from main import app
```

`fastapi/vercel.json`

```json
{
  "version": 2,
  "builds": [{ "src": "api/index.py", "use": "@vercel/python" }],
  "routes": [{ "src": "/(.*)", "dest": "api/index.py" }]
}
```

Vercel Build/Output fields for backend:

1. Install Command: `pip install -r requirements.txt`
2. Build Command: leave empty
3. Output Directory: leave empty
4. Start Command: leave empty

Backend Environment Variables:

1. `MONGO_URL`
2. `MONGO_DB=ezfoodz`
3. `MONGO_AUTH_SOURCE=admin`
4. `RAZORPAY_KEY_ID`
5. `RAZORPAY_KEY_SECRET`

Important backend caveats on Vercel:

1. `uploads/` is ephemeral in serverless runtime
2. Long-running tasks are not ideal for serverless
3. For persistent image/file uploads use Cloudinary, S3, or GCS

---

## 4) Exact Values to Fill in Vercel UI

For `restaurant_website/frontend` project:

1. Application Preset: `Vite`
2. Root Directory: `restaurant_website/frontend`
3. Build Command: `npm run build`
4. Output Directory: `dist`
5. Install Command: `npm install`

For `fastapi` project:

1. Application Preset: `Other`
2. Root Directory: `fastapi`
3. Build Command: empty
4. Output Directory: empty
5. Install Command: `pip install -r requirements.txt`

For `ezfoodz` Flutter web project (direct source build):

1. Application Preset: `Other`
2. Root Directory: `ezfoodz`
3. Build Command: `flutter build web --release --dart-define=API_BASE_URL=https://<your-backend-vercel-domain>`
4. Output Directory: `build/web`
5. Install Command: `flutter pub get`

---

## 5) Domain Wiring Order

Deploy in this order:

1. Deploy backend (`ezfoodz-api`) first
2. Copy backend production URL
3. Add that URL to `VITE_API_BASE_URL` in restaurant project
4. Build Flutter web with `--dart-define=API_BASE_URL=<backend-url>`
5. Deploy both frontends

---

## 6) Google Cloud Exception Path (Separate)

Use this only if you decide to move away from all-Vercel.

## Backend on Cloud Run

1. Source: `fastapi`
2. Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
3. Env vars: same five backend vars listed above
4. Recommended for stable API + upload-heavy workloads

## Restaurant frontend on Cloud Run or Firebase Hosting

Cloud Run settings:

1. Root: `restaurant_website/frontend`
2. Build: `npm install && npm run build`
3. Start: `npx serve -s dist -l $PORT`

## Flutter web on Firebase Hosting or GCS

```bash
cd ezfoodz
flutter build web --release --dart-define=API_BASE_URL=https://<your-cloud-backend-url>
```

Firebase Hosting is usually the easiest for Flutter web.

---

## 7) Security Checklist Before Going Public

1. Rotate MongoDB password and Razorpay secret (they were exposed in local context)
2. Keep all secrets only in Vercel/Cloud env vars
3. Restrict CORS in backend for production origins
4. Ensure HTTPS URLs only in frontend environment values
