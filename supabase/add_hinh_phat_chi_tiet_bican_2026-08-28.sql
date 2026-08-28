-- ============================================================================
-- QLVA — Thêm cột "hinhPhatChiTiet" (jsonb) vào bảng "bican" (2026-08-28)
--
-- BỐI CẢNH: nâng cấp tab "Đã xét xử" (module "Án đã giải quyết") — cho nhập ĐIỂM/KHOẢN của điều
-- luật + MỨC ÁN cho TỪNG tội danh của TỪNG bị can (1 bị can nhiều tội, mỗi tội 1 mức án riêng).
-- "bican.hinhPhatChiTiet" là 1 MẢNG jsonb SONG SONG theo index với "bican.toiDanh":
--   [{ "khoan": "2", "diem": "a, b", "mucAnLoai": "nam", "mucAnNam": 7, "mucAnThang": 6 }, ...]
--   - khoan/diem: chuỗi tự do (đúng cách ghi trong bản án).
--   - mucAnLoai/mucAnNam/mucAnThang: cùng enum NHAN_LOAI_MUC_AN + ràng buộc như cột cùng tên.
-- "bican.mucAnLoai"/"mucAnNam"/"mucAnThang" (mức án "chung" của bị can — đã có từ 2026-07-21, dùng
-- tính Thời hạn bảo quản khi nộp lưu kho) giờ TỰ TÍNH cộng dồn từ hinhPhatChiTiet theo Điều 55
-- BLHS 2025 (có tử hình → tử hình; chung thân → chung thân; tù có thời hạn → cộng dồn tối đa 30
-- năm). Xem hàm `tongHopHinhPhat` phía JS.
--
-- AN TOÀN: chỉ ADD COLUMN, DEFAULT '[]'::jsonb (không đụng dữ liệu/cột nào có sẵn), NOT NULL an
-- toàn vì đã có default cho mọi dòng hiện có. Không cần backfill.
--
-- Chạy 1 lần qua Supabase Dashboard → SQL Editor (project eutatszoaseixchvjbtg), hoặc qua Session
-- pooler như các script khác (xem supabase/README.md). NHỚ có dòng NOTIFY cuối để PostgREST
-- reload schema cache (nếu chạy qua Session pooler; Dashboard SQL Editor thường tự reload).
-- ============================================================================

alter table "bican"
  add column if not exists "hinhPhatChiTiet" jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';
