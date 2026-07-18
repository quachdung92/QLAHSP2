# Kế hoạch chuyển hạ tầng dữ liệu từ Firebase (Firestore) sang Supabase (Postgres)

> Nhánh: `supabase-migration`. Tài liệu này là nguồn tham chiếu chính cho toàn bộ quá trình chuyển
> đổi — giữ cập nhật qua từng phiên làm việc, đừng để lệch với thực tế code trên nhánh này (giống
> cách `CLAUDE.md` được duy trì cho `main`).

## 1. Vì sao chuyển

Firestore tính phí theo **lượt đọc (read)** — mô hình này là nguyên nhân trực tiếp của rất nhiều
đợt "tối ưu Firestore" đã làm trên `main` (gộp listener dùng chung, cache lạnh IndexedDB, sentinel
cho dữ liệu "nóng", cursor pagination thật... — xem các mục "Tối ưu Firestore..." trong
`CLAUDE.md`). Đó là cách chữa triệu chứng: mô hình pricing theo read vẫn còn nguyên, mọi tính năng
mới đều phải cân nhắc thêm chi phí đọc. Mục tiêu của việc chuyển sang Supabase (Postgres, tính phí
theo dung lượng/băng thông/compute, không tính theo từng lượt đọc) là giải quyết dứt điểm gốc rễ,
không phải vá thêm.

**Ràng buộc không đổi**: vẫn giữ nguyên tắc "1 file HTML, mọi thư viện qua CDN, không có bước
build" — Supabase JS client cũng có bản UMD/ESM qua CDN nên khả thi giữ nguyên kiến trúc này.

## 2. Phạm vi hiện trạng Firebase (đã khảo sát trên `qlva.html`, ~11.923 dòng script chính)

### Collection Firestore (9)
- **7 collection nghiệp vụ thật**: `vuan`, `bican`, `lichsuChuyenGiaiDoan` (log append-only —
  nguồn sự thật duy nhất cho số liệu báo cáo), `kybaocao`, `canbo`, `danhMucToiDanh`,
  `phienGiaoNhan`.
- **2 collection thuần kỹ thuật** (sẽ không cần tồn tại riêng ở Postgres): `boDemMaVu` (bộ đếm
  sinh mã vụ án, chỉ đọc/ghi trong transaction, không bao giờ query cả collection) và
  `meta/vuAnMoiNhat` (1 doc sentinel để các client biết có vụ mới mà không cần listener sống trên
  cả danh sách — cơ chế né tránh chi phí Firestore, xem mục 5).

