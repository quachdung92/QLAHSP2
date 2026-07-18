# `supabase/` — schema Postgres cho QLVA (nhánh `supabase-migration`)

Xem `SUPABASE_MIGRATION.md` ở gốc repo để biết bối cảnh/lộ trình đầy đủ. **ĐÃ áp dụng thành công
lên Supabase thật** (project `eutatszoaseixchvjbtg`, xem `SUPABASE_MIGRATION.md` mục 4c) — không
còn ở trạng thái "chỉ là bản nháp chờ env" nữa.

## Nội dung

- `schema.sql` — `CREATE TABLE`/`CREATE INDEX` cho 7 bảng nghiệp vụ + 1 bảng đếm nội bộ
  (`boDemMaVu`). Đọc phần comment đầu file trước khi sửa — có 6 quyết định thiết kế quan trọng
  (tên cột camelCase có quote, enum dùng CHECK không dùng native ENUM, mảng song song giữ nguyên
  dạng cột `text[]` không tách bảng con...).
- `rls.sql` — bật Row Level Security + 1 policy "authenticated đọc/ghi mọi thứ" cho mỗi bảng,
  mirror đúng `firestore.rules` hiện tại (không phân quyền theo role/field).
- `functions.sql` — 4 hàm RPC thay 4 vị trí `db.runTransaction()` của Firestore (sinh mã vụ án,
  sinh mã hàng loạt, sinh mã vụ tách, tính lại điều luật/loại khởi tố). Các hàm này sẽ được gọi
  thẳng qua `.rpc(...)` từ JS, KHÔNG đi qua lớp shim giả lập Firestore API.

## Kết nối Supabase project hiện có (ref `eutatszoaseixchvjbtg`)

**Kết nối trực tiếp (`db.eutatszoaseixchvjbtg.supabase.co`) KHÔNG dùng được** từ môi trường thực
thi lệnh hiện tại — host đó chỉ có bản ghi DNS IPv6 (AAAA), không có IPv4, và môi trường này không
có route IPv6 ra ngoài (`ENETUNREACH` khi thử thẳng). Luôn dùng **Session pooler** cho mọi việc
quản trị/import dữ liệu (KHÔNG dùng Transaction pooler — pooler đó tối ưu cho query ngắn hạn của
ứng dụng runtime, không hợp cho script chạy nhiều câu lệnh/hàm `plpgsql`):

```
host: aws-0-ap-southeast-1.pooler.supabase.com
port: 5432
user: postgres.eutatszoaseixchvjbtg
database: postgres
```

Mật khẩu DB **không được ghi vào file nào trong repo** — chỉ truyền qua biến môi trường lúc chạy
script tạm trong thư mục scratchpad (ngoài git), hỏi lại Dũng nếu phiên sau cần dùng lại.

## Đã kiểm chứng (2026-07-19 — đầy đủ, không còn khoảng trống)

1. **Cú pháp**: parse-check sạch qua `libpg-query` (bộ phân tích cú pháp Postgres thật).
2. **Áp dụng thật**: cả 3 file chạy thành công lên project Supabase thật qua Session pooler, không
   sửa gì — 8 bảng + 7 RLS policy + 4 hàm RPC đều tạo đúng, xác nhận `CREATE FUNCTION` biên dịch
   sạch phần thân `plpgsql` (khoảng trống lớn nhất trước đó, giờ đã hết).
3. **Chức năng RPC** (14 assertion, dữ liệu test tự tạo rồi dọn sạch): `sinhMaVuAnMoi`,
   `sinhNhieuMaVuAn` (gộp đúng theo nhóm YYMM), `tachVuSinhMa`, `capNhatDieuLuatVaLoaiKhoiTo` (tính
   đúng `loaiKhoiTo`/`dieuLuat`/cache `soBiCan`+`biCanDaiDien`) — đều PASS.
4. **RLS qua REST API thật** (không phải qua kết nối Postgres trực tiếp — kết nối đó chạy role
   `postgres` superuser nên KHÔNG bị RLS chặn): `POST /rest/v1/vuan` bằng `anon key` bị chặn đúng
   (`HTTP 401`, `42501 - new row violates row-level security policy`).
5. `pgcrypto` có sẵn trên project (không cần cài thêm — `create extension if not exists pgcrypto`
   trong `schema.sql` chạy không lỗi).

## Việc còn lại (Phase 2 trở đi, xem `SUPABASE_MIGRATION.md`)

Không còn việc gì ở tầng schema/RLS/RPC cần làm thêm trước khi bắt đầu viết lớp shim. Việc tiếp
theo là ở tầng ứng dụng (`qlahs-sup.html`) — xem `SUPABASE_MIGRATION.md` mục 8 "Trạng thái hiện
tại" để biết thứ tự việc cần làm.
