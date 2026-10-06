#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
set -a
source .env
set +a
export DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 ASPNETCORE_ENVIRONMENT=Development
mkdir -p .local
test_db="student_finance_test_$$"
api_pid=""
cleanup() {
  if [[ -n "$api_pid" ]]; then kill "$api_pid" 2>/dev/null || true; wait "$api_pid" 2>/dev/null || true; fi
  docker compose exec -T postgres dropdb -U student --if-exists "$test_db"
}
trap cleanup EXIT
docker compose up -d --wait postgres
docker compose exec -T postgres createdb -U student "$test_db"
export ConnectionStrings__Finance="Host=127.0.0.1;Port=5432;Database=$test_db;Username=student;Password=${POSTGRES_PASSWORD:?}"
dotnet tool restore
dotnet ef database update --project backend/ViSinhVien.Api
dotnet run --no-launch-profile --no-build --project backend/ViSinhVien.Api --urls http://127.0.0.1:5081 > .local/test-api.log 2>&1 &
api_pid=$!
python3 - <<'PY'
import time, urllib.request
for attempt in range(60):
    try:
        with urllib.request.urlopen('http://127.0.0.1:5081/api/health', timeout=2) as response:
            if response.status == 200: break
    except (OSError, urllib.error.URLError): time.sleep(0.5)
else: raise SystemExit('Test API chưa khởi động. Xem .local/test-api.log')
PY
python3 -m unittest discover -s tests -v
if [[ "${RUN_FLUTTER_LIVE:-0}" == "1" ]]; then
  (cd mobile && flutter test test/live_api_test.dart --reporter expanded \
    --dart-define=LIVE_API=true --dart-define=API_BASE_URL=http://127.0.0.1:5081)
fi
# Direct SQL confirms the smoke test wrote real PostgreSQL rows.
docker compose exec -T postgres psql -U student -d "$test_db" -c 'SELECT count(*) AS transactions_written FROM transactions;'
