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

## 4. Thiết kế schema Postgres (bản nháp — chốt chi tiết ở Phase 1)

Nguyên tắc: giữ tên bảng/field tiếng Việt gần nhất có thể với Firestore hiện tại (giảm rủi ro dịch
sai khi đối chiếu với `CLAUDE.md`/logic nghiệp vụ đã tài liệu hoá rất kỹ qua nhiều phiên).

| Bảng Postgres | Nguồn Firestore | Ghi chú |
|---|---|---|
| `vuan` | `vuan` | PK `id` TEXT = mã vụ án hiện tại (giữ nguyên business key, không đổi UUID). |
| `bican` | `bican` | PK UUID tự sinh, FK `ma_vu_an → vuan.id`. Cân nhắc tách `toiDanh[]`/`dieuLuatBC[]` (2 mảng song song theo index) thành bảng con `bican_toi_danh(bican_id, thu_tu, ten_toi_danh, dieu_luat)` — quyết định cụ thể ở Phase 1 sau khi rà lại toàn bộ chỗ đọc/ghi 2 field này (`chuanHoaTenToiDanh`/`layMaDieuLuatBiCan`, xem CLAUDE.md audit "chưa xác định điều luật"). |
| `lichsu_chuyen_giai_doan` | `lichsuChuyenGiaiDoan` | PK UUID, FK `ma_vu_an`. Append-only — cân nhắc RPC riêng cho "Sửa kỳ" thay vì UPDATE trực tiếp qua RLS, giữ tinh thần append-only chặt hơn hiện tại. |
| `ky_bao_cao` | `kybaocao` | Map thẳng 1-1. |
| `can_bo` | `canbo` | Map thẳng 1-1. |
| `danh_muc_toi_danh` | `danhMucToiDanh` | Map thẳng 1-1. |
| `phien_giao_nhan` | `phienGiaoNhan` | Map thẳng 1-1. |
| *(không cần bảng riêng)* | `boDemMaVu` | Thay bằng Postgres `sequence` theo YYMM, hoặc 1 bảng counter tối giản + RPC atomic (`INSERT ... ON CONFLICT DO UPDATE RETURNING`). |
| *(không cần bảng riêng)* | `meta/vuAnMoiNhat` | Xem mục 5 — cân nhắc bỏ hẳn cơ chế sentinel này. |

**RLS**: mirror đúng rule hiện tại — `USING (auth.role() = 'authenticated')` cho mọi bảng, không
phân quyền field/row (giữ đúng mô hình bảo mật hiện tại, không mở rộng phạm vi).

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
2. **Transform**: chuẩn hoá kiểu dữ liệu (Timestamp → ISO string cho `timestamptz`; nếu chọn tách
   bảng con `bican_toi_danh` thì chuyển 2 mảng song song thành các hàng con).
3. **Import**: dùng kết nối Postgres trực tiếp Supabase cấp (nhanh hơn nhiều so với qua REST cho
   khối lượng ~1400 vụ + ~2250 bị can + hàng nghìn dòng log) — `psql`/COPY hoặc script Node dùng
   driver `pg`.
4. **Đối chiếu**: so số dòng theo từng bảng, VÀ chạy lại các phép kiểm tra nghiệp vụ đã có (VD
   tổng số liệu Biểu B10 của 1 kỳ đã chốt phải khớp giữa Firestore cũ và Postgres mới).
5. **Thứ tự bắt buộc**: `qlahs-test` xong xuôi + kiểm chứng kỹ → mới làm `qlahsp2` — đúng văn hoá
   "test trước, prod sau" đã áp dụng nhất quán trong toàn bộ dự án này.

## 7. Lộ trình theo giai đoạn

- [x] **Phase 0**: tạo nhánh `supabase-migration`, viết tài liệu kế hoạch này. Chưa đụng code ứng
      dụng, chưa tạo file SQL thực thi.
- [ ] **Phase 1**: Dũng tạo 2 project Supabase thật (1 ứng với `qlahs-test`, 1 ứng với `qlahsp2` —
      cần tài khoản/thao tác thủ công, Claude không tự tạo được). Viết schema DDL + RLS + 4 hàm
      RPC (cho 4 transaction ở mục 3), áp dụng lên project test trước.
- [ ] **Phase 2**: viết lớp shim (mục 3). Tạo 1 file thử nghiệm riêng (không đụng
      `qlva.html`/`qlva-dev.html` đang chạy thật) để phát triển/kiểm chứng shim độc lập. Đánh giá
      cơ hội đơn giản hoá ở mục 5.
- [ ] **Phase 3**: chuyển Auth sang Supabase Auth — tài khoản Firebase Auth hiện có phải tạo lại
      thủ công trên Supabase (không tự động chuyển mật khẩu giữa 2 hệ thống được).
- [ ] **Phase 4**: export/import dữ liệu thật theo mục 6, `qlahs-test` trước.
- [ ] **Phase 5**: kiểm thử toàn diện trên project test (đủ bộ Playwright hồi quy hiện có + kịch
      bản mới cho Realtime/RPC), quyết định hướng xử lý khoảng trống offline persistence.
- [ ] **Phase 6**: export/import `qlahsp2` (dry-run trước, đối chiếu số liệu kỹ), cắt sang
      production. Giữ Firestore ở chế độ đọc-only 1 thời gian làm lưới an toàn trước khi ngừng hẳn.

## 8. Trạng thái hiện tại

Đang ở **Phase 0** — nhánh đã tạo, tài liệu này vừa viết xong. Chưa có project Supabase nào được
tạo, chưa có dòng code migration nào. Việc tiếp theo (Phase 1) cần Dũng tạo project Supabase trước
khi có thể viết schema/RLS/RPC thật.
