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

### 4c. Đã áp dụng lên Supabase THẬT + kiểm chứng chức năng (2026-07-19)

Project Supabase thật đã được Dũng tạo: ref `eutatszoaseixchvjbtg` (URL
`https://eutatszoaseixchvjbtg.supabase.co`). **Quyết định phạm vi**: đây là project DUY NHẤT dùng
làm môi trường chính (không tách riêng test/prod ở bước này) — sẽ nạp dữ liệu mock kéo từ project
Firestore thật, và **reset lại khi hoàn thiện** trước khi thật sự lên production. Khác nhẹ so với
lộ trình gốc ở mục 7 (dự tính 2 project ngay từ Phase 1) — điều chỉnh vì đơn giản hoá thao tác cho
Dũng, không ảnh hưởng tới thiết kế schema.

**Vấn đề hạ tầng phát hiện khi kết nối**: host kết nối trực tiếp
(`db.eutatszoaseixchvjbtg.supabase.co`) chỉ có bản ghi DNS AAAA (IPv6), không có A (IPv4) — hành vi
mặc định mới của Supabase (gói IPv4 riêng phải trả thêm). Môi trường thực thi lệnh không có route
IPv6 ra ngoài (`ENETUNREACH` khi thử kết nối thẳng IPv6, dù DNS AAAA vẫn phân giải được — 2 việc
khác nhau). **Giải pháp**: dùng **Session pooler** (`aws-0-ap-southeast-1.pooler.supabase.com:5432`,
username `postgres.eutatszoaseixchvjbtg` — khác hẳn Direct connection cả về host lẫn username) —
tương thích IPv4, và đúng loại pooler cần cho việc chạy script quản trị nhiều câu lệnh/hàm
`plpgsql` (Transaction pooler tối ưu cho query ngắn hạn của ứng dụng runtime, KHÔNG hợp cho việc
này). **Lưu ý cho phiên sau**: khi cần chạy thêm script quản trị/import dữ liệu (Phase 4), dùng lại
đúng chuỗi Session pooler này, đừng thử Direct connection lại (sẽ lặp lại đúng lỗi IPv6 này).

**Đã áp dụng thành công cả 3 file** (`schema.sql` → `rls.sql` → `functions.sql`, qua script Node
dùng `pg`, chạy 1 lần không sửa gì) — xác nhận: 8 bảng đúng tên (7 nghiệp vụ + `boDemMaVu`), 7 RLS
policy đúng 1/bảng nghiệp vụ (không có ở `boDemMaVu`, đúng thiết kế), 4 hàm RPC tồn tại và BIÊN
DỊCH ĐÚNG (giải quyết dứt điểm phần "chưa kiểm chứng" ghi ở `supabase/README.md` — trước đó chỉ
parse-check cú pháp ngoài, chưa biết phần thân `plpgsql` có lỗi runtime/biên dịch không).

**Đã kiểm thử CHỨC NĂNG thật (14 assertion, dữ liệu tự tạo rồi dọn sạch ngay sau)**:
- `sinhMaVuAnMoi('9901')` gọi 2 lần liên tiếp → đúng `..._0001` rồi `..._0002`.
- `sinhNhieuMaVuAn(['9902','9902','9903','9902','9903'])` → đúng gộp riêng từng nhóm YYMM, số thứ
  tự liên tục trong CÙNG nhóm bất kể xen kẽ vị trí (`9902` ra `0001/0002/0003`, `9903` ra
  `0001/0002`) — xác nhận logic nhóm theo tháng hoạt động đúng như file gốc Firestore.
- `tachVuSinhMa` gọi 2 lần trên cùng 1 vụ giả → đúng hậu tố `_1` rồi `_2`.
- `capNhatDieuLuatVaLoaiKhoiTo` với 2 bị can giả (1 người khởi tố sớm hơn, tội danh khác nhau) →
  đúng gán `ban_dau`/`bo_sung` theo ngày khởi tố sớm nhất, `vuan.dieuLuat` gộp đúng cả 2 tội danh
  (nối `"; "`), cache `soBiCan`/`biCanDaiDien` cập nhật đúng.

**Đã kiểm chứng RLS qua ĐÚNG cổng ứng dụng thật sẽ dùng** (REST API/PostgREST bằng `curl` +
`anon key`, KHÔNG phải qua kết nối Postgres trực tiếp — kết nối đó chạy role `postgres` (superuser)
nên KHÔNG bị RLS chặn, test qua đó sẽ cho kết quả giả-đúng): `GET /rest/v1/vuan` bằng anon key trả
`200` (bảng đang trống); `POST /rest/v1/vuan` (thử ghi) bằng anon key bị chặn rõ ràng — `HTTP 401`,
lỗi Postgres `42501 "new row violates row-level security policy for table vuan"` — đúng ngữ nghĩa
"chưa đăng nhập (role anon, chưa phải authenticated) thì không ghi được", khớp hành vi
`request.auth != null` của Firestore rules cũ.

**Về credential**: mật khẩu DB (Session pooler) chỉ dùng tạm trong script test/áp dụng schema ở
thư mục scratchpad (ngoài repo), KHÔNG được ghi vào bất kỳ file nào trong git. `anon key` (đã nhận
từ Dũng) là loại key công khai-an-toàn theo thiết kế của Supabase (được RLS bảo vệ, giống hệt vai
trò `apiKey` của Firebase đã nhúng thẳng trong `qlva.html` từ trước) — sẽ nhúng vào `qlahs-sup.html`
khi viết lớp shim ở Phase 2, không cần giữ bí mật ở mức độ như mật khẩu DB.

### 4d. Lớp shim (Phase 2) — ĐÃ VIẾT + KIỂM CHỨNG ĐẦY ĐỦ bằng dữ liệu thật (2026-07-19)

