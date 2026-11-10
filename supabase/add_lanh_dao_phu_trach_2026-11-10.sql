-- Lãnh đạo phụ trách (tên tự do, giống ksvChinh). Chạy trong Supabase SQL Editor.
alter table "vuan" add column if not exists "lanhDaoPhuTrach" text;
notify pgrst, 'reload schema';
