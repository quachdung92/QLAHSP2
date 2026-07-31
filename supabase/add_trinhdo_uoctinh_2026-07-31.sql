-- ============================================================================
-- QLVA — Thêm cột "trinhDoUocTinh" vào bảng "bican" (2026-07-31)
--
-- BỐI CẢNH: tính năng mới "Auto-điền Trình độ học vấn" — khi bị can thiếu `trinhDo` (không có giá
-- trị mặc định, khác `gioiTinh` luôn mặc định "nam"), hệ thống tự chọn 1 giá trị NGẪU NHIÊN có
-- trọng số theo độ tuổi + loại tội danh (xem `chonTrinhDoNgauNhien`, `qlahs-sup.html`) thay vì để
-- trống — và đánh dấu bằng cột này để cán bộ biết đây là số DỰ ĐOÁN, chưa xác nhận, cần sửa lại
-- khi có hồ sơ đầy đủ. Cột NÀY CHƯA TỪNG TỒN TẠI trên bảng "bican" — giống mọi lần thêm field mới
-- trước đây (`soButLuc`/`soTapHoSo` ở "hoSoNopLuuKho", `mucAnLoai/...` ở "bican"), Postgres BẮT
-- BUỘC phải ALTER TABLE trước khi code JS ghi được field này — thiếu bước này thì `batch_commit`
-- RPC sẽ ÂM THẦM bỏ qua field lạ (không lỗi, chỉ không ghi được — đã xác nhận qua các lần trước),
-- khiến cột `trinhDoUocTinh` mãi mãi rỗng dù UI hiển thị đã "điền xong".
--
-- Kiểu dữ liệu: boolean, NOT NULL DEFAULT false — mọi dòng "bican" hiện có (kể cả dữ liệu cũ chưa
-- từng qua tính năng này) tự động coi là "không phải ước tính" (đúng, vì chưa hề bị auto-fill).
--
-- AN TOÀN: chỉ ADD COLUMN với DEFAULT cố định — không đụng dữ liệu/cột nào có sẵn, áp dụng ngay cho
-- mọi dòng hiện có mà không cần backfill riêng cho chính cột này.
--
-- CHẠY QUA Session pooler (xem supabase/README.md mục "Kết nối") hoặc Supabase Dashboard → SQL
-- Editor (project eutatszoaseixchvjbtg). BẮT BUỘC chạy NOTIFY ở cuối — thiếu bước này PostgREST sẽ
-- báo "Could not find the 'trinhDoUocTinh' column ... in the schema cache" dù cột đã tồn tại thật
-- (xem SUPABASE_MIGRATION.md mục 10, đã gặp đúng lỗi này nhiều lần trước đây).
--
-- ⚠ CHƯA CHẠY THẬT lên project eutatszoaseixchvjbtg tại thời điểm viết file này (phiên code không
-- có mật khẩu DB) — cần Dũng hoặc phiên có mật khẩu chạy file này TRƯỚC khi tính năng hoạt động
-- được trên dữ liệu thật.
-- ============================================================================

alter table "bican"
  add column if not exists "trinhDoUocTinh" boolean not null default false;

notify pgrst, 'reload schema';