Viết trong `qlahs-sup.html`: bỏ hẳn 3 script CDN Firebase, thay bằng 1 script
`@supabase/supabase-js@2` (UMD). Khối cấu hình cũ (`firebase.initializeApp`, `db.enablePersistence`)
thay bằng lớp shim đầy đủ — chi tiết kỹ thuật đã ghi trong comment đầu khối `<script>` của chính
file đó (không lặp lại ở đây), tóm tắt:
- `db.collection(name).where/orderBy/limit/startAfter().get()/.onSnapshot()`, `.doc(id?)`, `.add()`.
- `db.batch()` → `set/update/delete` → `commit()`.
- `firebase.firestore.FieldValue.{serverTimestamp,arrayUnion}`/`FieldPath.documentId()` giữ nguyên
  API cũ (shim tự định nghĩa lại, không phải SDK Firebase thật) — ~35 chỗ gọi trong code KHÔNG cần
  sửa gì.
- 4 vị trí `db.runTransaction` (sinh mã vụ án, sinh mã hàng loạt, sinh mã tách vụ, tính lại điều
  luật/loại khởi tố) sửa tay gọi thẳng `sb.rpc(...)` — đúng thiết kế mục 3, không đi qua shim chung.

**Bug thật tìm được + đã sửa qua Playwright test** (không phải giả thuyết): `batch.commit()` bản
đầu gộp insert theo BẢNG NÀO GẶP TRƯỚC trong danh sách thao tác — đúng với Firestore (không có FK,
thứ tự không quan trọng) nhưng **SAI với Postgres có FK thật**: `ThemVuAnForm` ghi log
`khoi_to_bican` (tham chiếu `bican.id`) XEN GIỮA các lần `batch.set()` tạo bị can, không phải tạo
hết bị can rồi mới ghi log — batch cũ chèn `lichsuChuyenGiaiDoan` TRƯỚC KHI `bican` tồn tại, lỗi
`23503 FK violation`. Đã sửa: thêm `_TABLE_INSERT_ORDER` (thứ tự phụ thuộc cố định: kybaocao/canbo/
danhMucToiDanh/meta → vuan → bican → phienGiaoNhan → lichsuChuyenGiaiDoan), `commit()` LUÔN insert
theo đúng thứ tự này bất kể thứ tự gọi `.set()` trong code ứng dụng.

**Phát hiện hạ tầng khác**: Supabase Realtime **KHÔNG tự bật cho bảng mới** — phải
`ALTER PUBLICATION supabase_realtime ADD TABLE "..."` cho từng bảng (đã làm cho cả 8 bảng), nếu
không `onSnapshot()` chỉ bắn được lần đầu (từ `.get()`), không bao giờ bắn lại khi có thay đổi.

**Đã kiểm chứng bằng Playwright thật, dữ liệu thật trên project `eutatszoaseixchvjbtg`** (17
assertion qua 3 kịch bản độc lập, không phải mock):
1. Đăng nhập qua shim Auth (Supabase Auth thật, user `admintest@local.com` đã tạo ở Phase 1) → vào
   được màn hình chính.
2. Test trực tiếp các thao tác nguyên thuỷ của shim qua `page.evaluate()` (13 assertion): doc
   set/get/delete; where nhiều điều kiện lọc đúng không lẫn; batch set+update+delete cùng lúc;
   **onSnapshot bắn ngay lần đầu + bắn lại đúng qua Realtime thật sau khi có thay đổi** (xác nhận
   cơ chế "refetch khi có bất kỳ thay đổi nào" hoạt động đúng); RPC `sinhMaVuAnMoi` sinh mã tăng
   dần đúng qua 2 lần gọi liên tiếp với YYMM ngẫu nhiên (tránh đụng dữ liệu cũ giữa các lần chạy
   test).
3. **Luồng UI THẬT đầy đủ** (4 assertion): mở form "Thêm vụ án" → điền Ngày QĐ KTVA + họ tên bị can
   → bấm "Lưu vụ án" → xác nhận modal "Tính vào kỳ báo cáo nào?" → form tự đóng đúng (không kẹt do
   lỗi) → vụ án xuất hiện lại trên Danh sách vụ án. Đối chiếu trực tiếp qua Postgres xác nhận ĐÚNG
   toàn bộ chuỗi dữ liệu: `vuan` (mã đúng định dạng `QLVA_E01.53_2601_0001`, `soBiCan`/
   `biCanDaiDien` cache tính đúng), `bican` (FK đúng), `lichsuChuyenGiaiDoan` (2 sự kiện
   `khoi_to_vu`+`khoi_to_bican`, đúng liên kết), `meta` sentinel (`capNhatLuc` cập nhật đúng qua
   `.set(..., {merge:true})`/upsert).
0 lỗi console thật xuyên suốt cả 3 kịch bản (đã lọc riêng 1 lỗi lệch giờ JWT do đồng hồ hệ thống
sandbox test — xem đoạn dưới — không phải bug code). Toàn bộ dữ liệu test đã dọn sạch sau khi xong
(cả 8 bảng về lại 0 dòng), project sẵn sàng cho bước nạp mock data thật (Phase 4).

