-- ============================================================================
-- QLVA — Schema Postgres (Supabase) thay thế Firestore
-- Xem SUPABASE_MIGRATION.md ở gốc repo để biết bối cảnh/lộ trình đầy đủ.
--
-- QUYẾT ĐỊNH THIẾT KẾ QUAN TRỌNG (đọc trước khi sửa):
-- 1. Tên BẢNG và tên CỘT giữ NGUYÊN camelCase, TRÙNG KHỚP 1:1 với tên collection/field
--    Firestore hiện tại (VD bảng "vuan", cột "tenVu", "ngayQdKtva"...) — dùng identifier có
--    quote kép. Đây là lựa chọn CÓ CHỦ ĐÍCH, không phải quên chuẩn snake_case: chiến lược
--    migrate đã chốt là dựng 1 lớp SHIM giả lập Firestore API phía JS — nếu tên cột khớp y hệt
--    tên field Firestore, PostgREST (Supabase) trả JSON với đúng key cũ, lớp shim KHÔNG cần
--    viết logic đổi tên field nào cả, giảm hẳn 1 lớp rủi ro. Đừng "sửa lại cho đúng chuẩn"
--    Postgres nếu không có lý do nghiệp vụ — sẽ phá vỡ chiến lược shim.
-- 2. Enum dùng CHECK constraint (`CHECK (col IN (...))`), KHÔNG dùng Postgres native ENUM type
--    — native enum khó thêm giá trị mới sau này (ALTER TYPE có nhiều hạn chế/khoá bảng), trong
--    khi enum nghiệp vụ ở đây đã đổi/thêm giá trị nhiều lần qua các phiên trước (VD phát hiện
--    "sua_thong_tin" là loaiSuKien có thật nhưng KHÔNG có trong tài liệu schema cũ).
-- 3. `toiDanh`/`dieuLuatBC` (bican) và `vuanToiDanh`/`vuanDieuLuat` (vuan) giữ dạng CỘT MẢNG
--    (`text[]`), KHÔNG tách bảng con — ứng dụng luôn thao tác chúng như mảng đồng bộ theo index
--    (`arr[0]` = tội chính, `.push()`, `.filter(Boolean)`...), tách bảng con sẽ cần JOIN+GROUP BY
--    để dựng lại đúng thứ tự mỗi lần đọc mà không có lợi ích quan hệ nào thật sự cần tới.
-- 4. `boDemMaVu` (bộ đếm sinh mã vụ án) VẪN giữ 1 bảng riêng (khác dự tính ban đầu "thay bằng
--    Postgres sequence") — sequence phải tạo trước cho từng YYMM, không tiện tạo động an toàn
--    qua RPC; 1 bảng counter nhỏ + UPSERT nguyên tử (`INSERT ... ON CONFLICT DO UPDATE
--    RETURNING`) đơn giản và an toàn hơn hẳn. Bảng này KHÔNG đi qua lớp shim — chỉ được gọi từ
--    bên trong các hàm RPC ở functions.sql.
-- 5. `meta/vuAnMoiNhat` (sentinel Firestore) CỐ Ý KHÔNG có bảng tương ứng — sentinel này chỉ tồn
--    tại để né chi phí đọc/listener của Firestore, Supabase không có động cơ chi phí tương tự.
--    Cân nhắc bỏ hẳn cơ chế này ở Phase 2 (xem SUPABASE_MIGRATION.md mục 5), subscribe thẳng qua
--    Supabase Realtime trên bảng "vuan".
-- 6. `danhMucToiDanh`: có 2 field Firestore SONG SONG chưa từng được đồng bộ cho cùng 1 khái
--    niệm ("namBLHS" — do công cụ seed ghi, dùng thật trong logic tra cứu; "blhsNam" — do form
--    sửa tay UI ghi, dùng trong hiển thị/lọc badge, giá trị mặc định còn không khớp cả map hiển
--    thị của chính nó). Schema này CHỈ giữ "namBLHS" làm cột chuẩn duy nhất — khi export/import
--    dữ liệu thật (Phase 4) phải chuyển đổi giá trị "blhsNam" cũ sang đúng "namBLHS" tương ứng,
--    không mang cả 2 field sang Postgres.
-- 7. CHƯA áp dụng file này lên Supabase thật — chỉ viết trước, chờ Dũng cấp env (Phase 1, xem
--    SUPABASE_MIGRATION.md mục 8 "Trạng thái hiện tại").
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- canbo — Cán bộ (KSV/ĐTV/thống kê), nguồn dropdown cho các field tên cán bộ ở nơi khác.
-- ----------------------------------------------------------------------------
create table "canbo" (
  "id"        text primary key default gen_random_uuid()::text,
  "hoTen"     text not null,
  "vaiTro"    text not null check ("vaiTro" in ('ksv','dtv','can_bo_thong_ke','khac')),
  "trangThai" text not null check ("trangThai" in ('dang_cong_tac','da_chuyen_don_vi'))
);
create index "canbo_trangThai_idx" on "canbo" ("trangThai");

-- ----------------------------------------------------------------------------
-- danhMucToiDanh — Danh mục tội danh/điều luật (BLHS 1999 + 2025), tra cứu Mã ĐL cho Biểu B10.
-- ----------------------------------------------------------------------------
create table "danhMucToiDanh" (
  "id"             text primary key default gen_random_uuid()::text,
  "soDieu"         text,                       -- optional trong thực tế — chỉ chắc chắn có ở dòng seed
  "tenToiDanh"     text not null,
  "dieuLuat"       text not null,              -- VD "Điều 173 BLHS 2025"
  "thuTuHienThi"   integer,
  "namBLHS"        text check ("namBLHS" in ('1999','2015','2025'))  -- xem ghi chú 6 ở đầu file
);
create index "danhMucToiDanh_thuTuHienThi_idx" on "danhMucToiDanh" ("thuTuHienThi");

-- ----------------------------------------------------------------------------
-- kybaocao — Kỳ báo cáo. tonCuoiKy*/baoCaoLuu là snapshot đông cứng lúc chốt kỳ — JSONB vì có
-- cấu trúc lồng nhau (theo giai đoạn / theo tội danh) không cần query field bên trong ở tầng DB.
-- ----------------------------------------------------------------------------
create table "kybaocao" (
  "id"               text primary key default gen_random_uuid()::text,
  "tenKy"            text not null,
  "ngayBatDau"       timestamptz,              -- null cho phép với kỳ "loai=luu_tru"
  "ngayChot"         timestamptz,
  "trangThai"        text not null check ("trangThai" in ('dang_mo','da_chot','luu_tru')),
  "loai"             text check ("loai" in ('luu_tru')),  -- redundant với trangThai='luu_tru', giữ để khớp dữ liệu thật
  "nguoiChot"        text,
  "thoiDiemChot"     timestamptz,
  "tonCuoiKy"        jsonb,                    -- {dieu_tra, truy_to, xet_xu} → số vụ
  "tonCuoiBiCan"     jsonb,                    -- cùng hình dạng, số bị can
  "tonCuoiKyTheoTD"  jsonb,                    -- { [toiDanh]: { [giaiDoan]: {vuAn, biCan} } }
  "baoCaoLuu"        jsonb,                    -- báo cáo đầy đủ đã tính, cache cho kỳ đã chốt
  "thoiDiemTinhLai"  timestamptz               -- chỉ có khi đã bấm "Tính lại số liệu"
);
create index "kybaocao_trangThai_idx" on "kybaocao" ("trangThai");

-- ----------------------------------------------------------------------------
-- boDemMaVu — bộ đếm nội bộ sinh mã vụ án theo YYMM. KHÔNG đi qua lớp shim, chỉ dùng trong RPC
-- (xem functions.sql: sinh_ma_vu_an_moi / sinh_nhieu_ma_vu_an).
-- ----------------------------------------------------------------------------
create table "boDemMaVu" (
  "yymm"      text primary key,        -- VD "2601"
  "soHienTai" integer not null default 0
);

-- ----------------------------------------------------------------------------
-- vuan — Vụ án. PK = mã vụ án hệ thống (maNoiSinh), y hệt cách Firestore dùng .doc(maNoiSinh)
-- làm document ID. Cột "maNoiSinh" giữ lại dù trùng giá trị với "id" — nhiều nơi trong ứng dụng
-- đọc vuAn.maNoiSinh từ chính object dữ liệu (không tách riêng khỏi doc.id như Firestore SDK
-- cho phép), giữ cột này để lớp shim không cần đặc cách suy field đó từ id.
-- ----------------------------------------------------------------------------
create table "vuan" (
  "id"                      text primary key,             -- = "maNoiSinh", KHÔNG auto-generate
  "maNoiSinh"               text not null,
  "maNganhCap"              text,
  "tenVu"                   text,
  "nguon"                   text not null default 'an_khoi_to_moi'
                              check ("nguon" in ('an_khoi_to_moi','tin_bao_khoi_to_len','an_noi_khac_chuyen_den','phuc_hoi_dieu_tra')),
  "nguonChiTiet"            text not null default '',
  "hanDieuTra"              timestamptz,
  "soQdKtva"                text,
  "ngayQdKtva"              timestamptz,
  "ksvChinh"                text,                          -- tên tự do, KHÔNG phải FK cứng (xem CLAUDE.md nguyên tắc #liên quan canbo)
  "ksvHoTro"                text[] not null default '{}',
  "dtvCbdt"                 text,
  "donViThuLy"              text not null default '',
  "dieuLuat"                text,                          -- tự tính khi có bị can, nhập tay khi 0 bị can
  "vuanToiDanh"             text[] not null default '{}',  -- tội danh cấp vụ khi CHƯA có bị can nào
  "vuanDieuLuat"            text[] not null default '{}',  -- điều luật song song theo index với vuanToiDanh
  "coQuanThuLy"             text not null default 'dieu_tra'
                              check ("coQuanThuLy" in ('dieu_tra','truy_to','xet_xu')),
  "trangThai"               text not null default 'dang_giai_quyet'
                              check ("trangThai" in ('dang_giai_quyet','da_xet_xu','an_huy','chuyen_di','tam_dinh_chi','dinh_chi','da_nhap')),
  "mucDoNghiemTrong"        text default 'dac_biet_nghiem_trong'
                              check ("mucDoNghiemTrong" in ('it_nghiem_trong','nghiem_trong','rat_nghiem_trong','dac_biet_nghiem_trong')),
  "noiChuyenDen"            text not null default '',
  "nhapVaoVu"               text references "vuan"("id"),
  "vuGoc"                   text references "vuan"("id"),
  "soDemTach"               integer not null default 0,
  "soBiCan"                 integer not null default 0,    -- cache, tự cập nhật qua tomTatBiCan()
  "biCanDaiDien"            text not null default '',      -- cache, tên bị can đại diện
  "anDiem"                  boolean not null default false,
  "uyQuyenXetXu"            text not null default '',
  "phienToaRutKN"           boolean not null default false,
  "soKetLuanDieuTra"        text,
  "soCaoTrang"              text,
  "soBanAn"                 text,
  "soQuyetDinhChuyenDi"     text,
  "soQuyetDinhTamDinhChi"   text,
  "soQuyetDinhDinhChi"      text,
  "soQuyetDinhAnHuy"        text,
  "ngayQuyetDinh"           timestamptz,
  "kyHoanThanh"             text references "kybaocao"("id"),
  "ngayQuyetDinhUocTinh"    boolean not null default false,
  "nguonNhapLieu"           text,                          -- VD "import_excel", null nếu tạo tay
  "daXoa"                   boolean not null default false,
  "ngayXoaMem"              timestamptz,
  "nguoiXoaMem"             text,
  "mucAnLoai"               text check ("mucAnLoai" in ('nam','an_treo','phat_tien','chung_than','tu_hinh')),
  "mucAnNam"                integer,
  "mucAnThang"              integer check ("mucAnThang" between 0 and 11),
  "ghiChu"                  text not null default '',
  "ngayTao"                 timestamptz,
  "nguoiTao"                text,
  "ngayCapNhat"             timestamptz,
  "nguoiCapNhatCuoi"        text,

  constraint "vuan_maNoiSinh_eq_id" check ("maNoiSinh" = "id")
);

create index "vuan_coQuanThuLy_trangThai_idx" on "vuan" ("coQuanThuLy","trangThai");
create index "vuan_trangThai_ngayTao_idx"     on "vuan" ("trangThai","ngayTao");
create index "vuan_trangThai_kyHoanThanh_idx" on "vuan" ("trangThai","kyHoanThanh");
create index "vuan_trangThai_ksvChinh_idx"    on "vuan" ("trangThai","ksvChinh");
create index "vuan_daXoa_idx"                 on "vuan" ("daXoa");
-- Lưu ý: Firestore cần 2 composite index riêng cho trangThai+ngayTao ASC và DESC (giới hạn
-- Firestore: hướng sort phải khớp đúng index). Postgres KHÔNG cần — 1 btree index duyệt ngược
-- được hiệu quả cho cả 2 chiều, nên chỉ cần đúng 1 index "vuan_trangThai_ngayTao_idx" ở trên.

-- ----------------------------------------------------------------------------
-- bican — Bị can.
-- ----------------------------------------------------------------------------
create table "bican" (
  "id"                 text primary key default gen_random_uuid()::text,
  "maVuAn"             text not null references "vuan"("id"),
  "hoTen"              text not null,
  "namSinh"            integer,
  "gioiTinh"           text not null default 'nam' check ("gioiTinh" in ('nam','nu')),
  "toiDanh"            text[] not null default '{""}',  -- phần tử đầu = tội chính
  "dieuLuatBC"         text[] not null default '{}',    -- song song theo index với toiDanh
  "dangVien"           text not null default 'khong' check ("dangVien" in ('khong','co')),
  "dangVienGiuChucVu"  boolean not null default false,  -- chỉ có ý nghĩa khi dangVien='co'
  "diaChi"             text not null default '',
  "bienPhapNganChan"   text check ("bienPhapNganChan" in ('giam','tai_ngoai')),
  "hanTamGiam"         timestamptz,                     -- chỉ khi bienPhapNganChan='giam'
  "danToc"             text not null default 'Kinh',
  "quocTich"           text not null default 'Việt Nam',
  "trinhDo"            text default '' check ("trinhDo" in ('','khong_biet_chu','tieu_hoc','thcs','thpt','dh_tro_len')),
  "taiPham"            text not null default 'khong' check ("taiPham" in ('khong','tai_pham','tai_pham_nguy_hiem')),
  "loaiBiCan"          text not null default 'ca_nhan' check ("loaiBiCan" in ('ca_nhan','phap_nhan')),
  "tenPhapNhan"        text not null default '',        -- chỉ khi loaiBiCan='phap_nhan'
  "maSoThue"           text not null default '',        -- chỉ khi loaiBiCan='phap_nhan'
  "ngayKhoiTo"         timestamptz,
  "loaiKhoiTo"         text check ("loaiKhoiTo" in ('ban_dau','bo_sung')),  -- tự tính, không nhập tay
  "soQdKtBiCan"        text not null default '',
  "kyThongKeKhoiTo"    text references "kybaocao"("id"),
  "nhomBiCanId"        text,                            -- chỉ có ở bị can sao chép lúc Tách vụ "Ở cả 2 vụ"
  "ngayTao"            timestamptz,
  "nguoiTao"           text,
  "ngayCapNhat"        timestamptz,
  "nguoiCapNhatCuoi"   text
);

create index "bican_maVuAn_idx" on "bican" ("maVuAn");
create index "bican_nhomBiCanId_idx" on "bican" ("nhomBiCanId") where "nhomBiCanId" is not null;

-- ----------------------------------------------------------------------------
-- phienGiaoNhan — Phiên giao/nhận hồ sơ.
-- ----------------------------------------------------------------------------
create table "phienGiaoNhan" (
  "id"               text primary key default gen_random_uuid()::text,
  "loaiGiaoDich"     text not null check ("loaiGiaoDich" in ('giao','nhan')),
  "laLuuTru"         boolean not null default false,   -- chỉ chọn được khi loaiGiaoDich='nhan'
  "tenPhien"         text not null default '',
  "nguoiThucHien"    text,
  "thoiDiemBatDau"   timestamptz not null default now(),
  "trangThai"        text not null default 'dang_mo' check ("trangThai" in ('dang_mo','da_luu')),
  "thoiDiemLuu"      timestamptz
);
create index "phienGiaoNhan_thoiDiemBatDau_idx" on "phienGiaoNhan" ("thoiDiemBatDau" desc);

-- ----------------------------------------------------------------------------
-- lichsuChuyenGiaiDoan — Log sự kiện append-only, nguồn sự thật duy nhất cho số liệu báo cáo kỳ.
-- Các cột cuối (từ "phienGiaoNhanId" trở xuống) CHỈ có giá trị khi loaiSuKien='giao_nhan_ho_so'
-- — để null ở mọi loại sự kiện khác, không tách bảng riêng vì đây vẫn cùng 1 "dòng lịch sử" của
-- vụ án, tách bảng sẽ phức tạp hoá truy vấn "toàn bộ lịch sử 1 vụ" vốn rất hay dùng.
-- ----------------------------------------------------------------------------
create table "lichsuChuyenGiaiDoan" (
  "id"                    text primary key default gen_random_uuid()::text,
  "maVuAn"                text not null references "vuan"("id"),
  "loaiSuKien"            text not null check ("loaiSuKien" in (
                             'khoi_to_vu','khoi_to_bican','chuyen_giai_doan','tra_ho_so',
                             'gia_han_dieu_tra','phuc_hoi','hoan_thanh','tach_vu','nhap_vu',
                             'duoc_nhap_vu','giao_nhan_ho_so','sua_thong_tin'
                             -- 'ket_luan_dieu_tra'/'ket_luan_dieu_tra_bo_sung'/'cao_trang'/
                             -- 'cao_trang_bo_sung' CỐ Ý KHÔNG đưa vào — dead code, chưa từng
                             -- được ghi bởi code thật (đã xác nhận qua audit toàn bộ write-site)
                           )),
  "maBiCan"               text references "bican"("id"),
  "tuGiaiDoan"            text check ("tuGiaiDoan" in ('dieu_tra','truy_to','xet_xu')),
  "denGiaiDoan"           text check ("denGiaiDoan" in ('dieu_tra','truy_to','xet_xu')),
  "hanCu"                 timestamptz,
  "hanMoi"                timestamptz,
  "hinhThucHoanThanh"     text check ("hinhThucHoanThanh" in ('da_xet_xu','chuyen_di','tam_dinh_chi','dinh_chi','an_huy')),
  "vuTachRa"              text references "vuan"("id"),
  "lyDoTach"              text check ("lyDoTach" in ('khac_toi_danh','de_tam_dinh_chi','de_dinh_chi','khac')),
  "vuNhapVao"             text references "vuan"("id"),
  "soQuyetDinh"           text not null default '',
  "ngaySuKien"            timestamptz,
  "kyThongKe"             text references "kybaocao"("id"),
  "lichSuSuaKy"           jsonb not null default '[]',   -- [{tuKy, denKy, lyDo, nguoiThucHien, thoiDiem}]
  "ghiChu"                text not null default '',
  "nguoiThucHien"         text,
  "thoiDiemGhi"           timestamptz not null default now(),

  -- Chỉ dùng khi loaiSuKien = 'giao_nhan_ho_so':
  "phienGiaoNhanId"       text references "phienGiaoNhan"("id"),
  "loaiGiaoDich"          text check ("loaiGiaoDich" in ('giao','nhan')),
  "tenVu"                 text,      -- snapshot lúc quét
  "soQdKtva"              text,      -- snapshot
  "ngayQdKtva"            timestamptz,
  "nguoiGiao"             text,      -- snapshot vuan.ksvChinh, sửa được sau
  "nguoiNhan"             text,      -- snapshot vuan.dtvCbdt, sửa được sau
  "nguoiNhanThucTe"       text not null default '',
  "soButLuc"              text not null default '',
  "trangThaiVu"           text,      -- snapshot vuan.trangThai
  "soQdGiaiQuyet"         text,      -- snapshot số QĐ giải quyết tương ứng
  "ngayQuyetDinh"         timestamptz,  -- snapshot ngày giải quyết
  "thoiHanBaoQuan"        text,
  "mucAnLoai"             text,
  "mucAnNam"              integer,
  "mucAnThang"            integer,
  "khongTiepNhan"         boolean not null default false,   -- chỉ có ý nghĩa khi loaiGiaoDich='nhan'
  "lyDoKhongTiepNhan"     text not null default ''
);

create index "lichsuChuyenGiaiDoan_maVuAn_thoiDiemGhi_idx"
  on "lichsuChuyenGiaiDoan" ("maVuAn","thoiDiemGhi");
create index "lichsuChuyenGiaiDoan_kyThongKe_loaiSuKien_denGiaiDoan_idx"
  on "lichsuChuyenGiaiDoan" ("kyThongKe","loaiSuKien","denGiaiDoan");
create index "lichsuChuyenGiaiDoan_kyThongKe_loaiSuKien_tuGiaiDoan_idx"
  on "lichsuChuyenGiaiDoan" ("kyThongKe","loaiSuKien","tuGiaiDoan");
create index "lichsuChuyenGiaiDoan_phienGiaoNhanId_idx"
  on "lichsuChuyenGiaiDoan" ("phienGiaoNhanId") where "phienGiaoNhanId" is not null;
create index "lichsuChuyenGiaiDoan_thoiDiemGhi_idx"
  on "lichsuChuyenGiaiDoan" ("thoiDiemGhi" desc);  -- phục vụ "Nhật ký thao tác" limit(300)