### Realtime & ghi dữ liệu
- **15 vị trí `onSnapshot`** → 9 kiểu subscription khác nhau (4 trong số đó đã gộp qua cơ chế cache
  dùng chung `firestoreCacheRegistry`/`useFirestoreCollectionCache`, xem CLAUDE.md "Tối ưu
  Firestore Đợt 1").
- **4 vị trí `db.runTransaction`**: `sinhMaVuAnMoi` (đếm tăng dần theo tháng để sinh mã vụ án),
  `sinhNhieuMaVuAn` (bản hàng loạt của trên, dùng lúc import Excel), `capNhatDieuLuatVaLoaiKhoiTo`
  (đọc lại toàn bộ bị can của 1 vụ, tính lại rồi ghi — tránh lost-update khi 2 người sửa đồng
  thời), `tachVuAn` (đếm số lần tách để sinh mã vụ con). Cả 4 đều là pattern "optimistic
  concurrency + counter", không phải giao dịch nhiều bước phức tạp.
- **~19 vị trí `batch()`/`commit()`**, vài chỗ chia lô 400 (giới hạn ghi/batch của Firestore) —
  giới hạn này biến mất hoàn toàn ở Postgres.
- **8 composite index** trong `firestore.indexes.json` (3 trên `lichsuChuyenGiaiDoan`, 5 trên
  `vuan`).

### Bảo mật & Auth
- **Security rules**: đúng 1 rule `request.auth != null` cho toàn bộ database — không phân quyền
  theo collection/field/role.
- **Auth**: chỉ email/password, không custom claims/role, `onAuthStateChanged` là cổng duy nhất
  vào toàn bộ UI (`App()`, gần cuối file). `auth.currentUser?.email` được đọc ở ~25 chỗ chỉ để ghi
  audit trail (`nguoiThucHien`/`nguoiCapNhatCuoi`), không đọc property nào khác của user.

### Khoảng trống thật cần lưu ý
- **Offline persistence** (`db.enablePersistence({synchronizeTabs:true})`) — Firestore SDK tự lo
  hàng đợi ghi + cache đọc khi mất mạng tạm thời. Supabase là REST/WebSocket thuần, **không có
  SDK offline-first tương đương sẵn có**. Đây là 1 tính năng thật sẽ mất nếu không tự xây thay thế
  — không chặn việc bắt đầu migrate, nhưng phải quyết định rõ ràng ở Phase 5 (chấp nhận mất tạm
  thời hay tự xây hàng đợi ghi riêng bằng localStorage/IndexedDB).

### Ngoài phạm vi Firestore/Auth (không đổi)
- Không dùng Firebase Storage/Functions/Realtime Database/Analytics/FCM/App Check — xác nhận qua
  grep toàn bộ codebase, không có kết quả nào.
- **Firebase Hosting giữ nguyên** — quyết định đã chốt với Dũng: vấn đề quota là do lượt đọc
  Firestore, không liên quan Hosting (gần miễn phí, không tính theo lượt đọc dữ liệu). `deploy.sh`/
  `deploy.bat`/`firebase.json`/`.firebaserc` không cần đổi gì.
- CDN không liên quan Firebase (React 18 UMD, Babel standalone, Tailwind, SheetJS `xlsx`,
  ExcelJS, Chart.js, qrcodejs) giữ nguyên 100%.

## 3. Chiến lược chuyển đổi code: lớp shim giả lập Firestore API

**Quyết định đã chốt** (thay vì sửa thẳng ~185 vị trí gọi Firestore cùng lúc): dựng 1 lớp trung
gian `db = createFirestoreShim(supabaseClient)` thay cho `db = firebase.firestore()`, giả lập
đúng SUBSET API mà ứng dụng đang thực sự dùng (không cần giả lập toàn bộ Firestore SDK):

- `db.collection(name).where(field, op, value).orderBy(field, dir).limit(n).get()` /
  `.onSnapshot(callback)`
- `db.collection(name).doc(id).get()` / `.set(data)` / `.update(data)` / `.delete()`
- `db.batch()` → `batch.set/update/delete(ref, data)` → `batch.commit()`

Bên trong shim, các thao tác này gọi Supabase (`.from(table).select()/.insert()/.update()/
.delete()`, `.channel().on('postgres_changes', ...)` cho phần realtime). Lợi ích: ứng dụng ở ~90%
vị trí gọi hầu như KHÔNG đổi cú pháp, chỉ đổi phần thân `db` — giảm rủi ro so với sửa thẳng diện
rộng, có thể chuyển từng collection 1 và rollback dễ dàng.

Chi tiết ngữ nghĩa cần giữ khi viết shim:
- `where(field, "in", [...])` → Postgres `= ANY(...)`, **bỏ hết giới hạn/logic chia lô 30 item**
  hiện có (Firestore giới hạn `in` tối đa 30, Postgres không có giới hạn tương tự).
- `FieldValue.arrayUnion` → `array_append` hoặc ghi qua RPC riêng.
- `Timestamp`/`.toDate()` → Postgres `timestamptz`, JS nhận về ISO string hoặc `Date` — cần audit
  lại toàn bộ pattern phòng thủ `d.toDate ? d.toDate() : new Date(d)` đang rải rác nhiều nơi.

**4 vị trí `runTransaction` KHÔNG đi qua shim chung** — viết tay riêng, gọi thẳng `.rpc()` tới các
hàm Postgres function (`plpgsql`) tương ứng, vì bản chất thực thi khác hẳn (Firestore transaction
là nhiều round-trip từ client; Postgres function chạy atomic trong 1 lần gọi). Quy mô nhỏ (4 hàm),
rủi ro thấp, làm riêng ở Phase 1-2.

## 4. Schema Postgres — ĐÃ VIẾT XONG (`supabase/schema.sql`, `rls.sql`, `functions.sql`)

**Quyết định thiết kế đã chốt (khác vài chỗ so với bản nháp ban đầu ở đây, xem comment đầu
`schema.sql` để biết đầy đủ lý do)**:

- **Tên bảng/cột giữ NGUYÊN camelCase, trùng khớp 1:1 tên collection/field Firestore** (VD bảng
  `"vuan"`, cột `"tenVu"`, `"ngayQdKtva"` — identifier có quote kép), KHÔNG đổi sang snake_case
  như bản nháp ban đầu dự tính (`lichsu_chuyen_giai_doan`, `ky_bao_cao`...). Lý do: lớp shim (mục
  3) chỉ thật sự "gần như không cần sửa code ứng dụng" nếu PostgREST trả JSON với đúng tên field
  cũ — đổi tên cột sẽ buộc shim phải có thêm 1 tầng map tên field, đúng thứ rủi ro chiến lược shim
  muốn tránh.
- `toiDanh`/`dieuLuatBC` (bican) và `vuanToiDanh`/`vuanDieuLuat` (vuan) **giữ dạng cột mảng
  `text[]`**, không tách bảng con — đã quyết định dứt điểm (không còn "cân nhắc") sau khi rà lại
  toàn bộ chỗ đọc/ghi: ứng dụng luôn thao tác như mảng đồng bộ theo index, tách bảng con chỉ thêm
  JOIN+GROUP BY mà không phục vụ nhu cầu quan hệ nào thật sự đang có.
- `boDemMaVu` **giữ 1 bảng riêng** (không thay bằng Postgres `sequence` như dự tính ban đầu) —
  sequence phải tạo trước cho từng YYMM, không tiện tạo động an toàn qua RPC; bảng counter nhỏ +
  UPSERT nguyên tử (`INSERT ... ON CONFLICT DO UPDATE RETURNING`) đơn giản/an toàn hơn. Bảng này
  KHÔNG cấp quyền cho role `authenticated` — chỉ được đụng từ bên trong 4 hàm RPC (SECURITY
  DEFINER), ứng dụng phía client không bao giờ gọi thẳng.
- `meta/vuAnMoiNhat` **cố ý không có bảng tương ứng** — xem mục 5.

Bảng tổng quan (đầy đủ ở `supabase/schema.sql`, đã đối chiếu TỪNG FIELD với write-site thật trong
`qlva.html` qua 2 agent Explore, không suy đoán từ tài liệu `schema_csdl_...md` — file đó thừa
nhận đã lỗi thời cho nhiều field thêm sau):

| Bảng Postgres | Nguồn Firestore | PK |
|---|---|---|
| `"vuan"` | `vuan` | `id` TEXT = `maNoiSinh` (business key, không đổi UUID) |
| `"bican"` | `bican` | `id` TEXT, default `gen_random_uuid()::text` |
| `"lichsuChuyenGiaiDoan"` | `lichsuChuyenGiaiDoan` | `id` TEXT, default uuid |
| `"kybaocao"` | `kybaocao` | `id` TEXT, default uuid |
| `"canbo"` | `canbo` | `id` TEXT, default uuid |
| `"danhMucToiDanh"` | `danhMucToiDanh` | `id` TEXT, default uuid |
| `"phienGiaoNhan"` | `phienGiaoNhan` | `id` TEXT, default uuid |
| `"boDemMaVu"` (nội bộ, không qua shim) | `boDemMaVu` | `yymm` TEXT |

**Enum**: dùng CHECK constraint (`CHECK (col IN (...))`), KHÔNG dùng Postgres native ENUM type —
enum nghiệp vụ ở đây đã đổi/thêm giá trị nhiều lần qua các phiên trước (xem mục 4b), native ENUM
khó thêm giá trị an toàn hơn CHECK.

**RLS** (`supabase/rls.sql`): mirror đúng rule hiện tại — 1 policy `USING (auth.role() =
'authenticated')` cho mỗi bảng (trừ `boDemMaVu`, xem trên), không phân quyền field/row.

**4 hàm RPC** (`supabase/functions.sql`, thay 4 `db.runTransaction`): `"sinhMaVuAnMoi"(yymm)`,
`"sinhNhieuMaVuAn"(yymm[])`, `"tachVuSinhMa"(vuGocId)`, `"capNhatDieuLuatVaLoaiKhoiTo"(maVuAn)` —
chạy SECURITY DEFINER, quyền EXECUTE giới hạn riêng cho role `authenticated`.

### 4b. Phát hiện lệch dữ liệu thật cần xử lý ở Phase 4 (export/import)

Qua audit field-level, phát hiện vài điểm KHÔNG khớp giữa tài liệu schema cũ và code/dữ liệu thật
— quan trọng khi viết script transform dữ liệu (mục 6), không phải lỗi cần sửa ngay bây giờ:

- `lichsuChuyenGiaiDoan.loaiSuKien` có giá trị **`sua_thong_tin`** dùng thật trong code (khi bấm
  "Sửa thông tin" 1 vụ án) nhưng KHÔNG có trong enum tài liệu cũ — đã đưa vào CHECK constraint.
  Ngược lại, 4 giá trị tài liệu cũ liệt kê (`ket_luan_dieu_tra`, `ket_luan_dieu_tra_bo_sung`,
  `cao_trang`, `cao_trang_bo_sung`) là **dead — chưa từng được ghi bởi code thật** (thay bằng
  `chuyen_giai_doan` + field `soKetLuanDieuTra`/`soCaoTrang` trên chính `vuan`) — CỐ Ý KHÔNG đưa
  vào CHECK constraint mới, nếu dữ liệu thật export ra có dòng nào mang giá trị này (rất khó xảy
  ra) thì phải map lại trước khi import.
- `lichsuChuyenGiaiDoan.soQuyetDinh` (free text "số QĐ/kết luận/cáo trạng/bản án") hoàn toàn thiếu
  trong tài liệu schema cũ dù có trên 7/12 loại sự kiện — đã thêm vào schema mới.
- `danhMucToiDanh` có **2 field song song chưa từng đồng bộ** cho cùng khái niệm "năm BLHS":
  `namBLHS` (do công cụ seed ghi, dùng thật trong logic tra cứu `taoDanhMucByTen`) và `blhsNam`
  (do form sửa tay UI ghi, giá trị mặc định `"2015_sd_2017"` còn không khớp map hiển thị của chính
  nó). Schema mới CHỈ giữ `"namBLHS"` — script transform (Phase 4) phải chuyển giá trị `blhsNam`
  cũ (nếu có, chỉ ở dòng nhập tay qua UI) sang đúng `namBLHS` tương ứng trước khi import, không
  mang cả 2 field song song sang Postgres.
- `lichsuChuyenGiaiDoan.ngaySuKien`/`thoiDiemGhi` không nhất quán kiểu ở nguồn: đa số ghi
  `new Date()` (client time), riêng sự kiện `sua_thong_tin` ghi `serverTimestamp()`/ISO string —
  script transform chuẩn hoá về `timestamptz` đồng nhất, không mang sự khác biệt kiểu này sang.

## 5. Cơ hội đơn giản hoá (cân nhắc ở Phase 2, KHÔNG bắt buộc)

Nhiều cơ chế phức tạp hiện có trong `qlva.html` (sentinel `meta/vuAnMoiNhat`, cache-registry dùng
chung với grace-period 3 phút, cursor pagination thủ công né tránh đọc lại...) tồn tại **chỉ vì**
Firestore tính phí theo từng lượt đọc/listener. Supabase không có động cơ chi phí tương tự để né
tránh subscribe trực tiếp. Khi vào Phase 2, cân nhắc nghiêm túc việc bỏ bớt các lớp né-chi-phí này
và subscribe thẳng qua Supabase Realtime — đúng tinh thần "đổi hạ tầng để giảm độ phức tạp", không
phải "giữ nguyên mọi lớp vá cũ trên nền mới". Đây KHÔNG phải việc bắt buộc của migration, chỉ là cơ
hội nên đánh giá khi đã có shim chạy ổn định.

## 6. Kế hoạch export/import dữ liệu thật (cả 2 project: `qlahs-test` và `qlahsp2`)

1. **Export**: script đọc toàn bộ 7 collection nghiệp vụ (không cần export `boDemMaVu`/`meta`) →
   dump JSON, 1 file/collection. Làm trên `qlahs-test` trước.
2. **Transform**: chuẩn hoá kiểu dữ liệu (Timestamp → ISO string cho `timestamptz`), cộng các phép
   chuyển đổi cụ thể phát hiện ở mục 4b (gộp `blhsNam`→`namBLHS`, loại bỏ 4 giá trị `loaiSuKien`
   dead nếu gặp, không cần tách mảng `toiDanh`/`dieuLuatBC` vì schema giữ nguyên dạng cột mảng).
3. **Import**: dùng kết nối Postgres trực tiếp Supabase cấp (nhanh hơn nhiều so với qua REST cho
   khối lượng ~1400 vụ + ~2250 bị can + hàng nghìn dòng log) — `psql`/COPY hoặc script Node dùng
   driver `pg`.
4. **Đối chiếu**: so số dòng theo từng bảng, VÀ chạy lại các phép kiểm tra nghiệp vụ đã có (VD
   tổng số liệu Biểu B10 của 1 kỳ đã chốt phải khớp giữa Firestore cũ và Postgres mới).
5. **Thứ tự bắt buộc**: `qlahs-test` xong xuôi + kiểm chứng kỹ → mới làm `qlahsp2` — đúng văn hoá
   "test trước, prod sau" đã áp dụng nhất quán trong toàn bộ dự án này.

## 7. Lộ trình theo giai đoạn

- [x] **Phase 0**: tạo nhánh `supabase-migration`, viết tài liệu kế hoạch này. Chưa đụng code ứng
      dụng.
- [~] **Phase 1** (đang làm — phần schema đã xong, còn chờ env): đã viết đầy đủ
      `supabase/schema.sql` + `rls.sql` + `functions.sql` (7 bảng + `boDemMaVu`, RLS, 4 hàm RPC),
      dựa trên khảo sát field-level thật từ code (không suy đoán) — xem mục 4/4b. Đã parse-check
      cú pháp qua `libpg-query` (bộ phân tích cú pháp Postgres thật) — sạch, nhưng **CHƯA áp dụng
      lên Supabase thật, CHƯA kiểm chứng bằng Postgres thật** (phần thân 4 hàm RPC chưa được
      trình biên dịch plpgsql xác nhận) — cần Dũng tạo 2 project Supabase thật (1 ứng với
      `qlahs-test`, 1 ứng với `qlahsp2`) rồi cấp connection string/API key mới áp dụng và test
      được (xem `supabase/README.md` mục "Chưa kiểm chứng").
- [ ] **Phase 2**: viết lớp shim (mục 3), phát triển trên **`qlahs-sup.html`** (đã tạo — copy
      nguyên văn từ `qlva.html`, đổi Firebase config trỏ sang project TEST `qlahs-test` thay vì
      production để tránh đụng dữ liệu thật trong lúc còn dùng Firebase song song, có nhãn
      `[SUP-TEST]` ở `<title>` để không nhầm với `qlva.html`/`qlva-dev.html` khi mở nhiều tab —
      xem comment đầu file). File này KHÔNG deploy, chỉ dùng cục bộ để phát triển/kiểm chứng shim
      độc lập, không đụng 2 file đang chạy thật. Đánh giá cơ hội đơn giản hoá ở mục 5.
- [ ] **Phase 3**: chuyển Auth sang Supabase Auth — tài khoản Firebase Auth hiện có phải tạo lại
      thủ công trên Supabase (không tự động chuyển mật khẩu giữa 2 hệ thống được).
- [ ] **Phase 4**: export/import dữ liệu thật theo mục 6, `qlahs-test` trước.
- [ ] **Phase 5**: kiểm thử toàn diện trên project test (đủ bộ Playwright hồi quy hiện có + kịch
      bản mới cho Realtime/RPC), quyết định hướng xử lý khoảng trống offline persistence.
- [ ] **Phase 6**: export/import `qlahsp2` (dry-run trước, đối chiếu số liệu kỹ), cắt sang
      production. Giữ Firestore ở chế độ đọc-only 1 thời gian làm lưới an toàn trước khi ngừng hẳn.

## 8. Trạng thái hiện tại

Đang ở **Phase 1** — schema/RLS/RPC đã viết xong (`supabase/*.sql`), commit trên nhánh
`supabase-migration`. Chưa có project Supabase nào được tạo, chưa áp dụng/test file SQL nào bằng
Postgres thật. **Việc cần làm tiếp theo**: Dũng tạo project Supabase (khuyến nghị tạo project ứng
với `qlahs-test` trước), cấp URL + `anon key` (và lý tưởng là cả connection string Postgres trực
tiếp, dùng cho import dữ liệu ở Phase 4) — phiên sau sẽ áp dụng 3 file SQL lên đó và kiểm chứng
theo checklist ở `supabase/README.md`.
