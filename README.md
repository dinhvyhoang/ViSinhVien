# Ví Sinh Viên

Đồ án đơn giản: **Flutter + ASP.NET Core 8 API + PostgreSQL 16/18**, quản lý
database bằng **pgAdmin 4**. Một người dùng, chưa có đăng nhập. **Không có giao dịch, ngân sách hoặc số dư giả**; chỉ các tên danh mục mặc định được khởi tạo theo đặc tả.

Xem [hướng dẫn chạy từng bước](docs/HUONG_DAN_CHAY.md),
[yêu cầu và thiết kế](docs/YEU_CAU.md), [API](docs/API.md).

Bản đầu gồm thêm/xem/sửa/xóa giao dịch, lọc và tìm kiếm, danh mục có lưu trữ,
tổng quan tháng, biểu đồ tròn/cột theo danh mục, ngân sách tháng và từng danh mục, cảnh báo 80%/100%/vượt mức, báo cáo tuần/tháng/năm và xuất CSV.
Giao diện dùng StatefulWidget và HTTP trực tiếp, không thêm kiến trúc phức tạp.

## Chạy nhanh

Sau khi tạo `.env` và cài .NET 8 + Flutter 3.47.6 + Docker:

```sh
bash scripts/run-api.sh
```

Windows dùng `powershell -ExecutionPolicy Bypass -File scripts/run-api.ps1` (Docker) hoặc `powershell -ExecutionPolicy Bypass -File scripts/run-api-local.ps1` (PostgreSQL 18 + pgAdmin 4 đã cài sẵn).
Giữ terminal API mở, mở terminal mới để chạy Android Emulator:

```sh
cd mobile
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

Xem hướng dẫn đầy đủ nếu chạy trên điện thoại thật hoặc PostgreSQL cài sẵn.

## Chuẩn bị database

Cài Docker + Docker Compose. Sao chép `.env.example` thành `.env`, nhập hai
mật khẩu phát triển riêng cho PostgreSQL và pgAdmin. Không commit `.env`.

```sh
docker compose --profile admin up -d --wait
```

Trên máy của bạn, mở pgAdmin tại cổng 5050 và đăng nhập bằng email/mật khẩu
trong `.env`. Register Server với Host `postgres`, Port `5432`, Maintenance
database `student_finance`, Username `student`, Password `POSTGRES_PASSWORD`
trong `.env`. Nếu dùng pgAdmin cài trực tiếp trên máy, Host là `localhost`.

Database này tách riêng với bài `cafe_pos`. Dừng dịch vụ bằng
`docker compose --profile admin stop`; dữ liệu nằm trong volume và vẫn được giữ.

## Cấu trúc

- `backend/`: API .NET, EF Core migrations.
- `mobile/`: Flutter để mở trong Android Studio.
- `docs/`: yêu cầu, cách chạy, kiểm tra.
- `scripts/`: lệnh hỗ trợ phát triển và kiểm thử.

Không đưa mật khẩu PostgreSQL vào Flutter. Đây là bản demo một người dùng;
chỉ chạy trong môi trường phát triển, chưa triển khai công khai.

