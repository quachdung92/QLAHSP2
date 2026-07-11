# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
      **Import Excel** (đọc DSAT/DSBCT, xem trước, ghi Firestore bằng batch) + công cụ dựng
      lại lịch sử cho dữ liệu import cũ (xem mục riêng bên dưới).
- [x] Module Danh sách & chi tiết vụ án: 2 cột — danh sách là panel CHÍNH (`flex-1`, chiếm phần
      lớn chiều rộng), chi tiết là panel PHỤ cố định `w-[420px]` bên phải (đảo ngược so với thiết
      kế ban đầu theo yêu cầu người dùng). Danh sách có: ô tìm kiếm khớp cả mã vụ/tên vụ/điều
      luật/tên bị can, **toggle "Đang giải quyết" / "Tất cả"** (`chiDangGiaiQuyet`, mặc định
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
      chi tiết dùng bảng key-value **1 cột/hàng** (không phải 2 cột/hàng như thiết kế cũ) để
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
      `<datalist>` gợi ý từ `canbo`, không ép buộc). Không có ràng buộc thứ tự giao/nhận (quét là
      ghi, không kiểm tra hồ sơ đang "ở đâu" trước đó) — quyết định có chủ đích để giữ thao tác
      quét nhanh, đơn giản như sổ giao nhận giấy truyền thống. **"In phiên"** xuất "Biên bản giao
      nhận hồ sơ" khổ A4 qua cùng cơ chế portal `#qr-print-root` đã dùng cho In mã QR (xem
      `BienBanGiaoNhanIn`) — mỗi vụ 1 dòng riêng: mã vụ (cột hẹp) + tên vụ 2 dòng (tên vụ/số-ngày
      QĐ KTVA) + KSV + ĐTV + cột "Người nhận thực tế / Ký tên" ngay tại dòng đó (không dùng 1
      khối ký tên chung cuối trang — vì 1 phiên có thể giao cho nhiều người khác nhau theo từng
      vụ, phải ký ngay cạnh đúng vụ đó).
- [x] Dựng lại lịch sử cho dữ liệu import cũ: nút "Dựng lại lịch sử" trong module Import Excel
      (`DungLaiLichSuTool`) — quét `vuan` chưa có dòng `lichsuChuyenGiaiDoan` nào, tự tạo 1 sự
      kiện `khoi_to_vu` + `khoi_to_bican` mỗi bị can theo dữ liệu hiện có. Idempotent (chạy
      lại không tạo trùng, vụ đã có log sẽ bị bỏ qua) nhưng KHÔNG dựng lại được các lần gia
      hạn/trả hồ sơ trước khi import — dữ liệu đó không còn lưu vết trong Excel gốc.
- [x] Các hành động nghiệp vụ trên 1 vụ án (nút ở panel chi tiết, đều qua `ModalXacNhanKy`
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
- [x] Module Án đã giải quyết (`AnDaGiaiQuyetModule`) — 5 tab theo `trangThai` cụ thể (Đã xét
      xử/Chuyển đi/Tạm đình chỉ/Đình chỉ/Án huỷ, danh sách `TAB_DA_GIAI_QUYET`), lấy `ngày quyết
      định` từ sự kiện `hoan_thanh` trong log (không phải `ngayCapNhat` của `vuan` — field đó có
      thể bị đổi bởi "Sửa thông tin" sau này nên không đáng tin làm ngày quyết định thật).
      Module **"Án tồn theo giai đoạn" (`AnTonModule`) đã bị XOÁ (2026-07-11)** theo yêu cầu
      người dùng — vai trò của nó (lọc theo giai đoạn + chỉ xem đang giải quyết + cảnh báo màu
      hạn điều tra) nay nằm hoàn toàn trong module Danh sách vụ án (toggle "Đang giải quyết" +
      tab giai đoạn có sẵn), không tạo module riêng nữa. Đừng làm lại module này trừ khi người
      dùng yêu cầu rõ ràng.
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
      gần nhất — có ghi rõ giới hạn trên UI, không cắt âm thầm).
- [x] Xuất Excel (nút trong module Danh sách, SheetJS dựng lại DSAT/DSBCT/TỔNG HỢP từ dữ liệu
      hiện tại) — **cần đối chiếu lại định dạng cột với file gốc**, đây là bản dựng hợp lý dựa
      theo mapping cột lúc import, chưa có file gốc để so khớp pixel-perfect.
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

## Chạy & phát triển

Không có bước build, không có test/lint tự động, không có `package.json` — đây là chủ đích
(xem "Yêu cầu bắt buộc" ở trên), không phải thiếu sót cần bổ sung tooling. Cách kiểm tra thay
đổi: mở trực tiếp `qlva.html` bằng trình duyệt (double-click hoặc `file://`), đăng nhập bằng
tài khoản Firebase Auth thật của project `qlahsp2`. Nếu `file://` gặp lỗi CORS/console im lặng
không tải được, phục vụ qua server tĩnh cục bộ đơn giản (VD `python -m http.server 8765` rồi mở
`http://localhost:8765/qlva.html`) — không cần build, chỉ là HTTP server thô. Babel standalone
compile JSX ngay trong trình duyệt lúc tải trang, nên lỗi cú pháp JSX sẽ hiện ở console (F12),
không có bước biên dịch riêng để bắt lỗi trước.

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

`ImportExcelModule` đọc dữ liệu bằng **chỉ số cột cố định** (`r[0]`, `r[1]`...) khớp đúng layout
file Excel gốc (header ở dòng 2, dữ liệu từ dòng 3 — `range: 2` trong `sheet_to_json`). Nếu sau
này đổi cấu trúc cột của file Excel gốc, phải sửa lại các chỉ số này ở `parseWorkbook`.

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
