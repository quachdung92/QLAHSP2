-- Chuyên đề nhập vụ (2026-11-16): 2 cờ mới trên vuan.
--  coHoSo     : false = vụ đã thụ lý nhưng CHƯA có hồ sơ (mặc định true).
--  choNhapVu  : true  = vụ phục hồi/chuyển đến để nhập vào 1 vụ khác chưa xác định ("rổ chờ nhập").
-- Chạy qua Supabase Dashboard -> SQL Editor (hoặc Session pooler, xem supabase/README.md).
alter table "vuan" add column if not exists "coHoSo" boolean not null default true;
alter table "vuan" add column if not exists "choNhapVu" boolean not null default false;
notify pgrst, 'reload schema';
