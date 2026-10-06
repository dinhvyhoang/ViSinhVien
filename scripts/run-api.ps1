$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    if (-not (Test-Path '.env')) { throw 'Tao .env tu .env.example va nhap mat khau truoc.' }
    Get-Content '.env' | ForEach-Object {
        if ($_ -match '^([A-Z_]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2].Trim('"', "'"), 'Process')
        }
    }
    if (-not $env:POSTGRES_PASSWORD) { throw 'Thieu POSTGRES_PASSWORD trong .env.' }
    $env:ConnectionStrings__Finance = "Host=127.0.0.1;Port=5432;Database=student_finance;Username=student;Password=$env:POSTGRES_PASSWORD"
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    docker compose up -d --wait postgres
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL chua san sang.' }
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'Khong khoi phuc duoc dotnet-ef.' }
    dotnet ef database update --project backend/ViSinhVien.Api
    if ($LASTEXITCODE -ne 0) { throw 'Migration that bai.' }
    dotnet run --no-launch-profile --project backend/ViSinhVien.Api --urls http://0.0.0.0:5080
    if ($LASTEXITCODE -ne 0) { throw 'API dung voi loi.' }
} finally { Pop-Location }
