-- Số thụ lý của vụ án (2026-11-05): nhập khi thêm vụ án mới, form tự gợi ý số gần nhất + 1.
alter table "vuan" add column if not exists "soThuLy" text;
notify pgrst, 'reload schema';
