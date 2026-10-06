# API bản đầu

Tiền là số nguyên VND, tối đa 1.000.000.000.000 đồng mỗi giao dịch/ngân sách.
Ngày dạng `yyyy-MM-dd`, tháng dạng `yyyy-MM`. Loại: `income` hoặc `expense`.
Mã lỗi: 400 dữ liệu sai, 404 không tìm thấy, 409 xung đột, 503 mất database.
Lỗi có trường `message` để Flutter hiển thị.

| Phương thức | Đường dẫn | Dữ liệu hoặc chức năng |
|---|---|---|
| GET | `/api/health` | Kiểm tra API và database |
| GET | `/api/categories` | Bao gồm cả danh mục lưu trữ |
| POST | `/api/categories` | `{name, type}` |
| PUT | `/api/categories/{id}` | `{name, isArchived}`; không đổi loại |
| GET | `/api/transactions` | `month`, `type`, `categoryId`, `search`, `page`, `pageSize` |
| GET | `/api/transactions/{id}` | Xem chi tiết |
| POST | `/api/transactions` | `{categoryId, amountVnd, transactionDate, note}` |
| PUT | `/api/transactions/{id}` | Cùng dữ liệu POST |
| DELETE | `/api/transactions/{id}` | 204 khi xóa thành công |
| GET | `/api/reports/monthly?month=2026-10` | Thu, chi, chênh lệch, ngân sách, chi theo danh mục |
| GET | `/api/budgets/2026-10` | `limitVnd: null` khi chưa thiết lập |
| PUT | `/api/budgets/2026-10` | `{limitVnd}`; tạo/cập nhật đúng một dòng |

Danh sách trả `{items, total, page, pageSize}`; ngày mới nhất trước. Tìm kiếm
trong ghi chú và tên danh mục. Bộ lọc kết hợp với nhau. Danh mục lưu trữ vẫn
hiện trong giao dịch cũ, không nhận giao dịch mới; giao dịch cũ được sửa số
tiền/ngày/ghi chú mà không bắt đổi danh mục.

## Chạy API

Cài .NET SDK 8.0.419 trở lên trong nhánh 8.0.4xx, Docker, tạo `.env`.
Trên Linux/macOS/Git Bash:

```sh
bash scripts/run-api.sh
```

API dùng cổng 5080. Mở file `backend/ViSinhVien.Api/ViSinhVien.Api.csproj`
trong Visual Studio để học và sửa code. Chuỗi kết nối được truyền bằng biến
môi trường, không ghi vào mã nguồn. Xem hướng dẫn chạy đầy đủ trong README.

## Migration và pgAdmin

`dotnet ef database update --project backend/ViSinhVien.Api` áp dụng migration.
`docs/database.sql` được xuất **từ migration EF Core**, có thể chạy bằng Query
Tool trên database `student_finance` trong pgAdmin. Script idempotent ghi lịch
sử EF nên việc chạy lại migration không tạo bảng trùng.

```sql
SELECT * FROM categories ORDER BY id;
SELECT t.id, c.name, c.type, t.amount_vnd, t.transaction_date, t.note
FROM transactions t JOIN categories c ON c.id = t.category_id
ORDER BY t.transaction_date DESC, t.id DESC;
SELECT * FROM monthly_budgets ORDER BY budget_month;
```

## Kiểm thử tích hợp

```sh
bash scripts/test-api.sh
```

Tạo database tạm độc lập, migrate, khởi động API trên cổng 5081, chạy 8 bài
kiểm thử (kèm nhiều tình huống dữ liệu sai), kiểm tra SQL trực tiếp rồi dọn
database tạm. Không dùng database chứa giao dịch của bạn.