**Giới hạn môi trường test đã ghi nhận (không phải bug)**: sandbox chạy Playwright có đồng hồ hệ
thống khớp ngày kịch bản phiên làm việc (`2026-07-19`), sớm/lệch so với giờ thực server Supabase —
occasionally khiến Realtime từ chối JWT với lỗi `PGRST303 "JWT issued at future"` (khắt khe hơn hẳn
REST API/Auth — những API đó không gặp vấn đề này suốt cả phiên). Chạy lại nhiều lần xác nhận đây
là vấn đề BIÊN/không nhất quán (có lần fail có lần pass), không phải lỗi logic — cơ chế refetch
dùng lại đúng code `.get()` đã test PASS ổn định. Nên re-test Realtime 1 lần nữa trên trình duyệt
thường (đồng hồ hệ thống đúng giờ thực) trước khi hoàn toàn tin tưởng, dù bằng chứng hiện tại đã
khá thuyết phục.

**Cập nhật (cùng ngày, ngay sau khi viết xong shim)**: đã LÀM 2/7 mục checklist ở mục 5 (mục 1 và
2) trong CHÍNH phiên này — ban đầu định để dành hẳn "phiên sau" (xem đoạn dưới, còn giữ nguyên vì lý
do tách bạch rủi ro vẫn đúng cho phần còn lại), nhưng vì `qlahs-sup.html` đã có nền shim chạy ổn
định + bộ test đã dựng sẵn, làm luôn 2 mục có giá trị rõ nhất trong khi bối cảnh còn "nóng" hợp lý
hơn hoãn lại. Kết quả và bug tìm được ghi ở mục 5 (đã đánh dấu `[x]`), không lặp lại ở đây.

Lý do gốc (vẫn áp dụng cho 5 mục còn lại `[ ]`): viết shim là "giữ nguyên hành vi ứng dụng, chỉ đổi
tầng dưới" (rủi ro thấp); checklist mục 5 là "chủ động đổi HÀNH VI ứng dụng" (bỏ live listener đóng
băng, đổi UX phân trang...) — cần tách bạch để dễ khoanh vùng nếu có lỗi phát sinh.

**Cập nhật lần 4 (cùng ngày) — CHECKLIST MỤC 5 ĐÃ RÀ XONG 7/7 MỤC.** Kết quả cuối:
- **2 mục bỏ hẳn** (code đơn giản hoá thật sự): `firestoreCacheRegistry`, sentinel
  `meta/vuAnMoiNhat`.
- **1 mục sửa 1 phần** (bỏ 30-item chunking + lọc filter server-side): kỹ thuật né composite
  index.
- **4 mục rà kỹ rồi QUYẾT ĐỊNH GIỮ NGUYÊN**, mỗi mục có lý do cụ thể độc lập với chi phí Firestore
  (không phải "chưa làm"/bỏ sót — xem chi tiết từng mục ngay dưới): cursor pagination đóng băng
  (tránh race tính đúng đắn), cache lạnh IndexedDB (lý do sản phẩm đã thống nhất từ trước, không
  chỉ chi phí), `fetchWithTtlCache` (hộp thoại tìm-chọn ngắn, không cần realtime),
  `BangBiCanCon`/`BangExcelModule`/cột Kỳ `DanhSachPanel` (công cụ 1 người + giới hạn filter thật
  của Supabase Realtime khiến "khôi phục live" phản tác dụng ở đúng màn hình đông người xem nhất).

**Bài học rút ra sau khi rà hết 7 mục**: không phải MỌI cơ chế "tránh live/tránh đọc lại" trong
code cũ đều thuần tuý vì chi phí Firestore như giả định ban đầu của checklist này — nhiều cơ chế
có LỚP LÝ DO THỨ 2 (tính đúng đắn, UX công cụ 1-người, giới hạn kỹ thuật của chính Realtime) mà chỉ
lộ ra khi đọc kỹ code thay vì suy đoán từ tên gọi. Giá trị thật của checklist này không phải "xoá
càng nhiều càng tốt" mà là XÁC NHẬN LẠI từng quyết định — 2/7 mục xoá được thật, 5/7 còn lại vẫn
đúng và giờ có lý do ghi rõ ràng hơn bản gốc.

### 4e. Phase 4 — export/import dữ liệu thật `qlahs-test` làm mock data — ĐÃ HOÀN TẤT (2026-07-19)

Script nằm ngoài repo (thư mục scratchpad phiên làm việc, không commit — thuần công cụ chạy 1 lần,
không phải phần code sản phẩm): `export_firestore.js` (Playwright, đăng nhập thật
`qlahs-test.web.app`/`admintest@local.com`, đọc qua `db.collection(...).get()` — không cần Admin
SDK/service account), `validate_export.js` (đối chiếu mọi tham chiếu kiểu FK giữa các collection
JSON đã export, chạy TRƯỚC import để biết trước có dữ liệu mồ côi hay không), `import_to_supabase.js`
(transform + insert qua Session pooler, thứ tự bảng đúng `_TABLE_INSERT_ORDER` của shim).

**Export**: 9354 document/7 collection — `vuan`=1386, `bican`=2252, `lichsuChuyenGiaiDoan`=5068,
`kybaocao`=6, `canbo`=10, `danhMucToiDanh`=586, `phienGiaoNhan`=46. `validate_export.js` xác nhận
**0 tham chiếu treo** (mọi `maVuAn`/`maBiCan`/`vuTachRa`/`vuNhapVao`/`kyThongKe`/`phienGiaoNhanId`
đều trỏ tới document còn tồn tại) — dữ liệu nguồn tự nhất quán trước khi import.

**3 lỗi CHECK constraint thật gặp phải khi import** (Postgres ép kiểu/ràng buộc nghiêm ngặt hơn hẳn
Firestore schemaless — mỗi lỗi chỉ lộ ra khi thử import THẬT, không đoán trước được từ đọc code):
1. `vuan.daXoa` NOT NULL nhưng THIẾU HẲN trên toàn bộ 1386 dòng thật (field mới thêm gần đây, dữ
   liệu cũ chưa có) → fallback `false`.
