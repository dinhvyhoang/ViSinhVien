# Kết quả kiểm tra trong cloud Linux

Toolchain: .NET SDK 8.0.425, Flutter 3.35.7 / Dart 3.9.2,
PostgreSQL 16, pgAdmin 4 phiên bản 9.8.

| Kiểm tra | Kết quả |
|---|---|
| Build backend | Đạt |
| API + PostgreSQL thật | 8 bài đạt; có nhiều tình huống con cho dữ liệu sai |
| Widget Flutter | 6 bài đạt |
| Flutter HTTP → API → PostgreSQL | 2 bài live đạt |
| `flutter analyze` | Không có vấn đề |
| Cài lại bằng lockfile | .NET `--locked-mode`, Flutter `--enforce-lockfile` đạt |
| Chạy lại migration | Không tạo lại bảng hay dữ liệu mẫu |
| PostgreSQL dừng | Health, đọc danh mục và thêm giao dịch trả 503 với JSON thông báo |
| PostgreSQL khởi động lại | API phục hồi, health trả 200 |
| pgAdmin | Container healthy, endpoint ping trả 200; tạm dừng để dành dung lượng build |
| Android APK release | Build thành công (khoảng 50 MB), chữ ký demo được xác minh bằng apksigner |

Luồng live đã kiểm tra: Flutter gửi khoản chi **35.000đ**, API ghi PostgreSQL,
Flutter đọc lại đúng danh mục/số tiền, sửa thành **42.000đ**, kiểm tra báo cáo
rồi xóa. Các test chạy trong database tạm và dọn database sau khi kết thúc.

Widget test kiểm tra số tiền sai không được gửi, body đúng, chỉ đóng form khi
thành công, giữ tiền/ghi chú khi backend lỗi, khóa nút tránh gửi hai lần,
tổng quan trên màn hình hẹp và lưu ngân sách rồi tải lại báo cáo.

`flutter test` mặc định chạy 6 bài widget và **bỏ qua 2 bài live**. Hai bài
live đã được chạy riêng bằng `RUN_FLUTTER_LIVE=1 bash scripts/test-api.sh`.

Các phần cần kiểm tra trên máy của bạn: chạy script PowerShell trên Windows,
thao tác bằng Android Emulator/điện thoại thật và mở dữ liệu bằng giao diện
pgAdmin. Cloud chưa thực hiện các thao tác này trên thiết bị thật.

Xem [hướng dẫn chạy và demo](HUONG_DAN_CHAY.md) để kiểm tra từng bước.

APK hiện dùng `API_BASE_URL=http://10.0.2.2:5080` cho Android Emulator. File
`mobile/build/app/outputs/flutter-apk/app-release.apk` là output build, không
đưa vào Git. Chưa chạy APK trên emulator/điện thoại thật. Bản này dùng chữ ký
debug theo template để demo; điện thoại thật cần build với IP LAN máy API.
