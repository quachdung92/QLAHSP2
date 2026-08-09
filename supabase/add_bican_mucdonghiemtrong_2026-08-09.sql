-- ============================================================================
-- Mức độ nghiêm trọng CỦA BỊ CAN (2026-08-09, theo yêu cầu Dũng) — KHÁC field cùng tên đã có sẵn
-- trên "vuan" (áp dụng chung cho cả vụ, dùng tính hạn điều tra Điều 172/174) — field mới này gắn
-- với TỪNG bị can, xác định theo TỘI DANH CHÍNH (dieuLuatBC[1]) của người đó, vì 1 vụ nhiều bị can
-- có thể mỗi người bị khởi tố tội khác nhau với mức độ nghiêm trọng khác nhau.
--
-- Mặc định "Đặc biệt nghiêm trọng", trừ vài điều luật BLHS 2025 phổ biến nhưng KHÔNG đặc biệt
-- nghiêm trọng: Điều 318 (Gây rối TTCC)/321 (Đánh bạc) -> Nghiêm trọng; Điều 322 (Tổ chức đánh bạc/
-- gá bạc) -> Rất nghiêm trọng. Logic suy default xem hàm `mucDoNghiemTrongMacDinhTheoDieu` trong
-- qlahs-sup.html (dùng thống nhất cho cả UI lẫn script backfill).
-- ============================================================================

alter table "bican" add column if not exists "mucDoNghiemTrong" text not null default 'dac_biet_nghiem_trong'
  check ("mucDoNghiemTrong" in ('it_nghiem_trong', 'nghiem_trong', 'rat_nghiem_trong', 'dac_biet_nghiem_trong'));

notify pgrst, 'reload schema';
