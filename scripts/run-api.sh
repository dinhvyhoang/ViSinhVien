#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f .env ]]; then
  echo 'Tạo .env từ .env.example và nhập mật khẩu trước.' >&2
  exit 1
fi
set -a
source .env
set +a
export ConnectionStrings__Finance="Host=127.0.0.1;Port=5432;Database=student_finance;Username=student;Password=${POSTGRES_PASSWORD:?}"
export ASPNETCORE_ENVIRONMENT=Development
export DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1
docker compose up -d --wait postgres
dotnet tool restore
dotnet ef database update --project backend/ViSinhVien.Api
exec dotnet run --no-launch-profile --project backend/ViSinhVien.Api --urls "${API_URLS:-http://0.0.0.0:5080}"
