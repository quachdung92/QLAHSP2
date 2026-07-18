# `supabase/` — schema Postgres cho QLVA (nhánh `supabase-migration`)

Xem `SUPABASE_MIGRATION.md` ở gốc repo để biết bối cảnh/lộ trình đầy đủ. Thư mục này chỉ chứa
DDL/RLS/RPC — **chưa từng được áp dụng lên Supabase thật**, vì chưa có project/env (đang ở Phase
0/1, chờ Dũng cấp thông tin kết nối).

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

## Thứ tự áp dụng khi có env (Phase 1)

```sql
-- Trong Supabase SQL Editor, hoặc qua psql với connection string:
\i schema.sql
\i rls.sql
\i functions.sql
```

`schema.sql` phải chạy trước (tạo bảng) → `rls.sql` (cần bảng đã tồn tại) → `functions.sql` (cần
bảng `boDemMaVu`/`vuan`/`bican` đã tồn tại).

## Đã kiểm chứng đến đâu

**Đã làm**: cả 3 file đã parse-check sạch bằng `libpg-query` (Node binding của ĐÚNG bộ phân tích
cú pháp Postgres thật, chạy qua WASM, không phải regex/đoán) — xác nhận cấu trúc SQL bên ngoài
(`CREATE TABLE`, `CREATE INDEX`, `DO $$...$$`, `CREATE FUNCTION` wrapper, `GRANT`/`REVOKE`) hợp lệ
cú pháp. **Chưa làm**: phần THÂN của 4 hàm `plpgsql` trong `functions.sql` (đoạn trong dấu
`$$...$$`) chỉ được bộ parser trên coi là 1 chuỗi mờ (không phân tích sâu vào bên trong) — nghĩa
là logic bên trong (vòng lặp, `array_fill`, `unnest`, `string_agg`, gán biến...) mới chỉ được soát
tay, CHƯA được trình biên dịch `plpgsql` thật xác nhận. Cũng chưa test NGỮ NGHĨA (constraint có
đúng ý, index có được dùng, RLS có chặn đúng) — tất cả cần Postgres thật.

## Việc cần làm ngay khi có project Supabase thật

1. Áp dụng cả 3 file lên project `qlahs-test`-tương-đương trước (KHÔNG áp dụng lên project ứng
   với `qlahsp2` cho tới khi đã kiểm chứng kỹ trên test).
2. Xác nhận `CREATE FUNCTION` không lỗi khi Postgres thật biên dịch phần thân `plpgsql` (bước này
   parse-check ở trên KHÔNG bao phủ, xem "Đã kiểm chứng đến đâu").
3. Test thử 4 hàm RPC bằng dữ liệu giả (VD gọi `sinhMaVuAnMoi('2601')` 2 lần liên tiếp, xác nhận
   ra đúng `..._0001` rồi `..._0002`; gọi `capNhatDieuLuatVaLoaiKhoiTo` sau khi insert vài dòng
   `bican` giả, xác nhận `vuan.dieuLuat`/`bican.loaiKhoiTo` tính đúng).
4. Xác nhận RLS hoạt động đúng: request không có JWT (`anon`) bị chặn hoàn toàn; request có JWT
   hợp lệ đọc/ghi được mọi bảng.
5. Rà lại xem Supabase project mặc định có sẵn `pgcrypto` chưa (thường có sẵn, nhưng xác nhận lại
   thay vì giả định).
