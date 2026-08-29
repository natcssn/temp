# EZFOODZ Deployment Guide

## Current Rollout Mode (as of 2026-04-18)

Implementation is running in **test-first mode** while phased features are being built.

### Active right now

1. Payment integration/testing uses **Razorpay TEST mode** first.
2. Student verification feature is being built with **free OCR/CV model path** first.
3. Delivery partner feature is planned as phased rollout with final UI flow already frozen.

### Implemented checkpoints in code

1. Required signup fields added for college selection and ID-card upload contract.
2. Backend now stores ID-card onboarding/verification state fields for users.
3. OCR verification endpoint added with free model path (rapidocr local, Hugging Face fallback).
4. Google OAuth access now gated behind college + ID CARD prerequisite input.
5. Payment verification reliability hardened in TEST mode with idempotent backend flow and status polling endpoint.
6. Order-status UX hardened against accidental completion taps (two-step acknowledge confirm).
7. Add-item navigation/session handling hardened in React and legacy dashboards.
8. Delivery partner backend contract implemented (register/login/me, available/active orders, accept/pickup/complete, earnings).
9. Delivery partner Flutter screens added and wired from customer login entry point.
10. Phase 9 automated verification checks completed (backend compile, delivery routes smoke, React build, Flutter analyze).
11. Phase 9 backend E2E smoke now passes fully (14/14 checkpoints, deterministic in-process run).

### Payment testing note

- Use only test credentials/cards in this stage.
- Requested sample card for test flow validation: `6527 6589 0000 1005`.
- Do not attempt live collection until LIVE phase checklist is complete.

### Pending before LIVE go-live

1. Deploy backend and publish stable production API URL.
2. Replace test Razorpay keys with live keys in backend env.
3. Complete end-to-end live payment smoke tests.
4. Finalize OCR model quality with larger ID-card sample set.
5. Complete security hardening (CORS allowlist, secret rotation, persistent media storage).

---

This guide is aligned to your request:

1. Restaurant website on Vercel
2. Customer frontend on Vercel
3. FastAPI backend on Vercel

Google Cloud is documented separately as an exception path.

## 0) Final Deployment Topology

Create 3 separate Vercel projects from the same repository:

1. `ezfoodz-restaurant-web` -> `restaurant_website/frontend`
2. `ezfoodz-customer-web` -> `ezfoodz`
3. `ezfoodz-api` -> `fastapi`

Do not deploy all three in one Vercel project.

---

## 1) Vercel Project: Restaurant Website (React + Vite)

Use these exact values in Vercel UI:

1. Application Preset: `Vite`
2. Root Directory: `restaurant_website/frontend`
3. Build Command: `npm run build`
4. Output Directory: `dist`
5. Install Command: `npm install`
6. Development Command: `npm run dev`
7. Start Command: leave empty

Important (from your screenshot):

If Build Command is currently `npm install`, change it to `npm run build`.

Environment Variables:

1. `VITE_API_BASE_URL=https://<your-backend-vercel-domain>`

Code requirement in `restaurant_website/frontend/src/api.js`:

```js
import axios from 'axios';

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';
const api = axios.create({ baseURL: BASE_URL });
```

---

## 2) Vercel Project: Customer Frontend (Flutter Web)

There are two valid ways.

## Option A (recommended for reliability): Pre-build and deploy static output

1. Build Flutter web locally or in CI:

```bash
cd ezfoodz
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://<your-backend-vercel-domain>
```

2. Deploy built web artifacts as a static Vercel project.

If root is already built output:

1. Application Preset: `Other`
2. Root Directory: folder containing built files
3. Build Command: leave empty
4. Output Directory: `.`
5. Install Command: leave empty

## Option B: Build Flutter directly on Vercel from source

Use only if your Vercel build environment has Flutter setup.

