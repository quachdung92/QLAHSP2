# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ĐANG LÀM DỞ (nhánh `bieu-10-audit`, tạm dừng 2026-07-13 — đọc mục này trước khi tiếp tục)

**Đã xong và đã commit/push trên nhánh này** (kế thừa từ `import-excel-fix`):
- Import Excel: bỏ bắt buộc Mã vụ/Tên vụ, tự ước tính ngày quyết định thiếu, Án đã giải quyết đổi
  bố cục 2 cột — xem "Tiến độ đã code" bên dưới, mục Import Excel/Án đã giải quyết.
- Fix bug `tinhLaiBaoCaoLuu` ghi đè `tonCuoiKyTheoTD`/`tonCuoiBiCan` bằng dữ liệu LIVE thay vì giữ
  cố định — xem mục "Kỳ báo cáo" bên dưới, đoạn "Bug đã sửa (2026-07-13) — B10 hiện tồn kỳ trước
  = tồn kỳ này".
- Công cụ `TaiTaoTonTheoTDTool` ("Sửa lại tồn cuối kỳ theo tội danh (Biểu B10)" trong Cài đặt →
  Import Excel) — tính lại đúng `tonCuoiKyTheoTD` cho TẤT CẢ kỳ đã chốt theo thứ tự thời gian từ
  log, sửa dữ liệu đã bị bug trên ghi sai trước đó. Đã kiểm chứng phần toán tích luỹ bằng test độc
  lập (4 kịch bản), CHƯA kiểm chứng bằng dữ liệu Firestore thật — **việc cần làm tiếp theo #1: mở
  `qlva-dev.html`, bấm nút này, xem kỹ log/cảnh báo trả về, đối chiếu vài kỳ bằng tay trước khi
  chạy trên `qlva.html` (production)**.
- Thêm dropdown lọc riêng theo KSV vào Án đã giải quyết + Giao nhận hồ sơ (tìm thủ công).

**Đã audit xong (agent nghiên cứu, KHÔNG phải code đã sửa) — 2 bug CONFIRMED cần sửa tiếp, việc
cần làm tiếp theo #2 và #3:**

1. **Bug nhập liệu (import) — mức độ ảnh hưởng CAO**: `ImportExcelModule`'s bị can write (hàm
   `ghiVaoCoSoDuLieu`, đoạn tạo doc `bican`) đang hardcode `loaiKhoiTo: "khoi_to_moi"` — đây là 1
   giá trị KHÔNG HỢP LỆ (chỉ có `"ban_dau"`/`"bo_sung"` là hợp lệ, xem hàm `tinhLoaiKhoiTo`/
   `tinhLoaiKhoiToTheoNgay`, có vẻ bị nhầm với field `nguon` có giá trị `"an_khoi_to_moi"`). Hậu
   quả: Biểu B10 lọc bị can theo đúng `=== "ban_dau"` mới tính vào khối nhân khẩu học (tuổi/trình
   độ/dân tộc/đảng viên/quốc tịch/tái phạm, cột C7-C24 cho Điều tra và tương tự Truy tố/Xét xử) —
   MỌI bị can nhập qua Import Excel bị loại khỏi khối này một cách ÂM THẦM (các chỗ khác trong app
   hiển thị bị can import vẫn đúng là "Ban đầu" vì dùng check ngược `=== "bo_sung" ? ... : "Ban
   đầu"`, chỉ B10 dùng check chặt `=== "ban_dau"` mới lộ ra sai khác). Đây gần như chắc chắn là
   nguyên nhân chính khiến B10 "không khớp báo cáo khác" mà người dùng thấy — **sửa: đổi
   `loaiKhoiTo: "khoi_to_moi"` thành gọi đúng `tinhLoaiKhoiTo`/`tinhLoaiKhoiToTheoNgay`, hoặc gán
   cứng `"ban_dau"` nếu Excel gốc không phân biệt được ban đầu/bổ sung**.
2. **Bug tính báo cáo — mức độ ảnh hưởng TRUNG BÌNH/CAO**: `tinhBieu10` hoàn toàn KHÔNG xử lý hình
   thức hoàn thành `an_huy` (án huỷ) — không trừ khỏi "Tổng thụ lý" (C3/C33/C60 chỉ trừ `nhapVu` +
   `hoanThanh.chuyen_di`, thiếu `an_huy`), và KHÔNG có cột riêng nào cho án huỷ ở cả 3 khối giai
   đoạn (khác với đình chỉ/tạm đình chỉ/đã xét xử đều có cột riêng). Trong khi "Tổng hợp báo cáo"
   và sheet "TK tội danh" đều tính đủ cả 5 hình thức hoàn thành gồm án huỷ. Vụ án huỷ vẫn hiện
   trên các báo cáo khác nhưng "biến mất" trên B10 — **sửa: thêm cột/logic án huỷ vào `tinhBieu10`,
   tương tự cách đình chỉ/tạm đình chỉ đã có**.
3. (Ưu tiên thấp hơn, chưa xác nhận bằng dữ liệu thật) Sheet "TK tội danh" nhóm theo
   `bc.toiDanh[0]` thô (không chuẩn hoá qua `getDL()`/`normDL()`/alias BLHS 2015→2025 như B10) —
   2 sheet trong CÙNG 1 file Excel có thể nhóm tội danh khác nhau, khiến người xem thấy số liệu
   "không khớp" giữa 2 sheet dù cả 2 đều đúng theo cách nhóm riêng của nó. Cân nhắc thống nhất.

Chi tiết đầy đủ (số dòng code, trích code) nằm trong báo cáo của agent audit đã chạy trong phiên
làm việc trước — nếu cần lại, hỏi lại y hệt câu hỏi audit cho agent `general-purpose` (đã audit
xong `tinhBieu10`, `tinhBaoCaoKyTuLog`, `ImportExcelModule`, các sheet Excel liên quan).

**Việc cần làm tiếp theo (theo thứ tự đề xuất):** (1) kiểm chứng `TaiTaoTonTheoTDTool` bằng dữ
liệu thật trên `qlva-dev.html`; (2) sửa bug #1 (loaiKhoiTo import); (3) sửa bug #2 (án huỷ thiếu
trong B10); (4) chạy lại `TaiTaoTonTheoTDTool` sau khi sửa xong (vì sửa bug #2 có thể đổi số đã
giải quyết theo tội danh của các kỳ cũ); (5) cân nhắc bug #3.

# QLVA — Quản lý vụ án Phòng 2, VKSND Hà Nội

## Bối cảnh

Ứng dụng quản lý vụ án hình sự thay thế file Excel thủ công (`Số_liệu_án_năm_2026...xlsx`).
Yêu cầu bắt buộc: **1 file HTML duy nhất**, mở thẳng bằng trình duyệt, không cần cài đặt,
nhiều người dùng cùng lúc (đồng bộ qua Firebase Firestore).

File chính: `qlva.html` (React 18 UMD + Babel standalone qua CDN, Tailwind CDN, Firebase compat SDK,
SheetJS để đọc/ghi Excel — tất cả nhúng trong 1 file, không có bước build).

Firebase project: `qlahsp2` (config đã có sẵn trong `qlva.html`). Firestore + Authentication
(Email/Password) đã được bật.

## Schema Firestore — xem chi tiết đầy đủ trong `schema_csdl_he_thong_quan_ly_an_v2.md`

Tóm tắt nhanh 7 collection: `vuan`, `bican`, `lichsuChuyenGiaiDoan` (log sự kiện, append-only —
nguồn sự thật duy nhất để đếm số liệu theo kỳ), `kybaocao`, `canbo`, `boDemMaVu` (bộ đếm sinh mã),
`phienGiaoNhan` (phiên giao/nhận hồ sơ — xem module Giao nhận hồ sơ bên dưới).

## Nguyên tắc thiết kế cốt lõi (đã thống nhất qua nhiều vòng, KHÔNG tự ý đổi)

1. **Log là nguồn sự thật duy nhất** để tính số liệu theo kỳ — không bao giờ suy ra số liệu
   từ trạng thái hiện tại (`coQuanThuLy`/`trangThai`) của `vuan`.
2. **Kỳ báo cáo do cán bộ thống kê tự quyết định** ngày chốt (không cố định 15 hay 16, có tháng
   chốt 26, có tháng chốt 30) — lưu trong collection `kybaocao`, không hardcode ngày.
3. **Mỗi thao tác nghiệp vụ đều hỏi "tính vào kỳ nào"** qua 1 modal dùng chung (mặc định = kỳ
   đang mở, sửa được sau, có audit trail `lichSuSuaKy`).
4. **Giai đoạn** chỉ 3 giá trị tuần tự Điều tra → Truy tố → Xét xử, chuyển lùi (trả hồ sơ) chỉ
   được đúng 1 bước mỗi lần, mỗi lần trả là 1 sự kiện log riêng.
5. **Tạm đình chỉ / Đình chỉ không tồn tại độc lập theo bị can.** Nếu chỉ áp dụng cho 1 phần bị
   can của vụ nhiều bị can → hệ thống **tự động tách vụ trước**, rồi áp trạng thái lên vụ mới
   tách. Chọn toàn bộ bị can thì áp thẳng lên vụ hiện tại, không tách.
   **Tách vụ án nói chung** (thủ công hoặc tự động ở trên) áp dụng được cho MỌI vụ đang giải
   quyết, kể cả 0 hoặc 1 bị can — vì 1 vụ có thể có nhiều hành vi cần tách xử lý độc lập dù chỉ
   1 bị can (hoặc hành vi chưa xác định được đối tượng). Khi tách, mỗi bị can chọn 1 trong 3:
   ở lại vụ gốc / chuyển hẳn sang vụ mới / **ở cả 2 vụ** (sao chép, hiếm dùng — cho trường hợp 1
   người có nhiều hành vi, chỉ tách 1 hành vi ra xử lý riêng). Bản sao liên kết với bản gốc qua
   `nhomBiCanId` để **Nhập vụ** sau này nhận ra là cùng 1 người và gộp lại thay vì tạo trùng.
6. **Mã vụ án tự sinh** — 2 loại:
   - Vụ mới: `QLVA_E01.53_{YYMM theo ngày QĐ KTVA}_{SEQ 4 số, reset mỗi tháng}`.
   - Vụ tách ra: kế thừa mã vụ gốc + hậu tố `_{n}` (n = số lần tách từ chính vụ gốc đó, đếm
     riêng qua field `soDemTach`, không dùng bộ đếm tháng). Tách nhiều tầng ra dạng `..._1_1`.
   - `maNganhCap` (mã do ngành cấp) ưu tiên hiển thị nếu có, `maNoiSinh` chỉ hiển thị khi chưa có.
   - Cả 2 loại sinh mã đều dùng Firestore transaction để tránh trùng khi nhiều người tạo cùng lúc.
7. **Tội danh (`toiDanh`) là mảng ở cấp bị can**, phần tử đầu = tội chính (dùng tính thống kê).
   Điều luật cấp vụ án (`dieuLuat`) tự gộp từ toàn bộ bị can nếu đã có bị can, chỉ cho nhập tay
   khi vụ chưa có bị can nào.
8. Mặc định: `gioiTinh = nam`, `danToc = "Kinh"`, `dangVien = "khong"`.
9. **Nhập vụ (`nhap_vu`)** dùng chung cho cả 2 trường hợp: nhập 2 vụ độc lập, và nhập ngược lại
   vụ gốc sau khi 1 vụ đã tách ra rồi được phục hồi.
