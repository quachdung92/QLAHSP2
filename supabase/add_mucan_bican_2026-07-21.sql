-- ============================================================================
-- QLVA — Thêm cột mức án TỪNG bị can vào bảng "bican" (2026-07-21)
--
-- BỐI CẢNH: tính năng mới "Mức án từng bị can" (nhập ở HoanThanhVuAnModal lúc chọn "Đã xét xử"
-- và ở SuaVuAnForm để bổ sung/sửa lại sau) cần ghi mucAnLoai/mucAnNam/mucAnThang lên TỪNG dòng
-- "bican" — 3 cột NÀY CHƯA TỪNG TỒN TẠI trên bảng "bican" (chỉ có sẵn trên "vuan", dùng cho mức
-- án cấp VỤ đã có từ trước, xem "vuan"."mucAnLoai" trong schema.sql). Khác Firestore (schemaless,
-- ghi field mới vào 1 document không cần khai báo trước), Postgres BẮT BUỘC phải ALTER TABLE
-- trước — thiếu bước này thì mọi lượt ghi `bican.mucAnLoai/...` từ `qlahs-sup.html` sẽ lỗi
-- "column does not exist" (đã xác nhận THẬT qua UI: batch.commit() ném lỗi 42703 cho phần ghi
-- "bican", trong khi phần ghi "vuan" cùng batch vẫn thành công vì "vuan" đã có sẵn cột này — xem
-- CLAUDE.md/ghi chú phiên 2026-07-21 để biết chi tiết cách phát hiện).
--
-- Kiểu dữ liệu/ràng buộc COPY Y HỆT "vuan"."mucAnLoai"/"mucAnNam"/"mucAnThang" trong schema.sql
-- (dòng ~168-170) để 2 nơi nhất quán, cùng enum NHAN_LOAI_MUC_AN phía JS.
--
-- AN TOÀN: chỉ ADD COLUMN (không đụng dữ liệu/cột nào có sẵn), cả 3 cột đều NULLABLE (không có
-- "not null"/default bắt buộc) — không có dòng "bican" nào bị ảnh hưởng, không cần backfill.
-- Chạy 1 lần qua Supabase Dashboard → SQL Editor (project eutatszoaseixchvjbtg), hoặc qua Session
-- pooler như các script khác trong thư mục này (xem supabase/README.md mục "Kết nối").
-- ============================================================================

alter table "bican"
  add column if not exists "mucAnLoai" text check ("mucAnLoai" in ('nam','an_treo','phat_tien','chung_than','tu_hinh')),
  add column if not exists "mucAnNam" integer,
  add column if not exists "mucAnThang" integer check ("mucAnThang" between 0 and 11);
