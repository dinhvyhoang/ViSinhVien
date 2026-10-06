# Hướng dẫn chạy từng bước

## 1. Cài công cụ trên máy của bạn

- Flutter **3.35.7** (Dart 3.9.2), Android Studio + Android SDK và emulator.
- .NET **8 SDK** (8.0.419 hoặc bản vá 8.0.4xx mới hơn), Visual Studio 2022
  nếu muốn dùng IDE cho backend.
- Docker Desktop + Docker Compose để chạy PostgreSQL 16. pgAdmin 4 có thể
  cài trực tiếp trên Windows hoặc dùng container trong dự án.
- Git. Python 3 chỉ cần cho bộ kiểm thử API tự động.

```sh
git clone https://github.com/dinhvyhoang/ViSinhVien.git
cd ViSinhVien
```

Không cần tạo worktree. Mở thư mục `mobile` bằng Android Studio; mở
`backend/ViSinhVien.Api/ViSinhVien.Api.csproj` bằng Visual Studio.

## 2. PostgreSQL và pgAdmin 4

Sao chép `.env.example` thành `.env`. Nhập hai mật khẩu phát triển của bạn
vào `POSTGRES_PASSWORD`, `PGADMIN_PASSWORD`; dùng chữ và số để thuận tiện
cho các script mẫu. File này đã được Git bỏ qua. Không chia sẻ mật khẩu.

```sh
docker compose --profile admin up -d --wait
```

Container PostgreSQL tạo database `student_finance` với user `student`.
Trên máy của bạn, pgAdmin web dùng cổng **5050**, đăng nhập bằng
`PGADMIN_EMAIL` và `PGADMIN_PASSWORD` trong `.env`.

Trong pgAdmin chọn **Register → Server**:

| Mục | Giá trị |
|---|---|
| Name | Ví Sinh Viên |
| Host | `postgres` nếu dùng pgAdmin container; `localhost` nếu pgAdmin cài trên Windows |
| Port | `5432` |
| Maintenance database | `student_finance` |
| Username | `student` |
| Password | Giá trị `POSTGRES_PASSWORD` trong `.env` |

Chỉ tạo role và database riêng cho bài; không dùng `cafe_pos`.
Nếu đã có PostgreSQL trên cổng 5432, có thể dùng bản đang cài và tạo database
`student_finance` trong pgAdmin, rồi truyền chuỗi kết nối của nó cho API
thay vì chạy script Docker. Các lệnh EF và Flutter bên dưới vẫn giữ nguyên.

## 3. Chạy backend và tạo bảng

Mở terminal tại thư mục gốc repository. Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-api.ps1
```

Linux/macOS/Git Bash:

```sh
bash scripts/run-api.sh
```

Script khởi động PostgreSQL, áp dụng migration và chạy API trên cổng **5080**.
Giữ terminal này mở. Kiểm tra bằng một terminal khác:

```sh
curl http://127.0.0.1:5080/api/health
curl http://127.0.0.1:5080/api/categories
```

Kết quả health phải có `status: ok`; danh mục có Ăn uống, Đi lại, Học tập,
Sinh hoạt, Gia đình hỗ trợ, Làm thêm. Trong pgAdmin refresh Schemas → public →
Tables để thấy ba bảng. Migration là nguồn cấu trúc; SQL tương ứng ở
`docs/database.sql`. Xem [API.md](API.md) để thử các endpoint.

Nếu dùng PostgreSQL cài sẵn, trong PowerShell đặt chuỗi kết nối với thông tin
của bạn rồi chạy thủ công:

```powershell
$env:ConnectionStrings__Finance = 'Host=localhost;Port=5432;Database=student_finance;Username=TEN_USER;Password=MAT_KHAU_CUA_BAN'
dotnet tool restore
dotnet ef database update --project backend/ViSinhVien.Api
dotnet run --no-launch-profile --project backend/ViSinhVien.Api --urls http://0.0.0.0:5080
```

## 4. Chạy Flutter trên Android Emulator

Khởi động emulator trong Android Studio, rồi mở terminal mới:

```sh
cd mobile
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

`10.0.2.2` là địa chỉ để **Android Emulator của Android Studio** gọi máy đang
chạy API. Mặc định ứng dụng cũng dùng địa chỉ này. Flutter không biết mật khẩu
PostgreSQL và không truy cập database trực tiếp.

Trên điện thoại thật, thay `10.0.2.2` bằng địa chỉ IPv4 trong mạng LAN của
máy chạy API, đặt điện thoại và máy tính cùng mạng, cho phép cổng 5080 qua
firewall của máy trên mạng riêng. Truyền địa chỉ đó bằng `API_BASE_URL`.

Nếu dùng Chrome để phát triển giao diện:

```sh
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5080
```

## 5. Demo luồng đầu tiên

1. Mở Giao dịch → dấu `+`.
2. Chọn Chi → Ăn uống → nhập `35000`, giữ ngày hôm nay, ghi chú Ăn trưa.
3. Bấm Lưu một lần; ứng dụng khóa nút trong lúc gửi và quay về danh sách
   khi API xác nhận thành công.
4. Trong pgAdmin Query Tool chạy:

```sql
SELECT t.id, c.name, t.amount_vnd, t.transaction_date, t.note
FROM transactions t JOIN categories c ON c.id = t.category_id
ORDER BY t.id DESC LIMIT 10;
```

5. Phải có khoản 35.000đ vừa nhập. Quay lại Tổng quan và chọn cùng tháng để
   xem tổng chi. Sửa thành 42.000đ rồi kiểm tra lại; thử xóa với xác nhận.
6. Thêm danh mục, tạo giao dịch rồi lưu trữ danh mục: lịch sử vẫn còn.
7. Đặt ngân sách và thử ba mức 80%, 100%, vượt 100%.

## 6. Kiểm thử và build

Tại thư mục `mobile`:

```sh
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

APK nằm tại `mobile/build/app/outputs/flutter-apk/app-release.apk`.
APK này dành cho **demo phát triển**: chữ ký debug của template Flutter và
cho phép HTTP để gọi API trong mạng riêng. Khi dùng điện thoại thật, build
lại với IP máy của bạn. Chưa có đăng nhập hay cấu hình phát hành lên store.

Tại thư mục gốc, Linux/macOS/Git Bash:

```sh
bash scripts/test-api.sh
RUN_FLUTTER_LIVE=1 bash scripts/test-api.sh
```

Lệnh thứ hai cần Flutter trên PATH và chạy thêm kiểm thử HTTP thật từ client
Flutter tới API/PostgreSQL. Lệnh `flutter test` thông thường bỏ qua hai bài
live này vì cần database riêng. Bộ test API không làm thay đổi dữ liệu cá nhân.

Sao lưu database sau khi demo:

```sh
mkdir -p .local
docker compose exec -T postgres pg_dump -U student -d student_finance > .local/student_finance.sql
```

Dừng API bằng Ctrl+C, dừng Docker bằng `docker compose --profile admin stop`.
Không dùng `down -v` nếu cần giữ giao dịch. Khi mở lại, chạy script API và
Flutter; pgAdmin có thể đóng mà ứng dụng vẫn hoạt động.
