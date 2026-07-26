-- ============================================================================
-- QLVA — Row Level Security (Supabase/Postgres)
-- Mirror ĐÚNG mô hình bảo mật Firestore hiện tại: firestore.rules chỉ có 1 rule
--   match /{document=**} { allow read, write: if request.auth != null; }
-- Nghĩa là: bất kỳ ai đăng nhập (Firebase Auth email/password) đều đọc/ghi được TOÀN BỘ dữ liệu,
-- không phân quyền theo collection/field/role. Bản Postgres áp dụng ĐÚNG mức độ này — không mở
-- rộng, không thu hẹp phạm vi so với hiện tại (không phải lúc migrate hạ tầng để tự ý đổi mô
-- hình bảo mật — nếu Dũng muốn phân quyền chặt hơn sau này, đó là 1 quyết định nghiệp vụ riêng).
--
-- `auth.role() = 'authenticated'` đúng ngữ nghĩa `request.auth != null` của Firestore: bất kỳ
-- request nào mang JWT hợp lệ từ Supabase Auth (đã đăng nhập) đều có role 'authenticated'.
-- Request không có JWT (chưa đăng nhập) có role 'anon' — bị chặn hoàn toàn, đúng hành vi cũ.
-- ============================================================================

alter table "vuan" enable row level security;
alter table "bican" enable row level security;
alter table "lichsuChuyenGiaiDoan" enable row level security;
alter table "kybaocao" enable row level security;
alter table "canbo" enable row level security;
alter table "danhMucToiDanh" enable row level security;
alter table "phienGiaoNhan" enable row level security;
alter table "dotNopLuuKho" enable row level security;
alter table "hoSoNopLuuKho" enable row level security;
-- Bảng "meta" (sentinel) ĐÃ XOÁ — xem ghi chú 5 đầu schema.sql, không còn code nào dùng.

-- boDemMaVu KHÔNG bật RLS ở đây theo kiểu "authenticated đọc/ghi được" — bảng này chỉ được đụng
-- vào từ BÊN TRONG các hàm RPC (functions.sql, chạy với quyền SECURITY DEFINER), ứng dụng phía
-- client không bao giờ gọi thẳng .from("boDemMaVu"). Enable RLS nhưng KHÔNG tạo policy nào cho
-- role authenticated — mặc định deny-all cho client, chỉ RPC (chạy dưới quyền definer) đọc/ghi
-- được, đúng tinh thần "bộ đếm nội bộ, không phải dữ liệu nghiệp vụ công khai qua API".
alter table "boDemMaVu" enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['vuan','bican','lichsuChuyenGiaiDoan','kybaocao','canbo','danhMucToiDanh','phienGiaoNhan','dotNopLuuKho','hoSoNopLuuKho']
  loop
    execute format(
      'create policy "authenticated_read_write" on %I for all using (auth.role() = ''authenticated'') with check (auth.role() = ''authenticated'')',
      t
    );
  end loop;
end $$;
