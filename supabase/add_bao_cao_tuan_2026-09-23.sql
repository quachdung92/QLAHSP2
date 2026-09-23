-- ============================================================================
-- QLVA — Tính năng "Báo cáo tuần" (2026-09-23)
--
-- BỐI CẢNH: Dũng gửi file mẫu "PL THỐNG KÊ CÔNG TÁC TUẦN.xlsx" (Phụ lục thống kê công tác tuần,
-- 1 sheet "PL HS ST", 87 dòng tiêu chí chia 6 mục A.I-A.VI + section "A. HÌNH SỰ", mỗi tuần 1 cột).
-- Đối chiếu cột tuần trong file mẫu xác nhận: KHÔNG phải tuần lịch cố định Thứ 2→Chủ nhật — có
-- tuần Thứ 4→Thứ 4 (8 ngày), có khoảng trống bị bỏ qua (VD 06/8-11/8 không có cột nào), có cột gộp
-- 2 tuần liền ("26/8-09/9"). Tức "tuần báo cáo" ở đây, GIỐNG HỆT "kỳ báo cáo" tháng đã có
-- (nguyên tắc #2 CLAUDE.md — "cán bộ thống kê tự quyết định ngày chốt kỳ"), là 1 KHOẢNG THỜI GIAN
-- DO CÁN BỘ TỰ CHỌN (Từ ngày/Đến ngày tự do), KHÔNG phải 1 tuần lịch cứng nhắc.
--
-- Bảng "baoCaoTuan" — mỗi dòng là 1 "tuần báo cáo" (khoảng ngày tuỳ chọn):
--   - "tuNgay"/"denNgay": khoảng ngày do cán bộ chọn khi thêm — dùng để lọc "lichsuChuyenGiaiDoan"
--     theo "ngaySuKien" (giống cách Kỳ báo cáo lọc theo "kyThongKe", chỉ khác đơn vị là NGÀY THẬT
--     thay vì 1 kỳ tháng có sẵn — không có khái niệm "kỳ tuần" nào khác trong hệ thống để tái dùng).
--   - "nhanTuan": nhãn hiển thị (VD "10/6-16/6"), tự gợi ý từ tuNgay/denNgay nhưng sửa tay được.
--   - "duLieuNhapTay": jsonb {rowId: number} — CHỈ lưu các dòng KHÔNG tự tính được từ dữ liệu hệ
--     thống (mục II "Tin báo, tố giác", mục III "Biện pháp ngăn chặn", các dòng phân loại theo
--     CHƯƠNG Bộ luật hình sự ở mục I — hệ thống hiện KHÔNG có trường phân loại tội danh theo
--     chương BLHS, chỉ có theo điều luật cụ thể — 2 dòng Tổng số thụ lý IV/V/VI cũng thuộc nhóm
--     này vì đòi hỏi trạng thái "tại 1 thời điểm bất kỳ trong quá khứ", trong khi hệ thống chỉ hỗ
--     trợ tính "tồn" as-of theo KỲ THÁNG qua RPC, chưa hỗ trợ as-of theo ngày tự do). Các dòng còn
--     lại (số vụ/bị can mới thụ lý + đã giải quyết theo từng giai đoạn ĐT/TT/XX, số còn tồn — LUÔN
--     LÀ SỐ SỐNG, không lưu) được TÍNH LẠI MỖI LẦN XEM từ "lichsuChuyenGiaiDoan"/trạng thái hiện
--     tại của "vuan" (JS "tinhBaoCaoTuan", qlahs-sup.html) — không lưu vào bảng này, đúng nguyên
--     tắc #1 CLAUDE.md ("log là nguồn sự thật duy nhất, không lưu số liệu suy ra").
--
-- QUAN TRỌNG — module này CHỈ dùng .doc(id).set(data,{merge:true})/.update() (upsert 1 dòng), KHÔNG
-- dùng db.batch() — nên KHÔNG cần sửa whitelist bảng của hàm "batch_commit" (xem
-- batch_commit_2026-07-20.sql và ghi chú tương tự ở add_nop_luu_kho_2026-07-23.sql).
-- ============================================================================

create table "baoCaoTuan" (
  "id"              text primary key default gen_random_uuid()::text,
  "tuNgay"          timestamptz not null,
  "denNgay"         timestamptz not null,
  "nhanTuan"        text not null,                 -- VD "10/6-16/6" — gợi ý tự động, sửa tay được
  "duLieuNhapTay"   jsonb not null default '{}',   -- {rowId: number} — chỉ các dòng không tự tính được
  "ngayTao"         timestamptz not null default now(),
  "nguoiTao"        text,
  "ngayCapNhat"     timestamptz not null default now(),
  "nguoiCapNhat"    text
);
create index "baoCaoTuan_tuNgay_idx" on "baoCaoTuan" ("tuNgay");

-- ---- RLS — mirror đúng mô hình hiện tại (authenticated đọc/ghi toàn bộ, xem rls.sql) ----
alter table "baoCaoTuan" enable row level security;
create policy "authenticated_read_write" on "baoCaoTuan"
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ---- Realtime — Supabase KHÔNG tự bật cho bảng mới tạo (xem supabase/README.md mục đã kiểm
-- chứng #6) — thiếu bước này thì onSnapshot() của lớp shim chỉ bắn đúng 1 lần lúc mount, không
-- bao giờ nhận cập nhật realtime sau đó.
alter publication supabase_realtime add table "baoCaoTuan";

-- Thêm 1 index phụ trợ cho việc lọc "lichsuChuyenGiaiDoan" theo NGÀY THẬT (ngaySuKien) trong 1
-- khoảng — trước đây mọi truy vấn thống kê theo kỳ chỉ lọc theo "kyThongKe" (đã có index riêng),
-- CHƯA có truy vấn nào lọc range theo "ngaySuKien". Postgres không BẮT BUỘC có index để chạy đúng
-- (khác Firestore), chỉ ảnh hưởng tốc độ ở quy mô lớn — thêm cho an toàn hiệu năng lâu dài.
create index if not exists "lichsuChuyenGiaiDoan_ngaySuKien_idx" on "lichsuChuyenGiaiDoan" ("ngaySuKien");

notify pgrst, 'reload schema';