1. Application Preset: `Other`
2. Root Directory: `ezfoodz`
3. Build Command: `flutter build web --release --dart-define=API_BASE_URL=https://<your-backend-vercel-domain>`
4. Output Directory: `build/web`
5. Install Command: `flutter pub get`
6. Start Command: leave empty

Code requirement in `ezfoodz/lib/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
```

---

## 3) Vercel Project: Backend (FastAPI)

Use these exact values in Vercel UI:

1. Application Preset: `Other`
2. Root Directory: `fastapi`
3. Build Command: leave empty
4. Output Directory: leave empty
5. Install Command: `pip install -r requirements.txt`
6. Start Command: leave empty

Required files inside `fastapi`:

`api/index.py`

```python
from main import app
```

`vercel.json`

```json
{
  "version": 2,
  "builds": [{ "src": "api/index.py", "use": "@vercel/python" }],
  "routes": [{ "src": "/(.*)", "dest": "api/index.py" }]
}
```

Backend Environment Variables:

1. `MONGO_URL`
2. `MONGO_DB=ezfoodz`
3. `MONGO_AUTH_SOURCE=admin`
4. `RAZORPAY_KEY_ID` (TEST key for current phase; LIVE key only in live phase)
5. `RAZORPAY_KEY_SECRET` (TEST key for current phase; LIVE key only in live phase)
6. `HF_TOKEN` (optional, only for Hugging Face OCR fallback)

Important backend caveat on Vercel serverless:

1. `uploads/` is ephemeral (non-persistent)
2. Use Cloudinary/S3/GCS for persistent media

---

## 4) Deployment Order (Do This Sequence)

1. Deploy backend (`ezfoodz-api`) first
2. Copy backend URL (for example `https://ezfoodz-api.vercel.app`)
3. Set `VITE_API_BASE_URL` in restaurant frontend project
4. Build/deploy customer frontend with `API_BASE_URL` pointing to backend URL
5. Redeploy frontends after env update

---

## 5) Google Cloud Exception (Separate Full Path)

Use this only if you choose to move away from all-Vercel.

## 5.1 Backend on Cloud Run

1. Source: `fastapi`
2. Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
3. Env vars: same five backend vars listed above
4. Recommended when you need stable long-running API and better upload handling

Deploy example:

```bash
gcloud run deploy ezfoodz-api \
  --source fastapi \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars MONGO_URL=...,MONGO_DB=ezfoodz,MONGO_AUTH_SOURCE=admin,RAZORPAY_KEY_ID=...,RAZORPAY_KEY_SECRET=...
```

## 5.2 Restaurant frontend on Cloud Run

1. Root: `restaurant_website/frontend`
2. Build: `npm install && npm run build`
3. Start: `npx serve -s dist -l $PORT`

## 5.3 Flutter web on Google Cloud

Build:

```bash
cd ezfoodz
flutter build web --release --dart-define=API_BASE_URL=https://<your-cloud-backend-url>
```

Host options:

1. Firebase Hosting (easiest for Flutter web)
2. GCS + Cloud CDN

---

## 6) Security Checklist Before Going Live

1. Rotate MongoDB password and Razorpay secret
2. Keep all secrets only in platform env vars
3. Restrict CORS to production origins
4. Ensure all frontend API URLs are HTTPS

---

## 7) Feature Rollout Checklist (Implementation Tracking)

1. Phase 0 docs baseline complete (`README.md`, `deploy.md`, `to_do.md`, `currentstate.md`)
2. Phase 1 required student fields (college + ID card upload)
3. Phase 2 OCR/CV verification integration (free model path)
4. Phase 3 OAuth access gate based on completed verification
5. Phase 4 Razorpay reliability hardening in TEST mode
6. Phase 5 order-status misclick-safe UX
7. Phase 6 add-item redirect and legacy dashboard stability fixes
8. Phase 7 delivery partner backend end-to-end
9. Phase 8 delivery partner Flutter UI flow end-to-end
10. Phase 9 full-flow verification and final live rollout readiness
