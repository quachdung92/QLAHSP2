-- ============================================================================
-- QLVA — Tính năng "Nộp lưu kho" (2026-07-23)
--
-- BỐI CẢNH: tính năng ĐỘC LẬP với "Nộp hồ sơ lưu trữ" đã có trong Giao nhận hồ sơ (đó là luồng
-- KSV/ĐTV nộp cho bộ phận lưu trữ, dùng để thống kê — ghi qua "lichsuChuyenGiaiDoan"/
-- "giao_nhan_ho_so"). Tính năng này là luồng RIÊNG: người quản lý lưu trữ gom các hồ sơ đã giải
-- quyết (tạm đình chỉ/đình chỉ/xét xử) của 1 giai đoạn, sắp xếp + đánh SỐ LƯU TRỮ cố định, rồi nộp
-- CẢ ĐỢT lên Kho lưu trữ chính thức — không tái dùng "phienGiaoNhan"/"lichsuChuyenGiaiDoan" vì đây
-- là 2 quy trình nghiệp vụ khác nhau (KSV→lưu trữ vs lưu trữ→Kho), tránh lẫn dữ liệu.
--
-- 2 bảng mới:
--   "dotNopLuuKho"  — 1 đợt nộp lưu (VD "Đợt nộp lưu năm 2026"), có trạng thái dang_mo/da_chot
--                     (khoá/mở khoá theo yêu cầu — mở lại được, KHÁC "kybaocao.trangThai=da_chot"
--                     hiện tại là khoá 1 chiều không có đường mở lại).
--   "hoSoNopLuuKho" — 1 dòng = 1 vụ án nằm trong 1 đợt, giữ "soThuTu" (numeric, dùng để SẮP XẾP ổn
--                     định — chèn thêm dùng số thập phân 14.1/14.2 để không phải renumber toàn bộ)
--                     và "nhanSo" (text hiển thị, mặc định = soThuTu, có thể sửa tay thành "14A").
--                     Snapshot vài field hiển thị từ "vuan" lúc thêm vào đợt (đỡ join lại mỗi lần
--                     hiển thị danh sách — giống pattern đã dùng ở "lichsuChuyenGiaiDoan"/
--                     "giao_nhan_ho_so") — KHÔNG PHẢI nguồn sự thật, chỉ để hiển thị nhanh.
--
-- QUAN TRỌNG — "db.batch().commit()" (lớp shim JS) đi qua hàm RPC "batch_commit"
-- (batch_commit_2026-07-20.sql) có DANH SÁCH TRẮNG bảng được phép ghi CỨNG trong thân hàm — thêm
-- bảng mới KHÔNG tự động ghi được qua batch() nếu không cập nhật whitelist này (khác các API khác
-- của shim như .doc().set()/.update()/.get()/.where() — những cái đó gọi thẳng PostgREST, hoàn
-- toàn generic theo tên bảng, không cần đăng ký gì thêm). File này CREATE OR REPLACE lại đúng thân
-- hàm gốc (copy nguyên từ batch_commit_2026-07-20.sql), CHỈ đổi dòng whitelist thêm
-- "dotNopLuuKho"/"hoSoNopLuuKho" — không sửa file gốc 2026-07-20 (giữ nguyên làm bản ghi lịch sử
-- đã chạy đúng ngày đó), tương tự cách các file migration khác trong thư mục này không sửa lại
-- lịch sử mà chỉ nối tiếp.
-- ============================================================================

create table "dotNopLuuKho" (
  "id"                   text primary key default gen_random_uuid()::text,
  "tenDot"               text not null,                       -- VD "Đợt nộp lưu năm 2026"
  "trangThai"            text not null default 'dang_mo' check ("trangThai" in ('dang_mo','da_chot')),
  "boLocThangNam"        jsonb,                                -- điều kiện lọc đã dùng lúc tạo danh sách (lưu để tham khảo/audit, không phải nguồn sự thật)
  "ngayTao"              timestamptz not null default now(),
  "nguoiTao"             text,
  "ngayChot"             timestamptz,
  "nguoiChot"            text,
  "ngayMoKhoaGanNhat"    timestamptz,
  "nguoiMoKhoaGanNhat"   text
);
create index "dotNopLuuKho_trangThai_idx" on "dotNopLuuKho" ("trangThai");

