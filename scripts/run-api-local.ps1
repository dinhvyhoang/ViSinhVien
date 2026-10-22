# Use the PostgreSQL server already installed on Windows (no Docker required).
# Create the database student_finance in pgAdmin before running this script.
param(
    [string]$DbHost = '127.0.0.1',
    [int]$DbPort = 5432,
    [string]$Database = 'student_finance',
    [string]$DbUser = 'postgres',
    [switch]$AllowLan
)
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
$original = [Environment]::GetEnvironmentVariable('ConnectionStrings__Finance', 'Process')
$pwdText = $null
try {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'Khong tim thay dotnet. Cai .NET 8 SDK hoac ban SDK moi hon.'
    }
    $password = Read-Host "Mat khau PostgreSQL cho user $DbUser (khong hien ky tu)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    try { $pwdText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    # PostgreSQL/Npgsql connection strings use double quotes to protect ; and =.
    $escaped = $pwdText.Replace('"','""')
    $env:ConnectionStrings__Finance = 'Host={0};Port={1};Database={2};Username={3};Password="{4}"' -f $DbHost, $DbPort, $Database, $DbUser, $escaped
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'Khong cai duoc dotnet-ef. Kiem tra ket noi internet va .NET SDK.' }
    dotnet ef database update --project backend/ViSinhVien.Api
    if ($LASTEXITCODE -ne 0) { throw 'Migration that bai. Kiem tra PostgreSQL, ten database va mat khau.' }
    $url = if ($AllowLan) { 'http://0.0.0.0:5080' } else { 'http://127.0.0.1:5080' }
    Write-Host "API dang khoi dong tai $url (Ctrl+C de dung)" -ForegroundColor Green
    if ($AllowLan) { Write-Warning 'Chi dung AllowLan trong mang rieng an toan. API demo chua co dang nhap.' }
    dotnet run --no-launch-profile --project backend/ViSinhVien.Api --urls $url
    if ($LASTEXITCODE -ne 0) { throw 'API dung voi loi.' }
} finally {
    $pwdText = $null
    [Environment]::SetEnvironmentVariable('ConnectionStrings__Finance', $original, 'Process')
    Pop-Location
}
