# Ví Sinh Viên

Đồ án đơn giản: **Flutter + ASP.NET Core 8 API + PostgreSQL 16**, quản lý
database bằng **pgAdmin 4**. Một người dùng, chưa có đăng nhập.

Xem [yêu cầu và thiết kế](docs/YEU_CAU.md). Các phần sẽ được hoàn thiện và
commit theo từng mốc của lộ trình.

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
