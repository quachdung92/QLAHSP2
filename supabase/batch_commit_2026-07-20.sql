-- ============================================================================
-- QLVA — batch_commit: ghi atomic thật cho db.batch().commit() của lớp shim
--
-- Vấn đề đang sửa (xem SUPABASE_MIGRATION.md mục 4i #5 / 4j "Còn lại CHƯA sửa"): shim hiện commit
-- TUẦN TỰ nhiều request REST riêng (insert theo bảng → upsert theo bảng → update song song → delete
-- theo bảng) — Firestore batch.commit() đảm bảo tất-cả-hoặc-không-gì, bản shim này KHÔNG có đảm bảo
-- đó. Mất mạng/lỗi Ở GIỮA chừng để lại dữ liệu nửa vời (VD "Xoá vĩnh viễn" xoá bican/log xong nhưng
-- xoá vuan thất bại → vụ án mồ côi; "Thêm vụ án" ghi vuan xong nhưng bican/log fail → vụ 0 bị can).
--
-- Hàm này nhận NGUYÊN "danh sách thao tác đã được lớp shim JS gộp+sắp xếp đúng thứ tự phụ thuộc"
-- (xem _TABLE_INSERT_ORDER/_sapXepTheoPhuThuoc trong qlahs-sup.html — logic sắp xếp giữ NGUYÊN,
-- không chuyển vào SQL) và chạy TOÀN BỘ trong 1 lần gọi hàm = 1 transaction Postgres thật: nếu BẤT
-- KỲ thao tác nào lỗi (FK violation, CHECK constraint, mất kết nối giữa chừng...), toàn bộ hàm rollback,
-- không để lại trạng thái nửa vời — đúng đảm bảo Firestore batch.commit() đã có, thậm chí TỐT HƠN
-- (Firestore giới hạn 500 op/batch phải tự cắt lô 400 — không atomic GIỮA các lô; ở đây 1 lần gọi
-- hàm bọc trọn cả batch, không giới hạn nhân tạo nào).
--
-- Định dạng p_ops (jsonb array), mỗi phần tử theo ĐÚNG thứ tự cần thực thi (JS tự sắp: insert theo
-- thứ tự phụ thuộc bảng → upsert theo thứ tự phụ thuộc bảng → update bất kỳ thứ tự → delete theo
-- thứ tự phụ thuộc NGƯỢC):
--   {"type":"insert", "table":"vuan", "data":{"id":"...", "tenVu":"...", ...}}
--   {"type":"upsert", "table":"vuan", "data":{"id":"...", ...}}              -- = Firestore set(merge:true)
--   {"type":"update", "table":"bican", "id":"...", "data":{"hoTen":"..."}}   -- KHÔNG có "id" trong data
--   {"type":"delete", "table":"bican", "ids":["id1","id2",...]}
--
-- Chỉ ghi ĐÚNG các cột THẬT SỰ có mặt trong "data" (tra qua information_schema.columns, vừa chặn
-- injection qua key lạ, vừa giữ đúng ngữ nghĩa Firestore: field không đụng tới thì giữ nguyên giá
-- trị cũ (update/upsert) hoặc dùng DEFAULT của cột (insert) — KHÔNG ghi đè NULL tường minh, đúng
-- bài học đã rút ra ở Phase 6 (mục 9 SUPABASE_MIGRATION.md: "gán NULL tường minh đè mất DEFAULT").
-- Xử lý TỪNG DÒNG riêng (không gộp nhiều dòng cùng bảng thành 1 câu INSERT nhiều VALUES) — vừa để
-- mỗi dòng tự có đúng bộ cột của riêng nó (PostgREST bulk-insert có gotcha đã biết: dòng thiếu field
-- so với dòng khác trong cùng mảng bị gán NULL tường minh thay vì DEFAULT — né hẳn bằng cách này),
-- vừa vẫn atomic + KHÔNG tốn thêm round-trip mạng nào (mọi dòng chạy trong CÙNG 1 lần gọi hàm).
--
-- Bug tự phát hiện + tự sửa (2026-07-20, phát hiện qua kiểm thử thật trên Supabase, không phải giả
-- thuyết suông) — bản đầu tiên implement "upsert" bằng `INSERT ... ON CONFLICT (id) DO UPDATE SET
-- <chỉ các cột có trong data>`. SAI: Postgres validate NOT NULL constraint của TOÀN BỘ cột trong
-- câu INSERT (kể cả cột KHÔNG được liệt kê, tự dùng DEFAULT) TRƯỚC KHI biết có xảy ra conflict hay
-- không — cột nào NOT NULL mà không có DEFAULT (VD "vuan"."maNoiSinh") sẽ làm insert "thăm dò" này
-- LUÔN LỖI 23502 dù dòng đó đã tồn tại và lẽ ra chỉ cần UPDATE. Bắt được lỗi thật qua kịch bản test
-- "upsert lần 2 vào dòng đã tồn tại, chỉ truyền đúng 1 field cần đổi" trên dữ liệu Supabase thật.
-- Đã sửa: "upsert" giờ tự kiểm tra dòng đã tồn tại chưa (SELECT ... FOR UPDATE, vừa xác định vừa
-- khoá dòng chống race), rồi rẽ nhánh dùng LẠI đúng logic INSERT (nếu chưa có) hoặc UPDATE thuần
-- (nếu đã có, KHÔNG qua ON CONFLICT nữa) — 2 nhánh này dùng chung code với type "insert"/"update"
-- gốc (qua cờ v_do_insert/v_do_update) để không có 2 bản logic tách rời dễ lệch nhau về sau.
--
-- SECURITY INVOKER (không phải DEFINER như 4 hàm trong functions.sql) — hàm này chỉ đụng 7 bảng
-- nghiệp vụ đã có policy RLS "authenticated đọc/ghi toàn bộ" (rls.sql), không cần bảng "boDemMaVu"
-- (đó là lý do DUY NHẤT 4 hàm kia cần DEFINER). Chạy dưới quyền người gọi thật để RLS tiếp tục là
-- lớp phòng thủ thật (không phải hình thức) — nếu sau này đổi mô hình phân quyền, hàm này tự động
-- tuân theo, không cần sửa gì thêm.
-- ============================================================================

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

    if v_table not in ('vuan','bican','lichsuChuyenGiaiDoan','kybaocao','canbo','danhMucToiDanh','phienGiaoNhan') then
      raise exception 'batch_commit: bảng không hợp lệ hoặc không được phép ghi qua hàm này: %', v_table;
    end if;

    -- ---- Xác định nhánh cần chạy (insert thuần / update thuần) cho từng loại op ----
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
      -- = Firestore set(ref, data, {merge:true}). KHÔNG dùng INSERT...ON CONFLICT (xem bug đã sửa
      -- ở comment đầu file) — tự kiểm tra tồn tại trước (khoá dòng bằng FOR UPDATE nếu có), rồi rẽ
      -- sang ĐÚNG 1 trong 2 nhánh insert/update thuần bên dưới.
      v_data := v_op->'data';
      v_id := v_data->>'id';
      if v_id is null or v_id = '' then
        raise exception 'batch_commit: upsert thiếu "id" trong data cho bảng %', v_table;
      end if;
      -- LƯU Ý (2026-07-20, phát hiện qua kiểm thử thật trên Supabase): "FOUND" KHÔNG được set đúng
      -- sau "EXECUTE ... INTO" động trong plpgsql (luôn ra false ở phiên bản Postgres project này
      -- đang chạy, kể cả khi câu SELECT thực sự có kết quả) — dùng "GET DIAGNOSTICS ... ROW_COUNT"
      -- thay thế, đã kiểm chứng đáng tin cậy (0 khi không có dòng, 1 khi có).
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
      continue; -- delete xử lý xong, sang op tiếp theo — không rơi xuống nhánh insert/update bên dưới

    else
      raise exception 'batch_commit: loại thao tác không hợp lệ: %', v_type;
    end if;

    -- ---- Nhánh INSERT thuần (dùng chung cho type="insert" và "upsert" khi dòng chưa tồn tại) ----
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

    -- ---- Nhánh UPDATE thuần (dùng chung cho type="update" và "upsert" khi dòng đã tồn tại) ----
    elsif v_do_update then
      select array_agg(k) into v_cols
      from jsonb_object_keys(v_data) as k
      where k <> 'id' and k in (
        select column_name from information_schema.columns
        where table_schema = 'public' and table_name = v_table
      );
      if v_cols is null or array_length(v_cols, 1) is null then
        continue; -- không có cột hợp lệ nào để ghi — không phải lỗi, chỉ bỏ qua (đúng hành vi cũ)
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

-- Chỉ role đã đăng nhập được gọi (đúng mô hình bảo mật hiện tại — không phân quyền thêm, xem
-- rls.sql). Với SECURITY INVOKER, RLS đã tự chặn "anon" ở tầng bảng rồi (mọi write bên trong hàm sẽ
-- bị RLS từ chối — đã kiểm chứng thật bằng anon key qua REST: HTTP 401/42501, 0 dòng lọt), revoke/
-- grant ở đây chỉ là lớp phòng thủ THÊM, không phải điều kiện bảo mật DUY NHẤT như 4 hàm SECURITY
-- DEFINER trong functions.sql (những hàm đó bỏ qua RLS nên PHẢI revoke đúng mới an toàn thật).
--
-- Lưu ý phát hiện được khi kiểm thử (2026-07-20): Supabase TỰ ĐỘNG cấp EXECUTE cho "anon" ngay lúc
-- CREATE FUNCTION (default privileges của project, chạy TRƯỚC các lệnh revoke/grant dưới đây) —
-- "revoke ... from public" KHÔNG đụng tới quyền đã cấp THẲNG cho role "anon" (public chỉ là 1
-- pseudo-role riêng, không tự động bao gồm việc thu hồi quyền đã cấp trực tiếp cho anon). Vì vậy
-- phải revoke TƯỜNG MINH khỏi "anon" ở đây — nếu chỉ dựa vào "revoke from public" như 4 hàm cũ
-- trong functions.sql, "anon" (chưa đăng nhập) vẫn GỌI ĐƯỢC hàm (dù với batch_commit không sao vì
-- SECURITY INVOKER để RLS chặn ghi thật — nhưng lỗ hổng NÀY áp dụng luôn cho 4 hàm SECURITY DEFINER
-- kia, nơi bỏ qua RLS — xem SUPABASE_MIGRATION.md để biết đã báo phát hiện này, CHƯA sửa vì ngoài
-- phạm vi đã thống nhất cho lần sửa này).
revoke execute on function "batch_commit"(jsonb) from public;
revoke execute on function "batch_commit"(jsonb) from anon;
grant execute on function "batch_commit"(jsonb) to authenticated;