2. `vuan.anDiem`/`nguon` mang giá trị "rác" trên ĐÚNG CÙNG 70/1386 dòng (`anDiem: ""` thay vì
   boolean thật, `nguon: "cq_dieu_tra"` không nằm trong 4 giá trị `NHAN_NGUON` hiện tại của code) —
   rõ ràng cùng 1 nguồn dữ liệu cũ/quirk chung. Ép `""` → `false` cho mọi cột boolean; `nguon` lạ
   map về DEFAULT schema (`an_khoi_to_moi`) — **quyết định CHỈ ĐÚNG cho dữ liệu mock/test này**, dữ
   liệu thật `qlahsp2` ở Phase 6 phải hỏi lại Dũng ý nghĩa thật của `cq_dieu_tra` trước khi map,
   không lặp lại suy đoán này.
3. `bican.bienPhapNganChan` giá trị cũ `"tam_giam"` (91/2252 dòng, tên trước khi đổi mã ngắn
   `"giam"` — khớp 1-1 rõ ràng qua nhãn `<option value="giam">Tạm giam</option>` trong code hiện
   tại, KHÁC hẳn trường hợp `nguon` ở trên vì đây không phải đoán mà là đổi tên field value thuần
   tuý) → rename thẳng.
4. `bican.loaiKhoiTo` giá trị cũ **KHÔNG HỢP LỆ** `"khoi_to_moi"` (123/2252 dòng — đúng bug
   `BackfillLoaiKhoiToTool` trong `qlva.html` đã tài liệu hoá: `ImportExcelModule` cũ từng hardcode
   sai giá trị này). Vì đây là field TỰ TÍNH (không nhập tay), script **tính lại đúng bằng thuật
   toán `tinhLoaiKhoiToTheoNgay` của chính app** (theo từng vụ: bị can có `ngayKhoiTo` NHỎ NHẤT =
   `ban_dau`, còn lại `bo_sung`) thay vì map bừa — áp dụng cho TOÀN BỘ 2252 bị can (không chỉ 123
   dòng sai) để đảm bảo nhất quán theo từng vụ, đúng những gì `BackfillLoaiKhoiToTool` sẽ làm nếu
   chạy trên dữ liệu này. Kết quả: 100% ra `ban_dau` — đã xác nhận đây là ĐÚNG (không phải bug mới):
   kiểm tra riêng cho thấy trong 242 vụ có ≥2 bị can, **0 vụ có `ngayKhoiTo` khác nhau giữa các bị
   can** (mọi bị can cùng vụ luôn bị khởi tố cùng ngày trong tập dữ liệu thật này) — nên
   `tinhLoaiKhoiToTheoNgay` cho ra toàn `ban_dau` là kết quả toán học đúng, không phải lỗi transform.
5. `lichsuChuyenGiaiDoan.lyDoTach` giá trị cũ `"manual"` (1 dòng — code bản cũ trước khi
   `TachVuModal` có dropdown lý do, hiện chỉ `'khac_toi_danh'`/`'khac'`) → map về `"khac"` (không rõ
   lý do cụ thể, cùng nhóm "quyết định chỉ đúng cho mock data" như `nguon` ở trên).

**Import cuối cùng: THÀNH CÔNG 100%, đúng khớp số dòng export** (0 dòng nào bị bỏ qua/rớt):
`kybaocao`=6, `canbo`=10, `danhMucToiDanh`=586, `vuan`=1386, `bican`=2252, `phienGiaoNhan`=46,
`lichsuChuyenGiaiDoan`=5068 — 71 ô tổng cộng bị remap theo whitelist (70 `nguon` + 1 `lyDoTach`,
đúng số dòng "rác" phát hiện ở trên).

**Spot-check dữ liệu sau import** (đúng tinh thần mục 6: kiểm DỮ LIỆU, không phải "đối chiếu B10"):
`canbo.vaiTro` phân bố hợp lý (5 ksv/4 dtv/1 can_bo_thong_ke, không còn field `chucVu` cũ); FK
sanity (`bican`→`vuan`, `lichsuChuyenGiaiDoan`→`vuan`) 0 dòng mồ côi; `vuan.daXoa`/`anDiem` toàn bộ
boolean hợp lệ; `bican.bienPhapNganChan` chỉ còn 2 giá trị hợp lệ (`giam`=722, `tai_ngoai`=1530,
hết `tam_giam`). Ghi chú: dòng `vuan` mới nhất trong mock data là 1 vụ tên "VU TEST PLAYWRIGHT XOA
SAU..." — rác còn sót từ 1 lần test Playwright cũ chạy thẳng trên Firestore `qlahs-test` (không
phải lỗi migration, dữ liệu môi trường test vốn không sạch tuyệt đối — chấp nhận được vì đây đúng
là mock/test data, không phải production).

Toàn bộ 5 quyết định transform ở trên (trừ #3 rename `tam_giam`→`giam`, là đổi tên value 1-1 chắc
chắn) đều là **quyết định phù hợp cho MOCK DATA**, KHÔNG áp dụng máy móc lại cho Phase 6 (dữ liệu
`qlahsp2` thật) — Phase 6 phải hỏi lại Dũng ý nghĩa từng giá trị "rác" cụ thể tìm thấy lúc đó trước
khi quyết định map/backfill/bỏ qua, vì đây là dữ liệu án hình sự thật, không được đoán.

## 5. Checklist: rà lại các "tinh chỉnh vì Firebase" — KHÔNG mang nguyên xi sang Supabase

