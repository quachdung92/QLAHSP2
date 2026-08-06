-- ============================================================================
-- QLVA — Thêm cột "tonCuoiKyIds" vào bảng "kybaocao" (2026-08-04)
--
-- BỐI CẢNH: Dũng phát hiện đối chiếu báo cáo kỳ đã chốt (VD tháng 7): "Cân đối số liệu" báo tồn
-- cuối kỳ Điều tra = 812 bị can (số này ĐÚNG, tính bằng công thức log, không đổi theo thời gian —
-- xem tonCuoiKy/tonCuoiBiCan), nhưng sheet "DS tồn ĐT" trong CHÍNH file báo cáo kỳ đó chỉ liệt kê
-- 810 bị can — vì sheet này lấy số LIVE tại thời điểm bấm xuất Excel (tinhTonHienTaiTheoGD), không
-- phải số tại thời điểm kết thúc kỳ 7. Nếu xuất lại kỳ 7 sau khi có vụ rời Điều tra ở tháng 8, số
-- LIVE trôi khỏi số đã chốt của kỳ 7 — không có cách nào biết "2 vụ nào bị lọt".
--
-- SỬA: cột mới lưu lại CHÍNH XÁC tập hợp ID vụ (theo từng giai đoạn) khớp với tonCuoiKy/tonCuoiBiCan
-- đã chốt, dựng lại bằng cách cộng dồn qua từng kỳ theo đúng công thức (tồn đầu kỳ trước + mới
-- trong kỳ − ra trong kỳ) — xem hàm mở rộng taiTaoTonCuoiKyTheoTDTatCa (qlahs-sup.html). Dùng để
-- xuất thêm sheet "DS tồn cuối kỳ {gđ}" trong Excel báo cáo tháng — KHÔNG đổi ý nghĩa sheet "DS tồn
-- {gđ}" đã có (sheet đó CỐ Ý giữ số live, nhiều công thức khác — "Số tồn hiện tại", "TK tội danh",
-- Biểu B10 kỳ chưa chốt — đang phụ thuộc đúng tính chất live này).
--
-- Kiểu dữ liệu: jsonb, hình dạng {dieu_tra: [id,...], truy_to: [id,...], xet_xu: [id,...]} — giống
-- tonCuoiKyTheoTD/baoCaoLuu (dữ liệu lồng nhau, không cần query field bên trong ở tầng DB).
--
-- AN TOÀN: chỉ ADD COLUMN (nullable, không DEFAULT) — không đụng dữ liệu/cột nào có sẵn. Cột NULL
-- ở mọi kỳ hiện có cho tới khi chạy lại nút "Sửa lại tồn cuối kỳ theo tội danh (Biểu B10)" (Cài đặt
-- → Import Excel) — nút này giờ tính + lưu CẢ tonCuoiKyTheoTD LẪN tonCuoiKyIds trong cùng 1 lượt
-- duyệt lịch sử, không cần chạy 2 lần.
--
-- CHẠY QUA Session pooler (xem supabase/README.md mục "Kết nối") hoặc Supabase Dashboard → SQL
-- Editor (project eutatszoaseixchvjbtg). BẮT BUỘC chạy NOTIFY ở cuối — thiếu bước này PostgREST sẽ
-- báo "Could not find the 'tonCuoiKyIds' column ... in the schema cache" dù cột đã tồn tại thật.
--
-- ⚠ CHƯA CHẠY THẬT lên project eutatszoaseixchvjbtg tại thời điểm viết file này — cần Dũng hoặc
-- phiên có mật khẩu DB chạy file này TRƯỚC khi tính năng hoạt động được trên dữ liệu thật.
-- ============================================================================

alter table "kybaocao"
  add column if not exists "tonCuoiKyIds" jsonb;

notify pgrst, 'reload schema';
