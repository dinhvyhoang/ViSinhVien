# Lấy mã nguồn và chạy trên máy Windows khác

Đây là cùng mã nguồn đã build APK và chạy trên giả lập Pixel 7. Máy mới cần cài công cụ và có PostgreSQL riêng; không phụ thuộc đường dẫn hoặc database trên máy tác giả.

## Chuẩn bị một lần

- Git, Flutter 3.47.6 (Dart 3.13.5).
- Android Studio, Android SDK và một Android Emulator nếu muốn chạy Android. Môi trường đã kiểm chứng dùng JDK 25 đi kèm Android Studio, Gradle 9.3.1 và Android Gradle Plugin 9.1.0; wrapper Gradle đã nằm trong repo.
- .NET 8 SDK 8.0.419 trở lên trong nhánh 8.0.4xx. Nếu dùng SDK 10 như máy đã kiểm chứng, cài thêm ASP.NET Core Runtime 8.
- PostgreSQL 16 hoặc 18 đang chạy, pgAdmin 4 để tạo database. Nhớ user, mật khẩu và cổng của PostgreSQL trên máy mình.
- Chrome nếu muốn chạy giao diện web.

Chạy `flutter doctor` và xử lý các mục Android nếu dùng giả lập. Lần build đầu cần Internet để tải dependency.

## 1. Clone mã nguồn

```powershell
git clone https://github.com/dinhvyhoang/ViSinhVien.git
cd ViSinhVien
```

Nếu đã clone, lưu các thay đổi riêng rồi dùng `git pull` để cập nhật.

## 2. Tạo database và chạy API

Trong pgAdmin kết nối PostgreSQL của máy mình, tạo database **student_finance**. Không cần tự tạo bảng hoặc chạy file SQL: script sẽ chạy EF migrations.

Mở PowerShell tại thư mục gốc `ViSinhVien`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-api-local.ps1 -DbUser postgres -DbPort 5432
```

Thay user/cổng nếu PostgreSQL trên máy dùng giá trị khác. Nhập mật khẩu PostgreSQL khi được hỏi. Cách này không cần Docker và không cần file `.env`.

**Giữ terminal API mở.** Mở `http://127.0.0.1:5080/api/health`; phải thấy `status: ok`. Nếu lỗi kết nối, kiểm tra dịch vụ PostgreSQL, user, mật khẩu, cổng và tên database.

## 3. Chạy giao diện

Mở terminal thứ hai tại thư mục gốc:

```powershell
cd mobile
flutter pub get --enforce-lockfile
```

Chọn một cách chạy:

**Chrome trên cùng máy** (không cần giả lập):

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5080
```

**Android Emulator**: dùng Android Studio mở thư mục `mobile`, khởi động máy ảo trong Device Manager rồi chạy:

```powershell
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

Nếu mã thiết bị khác `emulator-5554`, dùng mã hiển thị bởi `flutter devices`. `10.0.2.2` là địa chỉ máy chạy API nhìn từ Android Emulator.

Điện thoại vật lý cần IP LAN của máy API, cùng mạng riêng và script API có tham số `-AllowLan`; xem `HUONG_DAN_CHAY.md`. APK cấu hình cho emulator không tự kết nối được API trên máy khác hoặc điện thoại thật.

## Dữ liệu và trạng thái

- Máy bạn bắt đầu với danh mục mặc định và không có giao dịch/ngân sách. Thêm dữ liệu trong ứng dụng sẽ lưu thật vào PostgreSQL của máy bạn.
- Git không chứa mật khẩu hoặc dữ liệu cá nhân trên máy tác giả. Vì vậy giao diện giống nhau nhưng số tiền phụ thuộc dữ liệu bạn nhập.
- Đã xác nhận trên máy phát triển: .NET build; Flutter analyze; 18 kiểm thử Flutter, 2 kiểm thử HTTP thật và 15 kiểm thử API; build web, build APK và mở app trên giả lập Pixel 7. Chưa xác nhận trên máy của người nhận hoặc điện thoại vật lý.
- Đăng nhập nhiều người dùng và nhắc ghi chép theo lịch chưa được triển khai.