**Theo yêu cầu rõ ràng của Dũng** (2026-07-19): đây không còn là gợi ý tuỳ chọn — Phase 2 phải
CHỦ ĐỘNG rà từng cơ chế dưới đây, quyết định giữ/bỏ/đơn giản hoá cho ĐÚNG với mô hình Supabase, chứ
không lặp lại y nguyên các "tinh chỉnh" vốn sinh ra chỉ để né chi phí đọc/listener của Firestore.
Toàn bộ danh sách dưới đây lấy từ lịch sử thật đã ghi trong `CLAUDE.md` (các mục "Tối ưu
Firestore..."), không suy đoán. Với MỖI mục, việc cần làm ở Phase 2 là: đọc lại code hiện tại,
quyết định 1 trong 3 hướng (**bỏ hẳn** quay về cách đơn giản/trực tiếp nhất; **giữ nguyên** nếu vẫn
có lý do chính đáng KHÁC ngoài chi phí Firestore, VD trải nghiệm người dùng; **đơn giản hoá** giữ
lại lợi ích cốt lõi nhưng bỏ phần phức tạp thừa) — rồi TEST LẠI đúng kịch bản Playwright tương ứng
đã có sẵn cho từng tính năng đó trước khi coi là xong.

- [x] **`firestoreCacheRegistry`/`useFirestoreCollectionCache`** — **ĐÃ BỎ HẲN** registry toàn cục
      (ref-count + grace-period 3 phút). `useFirestoreCollectionCache`/`useFirestoreCacheLoaded`
      giữ NGUYÊN chữ ký hàm `(cacheKey, queryFn)` → `data`/`loaded` (13 call site KHÔNG cần sửa gì)
      nhưng bên trong giờ mỗi hook instance tự subscribe `onSnapshot` riêng qua shim (Supabase
      Realtime) thay vì tra registry chia sẻ. Đánh đổi CHẤP NHẬN ĐƯỢC: vài nơi 2 hook cùng cacheKey
      (VD `ModalXacNhanKy`'s `danhSachKy`+`dataDaVe`) giờ mở 2 kết nối Realtime thay vì chia sẻ 1 —
      không còn đáng lo dưới mô hình giá Supabase.
- [x] **Sentinel `meta/vuAnMoiNhat`** + `dsDangGiaiQuyetRegistry`/`useDanhSachDangGiaiQuyet` — **ĐÃ
      BỎ HẲN** toàn bộ cơ chế (registry, sentinel document, patch cục bộ tay ở 3 nơi). Bảng `meta`
      **đã XOÁ khỏi schema** (không còn code nào đọc/ghi — xem `schema.sql` ghi chú 5, lịch sử đủ
      3 giai đoạn: dự tính không tạo → tạo tạm lúc viết shim → xoá hẳn ở đây). `useDanhSachDangGiaiQuyet()`
      giữ NGUYÊN chữ ký `[ds, dangTai]` (2 call site không cần sửa) nhưng subscribe Realtime THẲNG
      trên `"vuan"` lọc `trangThai='dang_giai_quyet'`. **Lợi ích PHỤ vượt quá kỳ vọng ban đầu**: bản
      sentinel cũ CHỈ báo được vụ MỚI TẠO (mọi thay đổi khác — xoá mềm, khôi phục, hoàn thành... —
      phải patch tay riêng từng nơi, dễ sót); bản Realtime mới tự phản ánh MỌI thay đổi từ BẤT KỲ
      nguồn nào (không chỉ thao tác của chính người dùng đang xem) mà không cần patch tay ở đâu cả.
      **Đã kiểm chứng riêng bằng Playwright thật** (3 assertion mới, `test_sup_realtime_list.js`):
      tạo 1 vụ THẲNG qua `db.collection("vuan").doc().set()` (không qua nút "Thêm vụ án") → UI đang
      mở sẵn (không remount) tự hiện vụ đó; đánh dấu `daXoa=true` THẲNG qua DB (mô phỏng "nguồn
      khác") → UI tự ẩn vụ đó ngay — đúng chứng minh lợi ích PHỤ nêu trên là có thật, không phải suy
      đoán. Chạy lại toàn bộ 17+4 assertion cũ (`test_sup_shim.js`/`test_sup_ui_flow.js`) sau khi
      xoá 2 cơ chế này — vẫn PASS 100%, không có gì bị phá vỡ.
- [x] **Cache lạnh IndexedDB cho "Án đã giải quyết"** (`dongBoColdCacheVuAnDaGiaiQuyet`, đồng bộ
      delta qua `ngayCapNhat > lastSync`, không dùng `onSnapshot`) — **ĐÃ RÀ, QUYẾT ĐỊNH GIỮ
      NGUYÊN**. Đối chiếu lại với bộ nhớ dài hạn `toi-uu-firestore-effectiveness` (quyết định đã
      thống nhất TRƯỚC ĐÓ với Dũng, không phải suy đoán mới): lý do chấp nhận dữ liệu cũ ở đây
      KHÔNG THUẦN vì chi phí Firestore — có cả lý do sản phẩm thật ("hệ thống ít user, chủ yếu dùng
      để xem/trích xuất, ưu tiên tiết kiệm đọc hơn độ mới tức thời", và ý tưởng thêm timer đồng bộ
      định kỳ đã CHỦ ĐỘNG bị bác bỏ trước đây cùng lý do này — xem bộ nhớ đó). Phần lý do sản phẩm
      vẫn đúng bất kể backend nào — vụ đã giải quyết gần như bất biến, không cần realtime cho use
      case "xem/trích xuất". **Giữ nguyên cơ chế cache lạnh + đồng bộ delta 1 lần lúc mount**,
      không đổi sang Realtime subscription.
- [x] **Cursor pagination "đóng băng trang đầu sau khi bấm Tải thêm"** (tab "Tất cả" của Danh sách
      vụ án) — **ĐÃ RÀ, QUYẾT ĐỊNH GIỮ NGUYÊN** (không phải bỏ qua — đã đánh giá kỹ, không phải
      "chưa làm"). Lý do ban đầu ghi trong checklist ("chỉ để né phí") **không chính xác đầy đủ**:
      đọc lại kỹ code xác nhận việc "đóng băng" tồn tại để tránh 1 vấn đề TÍNH ĐÚNG ĐẮN thật —
      nếu trang 1 vẫn live TRONG LÚC đã phân trang bằng cursor (`startAfter`), bất kỳ thay đổi nào
      trên trang 1 sẽ làm listener bắn lại, ghi đè `cursorRef` về đúng ranh giới trang 1, khiến
      "Tải thêm" kế tiếp coi như không có gì mới (chính code gốc đã phải thêm `dangPhanTrangRef`
      để phòng ngừa 1 dạng race của đúng vấn đề này). Đây là hệ quả của việc KẾT HỢP live-query với
      cursor pagination — tồn tại tương tự dưới BẤT KỲ backend nào hỗ trợ Realtime (Supabase không
      miễn nhiễm), không phải đặc thù chi phí Firestore. Bỏ đóng băng để "khôi phục live" sẽ tái
      lập đúng lớp race này, không mang lại giá trị tương xứng với rủi ro — tab "Tất cả" cũng không
      phải màn hình chính (mặc định là "Đang giải quyết", đã live hoàn toàn qua mục ngay trên).
      **Giữ nguyên hành vi đóng băng**, không sửa gì thêm ở đây.
- [x] **`fetchWithTtlCache`** (TTL cache 1 lần cho `NhapVuModal` tìm vụ đích) — **ĐÃ RÀ, QUYẾT ĐỊNH
      GIỮ NGUYÊN**. Đây là hộp thoại "tìm vụ đích để nhập vào" — mở ra, gõ tìm, chọn, đóng lại;
      không có nhu cầu thấy thay đổi realtime của người khác TRONG lúc đang tìm (phiên thao tác
      ngắn, việc nhập vụ là hành động 1 người thực hiện tại 1 thời điểm). Giữ nguyên.
- [x] **Loạt quyết định "hot data không cần live" khác** (`BangBiCanCon`, `BangExcelModule`, cột Kỳ
      của `DanhSachPanel`) — **ĐÃ RÀ TỪNG CÁI RIÊNG**, quyết định GIỮ NGUYÊN cho cả 3, lý do khác
      nhau cho từng nhóm:
      - `BangBiCanCon`/`BangExcelModule` (Cài đặt → Bảng dữ liệu Excel): comment trong chính code
        đã ghi rõ "công cụ sửa hàng loạt cho 1 người thao tác, không phải màn hình xem chung" —
        lý do sản phẩm, độc lập chi phí backend. Restore live còn có thể PHẢN TÁC DỤNG: refetch
        realtime giữa lúc đang gõ vào 1 ô có thể xoá mất input chưa lưu của chính người dùng.
      - Cột Kỳ của `DanhSachPanel` (màn hình mặc định, nhiều người xem nhất — ứng viên "loại sau"
        rõ nhất trong gợi ý ban đầu của checklist): rà kỹ hơn phát hiện lý do KHÔNG chỉ chi phí —
        Supabase Realtime (`postgres_changes`) chỉ hỗ trợ filter dạng `cột=eq.giá_trị` đơn giản,
        KHÔNG hỗ trợ `in` — nên `onSnapshot` của shim cho query `where("maVuAn","in",[500 id])` sẽ
        phải subscribe KHÔNG LỌC (mọi thay đổi trên `lichsuChuyenGiaiDoan` — bảng ghi nhiều nhất hệ
        thống, theo chính mô tả trong code) rồi refetch lại NGUYÊN batch 500 vụ mỗi lần bất kỳ ai
        trong hệ thống ghi BẤT KỲ sự kiện nào — gây refetch/render nhiễu liên tục trên đúng màn hình
        đông người xem nhất, phản tác dụng ngược với mục tiêu "cải thiện UX". Đây là giới hạn thật
        của Supabase Realtime (filter chỉ hỗ trợ đơn giản), không phải lười rà. **Giữ nguyên cả 3**,
        không sửa code.
- [x] **Kỹ thuật né composite index thủ công** — rà toàn bộ codebase (grep `composite index`), tìm
      đúng **2 chỗ thật sự cần sửa** (1 chỗ khác ở `XoaHinhThucGiaiQuyetModal` tái dùng dữ liệu ĐÃ
      TẢI SẴN thay vì query riêng — đây là thực hành tốt độc lập với backend, không phải "né index",
      giữ nguyên):
      1. `GiaoNhanHoSoModule`'s `dsQuet` — trước đây `where("phienGiaoNhanId","==",...)` KHÔNG kèm
         `orderBy` (né composite index Firestore), tự `.sort()` lại phía client. Đổi sang
         `.orderBy("thoiDiemGhi","desc")` server-side, bỏ dòng `.sort()` thủ công.
      2. `fetchKyKhoiToBiCan` — trước đây `where("maVuAn","in",...)` rồi lọc `loaiSuKien` phía
         CLIENT (né composite index `maVuAn+loaiSuKien`). Đổi sang lọc thẳng trong query
         (`.where("loaiSuKien","==","khoi_to_bican")`) — Postgres không cần index riêng mới CHẠY
         ĐÚNG (chỉ có thể không dùng được index cho phần đó, vẫn ra kết quả đúng), giảm số dòng
         phải tải về so với tải nguyên lịch sử rồi lọc lại.
      **Đã kiểm chứng bằng Playwright thật** (5 assertion mới, `test_sup_index_avoid.js`, có tạo
      dữ liệu FK thật — phát hiện thêm ràng buộc `phienGiaoNhanId`/`maBiCan` là FK thật cần dữ liệu
      hợp lệ, khác Firestore không kiểm tra tham chiếu): 3 sự kiện cùng phiên trả đúng đủ + đúng thứ
      tự `orderBy` server-side; lọc `loaiSuKien` trong query đúng, không lẫn loại sự kiện khác.

**Đã dọn xong (mục kỹ thuật, không phải "chưa làm")**: giới hạn 30-item của `where(..., "in", ...)`
— đã xoá hết `chiaNhoDsId`/chia lô 30 trong `qlahs-sup.html` (7 call site: `batchLayBiCanList`,
`XoaVuAnModal` kiểm tra vụ tách, `DanhSachPanel` (2 nơi: tìm bị can + cột Kỳ), `vuAnTuLogDocs`,
`fetchBiCanTheoVuIds`, `fetchKyKhoiToBiCan`), đổi thành 1 query `"in"` duy nhất mỗi nơi — Postgres
`ANY()` không giới hạn 30 như Firestore. **Đã kiểm chứng bằng Playwright thật** (mảng 45 phần tử,
vượt hẳn giới hạn 30 cũ) xác nhận query trả về đúng đủ 45/45 kết quả. `db.enablePersistence`
(offline persistence) vẫn để riêng — đây là tính năng THẬT (chống mất mạng tạm thời), không phải
né chi phí, xử lý ở Phase 5 (mục 7 của tài liệu này) như đã ghi, không thuộc checklist này.

**Bug thật tìm được + sửa qua chính quá trình dọn 30-item chunking**: `batch.delete()` trong shim
gốc xử lý song song (`Promise.all`) KHÔNG phân biệt bảng nào, trong khi `batch.set()` (insert) đã
được sửa đúng thứ tự phụ thuộc từ trước (Phase 2) — dẫn tới lỗi FK 23503 CÙNG HỌ khi 1 batch xoá
nhiều bảng có quan hệ cha-con cùng lúc (VD script dọn dữ liệu test tự xoá `vuan`+`bican`+
`lichsuChuyenGiaiDoan` trong 1 batch — xoá `vuan` có thể chạy trước khi 2 bảng con xoá xong). Đã
sửa: `commit()` giờ xoá theo thứ tự NGƯỢC LẠI `_TABLE_INSERT_ORDER` (con trước, cha sau), gộp theo
bảng thành 1 lượt `.in('id', ids)` mỗi bảng thay vì N request riêng lẻ (nhanh hơn cả bản cũ).

## 6. Kế hoạch export/import dữ liệu thật

**Cập nhật phạm vi (xem mục 4c)**: hiện chỉ có 1 project Supabase (`eutatszoaseixchvjbtg`), dự định
nạp dữ liệu MOCK kéo từ Firestore `qlahs-test` trước (không phải dữ liệu thật `qlahsp2`) để phát
triển/kiểm thử shim, rồi **reset lại** project này trước khi thật sự cần dữ liệu production —
nghĩa là bước import "dữ liệu thật `qlahsp2`" chỉ thực hiện 1 LẦN DUY NHẤT, ngay trước khi cắt hẳn
sang Supabase (cuối Phase 6), không lặp lại nhiều vòng test như dự tính ban đầu.

1. **Export**: script đọc toàn bộ 7 collection nghiệp vụ (không cần export `boDemMaVu`/`meta`) →
   dump JSON, 1 file/collection. Làm trên `qlahs-test` trước (làm mock data cho project Supabase
   hiện có).
2. **Transform**: chuẩn hoá kiểu dữ liệu (Timestamp → ISO string cho `timestamptz`), cộng các phép
   chuyển đổi cụ thể phát hiện ở mục 4b (gộp `blhsNam`→`namBLHS`, loại bỏ 4 giá trị `loaiSuKien`
   dead nếu gặp, không cần tách mảng `toiDanh`/`dieuLuatBC` vì schema giữ nguyên dạng cột mảng).
3. **Import**: dùng **Session pooler** (đã xác nhận hoạt động ở mục 4c — Direct connection KHÔNG
   dùng được từ môi trường thực thi hiện tại do chỉ hỗ trợ IPv6) — `psql`/COPY hoặc script Node
   dùng driver `pg`, nhanh hơn nhiều so với qua REST cho khối lượng ~1400 vụ + ~2250 bị can + hàng
   nghìn dòng log.
4. **Đối chiếu**: so số dòng theo từng bảng (đúng những gì cần kiểm — export/import có thể sai
   lệch dữ liệu, VD field mảng/ngày tháng convert sai). **KHÔNG cần** so sánh "B10 tính ra có khớp
   giữa Firestore cũ và Postgres mới không" như 1 bước riêng — `tinhBieu10`/`tinhBaoCaoKy` là ĐÚNG
   1 đoạn code JS không đổi gì khi qua shim (chỉ đổi tầng `db` bên dưới), không có chỗ nào để công
   thức tính RA KHÁC ĐI giữa 2 hệ thống. Nếu B10 sai sau migrate thì chỉ có thể do (a) dữ liệu
   export/import sai lệch, hoặc (b) shim trả sai dữ liệu so với Firestore — cả 2 đều là lỗi ở TẦNG
   DỮ LIỆU, không phải lỗi B10. Chạy thử B10 sau khi nạp mock data vẫn có giá trị làm 1 phép thử
   tổng hợp (chạm gần như mọi field/mọi collection cùng lúc, dễ lộ lỗi map dữ liệu hơn test đơn lẻ
   từng bảng) — nhưng đúng bản chất là "kiểm tra dữ liệu qua 1 phép tính phức tạp", không phải
   "đối chiếu logic B10".
5. **Reset trước khi lên thật**: trước khi import dữ liệu `qlahsp2` thật ở Phase 6, xoá sạch dữ
   liệu mock đã nạp ở bước trên (giữ nguyên schema/RLS/RPC, chỉ xoá rows) — đúng ý định "reset lại
   khi hoàn thiện" Dũng đã nêu.

## 7. Lộ trình theo giai đoạn

- [x] **Phase 0**: tạo nhánh `supabase-migration`, viết tài liệu kế hoạch này. Chưa đụng code ứng
      dụng.
- [x] **Phase 1**: `supabase/schema.sql` + `rls.sql` + `functions.sql` đã viết, ÁP DỤNG THÀNH CÔNG
      lên project Supabase thật (`eutatszoaseixchvjbtg`) và KIỂM CHỨNG chức năng đầy đủ (14
      assertion RPC + RLS xác nhận qua REST API thật) — xem mục 4c. Không còn việc "chưa kiểm
      chứng" nào ở bước schema nữa.
- [x] **Phase 2**: lớp shim ĐÃ VIẾT + KIỂM CHỨNG ĐẦY ĐỦ bằng dữ liệu thật (mục 4d), VÀ checklist
      mục 5 ĐÃ RÀ XONG 7/7 mục (xem đầu mục 5) — Phase 2 coi như HOÀN TOÀN xong. Tóm tắt: CDN
      Firebase (3 script) đổi sang 1 script `@supabase/supabase-js`, khối cấu hình cũ thay bằng lớp
      shim đầy đủ (`db`/`auth` giả lập, `firebase.firestore.FieldValue/FieldPath` giữ nguyên API
      cho ~35 chỗ gọi cũ không cần sửa), 4 vị trí `db.runTransaction` sửa tay gọi `.rpc(...)`.
      Checklist mục 5: 2 mục bỏ hẳn, 1 mục sửa 1 phần, 4 mục rà kỹ và giữ nguyên có lý do rõ ràng.
- [ ] **Phase 3**: chuyển Auth sang Supabase Auth — tài khoản Firebase Auth hiện có phải tạo lại
      thủ công trên Supabase (không tự động chuyển mật khẩu giữa 2 hệ thống được).
- [x] **Phase 4**: export dữ liệu thật từ `qlahs-test` (Firestore, 9354 document/7 collection) →
      import làm MOCK DATA vào project Supabase hiện có — THÀNH CÔNG 100%, đúng khớp số dòng, 5
      lỗi CHECK constraint thật gặp phải + đã sửa (xem mục 4e chi tiết đầy đủ). Chưa kiểm thử qua
      UI `qlahs-sup.html` với dữ liệu này — việc tiếp theo.
- [ ] **Phase 5**: kiểm thử toàn diện trên project Supabase hiện có (đủ bộ Playwright hồi quy hiện
      có + kịch bản mới cho Realtime/RPC), quyết định hướng xử lý khoảng trống offline persistence.
- [ ] **Phase 6**: **reset project Supabase** (xoá dữ liệu mock, giữ schema/RLS/RPC) → export/import
      dữ liệu thật `qlahsp2`, đối chiếu số liệu kỹ, cắt sang production. Giữ Firestore ở chế độ
      đọc-only 1 thời gian làm lưới an toàn trước khi ngừng hẳn.

## 8. Trạng thái hiện tại

**Phase 1 xong hoàn toàn** (schema/RLS/RPC áp dụng + kiểm chứng thật, mục 4c). **Phase 2 (lớp shim)
đã viết xong + kiểm chứng đầy đủ bằng dữ liệu thật** (17 assertion, gồm 1 luồng UI thật trọn vẹn
"Thêm vụ án" → RPC sinh mã → batch ghi đúng thứ tự phụ thuộc → đọc lại đúng, xem mục 4d) — 1 bug
FK-ordering thật đã tìm ra và sửa qua chính quá trình test này. `qlahs-sup.html` hiện chạy được
đầy đủ trên nền Supabase (KHÔNG còn phụ thuộc Firebase gì, kể cả CDN script). Toàn bộ dữ liệu test
đã dọn sạch — project Supabase đang ở trạng thái sạch (0 dòng mọi bảng), sẵn sàng nạp mock data.

**Phase 2 ĐÃ HOÀN TẤT** (shim + checklist mục 5). Bảng `meta` đã xoá khỏi schema thật (DROP TABLE
đã chạy trên project Supabase).

**Phase 4 ĐÃ HOÀN TẤT** (export/import mock data từ `qlahs-test`, xem mục 4e) — project Supabase
hiện có đầy đủ 7 bảng nghiệp vụ với dữ liệu thật (đã transform), sẵn sàng kiểm thử UI.

**Việc tiếp theo** (thứ tự khuyến nghị):
1. Kiểm thử qua `qlahs-sup.html` với dữ liệu mock đã nạp — đăng nhập, duyệt Danh sách vụ án, mở
   panel chi tiết vài vụ, thử Kỳ báo cáo/Xuất Excel báo cáo tháng (Biểu B10) trên ít nhất 1 kỳ, thử
   Giao nhận hồ sơ — trọng tâm là XÁC NHẬN DỮ LIỆU HIỂN THỊ ĐÚNG qua UI thật (không phải "so B10
   với Firestore" — xem lý do ở mục 6, B10 dùng chung 100% code nên không có chỗ để tính khác đi).
2. Chuyển Auth sang Supabase Auth thật cho toàn bộ tài khoản cán bộ (Phase 3 — hiện chỉ có đúng 1
   tài khoản test `admintest@local.com` phục vụ phát triển/kiểm thử, chưa phải danh sách thật).