create table "hoSoNopLuuKho" (
  "id"                    text primary key default gen_random_uuid()::text,
  "dotId"                 text not null references "dotNopLuuKho"("id"),
  "maVuAn"                text not null references "vuan"("id"),
  "soThuTu"               numeric not null,                    -- khoá sort ổn định — chèn thêm dùng số thập phân (14.1, 14.2...), KHÔNG renumber toàn bộ
  "nhanSo"                text not null,                       -- nhãn hiển thị "14"/"14A"/"14B", mặc định = soThuTu lúc chốt
  -- Snapshot lúc thêm vào đợt — xem ghi chú đầu file.
  "tenVu"                 text,
  "hinhThucGiaiQuyet"     text,                                 -- snapshot vuan.trangThai lúc thêm (tam_dinh_chi/dinh_chi/da_xet_xu)
  "ngayGiaiQuyet"         timestamptz,                          -- snapshot vuan.ngayQuyetDinh
  -- Số/ngày QĐ KTVA + số QĐ giải quyết (2026-07-26, theo yêu cầu người dùng "để biết còn thiếu vụ
  -- nào" khi đối chiếu sổ với hồ sơ giấy — bìa hồ sơ giấy luôn ghi các số này, không phải tên vụ).
  "soQdKtva"              text,                                 -- snapshot vuan.soQdKtva
  "ngayQdKtva"            timestamptz,                          -- snapshot vuan.ngayQdKtva
  "soQuyetDinhGiaiQuyet"  text,                                 -- snapshot số QĐ giải quyết (soBanAn/soQuyetDinhTamDinhChi/... tuỳ hinhThucGiaiQuyet, qua fieldSoQuyetDinhTrenVuAn)
  "ksvChinh"              text,
  "thoiHanBaoQuan"        text,                                 -- snapshot chuỗi đã tính sẵn (VD "19 năm"/"Vĩnh viễn")
  "thoiDiemQuetXacNhan"   timestamptz,                          -- null = chưa quét đưa lên Kho; set khi quét QR xác nhận (KHÔNG đụng "lichsuChuyenGiaiDoan")
  "ngayTao"               timestamptz not null default now(),
  "nguoiTao"              text,

  constraint "hoSoNopLuuKho_dot_vu_unique" unique ("dotId", "maVuAn")  -- 1 vụ không trùng trong cùng 1 đợt
);
create index "hoSoNopLuuKho_dotId_soThuTu_idx" on "hoSoNopLuuKho" ("dotId", "soThuTu");
create index "hoSoNopLuuKho_maVuAn_idx" on "hoSoNopLuuKho" ("maVuAn");

-- ---- RLS — mirror đúng mô hình hiện tại (authenticated đọc/ghi toàn bộ, xem rls.sql) ----
alter table "dotNopLuuKho" enable row level security;
alter table "hoSoNopLuuKho" enable row level security;
create policy "authenticated_read_write" on "dotNopLuuKho"
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "authenticated_read_write" on "hoSoNopLuuKho"
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ---- Realtime — Supabase KHÔNG tự bật cho bảng mới tạo (xem supabase/README.md mục đã kiểm
-- chứng #6) — thiếu bước này thì onSnapshot() của lớp shim chỉ bắn đúng 1 lần lúc mount, không
-- bao giờ nhận cập nhật realtime sau đó.
alter publication supabase_realtime add table "dotNopLuuKho";
alter publication supabase_realtime add table "hoSoNopLuuKho";

-- ---- Cập nhật whitelist bảng của batch_commit — copy nguyên thân hàm gốc, chỉ thêm 2 bảng mới ----
create or replace function "batch_commit"(p_ops jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_op jsonb;
  v_type text;
  v_table text;
  v_id text;
  v_data jsonb;
  v_cols text[];
  v_col_list text;
  v_set_list text;
  v_ids text[];
  v_do_insert boolean;
  v_do_update boolean;
  v_probe int;
  v_row_count int;
begin
  for v_op in select * from jsonb_array_elements(p_ops)
  loop
    v_type  := v_op->>'type';
    v_table := v_op->>'table';

    if v_table not in ('vuan','bican','lichsuChuyenGiaiDoan','kybaocao','canbo','danhMucToiDanh','phienGiaoNhan','dotNopLuuKho','hoSoNopLuuKho') then
      raise exception 'batch_commit: bảng không hợp lệ hoặc không được phép ghi qua hàm này: %', v_table;
    end if;

    if v_type = 'insert' then
      v_data := v_op->'data';
      v_id := v_data->>'id';
      v_do_insert := true; v_do_update := false;

    elsif v_type = 'update' then
      v_id   := v_op->>'id';
      v_data := v_op->'data';
      v_do_insert := false; v_do_update := true;
      if v_id is null or v_id = '' then
        raise exception 'batch_commit: update thiếu "id" cho bảng %', v_table;
      end if;

    elsif v_type = 'upsert' then
      v_data := v_op->'data';
      v_id := v_data->>'id';
      if v_id is null or v_id = '' then
        raise exception 'batch_commit: upsert thiếu "id" trong data cho bảng %', v_table;
      end if;
      execute format('select 1 from %I where id = $1 for update', v_table) into v_probe using v_id;
      get diagnostics v_row_count = row_count;
      if v_row_count > 0 then
        v_do_insert := false; v_do_update := true;
      else
        v_do_insert := true; v_do_update := false;
      end if;

    elsif v_type = 'delete' then
      select array_agg(x) into v_ids from jsonb_array_elements_text(v_op->'ids') as x;
      if v_ids is not null and array_length(v_ids, 1) is not null then
        execute format('delete from %I where id = any($1)', v_table) using v_ids;
      end if;
      continue;

    else
      raise exception 'batch_commit: loại thao tác không hợp lệ: %', v_type;
    end if;

    if v_do_insert then
      if v_id is null or v_id = '' then
        raise exception 'batch_commit: insert thiếu "id" cho bảng %', v_table;
      end if;
      select array_agg(k) into v_cols
      from jsonb_object_keys(v_data) as k
      where k in (
        select column_name from information_schema.columns
        where table_schema = 'public' and table_name = v_table
      );
      if v_cols is null or array_length(v_cols, 1) is null then
        raise exception 'batch_commit: "data" rỗng hoặc không khớp cột nào của bảng %', v_table;
      end if;
      v_col_list := (select string_agg(format('%I', c), ', ') from unnest(v_cols) as c);
      execute format(
        'insert into %1$I (%2$s) select %2$s from jsonb_populate_record(null::%1$I, $1)',
        v_table, v_col_list
      ) using v_data;

    elsif v_do_update then
      select array_agg(k) into v_cols
      from jsonb_object_keys(v_data) as k
      where k <> 'id' and k in (
        select column_name from information_schema.columns
        where table_schema = 'public' and table_name = v_table
      );
      if v_cols is null or array_length(v_cols, 1) is null then
        continue;
      end if;
      v_col_list := (select string_agg(format('%I', c), ', ') from unnest(v_cols) as c);
      v_set_list := (select string_agg(format('%1$I = p.%1$I', c), ', ') from unnest(v_cols) as c);
      execute format(
        'update %1$I as t set %2$s from (select %3$s from jsonb_populate_record(null::%1$I, $1)) as p where t.id = $2',
        v_table, v_set_list, v_col_list
      ) using v_data, v_id;
    end if;
  end loop;
end;
$$;

revoke execute on function "batch_commit"(jsonb) from public;
revoke execute on function "batch_commit"(jsonb) from anon;
grant execute on function "batch_commit"(jsonb) to authenticated;

notify pgrst, 'reload schema';
