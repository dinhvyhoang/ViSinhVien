# API Ví Sinh Viên

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
| GET | `/api/reports/summary?period=month&date=2026-10-22` | Báo cáo tuần/tháng/năm, tỷ trọng danh mục |
| GET | `/api/reports/export?period=month&date=2026-10-22` | Tải CSV UTF-8 BOM cho Excel, dữ liệu giao dịch thật |
| GET | `/api/budgets/2026-10` | `limitVnd: null` khi chưa thiết lập |
| PUT | `/api/budgets/2026-10` | `{limitVnd}`; tạo/cập nhật đúng một dòng |
| DELETE | `/api/budgets/2026-10` | Gỡ hạn mức tháng, không xóa giao dịch hay hạn mức danh mục |
| PUT | `/api/budgets/2026-10/categories/1` | `{limitVnd}`; hạn mức danh mục chi đang sử dụng |
| DELETE | `/api/budgets/2026-10/categories/1` | Gỡ hạn mức danh mục, giữ nguyên giao dịch |
| GET | `/api/profile` | `{displayName}`; rỗng khi người dùng chưa nhập tên |
| PUT | `/api/profile` | `{displayName}`; tối đa 80 ký tự, lưu PostgreSQL |

Danh sách trả `{items, total, page, pageSize}`; ngày mới nhất trước. Tìm kiếm
trong ghi chú và tên danh mục. Bộ lọc kết hợp với nhau. Danh mục lưu trữ vẫn
hiện trong giao dịch cũ, không nhận giao dịch mới; giao dịch cũ được sửa số
tiền/ngày/ghi chú mà không bắt đổi danh mục.

Ngày giao dịch không được ở tương lai theo múi giờ Việt Nam (`Asia/Ho_Chi_Minh`).
Ứng dụng một người dùng, chưa có xác thực hoặc đồng bộ tài khoản đám mây.
Database chỉ khởi tạo danh mục; không tự tạo giao dịch, ngân sách hay tên người dùng.

## Báo cáo tuần tháng năm

`period`: `week`, `month`, `year`. `date`: ngày bất kỳ nằm trong kỳ dạng
`yyyy-MM-dd`, năm 1900–2100. Tuần bắt đầu thứ Hai và kết thúc Chủ nhật.
Kết quả gồm `period`, `startDate`, `endDate` (bao gồm ngày cuối), `incomeVnd`,
`expenseVnd`, `balanceVnd`, `transactionCount`, `expenseByCategory`.
Mỗi dòng danh mục gồm `categoryId`, `categoryName`, `type`, `amountVnd`,
`transactionCount`, `percent` (phần trăm tổng chi, làm tròn 2 chữ số).
Kỳ không có dữ liệu trả số tổng bằng 0 và danh sách rỗng.

CSV dùng cùng tham số kỳ, chứa từng giao dịch với mã, ngày, danh mục, loại,
số tiền nguyên VND và ghi chú. Có dấu BOM UTF-8 cho tiếng Việt trong Excel;
ghi chú và tên bắt đầu ký tự công thức được thoát dưới dạng văn bản.

## Ngân sách tháng và danh mục

GET ngân sách trả `month`, `limitVnd`, `spentVnd`, `remainingVnd`, `percent`,
`status`, `categoryBudgets`. Khi chưa đặt hạn mức, `limitVnd`, `remainingVnd`,
`percent` là `null`, `status` là `unset`.
Trạng thái `normal`: dưới 80%; `warning`: từ 80% đến dưới 100%; `reached`:
đúng 100%; `exceeded`: vượt 100%. Khoản còn lại có thể âm khi vượt ngân sách.

Mỗi dòng `categoryBudgets` chứa `categoryId`, `categoryName`, `isArchived`,
`limitVnd`, `spentVnd`, `remainingVnd`, `percent`, `status`. Danh sách bao gồm
mọi danh mục chi đang sử dụng, cùng danh mục lưu trữ có chi tiêu hoặc hạn mức
trong tháng. Hạn mức danh mục độc lập với hạn mức tổng tháng; ngân sách tháng
luôn tính theo tổng chi thực tế, không lấy chênh lệch thu chi.

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

Tạo database tạm độc lập, migrate, khởi động API trên cổng 5081, chạy 15 bài
kiểm thử (kèm nhiều tình huống dữ liệu sai), kiểm tra SQL trực tiếp rồi dọn
database tạm. Không dùng database chứa giao dịch của bạn.
