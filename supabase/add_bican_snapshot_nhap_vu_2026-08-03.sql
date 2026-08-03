-- ============================================================================
-- QLVA — Thêm cột "biCanSnapshot" vào bảng "lichsuChuyenGiaiDoan" (2026-08-03)
--
-- BỐI CẢNH: khi 1 vụ bị "Nhập vào vụ khác" (NhapVuModal, loaiSuKien="nhap_vu"), toàn bộ bị can
-- của vụ NGUỒN được chuyển hẳn `maVuAn` sang vụ ĐÍCH ngay lúc nhập. Mọi báo cáo/Excel xem SAU thời
-- điểm đó (tinhBaoCaoKyTuLog, Xuất Excel báo cáo tháng) lại đi TRUY VẤN LẠI "bican where
-- maVuAn==vụ nguồn" để biết vụ đó có bao nhiêu/những bị can nào — nhưng lúc này bị can đã dời hết
-- sang vụ đích, truy vấn luôn ra RỖNG. Hậu quả: sheet "DS nhập vụ {ĐT/TT/XX}" trong Excel báo cáo
-- tháng không tra được vụ bị nhập gốc có bị can nào (hiện "(Chưa có BC)" dù vụ đó có thể có nhiều
-- bị can thật) — phát hiện qua audit code theo yêu cầu Dũng kiểm tra công thức nhập/tách vụ.
--
-- Không ảnh hưởng tới số liệu TỔNG (vụ/bị can tồn) khi nhập cùng giai đoạn — số bị can vốn không
-- thực sự "ra" khỏi giai đoạn (chỉ đổi tên vụ), và việc luôn trả về 0 khi truy vấn lại lại "tình
-- cờ" cho đúng tổng — nhưng làm MẤT khả năng xem chi tiết bị can nào đã thuộc vụ bị nhập.
--
-- GIẢI PHÁP: snapshot NGUYÊN VẸN dữ liệu bị can của vụ nguồn (bcSnap.docs.map(d => d.data()),
-- TRƯỚC khi chuyển maVuAn) vào chính sự kiện "nhap_vu" — sheet "DS nhập vụ" đọc lại từ đây thay vì
-- truy vấn "bican" trực tiếp. Sự kiện log vốn append-only, snapshot 1 lần lúc ghi là đúng bản chất.
--
-- Kiểu dữ liệu: jsonb, NOT NULL DEFAULT '[]' — mọi dòng hiện có (kể cả các sự kiện nhap_vu cũ tạo
-- trước cột này) coi như "chưa có snapshot" (mảng rỗng) — sheet DS nhập vụ với dữ liệu cũ vẫn hiện
-- "(Chưa có BC)" như trước (không có cách khôi phục lại bị can gốc của các lần nhập vụ đã qua),
-- chỉ các lần "Nhập vụ" MỚI sau khi cột này tồn tại mới có đủ dữ liệu.
--
-- AN TOÀN: chỉ ADD COLUMN với DEFAULT cố định — không đụng dữ liệu/cột nào có sẵn.
--
-- CHẠY QUA Session pooler (xem supabase/README.md mục "Kết nối") hoặc Supabase Dashboard → SQL
-- Editor (project eutatszoaseixchvjbtg). BẮT BUỘC chạy NOTIFY ở cuối — thiếu bước này PostgREST sẽ
-- báo "Could not find the 'biCanSnapshot' column ... in the schema cache" dù cột đã tồn tại thật.
--
-- ⚠ CHƯA CHẠY THẬT lên project eutatszoaseixchvjbtg tại thời điểm viết file này (phiên code không
-- có mật khẩu DB) — cần Dũng hoặc phiên có mật khẩu chạy file này TRƯỚC khi tính năng hoạt động
-- được trên dữ liệu thật. Cho tới lúc đó, `batch_commit` RPC sẽ ÂM THẦM bỏ qua field lạ (không
-- lỗi, chỉ không ghi được — đã xác nhận qua các lần thêm cột trước đây), không ảnh hưởng gì tới
-- luồng "Nhập vụ" hiện có (chỉ riêng snapshot bị can chưa lưu được cho tới khi ALTER xong).
-- ============================================================================

alter table "lichsuChuyenGiaiDoan"
  add column if not exists "biCanSnapshot" jsonb not null default '[]';

notify pgrst, 'reload schema';
