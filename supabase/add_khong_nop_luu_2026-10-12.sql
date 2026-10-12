-- Hồ sơ trong sổ nộp lưu kho đã phục hồi điều tra → cho đánh dấu "không nộp lưu" (vẫn giữ số).
alter table "hoSoNopLuuKho" add column if not exists "khongNopLuu" boolean not null default false;
notify pgrst, 'reload schema';
