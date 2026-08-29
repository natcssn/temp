#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/fastapi"
FRONTEND_DIR="$ROOT_DIR/restaurant_website/frontend"
FLUTTER_DIR="$ROOT_DIR/ezfoodz"

BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_PORT="${FRONTEND_PORT:-5173}"
RUN_FLUTTER="${RUN_FLUTTER:-auto}"

PIDS=()
PYTHON_CMD=""
BACKEND_PYTHON=""
BACKEND_PIP=""

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err() { echo "[ERROR] $*"; exit 1; }

cleanup() {
  info "Stopping all services..."
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "Missing command: $1"
}

resolve_python() {
  if command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
  elif command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
  else
    err "Missing command: python or python3"
  fi
}

wait_http() {
  local url="$1"
  local name="$2"
  local attempts=30
  for ((i=1; i<=attempts; i++)); do
    if curl -s "$url" >/dev/null 2>&1; then
      info "$name is ready at $url"
      return 0
    fi
    sleep 1
  done
  warn "$name did not become ready in time: $url"
  return 1
}

info "Checking prerequisites..."
resolve_python
check_cmd node
check_cmd npm
check_cmd curl

IS_WSL="false"
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL="true"
fi

if [[ "$RUN_FLUTTER" == "auto" && "$IS_WSL" == "true" ]]; then
  RUN_FLUTTER="no"
  warn "WSL detected. Skipping Flutter here to avoid Windows CRLF launcher issues."
  warn "Run Flutter separately from PowerShell using: cd ezfoodz && flutter run -d chrome"
fi

if [[ "$RUN_FLUTTER" != "no" ]]; then
  check_cmd flutter
fi

[[ -d "$BACKEND_DIR" ]] || err "Backend folder not found: $BACKEND_DIR"
[[ -d "$FRONTEND_DIR" ]] || err "Frontend folder not found: $FRONTEND_DIR"
[[ -d "$FLUTTER_DIR" ]] || err "Flutter folder not found: $FLUTTER_DIR"

if [[ ! -f "$BACKEND_DIR/.env" ]]; then
  err "Missing fastapi/.env. Copy fastapi/.env.example to fastapi/.env and set values."
fi

grep -Eq '^[[:space:]]*MONGO_URL=.+' "$BACKEND_DIR/.env" || err "MONGO_URL is not set in fastapi/.env"
grep -Eq '^[[:space:]]*RAZORPAY_KEY_ID=.+' "$BACKEND_DIR/.env" || err "RAZORPAY_KEY_ID is not set in fastapi/.env"
grep -Eq '^[[:space:]]*RAZORPAY_KEY_SECRET=.+' "$BACKEND_DIR/.env" || err "RAZORPAY_KEY_SECRET is not set in fastapi/.env"

if [[ ! -d "$BACKEND_DIR/venv" ]]; then
  info "Creating backend virtual environment..."
  "$PYTHON_CMD" -m venv "$BACKEND_DIR/venv"
fi

if [[ -x "$BACKEND_DIR/venv/bin/python" ]]; then
  BACKEND_PYTHON="$BACKEND_DIR/venv/bin/python"
  BACKEND_PIP="$BACKEND_DIR/venv/bin/pip"
elif [[ -x "$BACKEND_DIR/venv/Scripts/python.exe" ]]; then
  BACKEND_PYTHON="$BACKEND_DIR/venv/Scripts/python.exe"
  BACKEND_PIP="$BACKEND_DIR/venv/Scripts/pip.exe"
else
  err "Could not find Python executable inside fastapi/venv"
fi

info "Installing backend dependencies..."
"$BACKEND_PIP" install -r "$BACKEND_DIR/requirements.txt"

info "Installing restaurant website dependencies..."
(cd "$FRONTEND_DIR" && npm install)

if [[ "$RUN_FLUTTER" != "no" ]]; then
  info "Getting Flutter packages..."
  (cd "$FLUTTER_DIR" && flutter pub get)
fi

info "Starting FastAPI backend on :$BACKEND_PORT"
(
  cd "$BACKEND_DIR"
  "$BACKEND_PYTHON" -m uvicorn main:app --reload --host 0.0.0.0 --port "$BACKEND_PORT"
) &
PIDS+=("$!")

info "Starting restaurant website on :$FRONTEND_PORT"
(
  cd "$FRONTEND_DIR"
  npm run dev -- --host 0.0.0.0 --port "$FRONTEND_PORT"
) &
PIDS+=("$!")

if [[ "$RUN_FLUTTER" != "no" ]]; then
  info "Starting Flutter app on Chrome"
  (
    cd "$FLUTTER_DIR"
    flutter run -d chrome
  ) &
  PIDS+=("$!")
fi

wait_http "http://127.0.0.1:$BACKEND_PORT/docs" "FastAPI"
wait_http "http://127.0.0.1:$FRONTEND_PORT" "Restaurant frontend"

cat <<EOF

Services started:
- FastAPI: http://127.0.0.1:$BACKEND_PORT
- Swagger: http://127.0.0.1:$BACKEND_PORT/docs
- Restaurant frontend: http://127.0.0.1:$FRONTEND_PORT
- Flutter: $( [[ "$RUN_FLUTTER" == "no" ]] && echo "not started in this shell" || echo "running via chrome device" )

Press Ctrl+C to stop all services.
EOF

if [[ "$RUN_FLUTTER" == "no" ]]; then
  cat <<EOF

Start Flutter from PowerShell:
1. cd C:\Users\natha\Downloads\ezfoodz-flutter\ezfoodz
2. flutter pub get
3. flutter run -d chrome

EOF
fi

wait
