# Flutter — Ví Sinh Viên

Mở thư mục này bằng Android Studio. Đã kiểm chứng với Flutter 3.47.6, Dart 3.13.5.

```sh
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

Chạy PostgreSQL và API trước. Xem [hướng dẫn đầy đủ](../docs/HUONG_DAN_CHAY.md).
`10.0.2.2` dành cho Android Emulator; điện thoại thật dùng IP LAN của máy API.

Code chia thành `api_client.dart`, `models.dart`, `widgets.dart` và các màn hình
trong `screens/`. Dùng StatefulWidget, không thêm thư viện quản lý state.
Biểu đồ dùng thanh theo tỷ lệ tổng chi để dễ hiểu và sửa.

```sh
flutter analyze
flutter test
```

Hai test HTTP thật được chạy riêng bằng `RUN_FLUTTER_LIVE=1 bash scripts/test-api.sh`
từ thư mục gốc. Không đưa mật khẩu database vào ứng dụng.


### Địa chỉ API mặc định

- Android Emulator: `http://10.0.2.2:5080`.
- Chrome trên máy phát triển: `http://127.0.0.1:5080`.
- Điện thoại thật: thêm `--dart-define=API_BASE_URL=http://IP_MAY_TINH:5080` và chạy API với `-AllowLan` trên mạng riêng.

Không có dữ liệu giao dịch, ngân sách, số dư hay biểu đồ giả được gắn trong ứng dụng; màn hình trống sẽ hiển thị thông báo để tạo dữ liệu thật. `MockClient` chỉ dùng trong thư mục `test/` để tự động kiểm tra giao diện, không chạy trong bản phát hành.

