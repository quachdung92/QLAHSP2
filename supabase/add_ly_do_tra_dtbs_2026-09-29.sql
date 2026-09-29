-- 2026-09-29: lý do VKS trả hồ sơ điều tra bổ sung (Biểu 2 D354-358 / D362-366).
-- Chỉ ghi trên sự kiện tra_ho_so từ Truy tố; rỗng = mặc định "Do phát sinh tình tiết mới hoặc lý do khác".
alter table "lichsuChuyenGiaiDoan" add column if not exists "lyDoTraDTBS" text not null default '';
notify pgrst, 'reload schema';