10. Khi **chốt kỳ báo cáo**, hệ thống tự chụp (snapshot) số dư "Còn" của từng cơ quan
    (Điều tra/Truy tố/Xét xử) vào chính `kybaocao.tonCuoiKy`, để làm "Án cũ" cho kỳ sau — vì đây
    là dữ liệu không tính được từ log của riêng 1 kỳ.

## Tiến độ đã code

- [x] `qlva.html`: đăng nhập Firebase Auth + khung sidebar (nay 7 module, xem `MODULES`) +
      **Import Excel** (đọc sheet "Danh sách án", xem trước, tự nhận diện trùng, ghi Firestore
      bằng batch — xem mục riêng "Import Excel — mẫu 'Danh sách án'" bên dưới, đã thay thế hẳn
      mẫu DSAT/DSBCT cũ) + công cụ dựng lại lịch sử cho dữ liệu import cũ (xem mục riêng bên dưới,
      chỉ còn cần cho dữ liệu import bằng mẫu DSAT/DSBCT trước đây — import bằng mẫu mới tự ghi
      log ngay, không cần công cụ này nữa).
- [x] Module Danh sách & chi tiết vụ án: 2 cột — danh sách là panel CHÍNH (`flex-1`, chiếm phần
      lớn chiều rộng), chi tiết là panel PHỤ cố định `w-[420px]` bên phải (đảo ngược so với thiết
      kế ban đầu theo yêu cầu người dùng). Danh sách có: ô tìm kiếm khớp cả mã vụ/tên vụ/điều
      luật/số QĐ KTVA (`soQdKtva`, thêm 2026-07-13)/tên bị can, **toggle "Đang giải quyết" / "Tất
      cả"** (`chiDangGiaiQuyet`, mặc định
      `true` — thay thế hẳn module "Án tồn theo giai đoạn" cũ đã bị xoá, kết hợp với tab lọc
      giai đoạn/KSV sẵn có là đủ vai trò của module đó), cột **Bị can** (mặc định chỉ hiện bị
      can đầu + link "+N bị can khác" để mở rộng, state `moRongBiCan`), cột **Kỳ mới**/**Kỳ giải
      quyết** (tính qua `tinhKyTheoVuAn` — kỳ mới lấy từ sự kiện `khoi_to_vu`, kỳ giải quyết lấy
      từ `hoan_thanh` GẦN NHẤT vì vụ có thể phục hồi rồi giải quyết lại; vụ tách ra không có "kỳ
      mới" vì không có sự kiện `khoi_to_vu` riêng — đúng, không phải vụ mới thật), cột **Số QĐ
      KTVA**/**Ngày KTVA**, 2 nút thao tác **Chuyển giai đoạn**/**Hoàn thành** hiện trực tiếp
      trên mỗi dòng (không phải menu `⋯` ẩn như trước). **Sắp xếp**: bấm tiêu đề cột để sort
      tăng/giảm (component dùng chung `ThSort`, mũi tên ▲/▼ chỉ chiều) — chỉ áp dụng cho Mã
      vụ/Ngày KTVA/Hạn ĐT (giá trị so sánh rõ ràng); KHÔNG làm sort cho Kỳ mới/Kỳ giải quyết vì
      đó là chuỗi hiển thị "Tháng N/YYYY", sort theo chuỗi sẽ sai thứ tự thời gian (VD "Tháng
      10" < "Tháng 2"). Đầu trang có `ThongKeKyHienTai` — thẻ nhỏ đếm nhanh số vụ mới/đã giải
      quyết trong kỳ đang mở, để tiện theo dõi mà không cần mở riêng module Kỳ báo cáo. Panel
      (2026-07-11) **Bấm vào ô kỳ để sửa ngay tại danh sách** — cột Kỳ mới/Kỳ giải quyết giờ
      bấm được (component `OKy` dùng chung), cộng thêm 2 cột mới **Kỳ vào Truy tố**/**Kỳ chuyển
      Xét xử** (kỳ của sự kiện GẦN NHẤT đưa vụ vào giai đoạn đó — vì đây cũng là mốc tính vào số
      liệu báo cáo kỳ, VD tháng 8 có 3 vụ kết thúc điều tra chuyển Truy tố, tháng 9 có 2 vụ
      chuyển Xét xử; giữ "gần nhất" vì 1 vụ có thể bị trả hồ sơ rồi chuyển giai đoạn lại nhiều
      lần). Bấm vào 1 ô kỳ (nếu vụ đã có sự kiện tương ứng, không phải "—") mở thẳng `SuaKyModal`
      (dùng chung với Nhật ký thao tác, xem mục Module Nhật ký thao tác) để sửa kỳ ngay, không
      cần qua Nhật ký thao tác tìm đúng dòng — tiện hơn cho cán bộ thống kê. Dùng hàm
      `timSuKienKyTheoVuAn` (khác `tinhKyTheoVuAn` cũ vẫn giữ nguyên cho Xuất Excel — hàm cũ trả
      về CHUỖI TÊN kỳ, hàm mới trả về CHÍNH sự kiện log kèm `id` vì `SuaKyModal` cần `id` để biết
      sửa đúng dòng nào). KHÔNG sort được các cột Kỳ này (như đã quyết định trước đây với Kỳ
      mới/Kỳ giải quyết — hiển thị dạng chuỗi "Tháng N/YYYY" nên sort chuỗi sẽ sai thứ tự thời
      gian); ai cần sort theo kỳ thì dùng module Nhật ký thao tác (đã hỗ trợ sort đúng theo thời
      gian thực của kỳ). **Ghi chú "↩ Trả bổ sung"** (2026-07-11) — giai đoạn Điều tra/Truy tố
      còn vào được qua đường **trả hồ sơ** (`tra_ho_so`, không chỉ qua khởi tố mới/chuyển giai
      đoạn tới), và đây vẫn tính vào số liệu báo cáo kỳ y hệt (sheet "DS viện trả DTBS"/"DS toà
      trả DTBS" của Xuất Excel báo cáo tháng), nên: (1) "Kỳ vào Truy tố" GỘP cả sự kiện
      `chuyen_giai_doan` (viện nhận từ điều tra) LẪN `tra_ho_so` có `denGiaiDoan: "truy_to"`
      (toà trả hồ sơ về truy tố) — giữ sự kiện gần nhất trong cả 2 loại; nếu sự kiện thắng là
      `tra_ho_so` thì hiện thêm dòng nhỏ màu vàng "↩ Trả bổ sung" ngay dưới tên kỳ để phân biệt
      với chuyển giai đoạn thông thường; (2) riêng **Điều tra** không có cột "kỳ vào" kiểu này
      (giai đoạn đầu, không có "chuyển giai đoạn tới") nên thêm 1 dòng phụ riêng dưới ô **Kỳ
      mới** — chỉ hiện khi vụ có sự kiện `tra_ho_so` với `denGiaiDoan: "dieu_tra"` (viện trả hồ
      sơ điều tra bổ sung), bấm vào dòng đó cũng mở `SuaKyModal` sửa được. Không đụng tới "Kỳ mới"
      gốc (`khoi_to_vu`) — 2 khái niệm tách biệt, không gộp chung 1 ô.
      **Ẩn/hiện cột (2026-07-11)** — danh sách đã lên 13 cột, nút **"Cột hiển thị"** (component
      `ChonCotHienThi`, popover checkbox, đóng khi click ra ngoài qua 1 backdrop `fixed inset-0`)
      cho ẩn bớt các cột KHÔNG PHẢI định danh chính (Mã vụ/Tên vụ/thao tác luôn hiện, không cho
      ẩn — xem mảng `DS_COT_TUY_CHON`). Lựa chọn lưu vào `localStorage` (khoá `qlva_danhsach_cotAn`)
      nên nhớ giữa các lần mở lại trang, không cần đăng nhập lại mỗi lần chọn.
      Panel chi tiết dùng bảng key-value **1 cột/hàng** (không phải 2 cột/hàng như thiết kế cũ) để
      không bị tràn chữ với bề rộng 420px, có gridline/zebra-row/badge màu theo giai đoạn-trạng
      thái — xem `MAU_GIAI_DOAN`/`MAU_TRANG_THAI`/`Badge`. Form **Thêm vụ án** (vụ + nhiều bị can
      trong 1 form, tội danh nhiều dòng Tội chính/Bổ sung), sinh `maNoiSinh` tự động qua
      transaction, tự tính `dieuLuat`/`loaiKhoiTo`. Nút **Sửa thông tin vụ án** và **Sửa** trên
      từng dòng bị can (sửa lỗi nhập liệu thường — không ghi log, không hỏi kỳ, khác với các
      hành động nghiệp vụ). KSV/ĐTV vẫn là ô nhập tay nhưng có gợi ý (`<datalist>`) từ danh sách
      `canbo` — xem module Cán bộ bên dưới.
- [x] Module Cán bộ: thêm/sửa KSV, ĐTV, cán bộ thống kê (collection `canbo`). Các ô KSV
      chính/KSV hỗ trợ/ĐTV ở form Thêm vụ án và Sửa thông tin vụ án vẫn lưu **tên dạng chuỗi**
      (không phải ref cứng tới `canbo`) — lựa chọn có chủ đích để tương thích dữ liệu đã có
      sẵn (từ Import Excel và các vụ tạo trước khi có module này), `<datalist>` chỉ gợi ý.
- [x] Module **Giao nhận hồ sơ** (`GiaoNhanHoSoModule`) — thiết kế để dùng với đầu đọc mã QR
      không dây 2.4GHz kiểu "giả lập bàn phím" (cắm đầu thu USB, không cần driver/app riêng —
      quét là gõ thẳng chuỗi mã vụ + Enter vào ô đang focus, y hệt gõ tay). Luồng: chọn loại
      giao dịch (Giao/Nhận) → tạo 1 `phienGiaoNhan` (trạng thái `dang_mo`) → ô input luôn
      auto-focus, mỗi lần nhận sự kiện `submit` (Enter) ghi NGAY 1 sự kiện `giao_nhan_ho_so` vào
      `lichsuChuyenGiaiDoan` (không hỏi kỳ báo cáo — giống "Sửa thông tin", đây là log hành
      chính lưu vết ai giữ hồ sơ, không phải sự kiện nghiệp vụ đổi giai đoạn/trạng thái, không
      ảnh hưởng số liệu báo cáo kỳ) → hiện ngay trong bảng "đã quét trong phiên", sửa/xoá được
      từng dòng tại chỗ cho tới khi bấm **"Lưu phiên"** (khoá lại, không sửa/quét thêm được nữa).
      Mỗi dòng có 3 trường người liên quan (field Firestore giữ tên cũ, chỉ đổi Ý NGHĨA + nhãn
      hiển thị so với bản đầu tiên): **KSV** (field `nguoiGiao`, mặc định `vuAn.ksvChinh`) và
      **ĐTV** (field `nguoiNhan`, mặc định `vuAn.dtvCbdt`) chỉ để THỂ HIỆN hồ sơ của ai — không
      phải người thực giao/nhận; **Người nhận thực tế** (`nguoiNhanThucTe`, để trống mặc định) —
      vì người thực tế cầm/ký nhận hồ sơ có thể khác (đi nhận thay). Cả 3 sửa tự do được (input +
      `<datalist>` gợi ý từ `canbo`, không ép buộc) — **bấm vào bất kỳ đâu trên cả dòng** (2026-
      07-13, không chỉ đúng chữ "Sửa" nhỏ) là vào chế độ sửa ngay (`DongGiaoNhan`'s `batDauSua`),
      vì thao tác giao nhận diễn ra nhanh/liên tục theo nhịp quét QR, không nên bắt rê chuột chính
      xác vào 1 link nhỏ. Cell nào có nút bấm/input khi đang sửa đều `stopPropagation` để không tự
      kích hoạt lại chế độ sửa hoặc lẫn với việc bấm Xoá. Không có ràng buộc thứ tự giao/nhận (quét là
      ghi, không kiểm tra hồ sơ đang "ở đâu" trước đó) — quyết định có chủ đích để giữ thao tác
      quét nhanh, đơn giản như sổ giao nhận giấy truyền thống. **"In phiên"** xuất "Biên bản giao
      nhận hồ sơ" khổ A4 qua cùng cơ chế portal `#qr-print-root` đã dùng cho In mã QR (xem
      `BienBanGiaoNhanIn`) — mỗi vụ 1 dòng riêng: mã vụ (cột hẹp) + tên vụ 2 dòng (tên vụ/số-ngày
      QĐ KTVA) + KSV + ĐTV + cột "Người nhận thực tế / Ký tên" ngay tại dòng đó (không dùng 1
      khối ký tên chung cuối trang — vì 1 phiên có thể giao cho nhiều người khác nhau theo từng
      vụ, phải ký ngay cạnh đúng vụ đó).
      **Tìm thủ công khi không có mã QR (2026-07-13)** — luồng gốc chỉ nhận vào đúng 1 mã vụ án
      chính xác (đọc thẳng `db.collection("vuan").doc(ma)`), không có cách nào thêm 1 dòng vào
      phiên nếu không cầm mã vụ trong tay. Thêm link nhỏ "Không có mã QR? Tìm thủ công..." dưới ô
      quét, mở ra 1 ô tìm kèm danh sách kết quả bấm chọn để ghi nhận — cùng chỗ dùng chung logic
      ghi sự kiện `giao_nhan_ho_so` với đường quét mã (tách hàm `ghiNhanVuVaoPhien`, cả 2 đường
      vào đều gọi hàm này để không lệch nhau field nào). Tìm theo tên vụ/KSV chính/tội danh (proxy
      qua field `dieuLuat` cấp `vuan`, giống lý do đã dùng ở Án đã giải quyết/Giao nhận không có
      bị can join)/số QĐ KTVA — lọc phía client trên 1 lần tải toàn bộ vụ **đang giải quyết** (không
      tìm cả vụ đã xong, vì hồ sơ giao nhận thực tế chỉ xoay quanh vụ đang thụ lý), tải 1 lần lúc
      mở panel (không realtime — đây là công cụ tra cứu để CHỌN, không phải danh sách cần luôn mới
      nhất).
      **Sửa thông tin vụ án ngay từ dòng giao nhận (2026-07-13)** — lý do thực tế: rất nhiều vụ
      lúc nhập ban đầu (import/tạo tay) chưa đủ thông tin, chỉ khi thực tế CẦM hồ sơ lúc giao/nhận
      mới biết rõ để bổ sung (VD đơn vị thụ lý, điều luật, KSV hỗ trợ...). Nút "✎ Sửa thông tin
      vụ án" nhỏ dưới tên vụ trong mỗi dòng (`DongGiaoNhan`) — bấm vào tải nguyên `vuan` doc hiện
      tại (log giao nhận chỉ lưu snapshot vài field, không đủ để mở form sửa) rồi mở thẳng
      `SuaVuAnForm` — DÙNG LẠI y nguyên component đã có ở panel chi tiết Danh sách vụ án, không
      viết lại logic sửa. KHÁC HẲN với việc bấm cả dòng để sửa (mục ngay trên) — bấm cả dòng chỉ
      sửa 3 field snapshot của DÒNG log (KSV/ĐTV/người nhận thực tế hiển thị lúc giao nhận), còn
      nút này sửa thẳng vào chính `vuan`, ảnh hưởng dữ liệu gốc dùng ở mọi module khác. Luôn hiện
      được kể cả khi phiên đã "Lưu phiên" (`khoaSua`) — khoá phiên chỉ chặn sửa dòng log, không
      liên quan gì tới sửa thông tin vụ án.
- [x] Dựng lại lịch sử cho dữ liệu import cũ: nút "Dựng lại lịch sử" trong module Import Excel
      (`DungLaiLichSuTool`) — quét `vuan` chưa có dòng `lichsuChuyenGiaiDoan` nào, tự tạo 1 sự
      kiện `khoi_to_vu` + `khoi_to_bican` mỗi bị can theo dữ liệu hiện có. Idempotent (chạy
      lại không tạo trùng, vụ đã có log sẽ bị bỏ qua) nhưng KHÔNG dựng lại được các lần gia
      hạn/trả hồ sơ trước khi import — dữ liệu đó không còn lưu vết trong Excel gốc. Vẫn giữ
      nguyên cho dữ liệu đã import bằng mẫu DSAT/DSBCT cũ; import bằng mẫu "Danh sách án" mới
      (mục dưới) không cần công cụ này vì đã tự ghi log ngay lúc import.
- [x] **Import Excel — đổi hẳn sang mẫu "Danh sách án" (2026-07-13), bỏ mẫu DSAT/DSBCT cũ** theo
      yêu cầu người dùng — mẫu cũ đọc 2 sheet DSAT/DSBCT y hệt cấu trúc file Excel thống kê thủ
      công cũ (nhiều cột cờ không rõ nghĩa, không tạo log, không chống trùng), thay bằng 1 sheet
      duy nhất tên đúng `"Danh sách án"` (hằng số `TEN_SHEET_DANH_SACH_AN`), cấu trúc **1 dòng/bị
      can, thông tin vụ lặp lại từng dòng** — cùng kiểu với các sheet DS mới/DS tồn... mà "Xuất
      Excel báo cáo tháng" (`VU_H`/`BC_H`, xem mục Xuất Excel báo cáo tháng) đã xuất ra, cộng thêm
      các cột bắt buộc để dựng được 1 vụ án hoàn chỉnh mà báo cáo không cần mang theo: Giai đoạn,
      Trạng thái, Ngày/Số quyết định (chỉ bắt buộc khi Trạng thái khác "Đang giải quyết" — dùng
      cho vụ án cũ đã có kết quả), Nguồn, Số/Ngày QĐ KTVA tách 2 cột riêng (bỏ hẳn kiểu ghép chung
      `"108/28.3.23"` của mẫu cũ — `splitSoNgayQuyetDinh` đã xoá vì không còn nơi dùng), và thêm
      cột Giới tính bên bị can (mẫu cũ hardcode cứng `gioiTinh: "nam"` cho mọi bị can vì DSBCT gốc
      không có cột này — nay đọc thật từ file).
      **Hàm đọc mới `parseWorkbookDanhSachAn`** (thay hẳn `parseWorkbook`/`mapNguon` cũ, đã xoá):
      header ở ĐÚNG dòng 1 (không phải dòng 2 như mẫu cũ — để có thể lấy thẳng 1 sheet report đã
      xuất ra làm gốc), dữ liệu từ dòng 2; đọc theo vị trí cột cố định y hệt nguyên tắc cũ. Nhận
      diện Giai đoạn/Trạng thái/Nguồn qua khớp NGƯỢC với chính `NHAN_GIAI_DOAN`/`NHAN_TRANG_THAI`/
      `NHAN_NGUON` (hàm `timTuNhan`, case-insensitive) — không nhận diện được thì mặc định Điều
      tra/Đang giải quyết/Án khởi tố mới kèm cảnh báo trên bảng xem trước, không chặn import.
      **Tự động nhận diện vụ trùng (yêu cầu cốt lõi của bản redesign này) theo đúng thứ tự ưu
      tiên mã vụ án → Số+Ngày QĐ KTVA**: sau khi đọc file, tải toàn bộ `vuan` hiện có 1 lần, dựng
      2 map tra cứu (`byMa` khớp cả `maNganhCap` lẫn `maNoiSinh`; `byQdNgay` khớp cặp
      `soQdKtva`+`ngayQdKtva` qua `fmtDate` làm khoá) — vụ trùng theo 1 trong 2 tiêu chí bị loại
      thẳng, KHÔNG ghi vào hệ thống (tránh xung đột/ghi đè dữ liệu đang có, đúng yêu cầu người
      dùng), hiện trong bảng xem trước riêng "vụ trùng — sẽ bỏ qua" kèm lý do/ID vụ đã có để đối
      chiếu. Vụ thiếu dữ liệu bắt buộc (thiếu Tên vụ/Ngày QĐ KTVA/Ngày quyết định khi đã giải
      quyết) rơi vào nhóm lỗi riêng "vụ thiếu dữ liệu — sẽ bỏ qua", cũng không import, phải sửa
      file rồi tải lại — 3 nhóm moi/trung/loi tính toán ngay khi tải file (không cần bấm gì thêm),
      chỉ nhóm "mới" mới có nút ghi vào hệ thống.
      **Vụ mới được cấp mã hệ thống thật (`maNoiSinh`) thay vì dùng thẳng mã trong file làm ID**
      (khác hẳn cách cũ `db.collection("vuan").doc(va.maNganhCap)` — rủi ro mã trống/trùng giữa
      2 dòng làm mất dữ liệu) — mã trong file giữ lại làm `maNganhCap` (mã tham chiếu), đúng kiểu
      dữ liệu `ThemVuAnForm` tạo ra. Sinh mã theo lô qua `sinhNhieuMaVuAn` (gom theo tháng QĐ
      KTVA, 1 transaction/tháng thay vì 1 transaction/vụ như `sinhMaVuAnMoi` — vì import có thể
      hàng chục/hàng trăm vụ cùng lúc, sinh từng vụ 1 transaction sẽ chậm).
      **Ghi log ngay lúc import (khác hẳn mẫu cũ hoàn toàn không tạo log, phải chạy
      `DungLaiLichSuTool` thủ công sau đó)**: mỗi vụ mới được ghi `khoi_to_vu` + `khoi_to_bican`
      mỗi bị can qua `taoSuKien`, và nếu Trạng thái khác "Đang giải quyết" thì ghi thêm 1 sự kiện
      `hoan_thanh` (kèm `soQuyetDinh`/`ngaySuKien` lấy từ 2 cột Ngày/Số quyết định, và field
      tương ứng trên `vuan` qua `fieldSoQuyetDinhTrenVuAn` — y hệt luồng `HoanThanhVuAnModal`) +
      set `ngayQuyetDinh`/`kyHoanThanh` trên `vuan` (đúng index mà module Án đã giải quyết cần,
      xem mục Án đã giải quyết) — vụ án cũ đã giải quyết import bằng mẫu này lên thẳng "Án đã giải
      quyết" ngay, không cần chạy thêm `BackfillNgayQuyetDinhTool`.
      **Hỏi kỳ báo cáo 1 LẦN cho cả đợt import** (không hỏi riêng từng vụ — 1 file thường là 1 đợt
      nhập cùng nguồn/cùng thời điểm) qua chính `ModalXacNhanKy` dùng chung (nguyên tắc thiết kế
      #3), bật lên khi bấm nút "Ghi ... vụ mới vào hệ thống" — cho chọn 1 kỳ báo cáo bình thường
      (án mới thật sự phát sinh trong kỳ đang làm việc) HOẶC **"Kỳ lưu trữ án cũ"** (`loai:
      "luu_tru"`, khái niệm đã có sẵn từ `MoKyMoiForm`/module Kỳ báo cáo — dùng khi nhập lại án cũ
      cho đủ hồ sơ, sự kiện gán vào kỳ này không tính vào báo cáo tháng nào) — `kyThongKe` của mọi
      sự kiện log VÀ `kyThongKeKhoiTo` trên từng `bican` đều set theo đúng lựa chọn này.
      File mẫu tham khảo: `Mau_Import_DanhSachAn.xlsx` (không phải code của app, tạo 1 lần bằng
      script Python dùng `openpyxl` rồi xoá script — nếu cần sửa mẫu, tạo lại tương tự, đừng coi
      file `.xlsx` này là nguồn sự thật của cấu trúc cột, nguồn thật luôn là
      `parseWorkbookDanhSachAn` trong `qlva.html`).
      **Fix: "Mã vụ" (cột A) không còn bắt buộc (2026-07-13, nhánh `import-excel-fix`)** — bug
      thật gặp phải: người dùng import 1 file 760 dòng đúng mẫu, hệ thống báo "không dòng nào có
      Mã vụ" dù dữ liệu hợp lệ. Nguyên nhân: bản đầu tiên bắt buộc cột A khác rỗng mới coi là 1
      dòng dữ liệu (`rows = rawRows.filter(r => r[0] != null...)`) — sai với đúng nhu cầu thực tế
      là NHẬP ÁN NGUỒN TỪ NGOÀI HỆ THỐNG, tức các vụ CHƯA TỪNG có mã vụ. Đã sửa 2 chỗ:
      (1) tiêu chí "dòng có dữ liệu" đổi thành có Tên vụ HOẶC Ngày QĐ KTVA (không cần cột A);
      (2) khoá NHÓM nhiều dòng bị can về cùng 1 vụ đổi từ luôn dùng `maVu` sang: có Mã vụ thì
      dùng Mã vụ (hành vi cũ, cho vụ đã có mã sẵn), KHÔNG có Mã vụ thì dùng cặp Số+Ngày QĐ KTVA
      giống hệt nhau (đúng yêu cầu nghiệp vụ người dùng nêu rõ: "số QĐ và ngày QĐ KTVA giống nhau
      là 1 vụ nhiều dòng do nhiều bị can"). Dòng vừa thiếu Mã vụ vừa thiếu Ngày QĐ KTVA thì KHÔNG
      gộp chung với dòng khác cũng thiếu (khoá riêng theo index dòng, tránh gộp nhầm 2 vụ không
      liên quan chỉ vì cùng thiếu thông tin). `vuData.maNganhCap = v.maVu || null` ở bước ghi đã
      tự đúng từ trước (không cần sửa) — vụ nhóm theo QĐ KTVA vẫn được `sinhNhieuMaVuAn` cấp
      `maNoiSinh` bình thường, tính năng "tự sinh mã vụ án mới cho vụ chưa có mã" thực chất đã có
      sẵn từ bản đầu, chỉ là dữ liệu chưa bao giờ lọt qua được bước đọc sheet. Bước đối chiếu
      trùng cũng thêm guard `if (v.maVu) {...}` trước khi tra `byMa` để tránh lookup vô nghĩa khi
      `maVu` rỗng. Đã kiểm chứng lại bằng file giả lập thật (Node + thư viện `xlsx` thật, không
      chỉ đọc code) trước khi mirror sang `qlva-dev.html` — xem lịch sử trò chuyện lúc sửa để biết
      cách dựng lại test tương tự nếu cần kiểm tra lại sau này.
      **Nới lỏng tiếp: chỉ bắt buộc Số QĐ KTVA + Ngày QĐ KTVA + KSV chính (2026-07-13, cùng
      nhánh)** — theo yêu cầu người dùng: nhập nhanh án mới với tối thiểu 3 trường này là đủ, các
      trường còn thiếu (Tên vụ, Điều luật, đơn vị thụ lý, Giai đoạn/Trạng thái/Nguồn...) bổ sung
      dần sau qua nút "Sửa thông tin vụ án" (đã có sẵn ở cả panel chi tiết Danh sách vụ án lẫn màn
      Giao nhận hồ sơ — xem 2 mục đó). Bỏ hẳn ràng buộc "thiếu Tên vụ" khỏi `_loi`, thêm ràng buộc
      mới "thiếu Số QĐ KTVA" và "thiếu KSV chính". Tên vụ bỏ trống: sau khi gom xong toàn bộ dòng
      của 1 vụ (vòng `vuMap.forEach` cuối `parseWorkbookDanhSachAn`, chạy SAU vòng nhóm dòng chính
      vì cần biết đủ `biCanList` mới đặt tên được), tự đặt tên tạm `"<tên bị can đầu tiên> và đồng
      phạm"` nếu có >1 bị can, chỉ tên bị can đó nếu đúng 1 bị can — giống hệt quy ước
      "Họ tên bị can đại diện" mà mẫu DSAT cũ dùng để tự đặt tên, chỉ khác là tính lúc đọc file
      thay vì lúc ghi. Vụ hoàn toàn không có bị can VÀ không có Tên vụ thì giữ nguyên rỗng (không
      tính lỗi) — hiển thị "(chưa đặt tên)" như panel chi tiết đã tự xử lý sẵn cho `tenVu` rỗng.
      Đã kiểm chứng lại bằng file giả lập thật (2 vụ: 1 vụ tối giản chỉ có 3 trường bắt buộc + 2 bị
      can → tự đặt tên đúng, không lỗi; 1 vụ thiếu KSV → đúng bị gắn `_loi`) trước khi mirror sang
      `qlva-dev.html`.
      **Vụ đã có kết quả nhưng thiếu Ngày quyết định: hết chặn, tự dùng ngày ước tính (2026-07-13,
      cùng nhánh)** — theo yêu cầu người dùng, cụ thể là dữ liệu Tạm đình chỉ cũ hay thiếu khoản
      này. Bỏ nhánh `thieu.push("Trạng thái ... thiếu Ngày quyết định")` (từng chặn hẳn, đưa vào
      nhóm lỗi) — thay bằng: khi Trạng thái ≠ "Đang giải quyết" VÀ thiếu Ngày quyết định VÀ đã có
      Ngày QĐ KTVA (bắt buộc nên luôn có, trừ khi vụ đã bị `_loi` vì lý do khác) → tự gán
      `ngayQuyetDinh = ngayQdKtva + 4 tháng` (`Date.setMonth`, tự cuốn năm đúng khi tràn tháng),
      gắn field mới `v.ghiChu` (con dấu ⚠ + giải thích rõ đây là ngày ước tính, cần cập nhật lại)
      VÀ đẩy 1 dòng cảnh báo riêng vào `warnings` để hiện ngay trên bảng xem trước trước khi ghi.
      `v.ghiChu` được set vào field `ghiChu` của chính `vuan` doc lúc ghi (`ghiVaoCoSoDuLieu`,
      trước đó hardcode `""`), VÀ nối thêm vào `ghiChu` của sự kiện `hoan_thanh` (nối sau
      `ghiChuNhap` cố định "Nhập qua Import Excel...") — để cả 2 nơi tra cứu (thông tin vụ + lịch
      sử) đều thấy cảnh báo, không chỉ 1 chỗ. CHỈ áp dụng field `ghiChu` mới này cho các vụ THẬT
      SỰ dùng ngày ước tính (rỗng nếu ngày quyết định có sẵn từ file) — không đụng tới field
      `ghiChu` cho các trường hợp khác. Đã kiểm chứng lại bằng file giả lập thật (vụ Tạm đình chỉ,
      QĐ KTVA 01/01/2026, không có Ngày quyết định → tự tính đúng 01/05/2026, không còn `_loi`,
      có cảnh báo trong `warnings`) trước khi mirror sang `qlva-dev.html`.
      **Cờ `ngayQuyetDinhUocTinh` + hiện đỏ trong Án đã giải quyết (2026-07-13, cùng nhánh)** —
      thêm field boolean riêng `v.ngayQuyetDinhUocTinh` lúc parse (tách khỏi việc suy luận từ
      `ghiChu` — rõ ràng hơn, không lệ thuộc string), set `vuData.ngayQuyetDinhUocTinh = true` lúc
      ghi (chỉ set field này khi `true`, không set `false` — field không tồn tại trên các vụ khác,
      tránh rác field cho toàn bộ dữ liệu tạo qua đường khác). `AnDaGiaiQuyetModule` đọc cờ này để
      tô đỏ + thêm icon ⚠ + tooltip ở đúng ô "Ngày quyết định" khi `true`. **Cờ này KHÔNG tự động
      xoá** khi sửa các trường khác qua `SuaVuAnForm` (xem mục dưới) — vì `SuaVuAnForm` không có ô
      sửa `ngayQuyetDinh` (theo đúng mục đích thiết kế ban đầu của form: "chỉ sửa thông tin
      thường... không đổi giai đoạn/trạng thái"). Nghĩa là hiện tại CHƯA có đường sửa
      `ngayQuyetDinh` trực tiếp trong UI — vụ dùng ngày ước tính sẽ mãi hiện đỏ cho tới khi có ai
      sửa trực tiếp trên Firestore, hoặc tới khi bổ sung 1 UI riêng cho việc này (chưa làm, chưa
      có yêu cầu rõ ràng — nếu cần, cân nhắc thêm ô "Ngày quyết định" có điều kiện vào
      `SuaVuAnForm` khi `vuAn.trangThai !== "dang_giai_quyet"`, và khi lưu thì xoá cờ
      `ngayQuyetDinhUocTinh`).
      **Đổi sang bố cục 2 cột giống hệt Danh sách vụ án (2026-07-13, cùng nhánh)** — thay vì 1
      bảng full-width kèm nút "✎ Sửa thông tin" đơn lẻ (bản chỉ mở được `SuaVuAnForm`), module này
      giờ dùng đúng layout `DanhSachPanel`/`ChiTietPanel` đã có: panel trái `flex-1` là bảng danh
      sách (đổi từ `<table>` full-width `overflow-hidden` sang khung `flex flex-col min-h-0` +
      `<thead className="... sticky top-0 z-10">` bên trong `<div className="flex-1 overflow-auto">`
      — đúng pattern cuộn nội bộ đã dùng ở `DanhSachPanel`, xem mục "Bố cục cuộn trang"), bấm 1
      dòng (`onClick={() => setSelectedId(v.id)}`, style `border-l-4` + `bg-indigo-50` khi đang
      chọn — COPY nguyên pattern từ `DanhSachPanel`) hiện panel phải cố định 420px là **chính
      `ChiTietPanel`** (dùng lại y nguyên component đã có ở Danh sách vụ án, KHÔNG viết lại) — tự
      động có đầy đủ: bảng thông tin, danh sách bị can, lịch sử, nút "In mã QR"/"Sửa thông tin"/
      "Xóa vụ án", VÀ các nút hành động nghiệp vụ phù hợp trạng thái hiện tại của vụ (do
      `ChiTietPanel` tự ẩn/hiện theo `vuAn.trangThai`/`coQuanThuLy` — vụ đã xong hẳn như Đã xét xử
      chỉ còn "In mã QR"/"Sửa thông tin"/"Xóa vụ án", riêng tab Tạm đình chỉ còn thêm cả nút "Phục
      hồi" vì `ChiTietPanel` có điều kiện `vuAn.trangThai === "tam_dinh_chi"` sẵn — đúng ý nghĩa
      nghiệp vụ, không cần code thêm gì). State `vuAnDangSua`/`SuaVuAnForm` gọi trực tiếp của bản
      trước đã bỏ, thay bằng `selectedId` + `<ChiTietPanel vuAnId={selectedId}
      onDoiSelected={setSelectedId} />` y hệt cách `DanhSachVuAnModule` ghép 2 panel.
      **Lọc riêng theo KSV ở mọi nơi có ô tìm kiếm (2026-07-13)** — trước đây chỉ `DanhSachPanel`
      (Danh sách vụ án) có dropdown "Tất cả KSV" riêng, các chỗ khác chỉ tìm KSV được gián tiếp
      qua ô tìm kiếm tự do (phải gõ đúng/gần đúng tên). Đã thêm dropdown KSV (cùng pattern
      `dsKsv = [...new Set(list.map(v => v.ksvChinh).filter(Boolean))].sort()`) vào:
      **Án đã giải quyết** (state `ksv`, kết hợp AND với lọc kỳ + tìm kiếm tự do trong
      `listHienThi`) và **Giao nhận hồ sơ → "Tìm thủ công"** (state `ksvTim` — khác 1 chỗ: panel
      này trước đây CHỈ hiện kết quả khi có gõ từ khoá, nay cho phép chỉ chọn KSV mà KHÔNG cần gõ
      gì cũng ra danh sách, đúng nhu cầu "xem hết hồ sơ đang giải quyết của 1 KSV" — điều kiện ẩn/
      hiện danh sách đổi từ `tuKhoaTim.trim()` sang `tuKhoaTim.trim() || ksvTim !== "tat_ca"`).
      KHÔNG thêm dropdown KSV vào `NhapVuModal` (ô tìm 1 vụ đích để nhập vào — công cụ tìm-chọn 1
      bản ghi, không phải màn danh sách/lọc) hay `DanhMucToiDanhModule` (danh mục tội danh, không
      có field KSV — không có khái niệm để lọc).
      dùng chung + hook `useHanhDongVuAn`): Chuyển giai đoạn, Trả hồ sơ, Gia hạn điều tra,
      Hoàn thành vụ án (gộp cả 5 hình thức da_xet_xu/chuyen_di/tam_dinh_chi/dinh_chi/an_huy —
      tự động tách vụ khi TĐC/ĐC chỉ áp dụng 1 phần bị can, xem hàm `tachVuAn`), **Tách vụ án**
      thủ công (nút hiện với MỌI vụ đang giải quyết, kể cả 0 hoặc 1 bị can — 2026-07-11: bỏ điều
      kiện cũ `biCanList.length >= 2`, vì 1 vụ có thể có nhiều hành vi cần tách xử lý độc lập dù
      chỉ 1 bị can, hoặc hành vi chưa xác định được đối tượng nào — tách vụ 0 bị can tạo 1 vụ mới
      trống). `ChonBiCan` giờ là lựa chọn **3 trạng thái** mỗi bị can thay vì checkbox nhị phân:
      "Ở lại vụ gốc" / "Chuyển hẳn sang vụ mới" / **"Ở cả 2 vụ"** (sao chép — 1 người có nhiều
      hành vi, chỉ 1 hành vi tách ra nhưng người đó vẫn còn liên quan ở vụ gốc). Bản sao được gắn
      `nhomBiCanId` trỏ về ID bị can gốc để đánh dấu "2 bản ghi này là CÙNG 1 người" — dùng khi
      **Nhập vào vụ khác** sau này: nếu bị can vụ nguồn có `nhomBiCanId` trùng với 1 bị can đã có
      sẵn ở vụ đích, hệ thống GỘP tội danh vào bản ghi đích và xoá bản ghi nguồn thay vì tạo bị
      can trùng (đã kiểm chứng qua test: tách "ở cả 2 vụ" rồi nhập lại → vụ gốc vẫn đúng 1 bị
      can, không nhân đôi). **Nhập vào vụ khác** cũng ghi sự kiện `nhap_vu` trên vụ nguồn NHƯ CŨ,
      cộng thêm 1 sự kiện `duoc_nhap_vu` mới trên vụ ĐÍCH — vụ nguồn tuy không xoá (`trangThai:
      "da_nhap"`) nhưng trước đây lịch sử vụ đích không có dấu vết gì về việc đã nhận nhập; giờ
      lưu sẵn mã vụ/tên vụ/KSV của vụ nguồn dạng chuỗi trong `ghiChu` của sự kiện `duoc_nhap_vu`
      để tra soát nhanh ngay trên lịch sử vụ đích. Phục hồi (từ tạm đình chỉ).
      **Xóa vụ án (2026-07-13, `XoaVuAnModal`)** — KHÁC HẲN mọi hành động khác ở trên: đây không
      phải sự kiện nghiệp vụ (không đi qua `ModalXacNhanKy`/hỏi kỳ), mà là xóa vĩnh viễn dùng để
      sửa sai sót tạo nhầm (VD double-click tạo trùng, nhập liệu hoàn toàn sai) — hiếm dùng, KHÔNG
      phải luồng nghiệp vụ bình thường (đã có sẵn Hoàn thành/Trả hồ sơ/Tách vụ cho các trường hợp
      hợp lệ khác, đừng dùng Xóa để "sửa" 1 vụ hợp lệ). Nút đặt tách biệt cuối panel chi tiết (chữ
      đỏ nhỏ, ngoài cụm nút hành động chính phía trên) để tránh bấm nhầm. Bắt gõ lại đúng mã vụ
      hiển thị (`hienThiMa`) để xác nhận mới cho bấm xóa (không có cách hoàn tác). **Chặn hẳn** nếu
      còn vụ án nào có `vuGoc` trỏ về vụ đang xóa (tức đã TÁCH RA từ vụ này và còn tồn tại) — tránh
      để lại dữ liệu mồ côi mất gốc. Xóa cascade đúng 3 collection: doc `vuan`, mọi `bican` có
      `maVuAn` khớp, mọi `lichsuChuyenGiaiDoan` có `maVuAn` khớp (dùng `batch.delete`, chunk 400).
      KHÔNG cập nhật `baoCaoLuu` của kỳ đã chốt (chỉ cảnh báo trong modal, giống mọi thao tác sửa
      dữ liệu thuộc kỳ đã chốt khác) — người dùng tự chạy "Tính lại số liệu" ở Kỳ báo cáo nếu cần.
      KHÔNG xử lý trường hợp bị can của vụ này có bản sao (`nhomBiCanId`) ở vụ khác từ thao tác
      Tách — xóa vụ gốc sẽ làm ID nhóm đó không còn trỏ tới bị can thật nào, nhưng không phá dữ
      liệu bản sao, chỉ mất khả năng "Nhập vụ" nhận diện gộp về sau; chưa cần xử lý vì chưa gặp
      yêu cầu thực tế, nếu phát sinh vấn đề thì bổ sung cảnh báo tương tự cảnh báo vụ tách.
- [x] Module Án đã giải quyết (`AnDaGiaiQuyetModule`) — 5 tab theo `trangThai` cụ thể (Đã xét
      xử/Chuyển đi/Tạm đình chỉ/Đình chỉ/Án huỷ, danh sách `TAB_DA_GIAI_QUYET`), lấy `ngày quyết
      định` từ sự kiện `hoan_thanh` trong log (không phải `ngayCapNhat` của `vuan` — field đó có
      thể bị đổi bởi "Sửa thông tin" sau này nên không đáng tin làm ngày quyết định thật).
      Module **"Án tồn theo giai đoạn" (`AnTonModule`) đã bị XOÁ (2026-07-11)** theo yêu cầu
      người dùng — vai trò của nó (lọc theo giai đoạn + chỉ xem đang giải quyết + cảnh báo màu
      hạn điều tra) nay nằm hoàn toàn trong module Danh sách vụ án (toggle "Đang giải quyết" +
      tab giai đoạn có sẵn), không tạo module riêng nữa. Đừng làm lại module này trừ khi người
      dùng yêu cầu rõ ràng.
      **Lọc theo kỳ gồm cả kỳ lưu trữ án cũ + tìm kiếm (2026-07-13)** — dropdown "Lọc theo kỳ"
      trước đây lọc bỏ kỳ `loai: "luu_tru"` (`.filter(k => k.loai !== "luu_tru")`, sao chép máy
      móc từ `ModalXacNhanKy` — ở đó lọc bỏ vì mục đích khác: chỉ để chọn kỳ MẶC ĐỊNH lúc ghi log
      mới, không nên tự nhảy vào kỳ lưu trữ), khiến vụ án cũ nhập lại qua Import Excel (mẫu "Danh
      sách án", gán vào kỳ lưu trữ) hoặc gán tay vào kỳ lưu trữ không lọc riêng ra xem được ở đây.
      Đã bỏ điều kiện lọc đó — danh sách kỳ giờ gồm đầy đủ, kỳ lưu trữ hiện nhãn `" [Lưu trữ]"`
      (đúng quy ước nhãn đã dùng ở `ModalXacNhanKy`/`SuaKyModal`). Thêm ô **tìm kiếm tự do**
      (`tuKhoa`, đặt cạnh dropdown lọc kỳ) khớp đồng thời mã vụ/tên vụ/điều luật (dùng làm proxy
      tội danh — field `dieuLuat` ở cấp `vuan` đã gộp từ bị can theo nguyên tắc thiết kế #7, module
      này không query thêm `bican` nên không tra được tội danh gốc từng bị can) /KSV chính/KSV hỗ
      trợ/ghi chú — cùng pattern với ô tìm kiếm đã có ở module Danh sách vụ án (`DanhSachVuAnModule`,
      dòng ~3899-3913), lọc qua `useMemo` kết hợp với lọc kỳ hiện có, không thêm query Firestore
      mới (lọc trên `list` đã tải sẵn theo `hinhThuc`).
- [x] Module Kỳ báo cáo (mở kỳ mới có chặn trùng kỳ đang mở, chốt kỳ tự snapshot tồn cuối kỳ
      theo từng cơ quan vào `tonCuoiKy`). Bấm vào 1 dòng kỳ mở ra **báo cáo chi tiết theo giai
      đoạn** (`KyChiTietModal`/`tinhBaoCaoKy`): tồn đầu kỳ (lấy từ `tonCuoiKy` của kỳ liền
      trước) + số mới + đã giải quyết + tồn cuối kỳ + số vụ/số bị can đang tồn hiện tại — luôn
      tính trực tiếp từ `lichsuChuyenGiaiDoan` theo đúng nguyên tắc "log là nguồn sự thật duy
      nhất", không suy ra từ trạng thái hiện tại. Lưu ý: sự kiện `hoan_thanh` không lưu
      `tuGiaiDoan`, nên hàm dùng `coQuanThuLy` hiện tại của vụ làm proxy xác định đã hoàn thành
      từ giai đoạn nào — an toàn vì hệ thống không đổi `coQuanThuLy` sau khi vụ đã hoàn thành.
      **Công thức "số mới" đã sửa lại (2026-07-11), áp dụng THỐNG NHẤT cho cả 3 giai đoạn** —
      trước đó Điều tra được code riêng (gán mọi sự kiện `khoi_to_vu` vào Điều tra bất kể vụ
      khởi tạo trực tiếp ở giai đoạn nào, và thiếu hẳn "trả về từ giai đoạn sau"), khiến
      `tồn đầu kỳ + mới − giải quyết ≠ tồn cuối kỳ`. Công thức đúng: mới ở 1 giai đoạn = khởi tố
      trực tiếp vào đúng giai đoạn đó (`khoi_to_vu` có `denGiaiDoan` trùng — vụ nhập tay/import
      có thể vào thẳng Truy tố/Xét xử) + **vụ tách ra** (`tach_vu` có `denGiaiDoan` trùng — 1
      bản ghi `vuan` mới xuất hiện ở giai đoạn vụ gốc đang ở lúc tách, PHẢI tính "vào" thì mới
      khớp với việc nó bị tính "ra" nếu giải quyết luôn trong kỳ) + chuyển đến từ giai đoạn trước
      (`chuyen_giai_doan`, không áp dụng cho Điều tra) + trả về từ giai đoạn sau (`tra_ho_so`, CÓ
      áp dụng cho Điều tra — viện trả hồ sơ điều tra bổ sung). Cả `khoi_to_vu` và `tach_vu` đều
      ghi `denGiaiDoan` ngay lúc tạo (`ThemVuAnForm`, `dungLaiLichSu`, `tachVuAn`'s callers) — dữ
      liệu cũ tạo trước ngày sửa không có field này (`null`), đã chạy script backfill 1 lần tính
      lại từ lịch sử chuyển giai đoạn thật của từng vụ (không backfill lại nếu import dữ liệu cũ
      lần nữa thì nhớ set `denGiaiDoan` ngay từ đầu, đừng lặp lại lỗi này). Ngoài `hoan_thanh`,
      vụ bị **nhập vào vụ khác** (`nhap_vu`, `trangThai` → `da_nhap`) cũng RA KHỎI "tồn" và phải
      tính vào "Đã giải quyết / ra khỏi giai đoạn" (`soNhapVu`, dòng "— Nhập vào vụ khác") —
      dùng cùng kiểu proxy `coQuanThuLy` hiện tại như `hoan_thanh`, cùng lý do (không đổi sau khi
      nhập). Thiếu khoản này thì công thức lệch y hệt kiểu lỗi tách vụ đã sửa ở trên.
      **Lưu sẵn báo cáo kỳ đã chốt (2026-07-11)** — trước đây MỖI LẦN bấm xem 1 kỳ (kể cả kỳ đã
      chốt từ lâu, số liệu không đổi) đều quét lại toàn bộ `lichsuChuyenGiaiDoan` (hàng chục
      query + đọc từng doc `vuan` cho mỗi dòng danh sách), rất chậm và tốn Firestore read không
      cần thiết — người dùng yêu cầu lưu lại kết quả. Hàm tính đầy đủ đổi tên thành
      `tinhBaoCaoKyTuLog` (logic không đổi); `tinhBaoCaoKy` (hàm nơi hiển thị gọi) giờ là wrapper:
      kỳ **đã chốt VÀ có `baoCaoLuu`** thì dùng lại thẳng `kybaocao.baoCaoLuu` (ghi lúc chốt qua
      `chotKyBaoCao`), chỉ tính LIVE lại phần "Số tồn hiện tại" (`soVuTon`/`soBiCanTon`/`dsTon`
      qua `tinhTonHienTaiTheoGD`) vì phần đó theo đúng thiết kế cũ luôn phải là số tại-thời-điểm-
      xem, không thuộc riêng về 1 kỳ nào. `tachBaoCaoLuu` tách phần "đông cứng" ra khỏi phần
      live trước khi lưu. Kỳ đang mở hoặc kỳ đã chốt trước khi có tính năng này (chưa có
      `baoCaoLuu`) vẫn tự tính đầy đủ như cũ, không bắt buộc backfill. Nút **"Tính lại số liệu"**
      (chỉ hiện với kỳ đã chốt, gọi `tinhLaiBaoCaoLuu`) cho phép tính lại và ghi đè `baoCaoLuu`
      khi cần — dùng khi có **"Sửa kỳ"** (xem Nhật ký thao tác) tác động tới sự kiện thuộc kỳ đã
      chốt đó, xem cảnh báo ở `SuaKyModal` bên dưới. **KHÔNG** đụng tới `tonCuoiKy`/`tonCuoiBiCan`/
      `tonCuoiKyTheoTD` khi tính lại (số "Còn" chốt là trạng thái `vuan` thật tại thời điểm chốt,
      độc lập với việc gán `kyThongKe` của từng sự kiện log nên "Sửa kỳ" không làm sai số này —
      chỉ làm sai các dòng "số mới"/"đã giải quyết" đếm theo `kyThongKe`).
      **Bug đã sửa (2026-07-13) — B10 hiện "tồn kỳ trước" = "tồn kỳ này"**: `tinhLaiBaoCaoLuu`
      từng VI PHẠM chính bất biến ở trên — nó có ghi đè `tonCuoiKyTheoTD`/`tonCuoiBiCan` (không
      chỉ `tonCuoiKy` mới được bảo vệ) bằng kết quả `tinhSnapTonTheoTD()`, hàm này luôn query
      **LIVE** trạng thái `vuan` **hiện tại lúc gọi**, không biết gì về thời điểm chốt lịch sử của
      kỳ đang tính lại. `chotKyBaoCao()` gọi đúng hàm này lúc CHỐT LẦN ĐẦU thì không sao (thời
      điểm gọi = thời điểm chốt); nhưng "Tính lại số liệu" có thể chạy rất lâu sau, khi live
      `vuan` đã trôi xa khỏi trạng thái lúc kỳ đó thực chốt — ghi đè biến `tonCuoiKyTheoTD` của kỳ
      CŨ thành ảnh chụp HIỆN TẠI. Biểu B10 (`tinhBieu10`, xem mục Xuất Excel Biểu B10 bên dưới)
      đọc "tồn kỳ trước" từ `kyTruoc.tonCuoiKyTheoTD` — nếu `kyTruoc` vừa bị "Tính lại" gần đây,
      cột "tồn kỳ trước" trùng y hệt "tồn kỳ này" dù 2 kỳ cách nhau cả tháng. Đã sửa: bỏ hẳn lệnh
      gọi `tinhSnapTonTheoTD()` khỏi `tinhLaiBaoCaoLuu`, hàm giờ CHỈ ghi `baoCaoLuu` +
      `thoiDiemTinhLai`. Kỳ nào đã bị "Tính lại" trước khi có bản sửa này thì `tonCuoiKyTheoTD`
      của kỳ đó ĐÃ BỊ CORRUPT (mang giá trị live tại thời điểm bấm tính lại, không phải lịch sử
      thật) — sửa code không tự phục hồi được dữ liệu đã ghi sai, chỉ chặn không cho sai thêm.
      **Công cụ sửa dữ liệu đã corrupt (2026-07-13, `taiTaoTonCuoiKyTheoTDTatCa` +
      `TaiTaoTonTheoTDTool`, nút "Sửa lại tồn cuối kỳ theo tội danh (Biểu B10)" trong Cài đặt →
      Import Excel)** — KHÔNG replay điểm-theo-thời-gian từng vụ (quá phức tạp/rủi ro cho báo cáo
      thống kê chính thức) mà dùng cách rẻ hơn nhiều, tái dùng khối xây dựng đã có sẵn và đã kiểm
      chứng: duyệt TẤT CẢ kỳ đã chốt theo thứ tự thời gian (bỏ qua kỳ lưu trữ), với mỗi kỳ K tính
      `tonCuoiKyTheoTD[K] = tonCuoiKyTheoTD[K-1] (đã tính đúng ở bước trước, kỳ đầu tiên = 0) + số
      mới theo tội danh trong K − số đã giải quyết theo tội danh trong K`, cả 2 vế lấy trực tiếp
      từ `tinhBaoCaoKyTuLog(K, ...).ds` (hàm đã lọc đúng theo `kyThongKe==K.id`, KHÔNG đụng gì tới
      `tonCuoiKyTheoTD` cũ nên tái dùng an toàn, không lặp lại lỗi gốc). Vì đi tuần tự theo lịch
      sử, kỳ nào cũng nhận giá trị đã được sửa đúng của kỳ liền trước, không còn phụ thuộc snapshot
      live nào nữa. Đối chiếu tổng theo giai đoạn của kết quả với `tonCuoiKy` (field KHÔNG BAO GIỜ
      bị ghi đè — neo tin cậy tuyệt đối) sau mỗi kỳ: lệch (VD do vụ có `kyThongKe: null` từ "Dựng
      lại lịch sử" cho dữ liệu import cũ, không được đếm vào "số mới" của kỳ nào) thì gom phần
      chênh vào tội danh `"(chưa xác định — chênh lệch dữ liệu cũ)"` để TỔNG luôn khớp con số tin
      cậy, thay vì âm thầm sai không dấu vết. Số âm bất thường (dữ liệu cũ thiếu khiến "đã giải
      quyết" tính ra nhiều hơn "đang có") bị chặn về 0 kèm cảnh báo, không cho lan sang kỳ sau.
      An toàn chạy lại nhiều lần (luôn tính lại từ đầu, không cộng dồn lên kết quả cũ). Đã kiểm
      chứng riêng phần toán tích luỹ + đối chiếu bằng test độc lập (4 kịch bản: kỳ đầu không lệch,
      kỳ giữa vẫn khớp, có vụ ẩn gây lệch dương được gộp đúng, số âm giả bị chặn đúng) trước khi
      viết vào code — phần phụ thuộc Firestore thật (`tinhBaoCaoKyTuLog`, fetch bị can...) chưa
      kiểm chứng bằng dữ liệu thật, cần chạy thử trên `qlva-dev.html` trước khi tin tưởng số liệu
      xuất ra từ nút này trên dữ liệu production.
      **Báo cáo tổng hợp nhiều kỳ (2026-07-11)** — tích chọn (checkbox) nhiều dòng kỳ rồi bấm
      "Xem báo cáo tổng hợp" (VD tích đủ 12 kỳ tháng ra báo cáo năm, đúng yêu cầu người dùng)
      → `TongHopNhieuKyModal`/`tinhBaoCaoTongHopNhieuKy`: gọi lại `tinhBaoCaoKy` cho TỪNG kỳ được
      chọn (nên kỳ đã chốt vẫn dùng cache, tổng hợp cả năm vẫn nhanh) rồi SUM các dòng số mới/đã
      giải quyết, ghép nối các mảng danh sách chi tiết; "Tồn đầu kỳ" lấy từ kỳ SỚM NHẤT được
      chọn, "Tồn cuối kỳ" lấy từ kỳ MUỘN NHẤT — chỉ đúng nghĩa nếu các kỳ chọn liên tiếp nhau,
      không ép buộc bằng code (không chặn chọn kỳ rời rạc), chỉ ghi chú nhắc trên UI. Bảng hiển
      thị dùng chung component `BangBaoCaoChiTiet` (đã tách ra từ `KyChiTietModal` để dùng lại ở
      đây — 2 nơi cùng nhận đúng 1 dạng dữ liệu `baoCao[gd]`), nút xuất Excel cũng dùng lại
      `xuatBaoCaoThangExcel` (chỉ cần field `tenKy` để đặt tên file cho phần thân báo cáo, không
      phụ thuộc gì khác từ `ky` nên tái dùng được thẳng cho báo cáo gộp — LƯU Ý claim này đã sai
      sót với riêng sheet Biểu B10, xem bug fix ngay dưới đây).
      **Bug đã sửa (2026-07-13) — B10 của báo cáo gộp luôn hiện "tồn kỳ trước" = 0**: lúc thêm
      Biểu B10 vào `xuatBaoCaoThangExcel` (nhận thêm tham số thứ 3 `kyTruoc`, xem mục Xuất Excel
      Biểu B10 bên dưới), nút xuất Excel của `TongHopNhieuKyModal` không được cập nhật theo — vẫn
      gọi `xuatBaoCaoThangExcel({tenKy}, baoCao)` thiếu hẳn tham số `kyTruoc`, khiến `tinhBieu10`
      nhận `kyTruoc = null` → mọi cột "tồn kỳ trước" trên B10 của báo cáo gộp luôn ra 0, sai với
      claim cũ "không phụ thuộc gì khác từ ky". Đã sửa: truyền thêm `dsKyChon[0]?.kyTruoc` (kỳ
      liền trước kỳ SỚM NHẤT trong nhóm chọn — đúng quy ước "Tồn đầu kỳ" mà bảng tổng hợp đã dùng
      ở trên) làm tham số thứ 3.
      **Sửa kỳ vào kỳ đã chốt (2026-07-11)** — `SuaKyModal` (module Nhật ký thao tác) giờ kiểm
      tra nếu kỳ CŨ hoặc kỳ MỚI của sự kiện đang sửa đã `da_chot`, hiện cảnh báo đỏ giải thích
      báo cáo đã lưu (`baoCaoLuu`) của kỳ đó sẽ không tự cập nhật, và bắt tick ô "Tôi hiểu và vẫn
      muốn sửa" mới cho bấm Lưu (không chặn hẳn — sửa sai sót sau khi chốt vẫn là nhu cầu hợp lệ,
      chỉ đảm bảo người dùng biết cần vào Kỳ báo cáo bấm "Tính lại số liệu" sau đó).
- [x] **Xuất Excel báo cáo tháng** (nút "Xuất Excel báo cáo tháng" trong `KyChiTietModal`, hàm
      `xuatBaoCaoThangExcel`, **dùng ExcelJS** qua CDN riêng — không dùng `XLSX`/SheetJS như phần
      xuất Excel khác trong app, vì bản SheetJS CDN đang dùng ở đây là bản miễn phí KHÔNG ghi
      được style dù có set `cell.s`/`cellStyles:true` — đã kiểm chứng bằng cách giải nén file
      `.xlsx` xuất ra xem `cellXfs` luôn rỗng. ExcelJS ghi style thật, dùng cho **wrap text mặc
      định trên mọi ô** của báo cáo tháng cho dễ đọc, xem hàm `themSheetDanhSach`) — 12 sheet:
      Tổng hợp báo cáo (dump đúng bảng trên màn hình) + DS án mới + DS toà trả DTBS + DS viện trả
      DTBS + DS đã xét xử/chuyển đi/tạm đình chỉ/đình chỉ/án huỷ mới (mỗi hình thức 1 sheet, gộp
      cả 3 giai đoạn) + DS nhập vào vụ khác + **DS án tồn TÁCH RIÊNG 1 sheet/giai đoạn** (không
      gộp chung 1 sheet như bản đầu tiên — theo yêu cầu người dùng, dễ lọc/in riêng từng giai
      đoạn hơn). Toàn bộ danh sách dựng từ CHÍNH object `baoCao` mà `tinhBaoCaoKy` đã trả về
      (field `ds` trong mỗi `baoCao[gd]`, thu thập song song lúc tính số liệu qua
      `vuAnTuLogDocs`) — không tính lại riêng — nên số dòng mỗi sheet danh sách LUÔN khớp đúng số
      trên sheet Tổng hợp và trên báo cáo đang xem trên màn hình. Nếu sửa công thức
      `tinhBaoCaoKy` sau này, nhớ cập nhật đồng bộ cả phần `ds` tương ứng, đừng để 2 bên lệch
      nhau.
- [x] Module Dashboard (thẻ số liệu tồn hiện tại, bảng cảnh báo sắp hết hạn, biểu đồ cột chồng
      xu hướng theo kỳ dùng Chart.js — script CDN đã thêm vào `<head>`).
- [x] Module Nhật ký thao tác (feed toàn hệ thống, lọc theo loại sự kiện, giới hạn 300 dòng
      gần nhất — có ghi rõ giới hạn trên UI, không cắt âm thầm). **Sửa kỳ báo cáo cho từng sự
      kiện** (2026-07-11) — trước đây nguyên tắc thiết kế #3 đã nói log "sửa được sau, có audit
      trail `lichSuSuaKy`" nhưng chưa từng có UI thật sự để làm việc đó, field `lichSuSuaKy` chỉ
      là mảng rỗng mặc định không ai ghi vào. Nay có cột **"Kỳ"** hiển thị tên kỳ của từng sự
      kiện (bấm tiêu đề để sort theo thời gian thực của kỳ — dùng `ngayBatDau` của `kybaocao`
      làm giá trị so sánh, KHÔNG sort theo chuỗi tên "Tháng N/YYYY" vì sai thứ tự y hệt lý do đã
      né ở cột Kỳ mới/Kỳ giải quyết của Danh sách vụ án) + bộ lọc riêng theo kỳ (gồm cả lựa chọn
      "Chưa gán kỳ") để tìm nhanh các sự kiện cần chỉnh. Nút **"Sửa kỳ"** trên mỗi dòng (trừ
      `giao_nhan_ho_so` — loại này cố ý không tham gia số liệu theo kỳ nên không cho gán) mở
      `SuaKyModal`: đổi `kyThongKe` của đúng 1 sự kiện, đồng thời `arrayUnion` 1 phần tử vào
      `lichSuSuaKy` (`tuKy`/`denKy`/`lyDo`/`nguoiThucHien`/`thoiDiem`) để giữ vết ai sửa từ kỳ
      nào sang kỳ nào — hiện ngay trong modal ở lần mở sau. Sửa kỳ ở đây tác động trực tiếp tới
      số liệu báo cáo kỳ (Kỳ báo cáo/Dashboard/Xuất Excel đều tính từ `kyThongKe` của
      `lichsuChuyenGiaiDoan`), nên chỉ áp dụng cho các loại sự kiện nghiệp vụ thật, không áp
      dụng cho log hành chính.
- [x] Xuất Excel (nút trong module Danh sách, SheetJS dựng lại DSAT/DSBCT/TỔNG HỢP từ dữ liệu
      hiện tại). **Đã rà soát lại (2026-07-11)** — không có file gốc để so khớp pixel-perfect
      (người dùng xác nhận không có sẵn), nhưng đã đối chiếu logic `xuatExcel` với layout DSAT/
      DSBCT gốc lúc đó và không phát hiện lỗi/lệch dữ liệu — số bị can tính live từ collection
      `bican` (không dùng field cache cũ), mọi field label đều tra đúng qua `NHAN_GIAI_DOAN`/
      `NHAN_TRANG_THAI`/`NHAN_NGUON`. Lưu ý **quan trọng, đừng hiểu nhầm**: đây LÀ bản xem/lưu trữ
      dễ đọc, KHÔNG phải bản mirror 1:1 của DSAT/DSBCT gốc — file gốc DSAT có nhiều cột cờ riêng
      (Điều tra/Truy tố/Xét xử đang thụ lý, tạm đình chỉ, đình chỉ, đã xét xử, án huỷ...) được
      `xuatExcel` GỘP LẠI thành 2 cột text đơn ("Cơ quan đang thụ lý"/"Trạng thái") cho dễ đọc
      trên màn hình — nên file xuất ra KHÔNG dùng để nhập ngược lại qua Import Excel được (cấu
      trúc cột hoàn toàn khác `parseWorkbookDanhSachAn`). **Cập nhật (2026-07-13)**: mẫu Import
      Excel đã đổi hẳn sang sheet "Danh sách án" (xem mục riêng), `parseWorkbook`/DSAT/DSBCT nói
      ở trên đã bị xoá khỏi code — đoạn này giữ lại làm lịch sử rà soát, KHÔNG còn đúng với code
      hiện tại; `xuatExcel` (module "Xuất Excel" trong Danh sách vụ án) vẫn KHÔNG tương thích để
      nhập ngược lại qua mẫu "Danh sách án" mới (cấu trúc cột khác hẳn). "Xuất Excel báo cáo
      tháng" ở Kỳ báo cáo (sheet DS mới/DS tồn..., cấu trúc `VU_H`/`BC_H`, xem mục riêng) GẦN với
      mẫu import mới hơn (cùng nguyên tắc 1 dòng/bị can, vụ 0 bị can vẫn 1 dòng) nhưng KHÔNG
      re-import thẳng được — vẫn thiếu các cột `parseWorkbookDanhSachAn` bắt buộc (Giai đoạn,
      Trạng thái, Nguồn, Số/Ngày QĐ KTVA, Ngày/Số quyết định) và thiếu cột Giới tính bên bị can,
      phải tự thêm các cột đó vào trước khi import lại.
      Nếu sau này có file gốc thật để so khớp pixel-perfect hoặc cần format xuất round-trip được,
      làm rõ với người dùng trước khi đổi cấu trúc cột.
- [x] Sinh mã QR + in A4 (nút "In mã QR" ở panel chi tiết, thư viện `qrcodejs` qua CDN — xem ghi
      chú hạ tầng bên dưới về vụ đổi thư viện). In qua `ReactDOM.createPortal` vào `#qr-print-root`
      (sibling của `#root`, khai báo sẵn trong `<body>`) — khi in, CSS `@media print` chỉ ẩn
      `#root` (`display:none`), không ẩn `#qr-print-root`, nên khối QR không bị nằm ngoài luồng
      của phần app đã ẩn. Nếu 2 vụ có `maNganhCap`, hiện thêm 1 mã QR mã ngành cấp bên trái mã QR
      mã vụ (component `KhoiQR` dùng chung).
- [x] **Số quyết định** (2026-07-11) — mọi modal hành động nghiệp vụ (Chuyển giai đoạn, Trả hồ sơ,
      Gia hạn điều tra, Hoàn thành vụ án, Phục hồi, Tách vụ án, Nhập vụ) đều có thêm 1 ô "Số quyết
      định" để cán bộ ghi số văn bản làm căn cứ, nhãn đổi theo ngữ cảnh: Chuyển giai đoạn Điều
      tra→Truy tố = "Số kết luận điều tra" (`nhanSoQuyetDinhChuyen`), Truy tố→Xét xử = "Số cáo
      trạng", Hoàn thành với hình thức Đã xét xử = "Số bản án" (map nhãn theo `hinhThuc` ở
      `NHAN_SO_QUYET_DINH_HOAN_THANH`), còn lại (Trả hồ sơ/Gia hạn/Phục hồi/Tách vụ/Nhập vụ) nhãn
      cố định mô tả đúng loại quyết định của hành động đó. Lưu 2 chỗ: (1) field `soQuyetDinh` trên
      chính sự kiện log (`taoSuKien`, mặc định `""`) — hiện ở cột **"Số QĐ"** mới trong bảng Lịch
      sử của `ChiTietPanel`; (2) RIÊNG với Chuyển giai đoạn và Hoàn thành/Đã xét xử, còn ghi thêm
      vào field cấp `vuan` (`soKetLuanDieuTra`/`soCaoTrang`/`soBanAn` — dùng
      `fieldSoQuyetDinhTrenVuAn(hinhThuc)` để tra field tương ứng) để tra cứu nhanh không cần lật
      lịch sử. Chỉ lưu số quyết định, KHÔNG bắt buộc nhập (không validate rỗng) — nhiều trường hợp
      cán bộ chưa có số ngay lúc thao tác, điền bổ sung sau qua sửa lịch sử nếu cần.

### Bố cục cuộn trang (đã xử lý, đừng lặp lại)
`AppShell`'s khung ngoài dùng `h-screen overflow-hidden` (KHÔNG phải `min-h-screen`) — bug cũ:
`min-h-screen` chỉ đặt chiều cao TỐI THIỂU, không chặn nội dung cao hơn viewport phát triển thêm,
nên khi 1 module có nội dung dài (ví dụ Danh sách vụ án nhiều dòng) sẽ đẩy toàn bộ trang cuộn
theo trình duyệt (`body` cuộn) thay vì chỉ cuộn bên trong bảng — kéo cả sidebar/tiêu đề/tab lọc/
panel chi tiết trôi mất theo. Với `h-screen`, `<main className="flex-1 p-8 overflow-auto">` mới
thực sự trở thành vùng cuộn giới hạn, và các panel con (`DanhSachPanel`, `ChiTietPanel`) tự cuộn
độc lập bên trong `overflow-auto` + `min-h-0` của chính chúng. Khi thêm module mới có nội dung
có thể dài, đảm bảo toàn bộ chuỗi cha (module → `AppShell` → `<main>`) giữ đúng pattern
`h-full`/`min-h-0`/`overflow-auto` ở đúng tầng cần cuộn, đừng để `overflow-auto` "chết" vì cha nó
dùng `min-h-*` thay vì `h-*`.

### Ghi chú hạ tầng quan trọng (đã xử lý, đừng lặp lại)
- Firestore **database** và **Security Rules** phải được khởi tạo thủ công qua Firebase
  Console — không có cách nào tạo qua REST API/API key công khai. Đã tạo xong; rules hiện tại
  cho phép `request.auth != null` đọc/ghi toàn bộ (không phân quyền theo vai trò).
- CDN `@babel/standalone` phải **ghim version cụ thể** (hiện tại `@7.25.6`) — bản không ghim
  version từng nhảy lên major 8.x không tương thích và làm trắng màn hình toàn bộ app.
- Firestore compat SDK bản đang dùng (10.12.2) **không hỗ trợ `.count()`** (aggregation query)
  — dùng `.get()` rồi lấy `.size` thay thế.
- Query `lichsuChuyenGiaiDoan` lọc theo `maVuAn` + sắp xếp `thoiDiemGhi` cần composite index
  (đã tạo). Nếu thêm query dạng where+orderBy khác field mới sau này, khả năng cũng cần index
  mới — kiểm tra console lỗi Firestore, nó luôn kèm link tạo index trực tiếp.
- CDN QR: package npm `qrcode` (dùng cho `InQRModal`) **không có bản build/UMD sẵn** trong các
  bản publish gần đây — đường dẫn cũ `qrcode@1.5.3/build/qrcode.min.js` trả về 404 (khiến
  `QRCode is not defined`, mã QR không hiện). Đã đổi sang thư viện `qrcodejs`
  (`cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js`) — API khác hẳn: dùng
  `new QRCode(divElement, {text, width, height})` vẽ vào 1 `<div>` chứa canvas tự sinh, không
  phải `QRCode.toCanvas(canvas, text, cb)`. Nếu sau này đổi thư viện QR khác, nhớ kiểm tra CDN
  trả về đúng file JS (không phải 404/HTML) trước khi tin tưởng.
- In A4 (`InQRModal`) từng bị lỗi in ra nhiều trang giống nhau: CSS cũ dùng
  `body * { visibility: hidden }` để ẩn phần app khi in, nhưng `visibility:hidden` vẫn giữ
  nguyên chỗ trong layout — khi danh sách vụ án dài (nhiều dữ liệu), trình duyệt tính ra nhiều
  trang in dựa theo chiều cao ẩn đó, và khối QR (`position:fixed`) bị lặp lại trên mỗi trang.
  Đã sửa bằng `#root { display: none }` (bỏ hẳn khỏi layout) + render khung QR qua
  `ReactDOM.createPortal` vào `#qr-print-root` nằm ngoài `#root` — xem mục Tiến độ đã code ở
  trên. Nếu thêm màn hình in mới sau này, dùng lại đúng pattern này (portal ra ngoài `#root`),
  đừng quay lại kiểu `visibility:hidden`.
- **Offline persistence (2026-07-13, nhánh `offline-indexeddb`)** — bật `db.enablePersistence({
  synchronizeTabs: true })` ngay sau khi khởi tạo `db` (thẻ `<script>` thường, trước cả thẻ
  Babel). Firestore compat SDK tự dùng **IndexedDB** làm cache nội bộ — không phải code tự viết
  tầng lưu trữ riêng. Phạm vi CÓ CHỦ Ý giới hạn: chỉ chống **mất mạng tạm thời trong lúc đang
  dùng** (wifi chập chờn, di chuyển giữa các phòng...) — app tiếp tục đọc dữ liệu đã cache, xếp
  hàng các ghi/sửa/xoá, tự đồng bộ khi có mạng lại. **KHÔNG** phải chế độ hoạt động hoàn toàn
  không cần Internet — trang vẫn cần mạng ở lần tải đầu (và mỗi lần load lại) để lấy các thư viện
  CDN (React/Babel/Tailwind/Firebase SDK...) và đăng nhập; một máy CHƯA TỪNG có mạng thì không mở
  được app, và không đồng bộ được với người dùng khác (Firestore cần mạng để nói chuyện với
  server — đã hỏi rõ người dùng, xác nhận chỉ cần chống rớt mạng tạm thời, KHÔNG cần máy hoàn
  toàn air-gapped — nếu sau này có yêu cầu air-gapped thật, đó là 1 tính năng khác hẳn, cần bundle
  thư viện CDN inline + tách hẳn 1 chế độ dữ liệu cục bộ, đừng nhầm với mục này).
  `OfflineBanner`/`useOnline` (component trong `AppShell`) dùng `navigator.onLine` + sự kiện
  `online`/`offline` của trình duyệt để hiện banner cảnh báo màu vàng cố định đầu trang khi mất
  mạng — tín hiệu này không chính xác 100% (có thể báo "online" dù mạng không thật sự ra được
  Internet) nhưng đủ dùng, không cần ping thật. Banner dùng `fixed` (không chiếm chỗ trong luồng
  layout) để không phá khung `h-screen`/`overflow-auto` đã ghim cẩn thận — xem mục "Bố cục cuộn
  trang" bên dưới, đừng đổi banner này sang layout tĩnh (static/relative).

## Chạy & phát triển

Không có bước build, không có test/lint tự động, không có `package.json` — đây là chủ đích
(xem "Yêu cầu bắt buộc" ở trên), không phải thiếu sót cần bổ sung tooling. Cách kiểm tra thay
đổi: mở trực tiếp `qlva.html` bằng trình duyệt (double-click hoặc `file://`), đăng nhập bằng
tài khoản Firebase Auth thật của project `qlahsp2`. Nếu `file://` gặp lỗi CORS/console im lặng
không tải được, phục vụ qua server tĩnh cục bộ đơn giản (VD `python -m http.server 8765` rồi mở
`http://localhost:8765/qlva.html`) — không cần build, chỉ là HTTP server thô. Babel standalone
compile JSX ngay trong trình duyệt lúc tải trang, nên lỗi cú pháp JSX sẽ hiện ở console (F12),
không có bước biên dịch riêng để bắt lỗi trước.

## Môi trường dev/test & công cụ hỗ trợ

- **`qlva-dev.html`** — bản sao gần như y hệt `qlva.html`, chỉ khác `firebaseConfig` trỏ sang
  project Firebase riêng **`qlahs-test`** (thay vì `qlahsp2` production). Dùng để thử tính năng
  mới/thao tác phá hoại (xoá, seed dữ liệu giả) mà không đụng dữ liệu thật. Khi sửa `qlva.html`,
  nhớ áp lại thay đổi tương ứng vào `qlva-dev.html` nếu muốn test trên project `qlahs-test` (2
  file không tự đồng bộ, không có build step nào gộp chúng lại).
- **`seed-tool.html`** — công cụ độc lập (không phải module trong `qlva.html`) để seed dữ liệu
  test hàng loạt hoặc xoá sạch collection, kết nối được tới **cả 2 project** (`qlahsp2` production
  VÀ `qlahs-test`, chọn qua UI). Có hàm `xoaProd()` xoá dữ liệu trên project **production** — mở
  file này cẩn thận, xác nhận đang thao tác đúng project trước khi bấm nút xoá/seed.
- **`firebase.json`** / **`firestore.indexes.json`** / **`firestore.rules`** — config Firebase
  CLI dùng chung cho cả 2 project khi deploy qua `firebase deploy --only firestore:rules` hoặc
  `--only firestore:indexes` (cần `firebase use <project-id>` trước để chọn đích). Rules hiện tại
  chỉ chặn theo `request.auth != null` (đã đăng nhập là đọc/ghi được toàn bộ), không phân quyền
  theo vai trò — xem ghi chú ở mục hạ tầng bên dưới.

## Kiến trúc code trong `qlva.html`

Toàn bộ code nằm trong 1 thẻ `<script type="text/babel">`, chia theo khối comment
`// ====== TÊN KHỐI ======` theo thứ tự: tiện ích dùng chung (parse ngày/số Excel) → từng màn
hình đăng nhập/module → khung chính `AppShell` → root `App`. Khi thêm module mới, theo đúng
pattern đã có:

1. Viết component module mới (ví dụ `DanhSachVuAnModule`) ở khối riêng, đặt trước `AppShell`.
2. Thêm 1 dòng vào mảng `MODULES` (đang ở ngay trên `AppShell`) với `ready: true`.
3. Thêm 1 nhánh `{tab === "id" && <ComponentMoi />}` trong `<main>` của `AppShell`.

`auth` và `db` (Firebase Auth/Firestore instance) là biến global khai báo ở thẻ `<script>` thường
phía trên (ngoài khối Babel) — mọi module dùng thẳng, không cần truyền qua props hay context.
Không có router: điều hướng module chỉ là state `tab` trong `AppShell`, không đổi URL.

`parseWorkbookDanhSachAn` (dùng bởi `ImportExcelModule`, xem mục "Import Excel — đổi hẳn sang mẫu
'Danh sách án'" ở Tiến độ đã code) đọc dữ liệu bằng **chỉ số cột cố định** (`r[0]`, `r[1]`...)
khớp đúng layout sheet `"Danh sách án"` (header ở dòng 1, dữ liệu từ dòng 2 — `range: 1` trong
`sheet_to_json`). Nếu sau này đổi cấu trúc cột của mẫu import, phải sửa lại các chỉ số này ở
`parseWorkbookDanhSachAn` VÀ cập nhật file mẫu `Mau_Import_DanhSachAn.xlsx` cho khớp.

## Mockup đã duyệt (mô tả bằng lời — không có file ảnh, tham khảo khi code UI)

- Danh sách vụ án: 2 cột — trái là thẻ danh sách lọc theo giai đoạn/KSV, phải là chi tiết vụ
  đang chọn (thông tin, nút chuyển giai đoạn/trả/đình chỉ/tách, danh sách bị can, lịch sử).
- Form thêm vụ án: bố cục ngang nhiều cột (không xếp chồng dọc), địa chỉ là textarea tự giãn,
  tội danh là danh sách nhiều dòng có nhãn "Tội chính"/"Bổ sung" + nút thêm dòng.
- Dashboard: thẻ số liệu (tồn từng giai đoạn) + bảng cảnh báo sắp hết hạn (đỏ/vàng) + biểu đồ
  cột chồng xu hướng theo kỳ.
- Trang in QR: A4, QR ~5x5cm chỉ chứa chuỗi mã vụ án thuần (tương thích hệ thống giao nhận hồ
  sơ PWA/Firebase khác đã có sẵn của người dùng — KHÔNG liên quan CSDL của dự án này, chỉ mượn
  format QR).

## Lưu ý khi tiếp tục code

- Không sửa lại các quyết định nghiệp vụ ở mục "Nguyên tắc thiết kế cốt lõi" trừ khi người dùng
  yêu cầu rõ ràng — đây là kết quả của nhiều vòng làm rõ nghiệp vụ thực tế với người dùng.
- File vẫn phải giữ nguyên tắc "1 file HTML", mọi thư viện qua CDN, không có bước build.
- Người dùng (Dũng) không phải lập trình viên — luôn giải thích bằng ngôn ngữ nghiệp vụ, không
  chỉ thuật ngữ kỹ thuật, khi hỏi lại hoặc báo tiến độ.
