-- ============================================================================
-- QLVA — Vá hiệu năng/hardening sau audit toàn hệ thống (2026-07-19)
-- Xem SUPABASE_MIGRATION.md mục 4i để biết đầy đủ bối cảnh từng phát hiện.
--
-- AN TOÀN: không đụng dữ liệu, không đổi hành vi nghiệp vụ nào — chỉ thêm index (tăng tốc đọc,
-- không ảnh hưởng kết quả), sửa cách RLS policy được thực thi (kết quả CHECK giống hệt, chỉ tính 1
-- lần/query thay vì 1 lần/dòng), và khoá search_path của 4 hàm RPC (hardening chuẩn, không đổi
-- logic bên trong). Chạy 1 lần qua Supabase SQL Editor hoặc Session pooler, idempotent (dùng
-- IF NOT EXISTS / DROP...CREATE nên chạy lại nhiều lần không sao).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 3 index còn thiếu thật (đối chiếu từng .where() trong qlahs-sup.html với 16 index đã có sẵn
--    trong schema.sql — audit LẦN ĐẦU kết luận "thiếu toàn bộ index" là SAI, đã sửa lại thành audit
--    có đối chiếu; đây là phần chênh lệch THẬT tìm được sau khi đối chiếu kỹ):
-- ----------------------------------------------------------------------------

-- lichsuChuyenGiaiDoan.loaiSuKien đứng RIÊNG (không kèm kyThongKe) — dùng ở "Tải toàn bộ lịch sử
-- giao nhận" (where loaiSuKien=="giao_nhan_ho_so") và vài công cụ backfill (where loaiSuKien in
-- [...]). 2 composite index sẵn có đều có kyThongKe làm cột ĐẦU nên không phục vụ được truy vấn này.
create index if not exists "lichsuChuyenGiaiDoan_loaiSuKien_idx"
  on "lichsuChuyenGiaiDoan" ("loaiSuKien");

-- vuan.vuGoc — dùng khi kiểm tra "vụ có con tách ra" trước khi cho xoá/thay vụ trùng
-- (where vuGoc=="X" hoặc where vuGoc in [...]).
create index if not exists "vuan_vuGoc_idx"
  on "vuan" ("vuGoc") where "vuGoc" is not null;

-- vuan.ngayCapNhat — dùng cho đồng bộ delta của cache lạnh "Án đã giải quyết"
-- (where ngayCapNhat > lastSync).
create index if not exists "vuan_ngayCapNhat_idx"
  on "vuan" ("ngayCapNhat");

-- ----------------------------------------------------------------------------
-- 2. RLS: bọc auth.role() trong subquery + thêm "to authenticated" tường minh.
--    Không bọc: Postgres gọi lại auth.role() cho MỖI DÒNG quét qua (5068 lần cho 1 lần đọc log).
--    Bọc trong (select ...): Postgres nhận ra biểu thức không phụ thuộc dòng nào, chỉ tính 1
--    LẦN/câu lệnh (khuyến nghị chính thức của Supabase — "RLS performance recommendations").
--    Thêm "to authenticated": request role anon bị loại ngay từ kế hoạch truy vấn, không cần chạy
--    policy để rồi mới biết là false.
--    Kết quả CHECK giống hệt bản cũ — chỉ đổi CÁCH thực thi, không đổi AI được phép làm gì.
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['vuan','bican','lichsuChuyenGiaiDoan','kybaocao','canbo','danhMucToiDanh','phienGiaoNhan']
  loop
    execute format('drop policy if exists "authenticated_read_write" on %I', t);
    execute format(
      'create policy "authenticated_read_write" on %I for all to authenticated using ((select auth.role()) = ''authenticated'') with check ((select auth.role()) = ''authenticated'')',
      t
    );
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- 3. Khoá search_path cho 4 hàm SECURITY DEFINER — hardening chuẩn (Supabase Security Advisor
--    cảnh báo "Function Search Path Mutable" nếu thiếu). Đặt cố định = public vì mọi bảng các hàm
--    này đụng tới (boDemMaVu/vuan/bican) đều nằm trong schema public, không cần sửa thân hàm để
--    thêm tiền tố schema. Rủi ro thực tế trước khi sửa thấp (chỉ role authenticated gọi được, và
--    user thường không tạo được object trong schema public để "che" tên bảng) nhưng đây là hardening
--    miễn phí, không có mặt trái.
-- ----------------------------------------------------------------------------
alter function "sinhMaVuAnMoi"(text) set search_path = public;
alter function "sinhNhieuMaVuAn"(text[]) set search_path = public;
alter function "tachVuSinhMa"(text) set search_path = public;
alter function "capNhatDieuLuatVaLoaiKhoiTo"(text) set search_path = public;
