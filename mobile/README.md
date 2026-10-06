# Flutter — Ví Sinh Viên

Mở thư mục này bằng Android Studio. Dùng Flutter 3.35.7, Dart 3.9.2.

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
