# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Gõ gộp "Số/Ngày" ở các ô Ngày chuyển giai đoạn/giải quyết (2026-07-30, `qlahs-sup.html`)

Theo yêu cầu người dùng: gõ `"380/06.7.2026"` vào ô "Ngày ..." (chuyển giai đoạn, giải quyết...)
sẽ tự tách và điền luôn cả 2 ô — Số quyết định = `"380"`, Ngày = `06/07/2026` — thay vì phải gõ tay
lần lượt 2 ô riêng, tiết kiệm thao tác cho 1 cặp dữ liệu hay đi cùng nhau trong thực tế nghiệp vụ
(số + ngày của cùng 1 văn bản).

**Cơ chế**: tách `parseNgayLinhHoat` (logic parse ngày linh hoạt vốn nằm trong closure của
`NhapNgay`) thành hàm top-level, thêm `tachSoVaNgayGop(s)` — chỉ tách khi có dấu `"/"` VÀ phần
SAU dấu `"/"` ĐẦU TIÊN tự nó parse được thành 1 ngày ĐẦY ĐỦ ngày/tháng/năm (không chỉ 2 nhóm số) —
nhờ điều kiện này, ngày gõ bình thường kiểu `"06/07/2026"` KHÔNG bị tách nhầm thành `"06"` +
`"07/2026"` (phần sau chỉ 2 nhóm, parse thất bại → rơi về nhánh ngày thuần như cũ). `NhapNgay`
nhận thêm prop **opt-in** `onTachSo` (chỉ truyền ở nơi có ô "Số quyết định" đi kèm) — không truyền
thì hành vi giữ NGUYÊN như cũ, không ảnh hưởng các `NhapNgay` khác không có ô Số đi kèm (VD Hạn
tạm giam, Ngày sinh, Ngày QĐ KTVA...).

**Áp dụng cho toàn bộ 9 cặp Ngày+Số quyết định lặp lại xuyên suốt app** (cùng 1 UI pattern, áp
dụng đồng bộ để tránh chỗ có chỗ không gây khó hiểu): `ChuyenGiaiDoanModal` (Ngày chuyển giai
đoạn), `TraHoSoModal` (Ngày trả hồ sơ), `GiaHanDieuTraModal` (Hạn điều tra mới), `PhucHoiModal`
(Ngày phục hồi), `HoanThanhVuAnModal` (Ngày quyết định — chính là "ngày giải quyết"),
`TachVuAnModal` (Ngày tách), `NhapVuModal` (Ngày nhập vụ), `ThemVuAnForm` (khối "Vụ án đã có kết
quả giải quyết", "Ngày giải quyết \*"), `SuaVuAnForm` (khối "Thông tin giải quyết", "Ngày giải
quyết").

**Kiểm chứng**: biên dịch qua `@babel/standalone` thật (cài tạm ngoài repo, gỡ sau khi test) —
sạch cú pháp; test logic thuần `tachSoVaNgayGop` độc lập xác nhận đúng cả 2 trường hợp mẫu
(`"380/06.7.2026"` và `"380/06/7/2026"` đều ra đúng `{so:"380", ngayIso:"2026-07-06"}"`) và không
tách nhầm ngày thuần (`"06/07/2026"`, `"06.07.2026"` đều trả `null`, giữ hành vi cũ). **CHƯA kiểm
chứng bằng Playwright/UI thật** — nên tự gõ thử 1 lần ở modal "Chuyển giai đoạn" hoặc "Hoàn thành
vụ án" trước khi tin tưởng tuyệt đối.

## Tính năng "Nộp lưu kho" — ĐÃ MERGE VÀO `main` + ĐÃ DEPLOY LÊN PRODUCTION (2026-07-23/26, `qlahs-sup.html`)

**Trạng thái hiện tại (2026-07-26)**: đã merge nhánh `nop-luu-kho` vào `main` (11 commit, không xung
đột) và deploy thật lên `qlahsp2.web.app` qua `./deploy.sh prod` — tính năng đang CHẠY THẬT, 4 cán
bộ dùng được ngay. 2 cột `soButLuc`/`soTapHoSo` trên `hoSoNopLuuKho` đã `ALTER TABLE` xong trên
Supabase thật (xem mục riêng cuối phần "Nộp lưu kho" bên dưới). Không còn phần nào dang dở của
tính năng này — các dòng "CHƯA merge/deploy" xuất hiện rải rác trong các mục con bên dưới là ghi
chú tại THỜI ĐIỂM VIẾT (lúc đó đúng là chưa), giữ nguyên làm lịch sử phát triển, KHÔNG còn đúng với
hiện tại — đọc dòng trạng thái này ở đầu mục làm nguồn sự thật mới nhất.

Theo yêu cầu người dùng — module hoàn toàn mới, **ĐỘC LẬP với "Nộp hồ sơ lưu trữ"** đã có trong
Giao nhận hồ sơ (đó là luồng KSV/ĐTV nộp hồ sơ CHO bộ phận lưu trữ để thống kê, ghi qua
`lichsuChuyenGiaiDoan`/`giao_nhan_ho_so`). Module này là luồng của CHÍNH bộ phận lưu trữ: gom hồ sơ
đã giải quyết (Tạm đình chỉ/Đình chỉ/Đã xét xử), sắp xếp + đánh **số lưu trữ cố định**, khoá/mở
khoá, rồi nộp cả đợt lên Kho lưu trữ chính thức — không tái dùng `phienGiaoNhan`/
`lichsuChuyenGiaiDoan` (2 quy trình nghiệp vụ khác nhau: KSV→lưu trữ vs lưu trữ→Kho, tránh lẫn dữ
liệu). Được thiết kế qua vài vòng hỏi-đáp làm rõ nghiệp vụ với người dùng trước khi code (xem lịch
sử hội thoại) — 3 quyết định quan trọng đã chốt: **STT reset về 1 mỗi đợt** (không liên tục xuyên
suốt), **gộp chung 1 sổ** (không tách theo giai đoạn ĐT/TT/XX), **quét QR lúc đưa lên Kho ghi
thẳng vào bảng riêng của module này** (không tạo/nối phiên Giao nhận hồ sơ).

**2 bảng Postgres mới** (`supabase/add_nop_luu_kho_2026-07-23.sql`, đã ALTER lên Supabase thật):
- `dotNopLuuKho` — 1 đợt nộp lưu, `trangThai` `dang_mo`/`da_chot` (khoá/mở khoá **2 chiều thật**,
  khác `kybaocao.trangThai=da_chot` hiện có vốn là khoá 1 chiều không mở lại được).
- `hoSoNopLuuKho` — 1 vụ trong 1 đợt, `soThuTu` (numeric, khoá sort ổn định — chèn thêm dùng số
  thập phân `1.001`/`1.002`... để KHÔNG renumber toàn bộ) + `nhanSo` (nhãn hiển thị "1"/"1A"/"1B"),
  snapshot vài field từ `vuan` lúc thêm vào đợt (đỡ join lại mỗi lần hiển thị), `thoiDiemQuetXacNhan`
  (null = chưa đưa lên Kho).

**Hạ tầng quan trọng phát hiện lúc code — `db.batch().commit()` đi qua RPC `batch_commit` có
DANH SÁCH TRẮNG bảng CỨNG trong thân hàm** (khác `.doc().set()/.update()/.get()/.where()` — những
API đó generic theo tên bảng, gọi thẳng PostgREST). Thêm bảng mới KHÔNG tự ghi được qua `batch()`
nếu không `CREATE OR REPLACE FUNCTION "batch_commit"` với whitelist đã thêm 2 bảng mới — đã làm
trong cùng file migration, kèm cập nhật `_TABLE_INSERT_ORDER` (JS) và `supabase/rls.sql`/
`supabase/schema.sql` (nguồn sự thật) cho khớp. Nếu thêm bảng mới cần dùng `db.batch()` sau này,
nhớ luôn kiểm tra bước này — dễ bị bỏ sót vì `.doc().set()` đơn lẻ vẫn hoạt động bình thường không
báo lỗi gì, chỉ riêng `batch()` mới cần.

**Kiến trúc màn hình** (`NopLuuKhoModule`, đặt trong `qlahs-sup.html` ngay sau `GiaoNhanHoSoModule`):
`ManChonDot` (chọn/tạo đợt) → `ManChiTietDot` (router theo `dot.trangThai` + `dsHoSo.length`) →
`ManChuanBiDanhSach` (lọc theo tháng/năm giải quyết + tuỳ chọn mở rộng kỳ trước chưa nộp/thống kê
thiếu, loại vụ ĐÃ có trong bất kỳ đợt nào từ trước, khối "Tình trạng nộp theo KSV" đếm
đã-nộp/chưa-nộp + drill-down danh sách cụ thể) → `ManXemTruocChot` (xem trước đã sắp xếp, bấm Chốt
sinh `soThuTu`/`nhanSo` + khoá đợt) → `ManSoLuuTru` (sổ: đã chốt = chỉ đọc + Mở khoá/Quét/In; đang
mở khoá = sửa được — Chèn sau/Xoá/Tính lại toàn bộ). `dot`/`dsHoSo` đều subscribe Realtime riêng
theo `dotId` (không tự tay đồng bộ state qua callback sau mỗi ghi — để 1 nguồn sự thật duy nhất,
tránh lệch giữa state cha tự set tay và Realtime đẩy về).

**Sắp xếp**: `sapXepDsNopLuuKho` — Thời hạn bảo quản (giảm dần, dùng `thoiHanBaoQuanSortKey`: Vĩnh
viễn = Infinity, "NN năm" = NN, chưa xác định = xếp cuối cùng không suy đoán) → Hình thức giải
quyết (`THU_TU_HINH_THUC_NOP_LUU_KHO`, thứ tự CỐ ĐỊNH tạm đình chỉ→đình chỉ→xét xử, KHÔNG phải
alphabet) → tên KSV (`localeCompare`).

**In ấn**: `InTagLuuTruModal` tái dùng nguyên lưới 6 ô/A4 (2 cột×3 hàng) đã có ở `InQRModal` chế độ
"góc giấy", chỉ khác là mỗi ô là 1 HỒ SƠ KHÁC NHAU (không phải nhiều bản của cùng 1 vụ) nên chia
trang theo nhóm 6 (`break-after: page`). `InSoLuuTruModal` tái dùng khổ A4 dọc + portal
`#qr-print-root` như `BienBanGiaoNhanIn`.

**Đã kiểm chứng đầy đủ bằng Playwright thật trên dữ liệu Supabase production thật** (`qlahs-sup.html`,
project `eutatszoaseixchvjbtg`, 1280+ vụ đã giải quyết thật) — tạo 1 đợt test, lọc hẹp còn 2 vụ thật
(tránh thao tác hàng loạt lên dữ liệu sản xuất), chạy trọn luồng: Chuẩn bị danh sách (xác nhận panel
"Tình trạng nộp theo KSV" tính đúng số liệu thật theo từng KSV) → Sắp xếp & Xem trước (xác nhận sort
đúng thứ tự 47 năm trước 33 năm) → Chốt (khoá đúng, sinh STT 1/2) → Quét tra cứu (hiện đúng thông
tin) → Xác nhận lên Kho (cập nhật đúng trạng thái) → Mở khoá → Chèn sau (xác nhận nhãn "1A" đúng
yêu cầu) → Tính lại toàn bộ STT (renumber đúng lại theo thời hạn bảo quản) → Xoá dòng → In tag (xác
nhận nội dung portal đúng) → In sổ danh sách (xác nhận nội dung đúng). Đã dọn sạch dữ liệu test
(xoá đợt + hồ sơ liên quan) và xác nhận 2 vụ án thật dùng để test KHÔNG bị đụng vào (module này chỉ
ĐỌC "vuan", không bao giờ ghi). 0 lỗi console liên quan tới thay đổi này (ngoại trừ cảnh báo Babel
kích thước file vô hại đã biết).

**Ghi chú môi trường test (không phải bug)**: giữa lúc kiểm chứng, tool chụp màn hình
(`computer`/screenshot) của trình duyệt test bị treo tạm thời trong khi `javascript_tool`/
`read_console_messages`/`get_page_text`/`read_page` vẫn phản hồi bình thường — xác nhận đây là vấn
đề riêng của cơ chế chụp màn hình trong môi trường test, không phải lỗi ứng dụng (DOM/React state
vẫn đúng, không có vòng lặp render vô hạn) — đã chuyển hẳn sang kiểm chứng qua các tool còn hoạt
động, không ảnh hưởng độ tin cậy của kết quả kiểm chứng.

**Cập nhật (2026-07-26, cuối ngày)**: đã merge `nop-luu-kho` vào `main` + deploy `qlahsp2.web.app`
theo đúng yêu cầu người dùng, sau khi đã kiểm chứng đầy đủ toàn bộ tính năng — xem dòng trạng thái
ở đầu mục "Nộp lưu kho" (đầu file) để biết tình hình mới nhất, dòng "chưa merge" ở trên chỉ còn giá
trị lịch sử tại thời điểm viết.

**Không cần mã QR trên tag** (đã hỏi lại, người dùng xác nhận CHỦ ĐỘNG không cần — đã có "In mã QR"
riêng cho việc đó ở panel chi tiết vụ án, tag này chỉ cần dễ quan sát bằng mắt) — thay vào đó
**"Số lưu trữ" là yếu tố quan trọng nhất trên tag, đã tăng độ nổi bật đáng kể** (2026-07-26): từ
`text-3xl` màu chàm (30px) lên `text-8xl font-black text-slate-900` (96px, đậm 900, gần đen tuyền)
— rõ nét kể cả khi in đen trắng/photo lại. Tên vụ/KSV giữ cỡ nhỏ, "Thời hạn bảo quản" tăng nhẹ lên
`text-xl` (đứng thứ 2 về độ nổi bật, sau Số lưu trữ).

**Bug đã sửa (2026-07-26) — "← Quay lại chỉnh sửa" ở màn xem trước làm MẤT SẠCH bộ lọc + lựa chọn
đã tick**, phải làm lại từ đầu mỗi lần muốn bớt 1 vụ sau khi đã xem trước. Nguyên nhân:
`ManChiTietDot` trước đây dùng conditional rendering kiểu `{cond && <ManChuanBiDanhSach/>}` — mỗi
lần chuyển qua lại giữa "chuẩn bị" và "xem trước", component bị UNMOUNT rồi MOUNT LẠI, mất hết
state nội bộ (bộ lọc tháng/năm, `dsChon`, `ungVien` đã tải). Đã sửa: `ManChuanBiDanhSach` giờ LUÔN
được giữ mounted suốt giai đoạn "đợt đang mở, chưa có hồ sơ" — chỉ ẨN bằng `className="hidden"` khi
đang xem trước, không gỡ khỏi cây React nữa — state nội bộ sống nguyên qua lại giữa 2 màn. Đã kiểm
chứng bằng Playwright thật: lọc tháng 1/2025, bỏ tick 1 dòng, bấm Xem trước rồi Quay lại — xác nhận
bộ lọc (tháng 1→1), danh sách 199 dòng, và đúng dòng đã bỏ tick trước đó vẫn giữ nguyên trạng thái
chưa tick (không phải "chọn hết" mặc định).

**Xác nhận lại sort đúng yêu cầu + thêm cột Số/Ngày QĐ KTVA + Số/Ngày QĐ giải quyết (2026-07-26)**
— người dùng nhắc lại tiêu chí sort (thời hạn → hình thức GQ gộp nhóm → cùng KSV đứng cạnh nhau);
rà lại `sapXepDsNopLuuKho` lúc đó **kết luận NHẦM là "ĐÃ ĐÚNG từ đầu"** (chỉ test bằng 2 giá trị thời
hạn hữu hạn khác nhau "47 năm"/"33 năm", không test trường hợp 2 dòng cùng "Vĩnh viễn") — **kết luận
này SAI, đã bị người dùng phát hiện lại bằng ảnh chụp thật ngay sau đó, xem mục sửa bug ngay dưới
đây**. Yêu cầu chính lúc này là thêm cột **Số QĐ KTVA/Ngày QĐ
KTVA** (từ `vuan.soQdKtva`/`ngayQdKtva`) và **Số QĐ giải quyết** (qua `fieldSoQuyetDinhTrenVuAn`,
field mới `laySoQdGiaiQuyetNopLuuKho`) + **Ngày GQ** (đã có sẵn ở màn chuẩn bị, còn thiếu ở màn xem
trước/sổ) — "để biết còn thiếu vụ nào" khi đối chiếu sổ điện tử với bìa hồ sơ giấy (bìa hồ sơ luôn
ghi các số này, không phải tên vụ, dễ đối chiếu nhầm nếu chỉ có tên).

**3 cột mới trên `hoSoNopLuuKho`** (`soQdKtva` text, `ngayQdKtva` timestamptz,
`soQuyetDinhGiaiQuyet` text) — snapshot lúc thêm vào đợt (Chốt hoặc Chèn sau), giống các field
snapshot khác đã có. Đã ALTER TABLE thêm 3 cột này lên Supabase thật, sửa trực tiếp CREATE TABLE
trong `add_nop_luu_kho_2026-07-23.sql` (KHÔNG tạo file migration mới — LÚC ĐÓ tính năng này vẫn
đang trên nhánh riêng CHƯA merge/deploy nên coi là chỉnh sửa tiếp bản thiết kế đang làm dở, khác
hẳn nguyên tắc "không sửa lại file migration đã chạy" áp dụng cho bảng ĐÃ có dữ liệu thật/đã lên
production — xem `batch_commit_2026-07-20.sql` để so sánh cách xử lý khi bảng đã thật sự ổn định).
**⚠ Từ 2026-07-26 trở đi, `hoSoNopLuuKho`/`dotNopLuuKho` ĐÃ ổn định (merge vào `main` + deploy
production + có dữ liệu thật)** — nguyên tắc "sửa trực tiếp file migration" ở trên KHÔNG còn áp
dụng nữa; mọi thay đổi schema tiếp theo cho 2 bảng này phải theo đúng quy tắc chung (tạo file
migration mới, không sửa lại `add_nop_luu_kho_2026-07-23.sql`), giống mọi bảng ổn định khác.

Thêm cột vào: bảng ứng viên (`ManChuanBiDanhSach`), bảng xem trước (`ManXemTruocChot`), sổ trên màn
hình + kết quả quét tra cứu (`ManSoLuuTru`), và **in sổ** (`InSoLuuTruModal`, quan trọng nhất vì đây
là bản dùng để đối chiếu tay với hồ sơ giấy) — sổ in từ 6 cột lên 9 cột nên **đổi từ khổ dọc 210mm
sang khổ NGANG 297mm** (cùng pattern `@page` cục bộ đã dùng ở `BienBanGiaoNhanIn`) để đủ chỗ đọc rõ.
Sổ trên màn hình cũng đổi từ `overflow-hidden` sang `overflow-x-auto` để không bị cắt mất cột khi
màn hình hẹp hơn 12 cột.

**Đã kiểm chứng bằng Playwright thật trên dữ liệu Supabase production thật** — tạo đợt test, lọc
2 vụ thật, xác nhận đủ cột đúng dữ liệu ở cả 4 nơi (bảng ứng viên, xem trước — vẫn đúng thứ tự 47
năm trước 33 năm, sổ sau khi chốt, và sổ in khổ ngang). Quét tra cứu ban đầu tưởng lỗi (không thấy
kết quả ngay sau khi gõ+Enter) — hoá ra chỉ là kiểm tra lại quá sớm trước khi React kịp render, gọi
lại `read_page`/`get_page_text` sau đó xác nhận kết quả hiện đúng đầy đủ (Số/Ngày QĐ KTVA + QĐ GQ),
không phải bug thật. Đã dọn sạch dữ liệu test sau khi kiểm chứng. 0 lỗi console liên quan.

## Bug thật đã sửa: sắp xếp nộp lưu kho ra lộn xộn khi nhiều dòng cùng "Vĩnh viễn" (2026-07-26)

Ngay sau mục ở trên (lúc đó kết luận NHẦM "đã đúng từ đầu") — người dùng gửi ảnh chụp màn "Xem
trước" thật: 15 dòng cùng "Vĩnh viễn" nhưng cột Hình thức GQ (Đình chỉ/Tạm đình chỉ/Đã xét xử) xen
kẽ lộn xộn, KHÔNG gộp nhóm — chứng minh trực tiếp bản sửa trước sai. Người dùng cũng nói rõ lại
thuật toán mong muốn bằng 5 bước: (1) gộp theo thời hạn bảo quản, (2) trong đó gộp theo hình thức
giải quyết, (3) trong đó gộp theo KSV, (4) trong đó sắp theo thứ tự thời gian ngày giải quyết,
(5) lặp lại — tức **thêm hẳn 1 tiêu chí thứ 4 (ngày giải quyết) chưa từng có trước đó**.

**Nguyên nhân thật**: `thoiHanBaoQuanSortKey("Vĩnh viễn")` trả về `Infinity`. Bản so sánh cũ tính
`kb - ka` (trừ trực tiếp) rồi `if (diff !== 0) return diff` — khi CẢ 2 dòng đều "Vĩnh viễn",
`Infinity - Infinity = NaN` trong JS, và **`NaN !== 0` luôn là `true`** — comparator trả về `NaN`
(bị `Array.sort` hiểu là "không đổi vị trí nhưng không dừng lại đúng") NGAY TỪ tiêu chí đầu tiên,
bỏ qua hẳn tiêu chí hình thức/KSV phía sau dù code 2 tiêu chí đó không hề sai. Đây đúng là lý do
lần kiểm chứng trước (chỉ so "47 năm" và "33 năm", đều là số hữu hạn, không bao giờ ra `NaN`) không
phát hiện được lỗi — **bài học: test comparator phải thử cả trường hợp 2 giá trị đầu-tiêu-chí BẰNG
NHAU (đặc biệt giá trị đặc biệt như `Infinity`), không chỉ thử các giá trị khác nhau**.

**Đã sửa** `sapXepDsNopLuuKho`: thay phép trừ bằng so sánh tường minh `ka !== kb` (không có phép
tính số học nào có thể ra `NaN`), và thêm hẳn tiêu chí thứ 4 — `layNgayGiaiQuyetMsNopLuuKho(v)`
(đọc `v.ngayQuyetDinh ?? v.ngayGiaiQuyet` — 2 tên field khác nhau giữa object "vuan" gốc và
"hoSoNopLuuKho" đã snapshot, chịu được cả Timestamp/Date/chuỗi ISO) — áp dụng SAU tiêu chí KSV,
đúng thứ tự 4 bước người dùng mô tả.

**Đã kiểm chứng lại bằng dữ liệu Supabase production thật, KHÔNG dùng dữ liệu giả** — đúng đợt
"Đợt nộp lưu năm 2025" người dùng đang chuẩn bị thật (1280 vụ, trạng thái "Đang mở", chưa Chốt):
bấm "Sắp xếp & Xem trước" (chỉ tính toán phía client, KHÔNG ghi Firestore/Supabase — an toàn đọc)
rồi đọc trực tiếp DOM bảng xem trước — xác nhận: mọi dòng "Vĩnh viễn" gộp lên đầu; trong đó "Tạm
đình chỉ" gộp liền một khối (đúng thứ tự cố định); trong khối đó, "Đặng Văn Sỹ" (24 dòng liền
nhau) rồi mới tới "Đào Việt Dũng" (14+ dòng liền nhau) — không còn xen kẽ; NGÀY GIẢI QUYẾT trong
từng nhóm KSV tăng dần đúng thứ tự thời gian (VD nhóm Đặng Văn Sỹ: 04/04/2025 → 16/05/2025 →
22/05/2025 → ... → 06/10/2025). Đã bấm "← Quay lại chỉnh sửa" ngay sau đó, KHÔNG bấm "Chốt" —
không có ghi nào vào dữ liệu thật trong lúc kiểm chứng.

## Nộp lưu kho: "Vấn đề cần bổ sung" + Excel xuất theo KSV để rà soát trước khi chốt (2026-07-26)

Cùng lúc với bug sort ở trên, người dùng yêu cầu thêm 2 phần: (1) 1 chỉ báo "vấn đề cần bổ sung"
cho từng hồ sơ, (2) xuất Excel danh sách chia theo TỪNG KSV với đầy đủ thông tin, để mỗi KSV tự
kiểm tra/rà soát và báo cáo lại bộ phận lưu trữ TRƯỚC KHI chốt danh sách chính thức (khác hẳn sổ
lưu trữ chính thức in ra SAU khi chốt — đây là bản nháp để phát hiện thiếu sót sớm).

**`layVanDeCanBoSungNopLuuKho(v)`** (đặt cạnh `laySoQdGiaiQuyetNopLuuKho`) — trả về mảng chuỗi mô
tả từng chỗ thiếu: thiếu thời hạn bảo quản (phân biệt rõ "thiếu mức án" nếu là Đã xét xử, vì
`tinhThoiHanBaoQuanVu` tự trả `null` khi thiếu `mucAnLoai` — gộp chung vào đúng 1 dòng, không tách
riêng "thiếu mức án" thành tiêu chí khác), thiếu số QĐ giải quyết, thiếu số/ngày QĐ KTVA, ngày giải
quyết là ngày ƯỚC TÍNH (cờ `ngayQuyetDinhUocTinh` từ Import Excel — xem mục "Import Excel: resolve
'Mã ĐL'..." không, đúng ra xem mục ngày ước tính ở phần "Giao nhận hồ sơ" cũ), và chưa nộp hồ sơ
giấy cho bộ phận lưu trữ (`v.daNop === false`). Hiện thành cột **"Vấn đề cần bổ sung"** mới ở cả
bảng ứng viên (`ManChuanBiDanhSach`) lẫn bảng xem trước (`ManXemTruocChot`) — gọn thành
`⚠ N vấn đề`/`✓ Đủ dữ liệu`, chi tiết đầy đủ nằm trong `title` (tooltip hover).

**Nút "⬇ Xuất Excel theo KSV để rà soát"** (`ManChuanBiDanhSach`, cạnh "Chọn tất cả"/"Bỏ chọn tất
cả") — xuất TOÀN BỘ `ungVien` (không riêng phần đang tick `dsChon` — KSV cần soát cả những vụ lưu
trữ lỡ bỏ tick, không chỉ phần đã chọn). ExcelJS, 1 sheet "Tổng hợp" (tất cả) + 1 sheet riêng cho
mỗi KSV (tên sheet khử ký tự Excel cấm `* ? : \ / [ ]` + cắt 31 ký tự + khử trùng tên nếu 2 KSV
trùng nhau sau khi cắt) + 1 sheet gộp `"(chưa gán KSV)"`. Mỗi sheet dùng lại đúng
`sapXepDsNopLuuKho` để thứ tự khớp với sổ chính thức sau này (dễ đối chiếu), 12 cột (STT/Mã vụ/Tên
vụ/KSV/Hình thức GQ/Số+Ngày QĐ KTVA/Số+Ngày QĐ GQ/Thời hạn bảo quản/Tình trạng nộp/Vấn đề cần bổ
sung — cột cuối nối chuỗi `vanDe.join("; ")`, tô màu đỏ đậm nếu "Chưa nộp", tô cam nếu có vấn đề).

**Đã kiểm chứng bằng Supabase production thật** — không tải file thật xuống đĩa (môi trường test
không mở lại file tải về được), thay vào đó chặn `URL.createObjectURL` để bắt lấy đúng `Blob` vừa
sinh ra, nạp lại bằng `new ExcelJS.Workbook().xlsx.load(...)` NGAY TRONG TRÌNH DUYỆT để đọc lại cấu
trúc thật (không phải suy đoán từ code) — trên "Đợt nộp lưu năm 2025" (1280 vụ, 35 KSV thật): xác
nhận đúng **37 sheet** (Tổng hợp + 35 KSV + 1 "(chưa gán KSV)"), header 12 cột đúng thứ tự, dữ liệu
từng dòng đúng (đối chiếu 2 dòng đầu sheet "Đặng Văn Sỹ" khớp y hệt dữ liệu đã thấy ở bảng xem
trước lúc kiểm chứng bug sort), cột "Vấn đề cần bổ sung" nối đúng nhiều lý do bằng `"; "`. File
~193KB cho 1280+ dòng × 37 sheet (không nhúng ảnh QR nên nhẹ, không lặp lại rủi ro treo tab đã gặp
ở "Tải toàn bộ lịch sử giao nhận" khi có hàng nghìn ảnh QR). 0 lỗi console.

**Chưa làm**: chưa tự tay tải file thật xuống đĩa rồi mở bằng Excel thật để xem bằng mắt (chỉ xác
nhận cấu trúc qua đọc lại bằng ExcelJS trong trình duyệt) — nên thử tải 1 lần trên `qlahs-sup.html`
thật và mở bằng Excel trước khi coi đây là đã kiểm chứng tuyệt đối 100%.

## Nộp lưu kho: tìm/lọc + chọn hàng loạt theo bộ lọc + "+ Thêm vụ" thủ công (2026-07-26)

Ngay sau 2 mục trên, người dùng phản hồi thêm 3 việc trên chính "Đợt nộp lưu năm 2025" thật (1280
vụ — quá nhiều để rà tay từng dòng): (1) bảng ứng viên cần tìm/lọc để tích/bỏ tích hàng loạt, (2)
nút "add" để bổ sung 1 vụ cụ thể nếu bị thiếu khỏi danh sách, (3) hỏi lại "tính năng quét QR nộp
lưu kho của tôi đâu rồi" — mục (3) hoá ra KHÔNG phải bug, xem giải thích riêng cuối mục này.

**Tìm/lọc bảng ứng viên** (`ManChuanBiDanhSach`) — thêm 1 ô tìm tự do (khớp mã vụ/tên vụ/KSV/số QĐ
KTVA) + 3 dropdown (KSV/Hình thức GQ/Tình trạng nộp), lọc thuần phía CLIENT trên `ungVien` đã tải
sẵn (`dsHienThi`, `useMemo`, không query thêm). **Đổi hẳn ý nghĩa "Chọn tất cả"/"Bỏ chọn tất cả"**
— trước đây luôn áp dụng cho TOÀN BỘ `ungVien`, giờ chỉ áp dụng cho ĐÚNG PHẦN ĐANG HIỂN THỊ
(`dsHienThi`) — lọc hẹp lại rồi bấm 1 trong 2 nút chỉ tick/bỏ tick đúng phần đó, KHÔNG đụng tới lựa
chọn đã có sẵn ở các dòng đang bị lọc ẩn đi (dùng `setDsChon(s => { const m = new Set(s); ... })`,
không reset toàn bộ Set). Nhãn nút tự đổi thành "... (đang hiện)" khi có bộ lọc đang áp dụng, header
bảng hiện thêm "đang hiện N" để tránh nhầm N đang hiện với tổng `ungVien.length`.

**Nút "+ Thêm vụ"** (cùng khu toolbar) — mở panel tìm 1 vụ CỤ THỂ trong TOÀN BỘ vụ đã giải quyết
(gọi lại `dongBoColdCacheVuAnDaGiaiQuyet()`, không giới hạn theo khoảng tháng/năm đang lọc ở màn
chuẩn bị — đúng nhu cầu "vụ bị thiếu" nghĩa là KHÔNG nằm trong bộ lọc mặc định), loại các vụ ĐÃ có
trong `ungVien`. Bấm 1 kết quả (`themVuThuCong`): kiểm tra lại 1 lần nữa qua Postgres xem vụ đã nằm
trong đợt nộp lưu KHÁC chưa (`hoSoNopLuuKho.where("maVuAn","==",id)`, chặn nếu có — số lưu trữ là cố
định, không cho trùng), tính `daNop` riêng cho đúng 1 vụ này (cùng logic join
`lichsuChuyenGiaiDoan`+`phienGiaoNhan.laLuuTru` đã dùng lúc tải cả danh sách, thu hẹp còn 1 vụ nên
không cần chia lô), rồi đẩy thẳng vào STATE `ungVien`/`dsChon` (tự động tick chọn) — **CHƯA ghi gì
vào Postgres**, giống mọi vụ khác ở màn "chuẩn bị", chỉ thật sự ghi khi bấm "Chốt danh sách" ở màn
sau.

**"Quét QR nộp lưu kho" — KHÔNG phải bug, tính năng đã có sẵn từ trước (`quetTraCuu` trong
`ManSoLuuTru`, xem mục "Tính năng mới: Nộp lưu kho" đầu file) nhưng CHỈ hiện SAU KHI đã Chốt ít
nhất 1 lần** (`ManChiTietDot` router: `dot.trangThai === "dang_mo" && dsHoSo.length === 0` vẫn còn
ở màn `ManChuanBiDanhSach`/`ManXemTruocChot`; chỉ khi `dsHoSo.length > 0` — tức đã Chốt — mới sang
`ManSoLuuTru` có ô "Quét QR tra cứu / xác nhận lên Kho" hiện to rõ **Số {nhanSo}** và
**{thoiHanBaoQuan}** đúng như mô tả). Lý do hợp lý về nghiệp vụ: Số lưu trữ (`nhanSo`) chỉ được
SINH RA lúc Chốt, quét trước đó sẽ không có gì để tra. "Đợt nộp lưu năm 2025" thật của người dùng
vẫn đang "Đang mở" (chưa Chốt lần nào) nên chưa tới được màn đó — **KHÔNG tự ý bấm Chốt lên dữ liệu
thật thay người dùng** (đây là hành động sinh số cố định + khoá đợt, ảnh hưởng cách đánh số 1280+
hồ sơ thật, cần người dùng tự bấm sau khi đã ưng ý với danh sách). Đã thêm 1 câu gợi ý vào banner
cảnh báo màu vàng ở `ManXemTruocChot` (ngay trước khi Chốt) nhắc rõ "màn tiếp theo sẽ có ô Quét QR
tra cứu" để không bị hỏi lại câu này lần sau.

**Đã kiểm chứng bằng Supabase production thật** trên chính "Đợt nộp lưu năm 2025" (1280 vụ) —
lọc theo KSV "Đặng Văn Sỹ" ra đúng 29 dòng (khớp số "Đã nộp 20/29" ở panel Tình trạng nộp theo
KSV); bấm "Bỏ chọn tất cả (đang hiện)" → tổng đã chọn giảm đúng 1280→1251 (= 29), 0 dòng nào trong
bảng lọc còn tick; bấm lại "Chọn tất cả (đang hiện)" → khôi phục đúng 1280. "+ Thêm vụ" tìm
"Nguyễn Văn" ra nhiều kết quả hợp lệ (đều đã giải quyết, chưa có trong `ungVien`) — bấm thêm 1 kết
quả (`QLVA_E01.53_2401_0054`), xác nhận tổng `ungVien` tăng đúng 1280→1281 VÀ tự động được tick
(tổng đã chọn cũng 1281), dòng mới hiện đầy đủ dữ liệu đúng ở bảng (KSV/Hình thức GQ/Số-ngày QĐ
KTVA/Số QĐ GQ/Thời hạn bảo quản/Vấn đề cần bổ sung). Không có ghi nào vào Postgres trong toàn bộ
quá trình kiểm chứng (chỉ 2 lượt đọc `.where().get()` để kiểm tra trùng đợt/tính `daNop`) — đã tải
lại trang sau khi test để trả `ungVien` về đúng 1280 gốc, không để lại trạng thái test trên tab.
0 lỗi console.

## Nộp lưu kho: quét liên tục tự động xác nhận + cảnh báo quét trùng + cột Số bút lục/Số tập (2026-07-26)

Người dùng phản hồi thêm 3 việc ở màn `ManSoLuuTru`/sổ in: (1) quét liên tục nhiều hồ sơ nên tự
động xác nhận "đã lên Kho" cho hồ sơ QUÉT TRƯỚC ĐÓ, không bắt bấm nút mỗi lần (tiết kiệm thao tác
đúng nhịp đầu đọc QR); (2) quét lại 1 hồ sơ đã xử lý phải cảnh báo tránh nhầm; (3) sổ in cần thêm
cột Số bút lục/Số tập để đối chiếu bìa hồ sơ giấy.

**`quetTraCuu` viết lại** — trước khi hiển thị kết quả quét MỚI, tự gọi `xacNhanDaLenKho(ketQuaQuet
cũ)` nếu hồ sơ đó hợp lệ và CHƯA có `thoiDiemQuetXacNhan` (tái dùng nguyên hàm đã có, kèm toast xác
nhận — không cần cờ "silent" riêng, toast đó đúng là tín hiệu người dùng cần biết "đã tự xác nhận
hộ"). 2 nhánh cảnh báo "quét trùng": (a) quét lại ĐÚNG hồ sơ đang hiển thị ngay lập tức — so trực
tiếp `ketQuaQuet.maVuAn`, KHÔNG dựa vào `dsHoSo` (tránh race vì Realtime có thể chưa kịp phản ánh
đúng lúc vừa tự xác nhận xong); (b) quét 1 hồ sơ đã có `thoiDiemQuetXacNhan` từ trước (phiên trước
hoặc đã tự xác nhận từ lâu) — dữ liệu này lấy thẳng từ `dsHoSo` (không racy, đã tồn tại từ trước).

**Cột "Số bút lục"/"Số tập"** — 2 field MỚI trên `hoSoNopLuuKho` (`soButLuc` text, `soTapHoSo`
text), snapshot từ đúng lần **"Nộp hồ sơ lưu trữ" GẦN NHẤT** của vụ đó (sự kiện `giao_nhan_ho_so`
có `loaiGiaoDich=="nhan"` + phiên đó `laLuuTru==true` — cùng tiêu chí đã dùng để tính `daNop`, xem
mục "Vấn đề cần bổ sung" ở trên) — **KHÔNG có trên `vuan`**, chỉ tồn tại trên sự kiện giao nhận
(ghi tay ở `DongGiaoNhan`, xem mục "Giao nhận hồ sơ" ở dưới). Hàm dùng chung mới
`layThongTinNopLuuTruMotVu(maVuAn)` (đặt cạnh `laySoQdGiaiQuyetNopLuuKho`) cho `themVuThuCong` và
`chenVaoSau` (xử lý đúng 1 vụ); `taiDuLieu` (xử lý hàng loạt cho cả `ungVien`) viết join riêng dùng
lại đúng `giaoNhanDocs` đã tải sẵn cho `daNop`, không query thêm. Rộng ra đủ 5 nơi: bảng ứng viên,
bảng xem trước, sổ trên màn hình, kết quả quét tra cứu, **và sổ in** (`InSoLuuTruModal`, yêu cầu
chính) + Excel xuất theo KSV.

**✅ ĐÃ CHẠY ALTER TABLE thật lên Supabase (2026-07-26, sau khi Dũng cung cấp mật khẩu DB)** — lúc
code ban đầu thiếu mật khẩu (không có sẵn trong env, theo đúng quy tắc "không ghi vào repo"), đã
sửa `add_nop_luu_kho_2026-07-23.sql` (CREATE TABLE gốc, vì lúc đó nhánh chưa merge/deploy) và
`schema.sql` — 2 cột `soButLuc`/`soTapHoSo` (text, nullable). Code JS đã kiểm chứng AN TOÀN khi
cột CHƯA tồn tại: `batch_commit` RPC tự lọc bỏ field không khớp cột nào của bảng (không lỗi, chỉ
im lặng không ghi được 2 field mới) — xác nhận qua đọc trực tiếp 1 dòng `hoSoNopLuuKho` thật, thiếu
hẳn 2 key này. Sau khi có mật khẩu, đã chạy đúng 2 lệnh sau qua Session pooler (script Node tạm
trong scratchpad, dùng package `pg` cài tạm rồi gỡ ngay sau, mật khẩu chỉ truyền qua biến môi
trường lúc chạy, không ghi vào file nào — đúng quy tắc `supabase/README.md`):
```sql
alter table "hoSoNopLuuKho" add column "soButLuc" text;
alter table "hoSoNopLuuKho" add column "soTapHoSo" text;
notify pgrst, 'reload schema';
```
Xác nhận qua `information_schema.columns`: cả 2 cột đã tồn tại đúng kiểu `text`. **Đã kiểm chứng
thêm 1 vòng round-trip GHI THẬT qua UI** (đợt TEST riêng, 1 vụ có sẵn Số bút lục "88" từ trước) —
Chuẩn bị danh sách → Xem trước → Chốt (qua đúng modal gõ mã xác nhận) → đọc thẳng lại document
`hoSoNopLuuKho` vừa tạo qua Postgres → xác nhận `soButLuc: "88"` đã LƯU THẬT (khác lần kiểm chứng
trước chỉ xác nhận HIỂN THỊ đúng, chưa xác nhận LƯU được). Đã dọn sạch đợt TEST ngay sau đó. Từ nay
tính năng "Số bút lục"/"Số tập" hoạt động đầy đủ trên production, không còn phần nào dang dở.

**Đã kiểm chứng phần join (soButLuc/soTapHoSo) bằng Supabase production thật** — mở lại
`ManChuanBiDanhSach` cho 1 đợt mới, thấy đúng 3 giá trị Số bút lục thật (88/172/187) khớp với các
vụ ĐÃ được nộp hồ sơ lưu trữ trước đó, xác nhận join lấy đúng dữ liệu nguồn dù cột đích chưa tồn
tại để LƯU (chỉ hiển thị tại chỗ, chưa ghi được xuống Postgres cho tới khi ALTER TABLE). Phần
`quetTraCuu`/`xacNhanDaLenKho` viết lại lúc đó CHƯA kiểm chứng trực tiếp qua thao tác quét thật, chỉ
kiểm chứng gián tiếp qua đọc lại logic — **đã kiểm chứng đầy đủ qua UI thật SAU ĐÓ** (đợt TEST
riêng, 2 vụ, gõ mã QR + Enter qua input thật, chặn `addToast` để bắt đúng nội dung toast): quét vụ
1 rồi quét sang vụ 2 → vụ 1 tự động có "✓ <ngày>" ở cột Lên Kho (không cần bấm nút); quét lại ĐÚNG
vụ 2 đang hiển thị → toast cảnh báo đúng "... vừa quét rồi — không quét trùng."; quét lại vụ 1 (đã
tự xác nhận từ trước, không phải vụ đang hiển thị) → toast đúng thứ tự: tự xác nhận vụ 2 (đang hiển
thị, chưa xác nhận) trước, RỒI mới cảnh báo "... đã được xác nhận lên Kho từ trước — quét trùng."
cho vụ 1. Cả 3 tình huống đúng như thiết kế. Đã dọn sạch đợt TEST sau khi kiểm chứng.

**⚠ PHÁT HIỆN QUAN TRỌNG lúc kiểm chứng, cần Dũng xác nhận lại**: "Đợt nộp lưu năm 2025" (đợt thật
1280 vụ, trước đó luôn thấy ở trạng thái "Đang mở" + 0 hồ sơ suốt nhiều lượt kiểm chứng trong ngày
26/07) — kiểm tra lại thì phát hiện đã **THỰC SỰ được Chốt lúc 04:49:37 rồi Mở khoá lại chỉ 3 GIÂY
SAU (04:49:40)**, bởi tài khoản **`b10verify@local.com`** (không phải tài khoản `admin@qlva.local`
dùng trong phiên này) — sinh đủ `soThuTu`/`nhanSo` **1 → 1280 thật** cho toàn bộ 1280 hồ sơ, và
**1 hồ sơ đã có `thoiDiemQuetXacNhan` thật** (đã được quét/xác nhận "đã lên Kho" thật). Nhịp
Chốt→Mở khoá cách nhau đúng 3 giây gợi ý đây là 1 phiên làm việc/agent KHÁC đang test tính năng
Chốt/Mở khoá — rất có thể lỡ thao tác trên đúng đợt SẢN XUẤT thật thay vì tạo đợt test riêng (đúng
rủi ro đã cảnh báo ở [[qlahsp2_main_concurrent_edits]] — nhiều phiên cùng sửa 1 cơ sở dữ liệu thật).
**KHÔNG tự ý sửa/hoàn tác gì** (không biết chắc đây là hành động của Dũng hay phiên khác, hoàn tác
nhầm còn tệ hơn) — chỉ dọn đúng 1 đợt TEST của riêng phiên này (`"TEST - xoá sau khi kiểm chứng
quét liên tục"`, tạo lúc kiểm chứng, chưa Chốt, đã xoá sạch). **Cần hỏi lại Dũng**: 1280 hồ sơ đã
có Số lưu trữ 1-1280 chính thức chưa (nếu đúng ý muốn thì không cần làm gì thêm, đợt vẫn "Đang mở"
nên vẫn sửa được), và 1 hồ sơ đã "đã lên Kho" đó có đúng thật sự đã đưa lên Kho chưa hay là do quét
test.

## Nộp lưu kho: thay "Tính lại toàn bộ STT" bằng luồng xem-trước-rồi-áp-dụng (2026-07-26)

Người dùng phản hồi trực tiếp về nút "Tính lại toàn bộ số thứ tự" cũ (đã có sẵn ở `ManSoLuuTru` từ
đầu — ghi thẳng `soThuTu`/`nhanSo` mới cho MỌI hồ sơ ngay khi bấm, không có bước xem trước): muốn
sửa/chỉnh đợt đã chốt thì tốt nhất là **quay lại đúng luồng "chuẩn bị danh sách → xem trước" quen
thuộc**, chỉ cần thêm 1 cột "STT đã chốt" (số cũ) để tự so sánh trước khi quyết định thêm/chèn/đổi
thứ tự — và **yêu cầu này thay thế hẳn** nút "Tính lại toàn bộ" (đã xoá, không giữ song song 2 cơ
chế làm cùng 1 việc).

**2 màn mới, đặt ngay trước `ManSoLuuTru`**: `ManSuaLaiDanhSachDaChot` (tương đương
`ManChuanBiDanhSach` nhưng dành cho đợt ĐÃ CÓ hồ sơ) → `ManXemTruocSuaDoi` (tương đương
`ManXemTruocChot` nhưng ghi UPDATE/INSERT/DELETE thay vì chỉ INSERT). Khác biệt quan trọng nhất so
với `ManChuanBiDanhSach`: **nguồn ứng viên ban đầu là CHÍNH `dsHoSo` đã có** (không phải query lại
theo khoảng tháng/năm) — đảm bảo KHÔNG BAO GIỜ làm "rơi mất" 1 hồ sơ đã lưu chỉ vì nó nằm ngoài
khoảng ngày mặc định (VD hồ sơ được thêm thủ công từ trước qua "+ Thêm vụ" với ngày giải quyết xa
ngoài phạm vi lọc gốc). Thêm hồ sơ MỚI hoàn toàn dùng lại đúng cơ chế "+ Thêm vụ" (tìm không giới
hạn ngày) — **cố tình KHÔNG dùng chung code với `ManChuanBiDanhSach`** (2 component phục vụ 2 mục
đích/2 hình dạng dữ liệu nguồn khác nhau — thêm nhiều prop điều kiện vào 1 component sẽ làm nó khó
đọc hơn là chấp nhận trùng lặp 1 đoạn ngắn).

**KHÔNG hiện cột "Mã vụ"** ở cả 2 màn mới (khác `ManChuanBiDanhSach`) — theo đúng quy ước đã có sẵn
của mọi màn "sổ" (`ManSoLuuTru` chính, `InSoLuuTruModal`): `hoSoNopLuuKho` không snapshot
`maNganhCap`/`maNoiSinh` nên `hienThiMa()` sẽ ra rỗng cho các dòng lấy từ `dsHoSo` — chỉ dùng
`hienThiMa()` được ở panel "+ Thêm vụ" (kết quả tìm là object "vuan" đầy đủ, có sẵn field đó).

**Ghi khi "Áp dụng thay đổi"** — với mỗi hồ sơ trong danh sách đã sắp xếp lại: có `_hoSoId` (đã có
sẵn trong đợt từ trước) → `batch.update(doc(_hoSoId), {...})`, CHỈ patch đúng field liệt kê
(`soThuTu`/`nhanSo`/snapshot...) — **KHÔNG đụng `thoiDiemQuetXacNhan`/`ngayTao`/`nguoiTao`** (giữ
nguyên trạng thái "đã lên Kho" dù số đổi, và giữ đúng lịch sử tạo ban đầu); không có `_hoSoId` (mới
thêm) → `batch.set(doc(), {...})`, giống hệt `chot()`. Hồ sơ có trong `dsHoSoCu` (đợt trước khi sửa)
nhưng KHÔNG còn trong danh sách cuối (bị bỏ tick) → `batch.delete` — banner cảnh báo rõ tên các hồ
sơ sẽ bị xoá TRƯỚC khi bấm Áp dụng, đúng tinh thần "không âm thầm mất dữ liệu".

**Cột "STT đã chốt" (`sttDaChot`)** hiện ở cả 2 màn — màn "sửa lại" hiện cạnh checkbox (số cũ hoặc
badge "Mới" nếu là hồ sơ vừa thêm), màn "xem trước" hiện CẠNH cột "STT mới" (vị trí `i+1` sau khi
sắp xếp lại) để so sánh trực tiếp — tô màu hổ phách nếu số thực sự đổi (`sttDaChot !== String(i+1)`)
để dễ nhận ra ngay những dòng bị ảnh hưởng, thay vì phải dò cả bảng.

**Đã kiểm chứng bằng Supabase production thật** — trên chính "Đợt nộp lưu năm 2025" (1280 vụ, xem
mục "phát hiện quan trọng" ngay trên: đợt này ĐÃ chốt thật rồi mở khoá lại, router tự động chuyển
đúng sang `ManSoLuuTru` thay vì `ManChuanBiDanhSach` — xác nhận điều kiện `dsHoSo.length > 0` hoạt
động đúng như thiết kế). Bấm "✎ Sửa lại danh sách" → đúng 1280 vụ hiện ra, cột "STT đã chốt" khớp
1-1280 thật; bấm "Xem trước thay đổi" → cột "STT mới" trùng khớp "STT đã chốt" ở mọi dòng đã xem
(đúng kỳ vọng, vì thứ tự chưa hề đổi — chưa thêm/bớt gì); "+ Thêm vụ" tìm lại đúng
"QLVA_E01.53_2401_0054" (Nguyễn Văn Nam, vẫn chưa nằm trong đợt nào — xác nhận qua kết quả tìm ra
đúng 1 dòng). **CHỦ ĐỘNG KHÔNG bấm "Áp dụng thay đổi"** trên đợt thật này (dù sẽ là no-op về mặt số
liệu, vẫn là 1 lượt ghi hàng loạt 1280 document thật không cần thiết cho việc kiểm chứng) — thoát ra
bằng "← Quay lại chỉnh sửa" rồi "Huỷ, quay lại sổ", xác nhận đợt trở về ĐÚNG trạng thái ban đầu
(1280 vụ — 1/1280 đã lên Kho), không có ghi nào xảy ra trong suốt quá trình test. 0 lỗi console.

**Đã bấm "Áp dụng thay đổi" thật, trên đợt TEST độc lập** (không phải đợt thật — đúng như "Chưa làm"
đã ghi lúc đầu, quay lại làm ngay sau đó): tạo "TEST - kiem chung sua lai danh sach da chot", thêm
3 vụ thật qua "+ Thêm vụ" (Công ty CP G20, Nguyễn Đức An, Nghiêm Thu Hằng), Chốt (sinh đúng STT
1/2/3) — **gặp 1 giới hạn môi trường test**: nút "Mở khoá" dùng `window.confirm()` thật, native
dialog này CHẶN ĐỨNG mọi `javascript_tool`/`computer` sau đó (treo 30s, kể cả `screenshot`) — không
có API dismiss dialog qua các tool hiện có; workaround: `navigate` sang 1 URL khác (`https://
example.com`) để trình duyệt tự đóng dialog, tab bị đá sang origin khác nên phải mở tab mới rồi
`db.collection("dotNopLuuKho").doc(id).update({trangThai:"dang_mo",...})` thẳng để bỏ qua nút (bản
thân `moKhoa()` không đổi, chỉ là hạn chế của môi trường kiểm chứng, không phải bug — ĐÃ CÓ TỪ
TRƯỚC, không phải do đợt sửa lần này gây ra).
Sau khi mở khoá: bấm "✎ Sửa lại danh sách" → bỏ tick "Nguyễn Đức An" + thêm "Nguyễn Văn Nam" qua
"+ Thêm vụ" → "Xem trước thay đổi" xác nhận đúng: dòng "Công ty CP G20" giữ STT mới=1=STT đã chốt
(không đổi), "Nghiêm Thu Hằng" STT đã chốt=3 → STT mới=2 (dồn lên vì có 1 dòng bị xoá), "Nguyễn Văn
Nam" hiện badge "Mới" ở cột STT đã chốt, banner cảnh báo đúng tên "Nguyễn Đức An" sẽ bị xoá → bấm
"Áp dụng thay đổi" → xác nhận trực tiếp qua Postgres: hồ sơ "Nguyễn Đức An" đã bị XOÁ hẳn (0 kết
quả `where maVuAn`), 2 hồ sơ còn lại đúng `soThuTu`/`nhanSo` mới.
**Kiểm tra riêng phần quan trọng nhất — "Đã lên Kho" phải sống sót qua lần sửa**: đặt tay
`thoiDiemQuetXacNhan` cho dòng "Công ty CP G20" (giả lập đã quét xác nhận), sửa lại danh sách 1 lần
nữa (bỏ tiếp "Nguyễn Văn Nam", ép STT đổi lại), Áp dụng, rồi đọc thẳng lại ĐÚNG document đó qua
Postgres — xác nhận **`thoiDiemQuetXacNhan` vẫn giữ nguyên giá trị đã đặt VÀ document giữ nguyên
đúng `id` cũ** (không bị xoá-tạo-lại) — đúng thiết kế `batch.update()` chỉ patch field liệt kê.
Đã dọn sạch hoàn toàn đợt TEST (2 hồ sơ còn lại + chính `dotNopLuuKho`) ngay sau khi kiểm chứng,
xác nhận lại "Đợt nộp lưu năm 2025" thật vẫn nguyên 1280 hồ sơ, không hề bị đụng vào trong suốt quá
trình test này. 0 lỗi console liên quan tới thay đổi này.

## Nộp lưu kho: thêm "Huỷ chốt hoàn toàn" — quay lại ĐÚNG trạng thái trước khi Chốt (2026-07-26)

Người dùng làm rõ lại ý muốn ngay sau mục "Sửa lại danh sách" ở trên: không phải muốn 1 công cụ
SỬA có kiểm soát (giữ nguyên phần không đổi) mà muốn **quay lại HẲN trạng thái CHÍNH XÁC như lúc
CHƯA từng bấm "Chốt danh sách"** — 2 lý do: (1) đề phòng ấn nhầm nút Chốt, (2) đang giai đoạn test,
cần bật/tắt qua lại giữa 2 trạng thái "chuẩn bị"/"đã chốt" nhiều lần cho tiện, không muốn để lại
STT/hồ sơ rác mỗi lần thử. Đây là tính năng THỨ 2, khác hẳn "Sửa lại danh sách" (vẫn giữ nguyên,
không thay thế) — 1 cái là sửa có kiểm soát, 1 cái là undo toàn bộ về vạch xuất phát.

**`huyChotHoanToan`** (`ManSoLuuTru`) — nút **"↩ Huỷ chốt hoàn toàn"** (đỏ, cảnh báo rõ số hồ sơ sẽ
mất + cảnh báo riêng nếu có hồ sơ đã "đã lên Kho" sẽ mất trạng thái đó luôn) hiện ở CẢ 2 nhánh
trạng thái (`daChot`/`!daChot`) — không bắt phải Mở khoá trước mới huỷ được, đúng nhu cầu "ấn nhầm
Chốt thì sửa ngay lập tức" mà không cần thêm 1 bước trung gian. Khi xác nhận: xoá TOÀN BỘ
`hoSoNopLuuKho` của đợt (theo lô tối đa 400/batch, cùng cỡ lô cascade xoá vụ án đã dùng ở
`XoaVuAnModal`) + reset `dotNopLuuKho` về **CHÍNH XÁC** trạng thái lúc mới tạo: `trangThai:
"dang_mo"`, `ngayChot`/`nguoiChot`/`ngayMoKhoaGanNhat`/`nguoiMoKhoaGanNhat` đều về `null` (không chỉ
đổi `trangThai` — xoá sạch luôn MỌI dấu vết từng Chốt/Mở khoá, đúng nghĩa "chưa từng bấm Chốt" chứ
không phải chỉ "đang mở khoá"). `dsHoSo.length` về 0 sau khi xoá → router (`ManChiTietDot`) TỰ ĐỘNG
quay lại đúng `ManChuanBiDanhSach` (không cần code thêm gì ở router, tận dụng điều kiện đã có).

**Đã kiểm chứng bằng Supabase production thật, thao tác qua ĐÚNG nút thật (không phải giả lập tay)**
— tạo đợt TEST, chốt 3 vụ thật, bấm "↩ Huỷ chốt hoàn toàn": **ghi đè tạm `window.confirm` để tự
động chấp nhận** (môi trường test không có cách dismiss dialog `confirm()` thật — xem ghi chú môi
trường ở mục dưới — nhưng vẫn bắt được ĐÚNG NỘI DUNG cảnh báo hiện ra trước khi tự chấp nhận, xác
nhận UI/logic gọi đúng), xác nhận qua Postgres: `hoSoNopLuuKho` của đợt còn **đúng 0** dòng,
`dotNopLuuKho` có `trangThai:"dang_mo"` và cả 4 field `ngayChot`/`nguoiChot`/`ngayMoKhoaGanNhat`/
`nguoiMoKhoaGanNhat` đều `null` — và trên UI, đợt tự động hiện lại ĐÚNG màn "Chuẩn bị danh sách"
(form lọc tháng/năm) như chưa từng Chốt. Đã khôi phục `window.confirm` gốc và xoá sạch đợt TEST
ngay sau đó, xác nhận lại "Đợt nộp lưu năm 2025" thật vẫn nguyên 1280 hồ sơ. 0 lỗi console.

**Ghi chú môi trường test (không phải bug)**: `window.confirm()` thật (native browser dialog) chặn
đứng MỌI lệnh điều khiển trình duyệt test tiếp theo (kể cả `screenshot`) cho tới khi dialog được
đóng — môi trường test không có API dismiss dialog trực tiếp, chỉ có cách vòng qua bằng
`navigate` sang 1 URL khác (trình duyệt tự đóng dialog khi điều hướng đi) rồi quay lại, hoặc ghi đè
tạm `window.confirm` TRƯỚC khi bấm nút (như đã làm ở trên) — đã gặp và xử lý y hệt cách này khi
kiểm chứng "Sửa lại danh sách" (mục ngay trên, thao tác Mở khoá). Đây là hạn chế CỦA MÔI TRƯỜNG
KIỂM CHỨNG, không phải bug ứng dụng — người dùng thật bấm nút vẫn thấy dialog `confirm()` bình
thường, không có gì khác biệt.

## Nộp lưu kho: gõ mã xác nhận cho "Chốt danh sách"/"Huỷ chốt hoàn toàn" (2026-07-26)

Người dùng yêu cầu thêm an toàn cho 2 nút dễ ảnh hưởng hàng loạt hồ sơ nếu bấm nhầm: "Chốt danh
sách" (sinh Số lưu trữ cố định lần đầu) và "↩ Huỷ chốt hoàn toàn" (xoá sạch, không hoàn tác). Thay
vì `window.confirm()` (dễ bấm "OK" theo phản xạ mà không đọc kỹ), dùng lại ĐÚNG pattern "gõ mã xác
nhận ngẫu nhiên" đã có ở `XoaVuAnModal` (`taoMaXacNhanNgauNhien`, bộ ký tự loại bỏ 0/O/1/l/I) —
tách thành component dùng chung mới **`XacNhanMaModal`** (đặt trước `ManXemTruocChot`), nhận
`canhBao` (nội dung cảnh báo tự do) + `onXacNhan` (hàm thực thi, chỉ bấm được khi gõ đúng mã).

**Áp dụng cho 2 nút**: "Chốt danh sách" (`ManXemTruocChot`, bấm mở modal thay vì gọi thẳng `chot()`)
và "↩ Huỷ chốt hoàn toàn" (`ManSoLuuTru`, bỏ hẳn `window.confirm()` cũ, dùng modal). **KHÔNG áp
dụng cho "Chốt lại"/"Mở khoá"** — 2 nút đó chỉ đổi `trangThai` (không mất dữ liệu, dễ bấm lại/mở
khoá lại nếu nhầm), rủi ro thấp hơn hẳn 2 nút trên nên giữ nguyên (Mở khoá vẫn `confirm()` thường,
Chốt lại không cần xác nhận gì thêm).

**Đã kiểm chứng đầy đủ qua UI thật trên đợt TEST độc lập** (tạo đợt, chọn 2 vụ thật, Xem trước, bấm
"Chốt danh sách") — modal hiện đúng mã ngẫu nhiên (VD "A7SB"); nút "Xác nhận Chốt" `disabled=true`
khi ô trống, VẪN `disabled=true` khi gõ mã SAI ("WRNG"), chuyển `disabled=false` NGAY khi gõ đúng
"A7SB"; bấm xác nhận → đợt chuyển đúng "Đã chốt (khoá)" với 2 hồ sơ, sinh đúng STT. Đã dọn sạch đợt
TEST ngay sau đó.

## Nộp lưu kho: xác nhận sự cố "Đợt nộp lưu năm 2025" ngày 2026-07-26 là THAO TÁC CHỦ Ý của người dùng

Mục ⚠ SỰ CỐ ngay dưới đây (viết lúc phát hiện, để nguyên làm lịch sử điều tra) ban đầu nghi ngờ đây
là 1 phiên khác lỡ bấm nhầm trên dữ liệu thật. **Người dùng đã xác nhận trực tiếp ngay sau đó: "tôi
ấn hủy chốt để quay lại bước cũ đấy"** — tức CHÍNH Dũng chủ động dùng đúng nút "↩ Huỷ chốt hoàn
toàn" (vừa build xong) để quay lại màn chuẩn bị danh sách, không phải sự cố/thao tác nhầm. Không
cần khôi phục gì — đúng ý muốn, họ tự chuẩn bị lại danh sách khi cần.

**Bài học vẫn giữ nguyên giá trị** dù không phải sự cố thật: xác nhận `huyChotHoanToan` vẫn NÊN có
audit trail riêng (`nguoiHuyChot`/`ngayHuyChot`) trong tương lai — lần này may mắn tự làm rõ được
nhờ hỏi trực tiếp người dùng, nhưng nếu là 1 tài khoản khác trong nhóm 4 cán bộ thì vẫn không truy
được ai đã bấm. Việc đó vẫn nên làm ở phiên sau, xem "Cần bổ sung ở phiên sau" trong mục dưới.

## ⚠ SỰ CỐ DỮ LIỆU THẬT (ĐÃ XÁC NHẬN LÀ THAO TÁC CHỦ Ý, xem mục ngay trên): "Đợt nộp lưu năm 2025" bị xoá sạch 1280 hồ sơ ngay trong lúc code (2026-07-26)

**Phát hiện ngay sau khi code xong mục "gõ mã xác nhận" ở trên** — mở lại app để test thì thấy
"Đợt nộp lưu năm 2025" hiện thẳng ra màn "Chuẩn bị danh sách" (đúng ra phải là sổ, vì đợt này đã có
1280 hồ sơ suốt cả ngày 26/07). Kiểm tra trực tiếp qua Postgres xác nhận: **`hoSoNopLuuKho` của
đợt này còn ĐÚNG 0 dòng** (trước đó — xác nhận lại nhiều lần trong ngày, gần nhất ngay trước khi
bắt đầu code mục "gõ mã xác nhận" — vẫn còn đủ 1280, kể cả 1 hồ sơ đã "đã lên Kho" thật), và
`dotNopLuuKho` của đợt có `trangThai:"dang_mo"`, `ngayChot`/`nguoiChot`/`ngayMoKhoaGanNhat`/
`nguoiMoKhoaGanNhat` đều `null` — **khớp CHÍNH XÁC dấu vết hàm `huyChotHoanToan` vừa code/deploy
trong phiên làm việc ngay TRƯỚC ĐÓ** (mục "Huỷ chốt hoàn toàn" phía trên) để lại sau khi chạy.

**Đã tự rà soát kỹ toàn bộ log thao tác của chính phiên này trong khoảng thời gian đó** — không có
lệnh `.delete()`/`.update()` nào nhắm vào đúng `dotId` của "Đợt nộp lưu năm 2025" được gọi bởi
chính phiên này trong khoảng thời gian tương ứng (mọi thao tác lúc đó chỉ là sửa file cục bộ qua
`Edit` + vài lượt bấm nút KHÔNG THÀNH CÔNG trên UI, không có ghi nào tới Postgres) — **kết luận: rất
có khả năng đây là 1 phiên làm việc/tài khoản KHÁC** (có thể chính Dũng, hoặc 1 phiên Claude Code
khác đang chạy song song) **đã tự bấm thử tính năng "Huỷ chốt hoàn toàn" MỚI (vừa commit ngay trước
đó) trên đúng đợt SẢN XUẤT thật thay vì tạo đợt test riêng** — đúng y hệt kiểu rủi ro đã gặp trước
đó cùng ngày (xem mục "phát hiện quan trọng" ở "Nộp lưu kho: 'Vấn đề cần bổ sung'..." phía trên, vụ
Chốt-rồi-Mở-khoá-3-giây bởi `b10verify@local.com`) — 2 sự cố cùng 1 ngày, cùng 1 đợt, đều là dấu
hiệu nhiều phiên/tài khoản đang thao tác đồng thời lên CHÍNH đợt lưu kho thật của Dũng thay vì môi
trường test cô lập, xem [[qlahsp2_main_concurrent_edits]].

**KHÔNG tự ý khôi phục/tái tạo lại 1280 hồ sơ** — dù về lý thuyết có thể tự tạo lại (dữ liệu gốc
`vuan` hoàn toàn KHÔNG bị đụng vào, `huyChotHoanToan`/tính năng liên quan chỉ xoá `hoSoNopLuuKho`,
chưa từng chạm tới `vuan`, nên chạy lại "Chuẩn bị danh sách → Xem trước → Chốt" gần như chắc chắn
sẽ sinh lại đúng 1280 vụ tương tự với đúng thứ tự cũ nhờ `sapXepDsNopLuuKho` đã sửa đúng và ổn
định) — **nhưng KHÔNG BIẾT CHẮC đây có phải ý muốn thật của Dũng hay không** (có thể họ đang cố
tình muốn làm lại từ đầu), tái tạo nhầm khi chưa hỏi còn tệ hơn việc để trống chờ xác nhận. **Cần
hỏi lại Dũng ngay khi có thể**: (1) việc xoá sạch đợt này có phải chủ ý không — nếu có thì không
cần làm gì thêm, cứ chuẩn bị lại danh sách bình thường; (2) nếu KHÔNG chủ ý, xác nhận trước khi tự
động chạy lại "Chuẩn bị danh sách → Xem trước → Chốt" để khôi phục — lưu ý riêng 1 hồ sơ từng "đã
lên Kho" thật sẽ KHÔNG tự khôi phục lại trạng thái đó, cần Dũng nhớ lại và quét xác nhận lại tay.

**Bài học rút ra, đã áp dụng ngay** — chính nút "Huỷ chốt hoàn toàn" gây ra sự cố này lại là đúng
động lực ban đầu khiến người dùng yêu cầu thêm "gõ mã xác nhận" (mục ngay phía trên) — càng củng cố
lý do cần tính năng đó. Riêng `huyChotHoanToan` **CHƯA ghi lại "ai đã bấm"** (khác `chotLai`/
`moKhoa` đều có `nguoiChot`/`nguoiMoKhoaGanNhat`) — đây là khoảng trống thật sự trong thiết kế, làm
sự cố này không thể truy được chính xác tài khoản nào đã bấm. **Cần bổ sung ở phiên sau**: ghi thêm
`nguoiHuyChot`/`ngayHuyChot`/`soHoSoDaXoa` vào audit trail của chính hành động này (có thể lưu tạm
trên 1 collection log riêng vì bản thân đợt đã bị xoá sạch hồ sơ, không còn chỗ nào giữ lại vết —
cân nhắc ghi vào `lichsuChuyenGiaiDoan` dạng 1 sự kiện hành chính mới, hoặc thêm field ngay trên
`dotNopLuuKho` trước khi field cũ bị ghi đè bởi lần Chốt kế tiếp).

## Giao nhận hồ sơ: thêm "Lý do giao nhận" + gọn KSV/ĐTV + Excel tách cột (2026-07-22, `qlahs-sup.html`)

Theo yêu cầu người dùng — 3 thay đổi độc lập cho module Giao nhận hồ sơ:

**1. Trường mới "Lý do giao nhận"** — ghi tay ngay tại dòng (giống Số bút lục/Người nhận thực tế:
không bắt buộc, không ảnh hưởng số liệu báo cáo kỳ). Field mới `lyDoGiaoNhan` trên sự kiện
`giao_nhan_ho_so`. UI dùng `<input list="ds-lydo-gnhs">` + `<datalist>` (hằng số
`GOI_Y_LY_DO_GIAO_NHAN`: "Hồ sơ trao đổi"/"Hồ sơ kết thúc điều tra"/"Hồ sơ chuyển toà"/"Hồ sơ tạm
đình chỉ"/"Hồ sơ đình chỉ"/"Hồ sơ trả điều tra bổ sung") — CHO CHỌN 1 gợi ý HOẶC tự gõ lý do khác,
không phải enum cứng, cùng pattern đã dùng cho ô KSV/ĐTV (`list="ds-canbo-gnhs"`).

**2. Gọn bảng trên màn hình — KSV/ĐTV chuyển từ 2 cột riêng xuống dưới "Tên vụ"** (theo phản hồi
người dùng: "dàn hàng ngang nhiều quá", khó xem trên màn hình bé) — hiển thị `KSV: x — ĐTV: y`
**in đậm, màu đỏ** (`font-bold text-red-600`) ngay dưới dòng QĐ KTVA trong ô Tên vụ, thay vì 2 cột
`<th>` riêng. Lúc sửa dòng (`dangSua`), 2 ô input KSV/ĐTV cũng chuyển vào trong cùng ô Tên vụ (xếp
dọc) thay vì 2 `<td>` riêng. Nhờ bớt 2 cột mà thêm được cột "Lý do giao nhận" mới mà bảng KHÔNG
rộng hơn trước (net −1 cột). Chỉ đổi ở bảng trên MÀN HÌNH (`DongGiaoNhan`) — Biên bản in A4
(`BienBanGiaoNhanIn`) giữ nguyên KSV/ĐTV là 2 cột riêng (khổ in A4 ngang không có vấn đề "màn hình
bé", giữ dạng bảng quen thuộc để ký), chỉ thêm cột "Lý do giao nhận" mới vào đó.

**3. Excel "Tải toàn bộ lịch sử" — tách "Hình thức giải quyết" thành 3 cột + thêm cột ngày gần
nhất** — trước đây 1 cột gộp text `"<Nhãn> — <Số QĐ> (<Ngày QĐ>)"` (`moTaHinhThucGiaiQuyet`) khó
lọc/sort, cộng 1 cột "Ngày giải quyết" riêng đã thêm trước đó (trùng lặp 1 phần dữ liệu). Đổi thành
đúng 3 cột riêng: **"Hình thức giải quyết"** (chỉ nhãn, VD "Đã xét xử"), **"Số QĐ"**
(`soQdGiaiQuyet`), **"Ngày QĐ"** (`ngayQuyetDinh`, thay hẳn cột "Ngày giải quyết" cũ — cùng nguồn
dữ liệu, không giữ trùng 2 cột cùng ý nghĩa). Thêm cột **"Ngày {giao/nhận} gần nhất"**
(`fmtNgayGio(moiNhat.thoiDiemGhi)`, đặt trước "Số lần"/"Lịch sử") — vụ có thể được giao/nhận nhiều
lần (`events.length > 1`), cột này cho xem nhanh lần MỚI NHẤT mà không cần mở ô "Lịch sử" ở cuối
dòng. "Lý do giao nhận" (mục 1) được thêm vào từng dòng trong ô "Lịch sử {giao/nhận}" (bên cạnh
"Người nhận"/"Bút lục"/"Quét" đã có) — không thêm cột riêng cho nó ở Excel (theo đúng pattern Số
bút lục/Người nhận thực tế cũng chỉ nằm trong "Lịch sử", không có cột riêng, vì các field này có
thể khác nhau giữa các lần quét, hợp lý hơn khi xem theo dòng thời gian thay vì 1 cột tổng).

**Hạ tầng quan trọng — cột mới cần ALTER TABLE trên Postgres thật (khác Firestore schemaless)**:
`qlahs-sup.html` chạy trên Supabase — thêm field mới vào 1 sự kiện log không tự động tạo cột như
Firestore, phải chạy DDL thật. Đã chạy `alter table "lichsuChuyenGiaiDoan" add column
"lyDoGiaoNhan" text not null default ''` + `notify pgrst, 'reload schema'` qua kết nối Postgres
trực tiếp (Session pooler, xem `supabase/README.md`) — **đã kiểm chứng lỗi thật trước khi sửa**:
thử ghi qua UI trước khi ALTER, nhận đúng lỗi `Could not find the 'lyDoGiaoNhan' column of
'lichsuChuyenGiaiDoan' in the schema cache`, sau khi ALTER xong thì ghi thành công ngay. Đã cập
nhật `supabase/schema.sql` (nguồn sự thật cho lần deploy schema tiếp theo) thêm cột này vào
`CREATE TABLE "lichsuChuyenGiaiDoan"` để không bị lệch với DB thật. Nếu cần thêm field mới tương tự
sau này, nhớ luôn kiểm tra bước ALTER TABLE này trước khi tin code đã xong — khác hẳn thói quen cũ
khi sửa `qlva.html`/Firestore (chỉ cần sửa code, không cần đụng gì tới "schema" vì Firestore không
có).

**Đã kiểm chứng bằng Playwright thật trên dữ liệu Supabase thật** (`qlahs-sup.html`, project
`eutatszoaseixchvjbtg`) — mở 1 phiên Giao thật, thêm 1 vụ thật qua "Tìm thủ công" (Nguyễn Quốc Huy),
xác nhận: ô Tên vụ hiện đúng "KSV: Quách Tiến Dũng — ĐTV: Phạm Hữu Kha" in đậm đỏ ngay dưới tên vụ;
bấm sửa dòng, chọn "Hồ sơ kết thúc điều tra" từ datalist "Lý do giao nhận", lưu — xác nhận cột hiện
đúng giá trị trên bảng VÀ ghi đúng vào Postgres thật (query trực tiếp qua `db.collection(...)`);
dựng lại đúng logic xây dựng sheet Excel (tách riêng, không phụ thuộc UI) bằng chính dữ liệu vừa
ghi — xác nhận header đủ 16 cột đúng thứ tự (Hình thức giải quyết/Số QĐ/Ngày QĐ tách riêng, có "Ngày
giao gần nhất"), dòng dữ liệu đúng giá trị, "Lịch sử giao" có đúng "Lý do: Hồ sơ kết thúc điều tra".
Đã dọn sạch dữ liệu test (xoá sự kiện + phiên test) sau khi kiểm chứng. 0 lỗi console liên quan tới
thay đổi này (ngoại trừ cảnh báo Babel kích thước file vô hại đã biết).
**Chưa kiểm chứng qua thao tác tải file Excel thật xuống đĩa** (nút "⬇ Tải toàn bộ lịch sử" trên
dữ liệu SẢN XUẤT thật có hàng nghìn dòng giao nhận — bấm thử trong lúc kiểm chứng làm treo cứng tab
trình duyệt test hàng chục giây do phải sinh hàng nghìn ảnh QR đồng bộ, môi trường test cũng không
lưu được file tải xuống ra đĩa để mở lại kiểm tra trực tiếp) — logic xây dựng sheet đã được xác
nhận đúng qua cách trên (dựng lại chính xác cùng đoạn code với dữ liệu thật), nhưng nên tự tải thử
1 lần trên `qlahs-sup.html` thật và mở file bằng Excel để yên tâm tuyệt đối trước khi coi đây là
đã kiểm chứng đầy đủ 100%.

## Giao nhận hồ sơ: "Số tập hồ sơ", cảnh báo "đã giao lại", mở rộng Thời hạn bảo quản, sửa lỗi Giao không lưu được (2026-07-22, `qlahs-sup.html`)

Chuỗi thay đổi độc lập trong CÙNG buổi làm việc với mục "Lý do giao nhận" ngay trên (session khác,
merge lại với nhau — xem [[qlahsp2_main_concurrent_edits]] nếu cần biết thêm về rủi ro nhiều phiên
cùng sửa `main`/dữ liệu thật đồng thời), theo yêu cầu người dùng qua nhiều lượt riêng biệt:

**1. Sửa lỗi thật trên production — phiên "Giao hồ sơ" (không lưu trữ) không lưu được dòng nào có
vụ "Đã xét xử".** `luu()` trong `DongGiaoNhan` yêu cầu `bcCaoNhat` (mức án bị can cao nhất, tính
cho Thời hạn bảo quản) bất kể loại phiên, nhưng effect tải `bcCaoNhat` chỉ chạy khi `hienThoiHan`
(= phiên "Nhận hồ sơ lưu trữ"). Ở phiên Giao/Nhận thường, `bcCaoNhat` mãi mãi `undefined` → lưu
luôn thất bại, chặn cả "Lưu phiên"/"In phiên" kèm toast gây hiểu nhầm là thiếu lý do "Không tiếp
nhận". Sửa: gate cả khối tính mức án trong `luu()` bằng `hienThoiHan` (khớp đúng điều kiện của
effect tải dữ liệu).

**2. Cảnh báo "đã giao lại" trên Excel "Tải toàn bộ lịch sử"** — 1 hồ sơ đã NHẬN nhưng sau đó lại
được GIAO đi (ngày giao > ngày nhận) thì dòng đại diện (lần nhận gần nhất) không còn phản ánh đúng
thực tế đang giữ hồ sơ. Thêm cột **"Cảnh báo"** (tô đỏ đậm khi có) ở 2 sheet Nhận/Nhận lưu trữ,
hiện `"⚠ Đã giao lại ngày ..."` — đối chiếu qua TOÀN BỘ sự kiện `giao_nhan_ho_so` của cùng vụ án
(gom 1 lần từ `rows` chưa lọc theo sheet), không chỉ trong phạm vi sheet đang xuất. Sheet Giao
không có cột này (khái niệm không áp dụng).

**3. Mở rộng bảng Thời hạn bảo quản: mức án tù dưới 3 năm cũng tính 19 năm.** Bảng gốc
"thoi han bao quan.xlsx" (xem `BANG_THOI_HAN_BAO_QUAN_THEO_NAM`) chỉ phủ từ 3 năm trở lên, mức án
thấp hơn trả về `null`. Theo yêu cầu người dùng "hình phạt tù đến dưới 3 năm 5 tháng thì thời hạn
bảo quản là 19 năm" — thêm mốc floor-lookup `0: "19 năm"` (dùng chung giá trị với mốc `3` đã có,
giữ nguyên mốc `3` để đối chiếu đúng bảng gốc, không xoá) — mở rộng dải áp dụng xuống ngay trên 0
năm. Không đổi gì từ "3 năm 6 tháng" trở lên.

**4. Trường mới "Số tập hồ sơ"** (`soTapHoSo`, cột mới trên `lichsuChuyenGiaiDoan`) — ghi tay,
CÙNG NHÓM Ý NGHĨA với `soButLuc` (không bắt buộc, không ảnh hưởng số liệu báo cáo kỳ), đặt NGAY
DƯỚI ô "Số bút lục" trong CÙNG 1 ô bảng (không tách cột riêng) — tô màu hổ phách + nhãn nhỏ để
phân biệt 2 dòng. Hồ sơ thường không quá 50 tập (`NGUONG_CANH_BAO_SO_TAP_HO_SO`) — vượt ngưỡng vẫn
lưu được bình thường, chỉ hiện cảnh báo đỏ nhắc kiểm tra lại có gõ nhầm không (không chặn). Có mặt
ở cả 3 nơi: bảng phiên trên màn hình, Biên bản in A4, dòng "Lịch sử" trong Excel lịch sử.
Sau đó theo yêu cầu tiếp "cho gọn": **cột "Lý do giao nhận" (mục ở phần trên) ẩn hẳn khi phiên
`laLuuTru`** (Nộp hồ sơ lưu trữ) — không có ý nghĩa với luồng đó (đã có Hình thức giải quyết/Mức
án/Thời hạn bảo quản đủ ngữ cảnh) — dùng lại đúng prop `hienThoiHan` có sẵn, không thêm prop mới.

**Sự cố hạ tầng thật gặp phải — cột `soTapHoSo` thiếu ALTER TABLE, giống hệt bài học đã ghi ở mục
"Lý do giao nhận" phía trên (Firestore vs Postgres schemaless khác nhau).** Deploy code xong,
người dùng báo lỗi thật khi ghi qua UI: `"Could not find the 'soTapHoSo' column of
'lichsuChuyenGiaiDoan' in the schema cache"`. Đã sửa bằng kết nối trực tiếp Postgres qua Session
pooler (xem `supabase/README.md`): `alter table "lichsuChuyenGiaiDoan" add column if not exists
"soTapHoSo" text not null default ''` + `notify pgrst, 'reload schema'`, cập nhật
`supabase/schema.sql` cho khớp. **Đã kiểm chứng qua đúng đường REST API mà app dùng** (không chỉ
tin kết nối Postgres trực tiếp) — gọi `GET /rest/v1/lichsuChuyenGiaiDoan?select=id,soTapHoSo` bằng
anon key thật, nhận `200 OK` (không còn lỗi schema cache).

**Mức độ kiểm chứng của toàn bộ mục này**: chỉ mới biên dịch qua `@babel/standalone` thật (cài tạm
qua npm ngoài repo, gỡ sau khi test) để xác nhận không lỗi cú pháp JSX — **CHƯA kiểm chứng bằng
Playwright/UI thật** cho các mục 1-4 (khác các mục khác trong file này thường có bước Playwright).
Nên tự thao tác thử 1 lần qua UI thật (giao/nhận 1 vụ Đã xét xử ở phiên không lưu trữ để xác nhận
mục 1 hết lỗi, tải Excel để xem cột Cảnh báo/Số tập hồ sơ) trước khi tin tưởng tuyệt đối.

## Bug đã sửa: Biểu B10 "Tồn kỳ này" theo tội danh dùng số LIVE khi kỳ chưa chốt (2026-07-21, `qlahs-sup.html`)

Người dùng phát hiện qua file Biểu B10 tải về: đang trong giai đoạn nhập bổ sung dữ liệu nên để
cả 2 kỳ 06/2026 và 07/2026 cùng "Đang mở" (chưa chốt) — 1 vụ được ghi nhận GIẢI QUYẾT vào kỳ 07
(`kyThongKe` = kỳ 07) làm tồn của kỳ 06 trên B10 BỊ THAY ĐỔI ngay lập tức, dù đúng nguyên tắc "log
là nguồn sự thật duy nhất": số liệu của kỳ 06 chỉ phụ thuộc `kyThongKe` gắn trên sự kiện, không
phụ thuộc thời điểm xem/tải báo cáo, và 1 sự kiện gắn kỳ 07 không được phép ảnh hưởng tới kỳ 06.

**Nguyên nhân**: `tinhBieu10` (tính Biểu B10 theo TỪNG tội danh D) có nhánh "Tồn kỳ này" tách biệt
cho kỳ ĐÃ CHỐT (dùng snapshot `kyTonTD`, đúng) và kỳ CHƯA CHỐT — nhánh chưa chốt lại đọc THẲNG
`d.tonHienTai` (LIVE, tại đúng thời điểm bấm xem/tải) lọc theo D, thay vì tính theo công thức log.
Đây là CÙNG LOẠI bug đã sửa ở `tinhBaoCaoKyTuLog` cho số tồn TỔNG (không theo tội danh) — xem
"Kỳ báo cáo: cho mở kỳ mới dù kỳ trước chưa chốt + tồn cuối kỳ tính bằng log" — nhưng bản sửa đó
CHƯA lan sang `tinhBieu10` (đúng như CLAUDE.md đã ghi chú trước đây: "tonCuoiKyTheoTD... CHƯA được
sửa theo hướng này"). Khi 1 vụ đang tồn ở kỳ 06 bị đổi `trangThai` (VD sang "tam_dinh_chi") do 1
hành động Hoàn thành vụ án gắn `kyThongKe=07`, `tinhTonHienTaiTheoGD` (lọc `trangThai ==
"dang_giai_quyet"`) LẬP TỨC không còn thấy vụ đó nữa — B10 kỳ 06 (đọc live) mất đúng 1 vụ ở tội
danh đó ngay khi vừa thao tác, dù sự kiện đó đúng ra chỉ nên ảnh hưởng kỳ 07.

**Đã sửa**: thêm hàm `tonTheoLogD(d, moiArr, D, tpVu, tpBc)` trong `tinhBieu10` — tính "tồn kỳ này
theo D" bằng công thức log: `tồn đầu kỳ theo D (tonTD_truoc) + mới theo D (khởi tố trực tiếp + tách
vụ + chuyển đến + trả về, đã lọc `kyThongKe` đúng kỳ) − ra theo D (chuyển đi + trả đi + mọi hình
thức hoàn thành + nhập vụ, cùng lọc kỳThongKe)` — ÁP DỤNG CHO CẢ VỤ VÀ BỊ CAN, thay thế nhánh
`vuCoD(d.tonHienTai, D)`/`bcCoD(d.tonHienTai, D)` cũ. Nhánh kỳ ĐÃ CHỐT (dùng `kyTonTD`) giữ nguyên
không đổi. Cũng sửa luôn dòng cảnh báo chẩn đoán (`tonThucTe` so sánh tổng B10 với "thực tế" để
phát hiện vụ thiếu điều luật) — trước đây ưu tiên `soVuTon` (live) cho cả nhánh chưa chốt, đổi
sang ưu tiên `baoCao[gd].tonCuoiKy` (aggregate log-based, cùng nguồn số liệu với `tonTheoLogD` mới)
để tránh cảnh báo giả do lệch NGUỒN dữ liệu (live vs log) chứ không phải do thiếu điều luật thật.

**Đã kiểm chứng bằng dữ liệu Supabase THẬT** (`qlahs-sup.html`, project test, không phải mock) —
tính B10 kỳ 06/2026 cho tội danh "Tội hiếp dâm người dưới 16 tuổi" (Điều 142 BLHS 2025), ghi nhận
đúng 8 vụ tồn; sau đó thực hiện ĐÚNG thao tác "Hoàn thành vụ án" thật (viết batch y hệt
`HoanThanhVuAnModal`) cho 1 vụ đang tồn ở tội danh này, gắn `kyThongKe = kỳ 07/2026` (không phải
06) — tính lại B10 kỳ 06: tồn vẫn đúng **8** (không đổi, đúng kỳ vọng), trong khi tổng tồn
log-based `tonCuoiKy` của kỳ 06 cũng giữ nguyên 300 (đã đúng từ bản sửa trước, không bị đụng lại).
Đối chiếu thêm: TRƯỚC khi sửa, aggregate `tonCuoiKy` (log, 300) và `soVuTon` (live, 298) của kỳ 06
đã lệch nhau sẵn trên dữ liệu thật — bằng chứng trực tiếp bug này đã xảy ra thật trên dữ liệu sản
xuất trước khi sửa, không phải giả thuyết suông. Đã dọn sạch dữ liệu test (xoá sự kiện log vừa tạo,
khôi phục lại `trangThai`/`ngayQuyetDinh`/`kyHoanThanh`/`soQuyetDinhTamDinhChi` của vụ về đúng
trạng thái gốc, xác nhận qua lịch sử vụ chỉ còn `khoi_to_vu`+`khoi_to_bican`). 0 lỗi console liên
quan tới thay đổi này.

**Giới hạn còn lại (không thuộc phạm vi sửa lần này, ĐÃ ghi chú từ trước)**: "Tồn đầu kỳ theo tội
danh" (`tonTD_truoc`, lấy từ `kyTruoc.tonCuoiKyTheoTD`) CHỈ có giá trị đáng tin khi kỳ TRƯỚC đã
CHỐT — nếu xem trước 1 kỳ mà kỳ liền trước nó cũng đang mở (VD xem trước kỳ 07 khi kỳ 06 chưa
chốt), "tồn đầu kỳ theo tội danh" của kỳ 07 sẽ ra 0 cho mọi tội danh (kiểm chứng trực tiếp: kỳ
07/"Điều 142" ra `dt_tn_vu = -2` trong lúc test ở trên) — ĐÂY LÀ GIỚI HẠN ĐÃ BIẾT, không phải lỗi
mới, đúng lý do công cụ "Sửa lại tồn cuối kỳ theo tội danh (Biểu B10)" (Cài đặt → Import Excel,
`taiTaoTonCuoiKyTheoTDTatCa`) tồn tại — chạy công cụ đó SAU KHI chốt xong các kỳ đang nhập bổ sung,
theo đúng thứ tự thời gian, để tồn đầu kỳ theo tội danh của mọi kỳ sau đó được tính đúng.

## Import Excel: thêm lựa chọn "Giữ cả 2 vụ" khi trùng Số/Ngày QĐ KTVA (2026-07-21, `qlahs-sup.html`)

Theo yêu cầu người dùng — trước đây mỗi dòng "vụ trùng" (trùng mã vụ hoặc trùng Số+Ngày QĐ KTVA
với vụ đã có) chỉ có 1 lựa chọn nhị phân: tích "Thay vụ cũ" (đưa vụ cũ vào Thùng rác, nhập vụ mới
thay vào) hoặc để trống (bỏ qua hẳn, không nhập). Không có cách nào nhập vụ mới từ file MÀ VẪN GIỮ
NGUYÊN vụ cũ — cần thiết khi trùng Số/Ngày QĐ KTVA chỉ là trùng hợp/sai sót nhập liệu, còn thực tế
là 2 vụ hoàn toàn khác nhau.

**Đã sửa** (`ImportExcelModule`, `qlahs-sup.html`): đổi checkbox "Thay vụ cũ" mỗi dòng trùng thành
1 dropdown 3 lựa chọn — "Bỏ qua" (mặc định, giữ hành vi cũ) / "Thay vụ cũ" (giữ nguyên logic cũ:
soft-delete vụ cũ qua Thùng rác) / **"Giữ cả 2 vụ"** (mới — nhập vụ từ file như 1 vụ HOÀN TOÀN MỚI,
KHÔNG đụng gì tới vụ cũ, không soft-delete). State đổi từ `Set` (`trungDuocChon`) sang `Map`
(`trungLuaChon`, index → `"thay_the"` | `"giu_ca_2"`, vắng mặt = bỏ qua) để biểu diễn 3 trạng thái
mỗi dòng thay vì nhị phân. Guard "⚠ Có vụ tách ra từ vụ này" (`idsCoVuCon`, chặn soft-delete để
tránh mồ côi hoá vụ tách) **chỉ áp dụng cho "Thay vụ cũ"** — vô hiệu hoá đúng option đó trong
`<select>` (`disabled`), "Giữ cả 2 vụ" luôn dùng được vì không đụng gì tới vụ cũ. `ghiVaoCoSoDuLieu`
gộp cả `dsThayThe` VÀ `dsGiuCa2` vào chung `dsMoi` (xử lý y hệt vụ mới bình thường — sinh mã, ghi
log...), chỉ `dsThayThe` mới chạy thêm vòng `batch.update` soft-delete vụ cũ.

**Đã kiểm chứng bằng Playwright thật trên dữ liệu Supabase thật** (`qlahs-sup.html`, project test) —
dựng file Excel test qua `XLSX.write` ngay trong console trình duyệt (1 dòng trùng Số QĐ KTVA "1680"
+ Ngày QĐ KTVA khớp đúng 1 vụ thật đã có trong hệ thống, 1 dòng vụ mới độc lập để đối chiếu), inject
qua `DataTransfer` vào input file thật (không phải mock) — xác nhận: hệ thống nhận diện đúng "1 vụ
trùng"; chọn "Giữ cả 2 vụ" ở dropdown, nút "Ghi" đổi đúng label "(gồm 1 vụ giữ cả 2)"; bấm ghi, xác
nhận qua query Supabase thật CẢ 2 vụ cùng tồn tại với CÙNG Số/Ngày QĐ KTVA "1680"/30/08/2025 (vụ cũ
`daXoa: false`, không bị đụng vào; vụ mới tạo ra mã hệ thống riêng) — đúng ý nghĩa "giữ cả 2". Đã dọn
sạch dữ liệu test sau khi kiểm chứng (xoá `vuan`/`bican`/`lichsuChuyenGiaiDoan` liên quan). 0 lỗi
console (ngoại trừ cảnh báo Babel kích thước file vô hại đã biết).

## Import Excel: resolve "Mã ĐL" (điều luật) NGAY lúc import, sửa file mẫu (2026-07-20)

Theo yêu cầu người dùng: dữ liệu import qua Excel vẫn luôn cần chạy thêm "Chuẩn hóa tội danh /
điều luật bị can" (Cài đặt → Import Excel) sau đó, nếu không sẽ hiện "chưa xác định" — muốn file
mẫu tự hướng dẫn đúng ngay từ đầu để KHÔNG cần bước chạy lại này nữa.

**Nguyên nhân**: `ghiVaoCoSoDuLieu` (hàm ghi dữ liệu Import Excel vào CSDL) LUÔN ghi cứng
`dieuLuatBC: [""]` cho mọi bị can, bất kể cột "Tội danh" trong file có ghi đúng định dạng hay
không — hoàn toàn không tra danh mục lúc import (khác với suy nghĩ ban đầu là "tra sai", thực ra
là "không tra gì cả"). Thêm nữa, ví dụ mẫu trong chính file `Mau_Import_DanhSachAn.xlsx` lại ghi
sai định dạng ("Tội cướp tài sản (Điều 168 BLHS)" — có phần "(Điều...)" phía sau), và "Hướng dẫn"
không hề nhắc gì về cách ghi cột này — dạy người dùng đúng cách sẽ VẪN không tự nhận được vì code
không tra cứu lúc import.

**Đã sửa (2 phần)**:
1. **Gộp logic chuẩn hoá 1 cặp (tên tội danh, mã điều luật) thành 2 hàm dùng chung mới**
   `taoDanhMucDayDu`/`chuanHoaMotToiDanh` (đặt cạnh `layMaDieuLuatBiCan`) — trích nguyên logic đã
   có trong `BackfillDieuLuatBCTool` (tra theo số điều → theo tên → suy từ Điều luật cấp vụ nếu
   trống hoàn toàn), rồi cho `BackfillDieuLuatBCTool` DÙNG LẠI 2 hàm này (giảm trùng lặp) và THÊM
   MỚI: `ghiVaoCoSoDuLieu` (Import Excel) cũng gọi đúng 2 hàm này để resolve `dieuLuatBC` NGAY lúc
   ghi — không cần chạy "Chuẩn hóa" riêng sau nữa cho dữ liệu import ĐÚNG định dạng.
2. **Sửa file mẫu `Mau_Import_DanhSachAn.xlsx`** (qua script Python/openpyxl, xoá sau khi chạy —
   xem ghi chú "Tài liệu tham khảo" ở dưới về việc không có script gốc làm nguồn sự thật): thêm
   mục "6b. Cột 'Tội danh' (bị can)..." vào sheet "Hướng dẫn", giải thích rõ 2 cách ghi hợp lệ
   (tên đầy đủ khớp danh mục, hoặc chỉ số điều luật) và CẢNH BÁO rõ định dạng sai ("Tên (Điều N)");
   sửa lại 2 dòng ví dụ ở sheet "Danh sách án" từ "Tội cướp tài sản (Điều 168 BLHS)" (sai, không
   khớp danh mục) thành "Tội cướp tài sản" (đúng, khớp `DANH_MUC_TOI_DANH_MAM`). Cũng cập nhật
   đoạn hướng dẫn hiển thị ngay trên màn hình Import Excel (`ImportExcelModule`) với nội dung
   tương tự.

**Đã kiểm chứng bằng test cô lập** (`test_import_dieuluat.js`, trích nguyên hàm mới): "Trộm cắp
tài sản" (thiếu tiền tố "Tội ") tự resolve đúng "Điều 173 BLHS 2025"; "173" (chỉ số điều) tự
resolve đúng cả tên lẫn mã; để trống hoàn toàn tự suy đúng từ Điều luật cấp vụ; định dạng SAI như
ví dụ CŨ trong file mẫu ("Tội trộm cắp tài sản (Điều 173)") xác nhận KHÔNG resolve được — đúng lý
do bắt buộc phải sửa ví dụ đó. 4/4 assertion PASS. Đã kiểm tra file `.xlsx` sau khi sửa mở lại
bằng openpyxl không lỗi, cấu trúc cột (23 cột, header dòng 1) giữ nguyên như trước.
**CHƯA import thử 1 file Excel thật qua UI** để xác nhận `dieuLuatBC` ghi đúng ngay trên dữ liệu
Firestore/Supabase thật (chỉ kiểm chứng logic thuần qua test cô lập) — nên thử 1 lần trên
`qlahs-sup.html` với file mẫu vừa sửa trước khi tin tưởng hoàn toàn.

## Bug tiếp theo: "Tồn cuối kỳ" xem trước (kỳ CHƯA chốt) vẫn dùng snapshot sống (2026-07-20)

Ngay sau mục "Kỳ báo cáo: cho mở kỳ mới..." dưới đây — bản sửa đầu tiên chỉ sửa `chotKyBaoCao`
(hàm chạy lúc bấm nút "Chốt kỳ"), NHƯNG người dùng phát hiện qua ảnh chụp báo cáo thật: xem TRƯỚC
báo cáo của kỳ 06/2026 lúc còn "Đang mở" (chưa bấm Chốt kỳ) vẫn hiện "Tồn cuối kỳ" Điều tra = 299
vụ/730 BC dù "Tổng số mới" = 300/731 và "Đã giải quyết" = 0 — thiếu đúng 1 vụ đã chuyển sang Truy tố
NGOÀI ĐỜI THẬT nhưng sự kiện đó gắn `kyThongKe` = kỳ 07 (đúng lỗi snapshot sống y hệt đã sửa ở
`chotKyBaoCao`, nhưng nằm ở CHỖ KHÁC: nhánh "kỳ chưa chốt" bên trong `tinhBaoCaoKyTuLog` — hàm
`chotKyBaoCao` chỉ chạy khi THỰC SỰ bấm nút Chốt, còn màn xem trước (đang mở, `KyChiTietModal`)
luôn gọi thẳng `tinhBaoCaoKyTuLog` mà KHÔNG qua `chotKyBaoCao`).

**Đã sửa**: nhánh "kỳ chưa chốt" trong `tinhBaoCaoKyTuLog` (trước đây `const hienTaiSnap =
db.collection("vuan").where(...).where("trangThai","==","dang_giai_quyet").get()`) đổi sang CÙNG
công thức log đã dùng ở `chotKyBaoCao`: `tonCuoiKy = tonDauKy + soMoi.tong − soGiaiQuyetVu` (và
tương tự cho bị can) — tái dùng các biến `tonDauKy`/`soMoi`/`chuyenDi`/`traDi`/`hoanThanhTheoGD`/
`soNhapVu` ĐÃ có sẵn trong cùng scope hàm, không cần query thêm (còn NHANH HƠN bản cũ vì bỏ hẳn 1
lượt query `vuan` sống). Tiện thể **đơn giản hoá lại `chotKyBaoCao`** — giờ nhánh "chưa chốt" của
`tinhBaoCaoKyTuLog` đã tự tính đúng `tonCuoiKy`/`tonCuoiBiCanKy`, nên `chotKyBaoCao` không cần tính
lại (trùng lặp) nữa, chỉ cần đọc thẳng `baoCaoSoBo[gd].tonCuoiKy`/`tonCuoiBiCanKy`.
Cũng hoist các mảng `ds.tachVu/chuyenDen/traVe/chuyenDi/traDi` (kèm `_soBiCan`) lên TRƯỚC bước tính
tồn cuối kỳ để dùng chung cho cả công thức log VÀ object `ds` cuối hàm — tránh gọi `vuAnTuLogDocs`
2 lần cho cùng 1 snapshot (đỡ tốn query kép so với bản đầu).
Sửa luôn 1 dòng ghi chú UI lỗi thời ở `KyChiTietModal` (nói "Tồn cuối kỳ đang lấy số tồn hiện tại"
— không còn đúng nữa) thành giải thích đúng: tồn cuối kỳ tính theo log của kỳ, có thể khác "Số tồn
hiện tại" (dòng riêng bên dưới, cố ý vẫn sống theo thời gian thực) nếu có vụ đổi trạng thái nhưng
gắn kỳ khác.

**Đã kiểm chứng trên dữ liệu Supabase THẬT** (không phải mock) — mở lại đúng báo cáo kỳ 06/2026 đã
gặp lỗi trong ảnh chụp gốc: "Tồn cuối kỳ" Điều tra giờ hiện đúng 300 vụ/731 BC (khớp Tổng số mới),
Truy tố/Xét xử 0/0 — "Số tồn hiện tại" (dòng riêng, cố ý vẫn live) vẫn đúng 299/730 và 1/1 như trước,
xác nhận 2 con số này giờ tách bạch đúng ý nghĩa, không còn nhầm lẫn.

## Kỳ báo cáo: cho mở kỳ mới dù kỳ trước chưa chốt + tồn cuối kỳ tính bằng log (2026-07-20)

Theo yêu cầu người dùng (đang trong giai đoạn nhập bù dữ liệu cũ, cần mở kỳ mới ngay dù kỳ hiện tại
chưa chốt) — 2 thay đổi trong `qlahs-sup.html`, module Kỳ báo cáo:

**1. `MoKyMoiForm` thêm checkbox "Bỏ qua cảnh báo 'kỳ trước chưa chốt'"** — trước đây mở kỳ mới
LUÔN bị chặn cứng nếu còn 1 kỳ `dang_mo` khác (không phải lưu trữ), không có cách nào bypass. Giờ
tích checkbox này thì bỏ qua hẳn bước kiểm tra, cho phép tồn tại 2 kỳ `dang_mo` cùng lúc. An toàn để
bypass vì đã sửa mục 2 ngay dưới — tồn cuối kỳ không còn phụ thuộc thứ tự/thời điểm chốt.

**2. `chotKyBaoCao` — tồn cuối kỳ (`tonCuoiKy`/`tonCuoiBiCan`, theo giai đoạn) đổi từ snapshot sống
sang CÔNG THỨC LOG (tồn đầu kỳ + mới − đã giải quyết, theo đúng `kyThongKe` của từng sự kiện).**
Lý do bắt buộc: thiết kế cũ giả định "chốt lúc = lúc kỳ thực sự kết thúc" (live trạng thái `vuan`
tại thời điểm bấm chốt phản ánh đúng lịch sử) — giả định này VỠ khi chốt trễ (đúng kịch bản mục 1):
vụ tồn ở kỳ 06/2026 nhưng sự kiện giải quyết nó lại được nhập SAU, gắn `kyThongKe` = kỳ 07/2026 —
nếu tới lúc chốt 06/2026 mới query LIVE, vụ đó đã hết "đang giải quyết" nên bị đếm THIẾU khỏi tồn
cuối kỳ 06, dù tại đúng thời điểm kết thúc kỳ 06 nó vẫn đang tồn. Công thức log không phụ thuộc THỜI
ĐIỂM tính, chỉ phụ thuộc `kyThongKe` đã gắn trên sự kiện, nên đúng bất kể chốt sớm hay trễ bao lâu.
Cài đặt: gọi `tinhBaoCaoKyTuLog` với `trangThai: "dang_mo"` để lấy lại các số mới/giải quyết đã tính
theo log (bỏ qua giá trị tồn cuối kỳ nó tự tính bên trong theo nhánh live), rồi tự cộng dồn
`tonDauKy + soMoi.tong − (chuyenDi + traDi + ΣhoanThanhTheoGD + soNhapVu)` — tương tự cho bị can qua
`_soBiCan` có sẵn trên từng phần tử các mảng `ds.*`. Ghi đè `b.tonCuoiKy`/`b.tonCuoiBiCanKy` TRƯỚC
khi đông cứng qua `tachBaoCaoLuu`, để `KyChiTietModal` đọc lại đúng số đã sửa.
**`tonCuoiKyTheoTD` (theo tội danh, dùng cho Biểu B10) CHƯA được sửa theo hướng này** — vẫn giữ
snapshot sống như cũ ở lần chốt đầu, có thể lệch tương tự nếu chốt trễ. Công cụ "Sửa lại tồn cuối
kỳ theo tội danh (Biểu B10)" (Cài đặt → Import Excel, `TaiTaoTonTheoTDTool`) đã tính đúng theo log
từ trước — chạy lại công cụ đó sau khi bù dữ liệu xong để đồng bộ số theo tội danh.

**Đã kiểm chứng bằng test cô lập** (`test_tonCuoiKy_log.js`, mô phỏng đúng kịch bản người dùng nêu):
vụ 2 bị can khởi tố mới ở kỳ 06 (không có sự kiện giải quyết nào gắn kỳ 06) → tồn cuối kỳ 06 đúng
"1 vụ/2 bị can" dù thực tế vụ đã được giải quyết SAU với sự kiện gắn kỳ 07; kỳ 07 nhận tồn đầu kỳ =
1/2 rồi trừ đúng khi có sự kiện hoàn thành gắn kỳ 07 → tồn cuối kỳ 07 = 0/0. 4/4 assertion PASS.
**CHƯA kiểm chứng bằng cách chốt kỳ thật trên dữ liệu Firestore/Supabase thật** — chốt kỳ là hành
động không thể hoàn tác (khoá không cho ghi log mới vào kỳ đó), không tự ý thử trên kỳ 06/2026 thật
đang có dữ liệu. Nên chốt thử 1 kỳ test (hoặc backup trước) để xác nhận số liệu đúng trước khi tin
tưởng hoàn toàn trên kỳ thật đầu tiên chốt sau bản sửa này.

## Audit "chưa xác định điều luật" ở Biểu B10 — không phải xung đột BLHS 2015/2025 (2026-07-19)

Theo yêu cầu người dùng: nhiều vụ án cũ bị Biểu B10/TK tội danh báo "chưa xác định điều luật" dù
cột "Điều luật" ở màn hình vẫn hiện có giá trị. Nghi ngờ ban đầu là xung đột BLHS 2015 vs 2025 —
**audit sâu xác nhận KHÔNG PHẢI** (danh mục `DANH_MUC_TOI_DANH_MAM` hiện chỉ còn đúng 2 bộ luật:
BLHS 1999 — 272 điều, đánh số HOÀN TOÀN khác BLHS 2025, VD Điều 173 BLHS 1999 = "Vi phạm sử dụng
đất đai" ≠ Điều 173 BLHS 2025 = "Trộm cắp tài sản"; và BLHS 2025 — 314 điều, đại diện luôn cho cả
"2015" vì số điều giữ nguyên qua các lần sửa đổi 2015/2017/2025, KHÔNG còn entry nào gắn nhãn
"2015" nữa — đúng như người dùng khẳng định "BLHS 2015 = BLHS 2025, bản 2025 chỉ là bản update").

**4 nguyên nhân THẬT tìm được** (dùng agent + đọc code trực tiếp, không suy đoán):
1. **Chính**: `ImportExcelModule` luôn ghi `dieuLuatBC` RỖNG cho mọi bị can nhập từ file Excel —
   phụ thuộc hoàn toàn vào việc khớp CHÍNH XÁC 100% tên tội danh (kể cả hoa/thường) với danh mục.
   Đây là lý do "vụ cũ" (nhập qua Excel) hay lỗi trong khi dữ liệu mới (nhập tay qua form có ô
   chọn tội danh — `ToiDanhInput`) thì sạch, đúng như người dùng quan sát.
2. **Công cụ "Chuẩn hóa tội danh / điều luật bị can" đã có sẵn** (Cài đặt → Import Excel,
   `BackfillDieuLuatBCTool`) để chữa mục 1 — nhưng CŨNG chỉ khớp tên CHÍNH XÁC 100%. Danh mục luôn
   ghi đủ tiền tố "Tội " (VD "Tội trộm cắp tài sản"), còn dữ liệu cũ/gõ tắt thường thiếu tiền tố
   này ("Trộm cắp tài sản") → vẫn không khớp dù đã chạy công cụ.
3. **Lỗi tiềm ẩn trong chính công cụ đó**: logic ưu tiên chọn `namBLHS === "2015"` khi trùng tên/số
   điều giữa 2 bộ luật — dead code từ khi danh mục đổi hết nhãn sang "2025" (không còn entry "2015"
   nào để so khớp), rủi ro chọn nhầm sang BLHS 1999 khi trùng số điều (VD "173").
4. **Trùng lặp code**: logic "chuẩn hoá điều luật" (normDL/getDL/danhMucByTen) bị viết lặp lại y
   hệt ở **5 nơi khác nhau** (`tinhSnapTonTheoTD`, `tinhBieu10`, `taiTaoTonCuoiKyTheoTDTatCa`,
   `tinhBaoCaoKyTuLog`, `BackfillDieuLuatBCTool`) — dễ sửa 1 nơi quên 4 nơi kia, đã từng bị đúng
   sự cố này (mục 3 chỉ được phát hiện ở 1-2 nơi khi audit tay, không phải cả 5).

**Kết luận về việc có cần giữ "Mã ĐL" không** (người dùng hỏi thẳng): CÓ, cơ chế resolve tên tội
danh → mã điều luật chuẩn là bắt buộc — Biểu B10 theo đúng mẫu ngành gộp số liệu theo **điều
luật**, không phải theo tên tội danh gõ tay (2 cách viết khác nhau của cùng 1 tội phải gộp về
đúng 1 dòng). Vấn đề không phải cơ chế thừa, mà là ĐỘ TIN CẬY của bước tra cứu — đã sửa đúng chỗ
đó, không bỏ cơ chế.

**Đã sửa (theo yêu cầu người dùng "sửa toàn bộ")**:
- Gộp 5 nơi trùng lặp thành 3 hàm dùng chung đặt đầu file (cạnh `tinhDieuLuat`):
  `chuanHoaMaDieuLuat` (alias BLHS 2015→2025), `chuanHoaTenToiDanh` (khoá tra cứu: hạ chữ thường,
  gộp khoảng trắng, **bỏ tiền tố "Tội "**), `taoDanhMucByTen`/`layMaDieuLuatBiCan` (dựng map +
  tra cứu, ưu tiên BLHS 2025 khi trùng — sửa đúng lỗi mục 3 ở trên).
- Áp dụng nới lỏng "bỏ tiền tố Tội " ở CẢ 5 nơi tính toán VÀ ở `ToiDanhInput.handleBlur` (form nhập
  liệu trực tiếp) — để dữ liệu MỚI cũng không rơi vào đúng bẫy tương tự nếu người dùng gõ tắt.
- `BackfillDieuLuatBCTool` (công cụ chuẩn hoá có sẵn) tự động hưởng lợi từ fix này — không cần viết
  công cụ mới, chỉ cần CHẠY LẠI công cụ cũ trên dữ liệu thật để chuẩn hoá các "vụ cũ" còn sót.

**Đã kiểm chứng bằng Playwright thật** (11 assertion mới): seed 1 bị can ghi tắt "Trộm cắp tài sản"
(thiếu "Tội ", `dieuLuatBC` rỗng — mô phỏng đúng thực trạng Import Excel) + 1 bị can chỉ ghi số điều
thuần "173" (trùng cả BLHS 1999 lẫn 2025) + 1 bị can đã có sẵn dieuLuatBC (không được đụng) — chạy
"Chạy chuẩn hóa": xác nhận cả 2 bị can thiếu dữ liệu đều được điền ĐÚNG "Điều 173 BLHS 2025" (không
còn "chưa xác định" dù thiếu tiền tố "Tội "), tự chọn đúng BLHS 2025 khi số điều trùng cả 2 bộ luật
(không nhầm sang 1999), không đụng vào bị can đã đủ dữ liệu, idempotent khi chạy lại lần 2. Không
phá vỡ 45 assertion hồi quy có sẵn (Bảng dữ liệu Excel, Excel giao nhận, backfill ngày giải
quyết...). PASS trên cả `qlva.html`/`qlva-dev.html`.

**Chạy thử trên dữ liệu Firestore THẬT (`qlva-dev.html`, project `qlahs-test`, 2252 bị can) — kết
quả bất ngờ: "Đã chuẩn hóa 0 bị can"**, dù nghi ngờ ban đầu là 4 nguyên nhân ở trên. Đào sâu bằng
Playwright chạy thẳng query Firestore thật (`page.evaluate` gọi `db.collection(...).get()`) phát
hiện **NGUYÊN NHÂN THỨ 5, LỚN HƠN HẲN 4 nguyên nhân đã sửa — không phải lỗi khớp tên/BLHS mà là dữ
liệu bị can THẬT SỰ TRỐNG TRƠN**: 2160/2252 bị can (96%) có `toiDanh`/`dieuLuatBC` là `[""]` (chuỗi
rỗng) ngay từ gốc, không có gì để công cụ tra cứu. Trong số đó, **2155 vụ (99.8%) lại CÓ SẴN
`vuan.dieuLuat` cấp VỤ đầy đủ** (VD "Điều 168 BLHS 2015") — khớp chính xác với quan sát ban đầu của
người dùng "cột điều luật vẫn báo cáo có nhưng cột Mã ĐL lại báo chưa xác định". Nguyên nhân gốc:
`parseWorkbookDanhSachAn` đọc cột "Điều luật" trong file Excel ghi THẲNG vào `vuan.dieuLuat` (cấp
vụ, độc lập với bị can), nhưng cột "Tội danh" (cấp TỪNG bị can) trong các file gốc đã import từ
trước **bị bỏ trống hoàn toàn** — B10 tính "Mã ĐL" theo `dieuLuatBC` của từng bị can nên không có gì
để tra, dù `vuan.dieuLuat` vẫn hiện đúng trên Danh sách vụ án.

**Đã sửa tiếp (theo lựa chọn người dùng "Điền tự động từ Điều luật của vụ")**: thêm 1 nhánh mới vào
`BackfillDieuLuatBCTool` — bị can nào `toiDanh`/`dieuLuatBC` trống HOÀN TOÀN (không phải thiếu tiền
tố/chỉ ghi số điều như 4 nguyên nhân trước) thì tra `vuan.dieuLuat` của CHÍNH vụ đó (`bc.maVuAn`
chính là doc id của `vuan`, tra thẳng qua map dựng từ `db.collection("vuan").get()` thêm vào cùng
`Promise.all`), thử khớp theo SỐ ĐIỀU trước (regex `/Điều\s+(\d+[a-zA-Z]*)/i`, dùng lại `dmByDieu`
đã có), fallback theo TÊN nếu không khớp số (dùng lại `dmByTen`+`chuanHoaTenToiDanh`) — áp dụng
CHUNG kết quả suy ra cho MỌI bị can của cùng 1 vụ. **Đây là 1 giả định nghiệp vụ** ("cùng vụ = cùng
tội danh chính", đúng với đa số vụ đồng phạm 1 tội — cũng là mô hình thống kê C7-C24 vốn đã dùng
"tội danh CHÍNH của vụ" chứ không tách theo từng bị can, xem "Trạng thái Biểu B10"), có thể sai với
vụ thật sự nhiều tội danh khác nhau theo từng bị can — cán bộ tự sửa lại qua "Sửa thông tin vụ án"
nếu phát hiện sai, vẫn tốt hơn hẳn "chưa xác định" cho toàn bộ báo cáo thống kê. Thông báo kết quả
tách riêng số lượng suy từ Điều luật cấp vụ (VD "Đã chuẩn hóa 3 bị can (trong đó 3 suy ra từ Điều
luật cấp vụ...)") để phân biệt với 4 nguyên nhân cũ, dễ đối chiếu khi kiểm tra lại.

**Đã kiểm chứng bằng Playwright + mock (10 assertion mới, `test_dieuluat_suytuvu.js`)**: vụ nhiều
bị can (2 bị can, `dieuLuat` cấp vụ dạng "Điều 173 BLHS 2015") → CẢ 2 bị can đều được suy đúng "Điều
173 BLHS 2025" + tên đầy đủ; vụ có `dieuLuat` cấp vụ dạng TÊN không có "Điều N" → khớp đúng qua
nhánh fallback tên; vụ hoàn toàn không có `dieuLuat` cấp vụ → bị can bị bỏ qua đúng, không crash.
Không phá 11 assertion cũ của `test_dieuluat_fix.js` (4 nguyên nhân đã sửa trước đó vẫn hoạt động
đúng). PASS trên cả `qlva.html`/`qlva-dev.html`, biên dịch Babel sạch, 2 file byte-identical phần
script.
**Đã chạy trên dữ liệu Firestore THẬT `qlva-dev.html`/project `qlahs-test` — phát hiện thêm 1 mắt
xích cuối cùng**: lần chạy "Chạy chuẩn hóa" đầu tiên với bản sửa mới vẫn báo **0 bị can**, dù code
đã đúng — đào tiếp bằng `page.evaluate` query thẳng Firestore phát hiện **collection
`danhMucToiDanh` HOÀN TOÀN RỖNG (0 document)** trên project `qlahs-test` — công cụ "Seed danh mục
tội danh" (`SeedDanhMucTool`, cùng khu Cài đặt → Import Excel, ghi 586 tội danh BLHS 2025+1999 từ
`DANH_MUC_TOI_DANH_MAM` vào Firestore) **chưa từng được chạy trên project này** — nên MỌI cơ chế tra
cứu theo Firestore (kể cả 4 nguyên nhân đã sửa ở trên) đều vô nghĩa vì không có gì để tra, bất kể
code đúng hay sai. Đã bấm "Seed ngay" (idempotent, an toàn) rồi chạy lại "Chạy chuẩn hóa" — kết quả
thật: **555 bị can được chuẩn hoá** (bấm chạy thêm lần 2 vì lần đầu bị cắt ngang do đóng trình duyệt
Playwright giữa lúc batch đang commit — an toàn vì mỗi batch tự commit độc lập, không mất/hỏng dữ
liệu, chỉ chưa xong hết; lần 2 dọn nốt phần còn lại, lần 3 xác nhận ổn định 0 thay đổi = idempotent
đúng). **Kết quả cuối cùng trên `qlahs-test`: 2247/2252 bị can (99.8%) đã có `dieuLuatBC` đầy đủ**,
chỉ còn ĐÚNG 5 bị can (thuộc 5 vụ) không tự động điền được vì bản thân vụ án đó cũng KHÔNG có
`dieuLuat` cấp vụ nào để suy ra (thiếu dữ liệu gốc thật sự, không phải lỗi code) — cần cán bộ nhập
tay qua "Sửa thông tin vụ án" nếu cần dùng cho thống kê.

**⚠ CHƯA kiểm tra được production (`qlahsp2`) có gặp đúng vấn đề `danhMucToiDanh` rỗng này hay
không** — không có tài khoản thật trên production trong phiên làm việc này (tài khoản test
`admintest@local.com` chỉ tồn tại trên project `qlahs-test`, thử đăng nhập vào `qlahsp2.web.app` bị
từ chối đúng như dự kiến, KHÔNG thử đoán mật khẩu khác). Vì `qlahs-test` và `qlahsp2` là 2 project
Firebase HOÀN TOÀN ĐỘC LẬP (không đồng bộ dữ liệu/collection nào với nhau — xem "Ghi chú hạ tầng"),
việc `danhMucToiDanh` rỗng trên `qlahs-test` KHÔNG chứng minh production cũng rỗng, nhưng cũng không
loại trừ khả năng đó (cả 2 project dùng chung code, ai đó có thể đã quên chạy "Seed ngay" trên
production y hệt). **Việc cần làm ở phiên sau/khi có tài khoản production thật**: đăng nhập
`qlva.html` production, vào Cài đặt → Import Excel, bấm "Kiểm tra" ở khối "Seed danh mục tội danh"
— nếu báo "Collection trống" thì bấm "Seed ngay" (an toàn, idempotent, không đụng dữ liệu vụ án/bị
can nào) rồi chạy "Chạy chuẩn hóa" (`BackfillDieuLuatBCTool`) để chuẩn hoá toàn bộ dữ liệu thật,
đúng quy trình đã kiểm chứng thành công ở trên.

## Excel "Tải toàn bộ lịch sử giao nhận": thêm cột Ngày giải quyết riêng + tách 3 sheet (2026-07-19)

Theo phản hồi người dùng — file Excel tải về cần **cột riêng "Ngày giải quyết"** (dễ filter/sort
trong Excel hơn là gộp chung trong ngoặc đơn ở cột "Hình thức giải quyết" như đã làm cho bảng trên
màn hình/biên bản in ngày hôm trước) và **tách "Nhận lưu trữ" thành sheet riêng** khỏi "Nhận"
thường (từ 2 sheet Giao/Nhận thành 3 sheet Giao/Nhận/Nhận lưu trữ) — 2 luồng nghiệp vụ khác hẳn
nhau (nộp hồ sơ lưu trữ vs giao/nhận hồ sơ đang xử lý bình thường), gộp chung khó quản lý.

**Cột "Ngày giải quyết"** — thêm ngay sau cột "Hình thức giải quyết" (không xoá phần ngày đã có
sẵn trong ngoặc đơn ở đó — giữ cả 2, cột mới dùng để filter/sort, phần trong ngoặc vẫn tiện đọc
nhanh khi lướt mắt), giá trị `fmtDate(moiNhat.ngayQuyetDinh)` — cùng field, cùng cách format với
mọi cột ngày khác trong sheet này (text `dd/mm/yyyy`, không phải native Date cell — nhất quán với
toàn bộ export này, kể cả sau khi thêm cột cũng lọc/filter dropdown trong Excel bình thường qua
giá trị text).

**Tách 3 sheet** — `laLuuTru` chỉ lưu trên chính DOC `phienGiaoNhan` (phiên), KHÔNG snapshot trên
từng sự kiện `giao_nhan_ho_so` (thiết kế cũ không cần biết việc này khi ghi sự kiện) nên KHÔNG cần
thêm field mới/backfill dữ liệu cũ — chỉ cần JOIN qua `phienGiaoNhanId` ngay lúc tải Excel: tải
thêm `phienGiaoNhan` (toàn bộ, nhỏ), dựng `Map<phienId, laLuuTru>`, phân loại mỗi dòng: `loaiGiaoDich
=== "giao"` → sheet "Giao"; `"nhan"` + phiên đó `laLuuTru` → sheet "Nhận lưu trữ"; `"nhan"` + không
→ sheet "Nhận". Phiên không tìm thấy (hiếm, dữ liệu rất cũ trước khi có `phienGiaoNhanId`) mặc định
KHÔNG coi là lưu trữ — an toàn hơn giả định nhầm.

**Đã kiểm chứng bằng Playwright thật, TẢI FILE THẬT VỀ RỒI ĐỌC LẠI BẰNG chính package `exceljs`**
(không chỉ đọc code hay kiểm tra qua `window.__mockStats`) — seed 3 phiên (Giao/Nhận thường/Nhận
lưu trữ) + 3 vụ + 3 sự kiện tương ứng, bấm "Tải toàn bộ lịch sử", `page.waitForEvent("download")`
lưu file thật, mở lại bằng `ExcelJS.Workbook().xlsx.readFile()` — xác nhận: đúng 3 sheet tên
"Giao"/"Nhận"/"Nhận lưu trữ"; header có cột "Ngày giải quyết" đúng vị trí (ngay sau "Hình thức
giải quyết"); mỗi sheet chỉ chứa đúng vụ thuộc loại giao dịch/lưu trữ tương ứng, không lẫn; vụ
đang giải quyết hiện "—", vụ đã xét xử hiện đúng ngày; **ảnh QR vẫn neo đúng cột B (Mã vụ)** sau
khi chèn thêm 1 cột mới ở giữa (xác nhận không bị lệch vị trí — rủi ro dễ gặp nhất khi chèn cột
vào 1 sheet đã có ảnh nhúng theo toạ độ cứng). 16/16 assertion PASS trên cả `qlva.html`/
`qlva-dev.html`, 0 lỗi console. Không phá vỡ test hồi quy của tính năng "Ngày giải quyết" ngày
hôm trước (bảng trên màn hình/biên bản in A4 vẫn đúng).

## Giao nhận hồ sơ: cột "Hình thức giải quyết" thêm "Ngày giải quyết" (2026-07-18)

Theo yêu cầu người dùng — cột "Hình thức giải quyết" (bảng phiên trên màn hình, Biên bản in A4,
Excel "Tải toàn bộ lịch sử") trước đây chỉ hiện `"<Nhãn> — <Số QĐ>"` (VD "Đã xét xử — 5/2026"),
giờ thêm ngày giải quyết trong ngoặc đơn ngay sau số QĐ: `"Đã xét xử — 5/2026 (15/06/2026)"`. Vụ
đang giải quyết (chưa có kết quả) vẫn hiện "Đang giải quyết" như cũ, không đổi gì.

**Không phải field mới** — dùng lại `ngayQuyetDinh` đã có sẵn trên `vuan` (field "Ngày giải quyết"
ở "Sửa thông tin vụ án"/module Án đã giải quyết). Chỉ cần: (1) thêm `ngayQuyetDinh:
vuAn.ngayQuyetDinh || null` vào snapshot lúc quét/chọn vụ (`ghiNhanVuVaoPhien`, cùng nhóm với
`trangThaiVu`/`soQdGiaiQuyet` đã snapshot từ trước — snapshot TẠI THỜI ĐIỂM quét, không tính lại
sau); (2) sửa đúng 1 hàm dùng chung `moTaHinhThucGiaiQuyet(dong)` thêm phần `(${fmtDate(ngày)})`
— cả 3 nơi hiển thị (bảng phiên/biên bản in/Excel lịch sử) đều gọi hàm này nên tự động lan ra cả
3, không cần sửa từng nơi riêng.

**Đã kiểm chứng bằng Playwright thật**: seed 1 vụ Đã xét xử có `ngayQuyetDinh` + 1 vụ đang giải
quyết, quét cả 2 vào phiên Nhận, xác nhận đúng chuỗi `"Đã xét xử — 5/2026 (15/06/2026)"` xuất hiện
ở bảng phiên VÀ Biên bản in A4; vụ đang giải quyết vẫn hiện "Đang giải quyết" không đổi. 0 lỗi
console. PASS trên cả `qlva.html`/`qlva-dev.html`.

**Công cụ backfill cho dữ liệu cũ (2026-07-18, cùng ngày, theo yêu cầu người dùng ngay sau đó)** —
các sự kiện `giao_nhan_ho_so` tạo TRƯỚC khi có tính năng này không có sẵn field `ngayQuyetDinh`
(chỉ dòng quét MỚI mới tự snapshot). Thêm `BackfillNgayQuyetDinhGiaoNhanTool` (Cài đặt → Import
Excel, cạnh `BackfillTomTatBiCanTool`) — quét mọi sự kiện `loaiSuKien == "giao_nhan_ho_so"`, với
mỗi dòng CHƯA có `ngayQuyetDinh` VÀ đã có hình thức giải quyết cụ thể (`trangThaiVu` khác
`"dang_giai_quyet"`/rỗng), lấy `ngayQuyetDinh` HIỆN TẠI của `vuan` tương ứng để bổ sung — không có
cách khôi phục đúng giá trị tại thời điểm quét cho dữ liệu cũ, chấp nhận vì ngày giải quyết hiếm
khi đổi sau khi đã chốt. Idempotent (bỏ qua dòng đã có sẵn), an toàn chạy lại nhiều lần.

**Đã kiểm chứng bằng Playwright thật** (8 assertion): seed 1 vụ Đã xét xử + 1 dòng `giao_nhan_ho_so`
cũ thiếu `ngayQuyetDinh` của vụ đó, cộng 1 vụ Đang giải quyết + dòng tương ứng (không nên đụng vào),
cộng 1 dòng đã có sẵn `ngayQuyetDinh` (không nên bị ghi đè) — chạy công cụ, xác nhận **chỉ đúng 1
dòng** được cập nhật, đúng giá trị ngày lấy từ vụ án, thông báo kết quả đúng số lượng; chạy lại lần
2 xác nhận idempotent (0 ghi thêm, đúng thông báo "không có gì cần cập nhật"). 0 lỗi console.
**Phát hiện + tự sửa 1 lỗ hổng của bộ mock test dùng chung** (không phải bug app): docs trả về từ
`.get()`/`.onSnapshot()` trong `mock-firebase.js` thiếu hẳn `.ref` — cần cho pattern
`batch.update(doc.ref, ...)` mà `BackfillTomTatBiCanTool` (đã có từ trước) cũng dùng y hệt. Đã sửa
`snapFromDocs` nhận thêm tham số `collectionName` để tự gắn `.ref` qua `makeDocRef` — Firestore SDK
thật luôn có `.ref` sẵn trên mọi doc snapshot, mock trước đó thiếu nên không phát hiện ra khi test
các tool dùng pattern này trước đây.

## Audit toàn hệ thống lần 2: giảm read + listener (2026-07-18, ngay sau bug "121 listener")

Theo yêu cầu người dùng "đánh giá hệ thống xem làm sao để giảm thiểu lượng read/listener hết mức
có thể" — rà soát lại TOÀN BỘ 17 vị trí `onSnapshot` còn lại trong code (sau khi đã sửa
`BangBiCanCon` ở mục ngay dưới). Kết luận: phần lớn đã đúng thiết kế (cache dùng chung `canbo`/
`danhMucToiDanh`/`kybaocao`; sentinel `meta/vuAnMoiNhat`; "Đang giải quyết" không live; cache lạnh
"Án đã giải quyết"; "Phiên gần đây" giới hạn 30; dòng đang quét trong phiên hiện tại; Thùng rác —
đều có lý do chính đáng để giữ live hoặc phạm vi đã đủ hẹp). Tìm ra đúng 2 điểm còn sót, đã sửa cả
2 theo xác nhận của người dùng:

**1. NGHIÊM TRỌNG — `DanhSachPanel` (màn hình mặc định mọi người mở đầu tiên)**: cột "Kỳ mới/Kỳ
giải quyết/Kỳ vào Truy tố/Kỳ chuyển Xét xử" dùng `onSnapshot` CHIA LÔ 30 trên `lichsuChuyenGiaiDoan`
— với danh sách mặc định ~500 vụ, tạo tới **17 listener sống cùng lúc** trên chính màn hình mặc
định, mọi người dùng đều dính (không cần "Mở tất cả" như `BangBiCanCon`, chỉ cần MỞ APP). Đáng chú
ý: đúng phần `bican` NGAY PHÍA TRÊN nó (cùng logic chia lô, tìm theo tên bị can) đã sửa đúng sang
`.get()` một lần từ đợt "Tối ưu Firestore Đợt 3" — chỗ `lichsuChuyenGiaiDoan` này bị BỎ SÓT, comment
cũ còn ghi nhầm "giống bican ở trên" dù code thực tế vẫn dùng `onSnapshot`.
**Đã sửa**: đổi sang tải 1 lần + cache theo `maVuAn` (`logKyTheoVu`, y hệt pattern
`bicanTimKiemTheoVu` đã có sẵn ngay cạnh — đọc cache trong effect nhưng KHÔNG đưa vào deps, tránh
vòng lặp vô hạn, chấp nhận đọc closure hơi cũ 1 nhịp, đúng pattern đã dùng ở đây rồi). Cột Kỳ không
còn realtime với thay đổi do người khác thao tác (Sửa kỳ ở Nhật ký thao tác, chuyển giai đoạn vụ
khác...) — chấp nhận được, đúng nguyên tắc "hot data không cần live" áp dụng khắp app, tự mới khi
đổi tab/tải lại trang.

**2. Vừa phải — `BangExcelModule` (Bảng dữ liệu Excel)**: danh sách vụ án (tới 500 doc) giữ 1
`onSnapshot` sống suốt thời gian mở tab — công cụ sửa hàng loạt cho 1 người thao tác, không cần
live, cùng lý do đã sửa `BangBiCanCon`. **Đã sửa**: đổi sang tải 1 lần (`taiDsVu`). Vì đây là công
cụ SỬA (không chỉ xem), phải xử lý đúng 2 đường ghi để không mất tính đúng đắn UI sau khi bỏ live:
- Ghi trực tiếp trong CHÍNH module (sửa từng ô `suaVu`/kéo fill `apDungGiaTriVu`) — biết chắc patch
  nào vừa ghi thành công nên **patch cục bộ ngay vào state `list`** (`patchCucBo`), KHÔNG cần đọc
  lại Firestore — rẻ hơn cả cách cũ (live listener trước đây vẫn phải chờ round-trip server mới
  cập nhật UI, patch cục bộ cập nhật NGAY tại chỗ).
- Ghi GIÁN TIẾP qua bảng con bị can (`BangBiCanCon` sửa `ngayKhoiTo`/tội danh chính →
  `capNhatDieuLuatVaLoaiKhoiTo` đổi `dieuLuat`/`tomTatBiCan` của vụ CHA) — module cha không còn
  live để tự bắt được thay đổi này. Thêm prop `onVuAnCoTheDoi(vuAnId)` truyền xuống `BangBiCanCon`,
  gọi sau khi `capNhatDieuLuatVaLoaiKhoiTo` thành công — cha tải lại **ĐÚNG 1 doc** vuan đó
  (`taiLaiMotVu`, `.doc(id).get()`), rẻ hơn hẳn tải lại cả danh sách 500 dòng.

**Đã kiểm chứng bằng Playwright thật** (14 assertion mới, cộng 48 assertion hồi quy có sẵn không bị
phá vỡ): (1) `DanhSachPanel` — 0 listener `onSnapshot` dạng "in" trên `lichsuChuyenGiaiDoan` (seed
10 vụ, trước fix sẽ ra 1 lô), cột "Kỳ mới" vẫn hiển thị đúng dữ liệu qua `.get()`; (2)
`BangExcelModule` — 0 listener trên `vuan`, dữ liệu vẫn tải đúng, sửa 1 ô vẫn ghi đúng Firestore
VÀ **không tạo thêm `.get()` nào** (patch cục bộ), UI phản ánh giá trị mới ngay lập tức; sửa Ngày
khởi tố của 1 bị can trong bảng con → xác nhận đúng **1 lượt `.get()` duy nhất** trên `vuan` (đọc
thẳng 1 doc, không phải query toàn danh sách) — chứng minh cơ chế đồng bộ chéo `onVuAnCoTheDoi`
hoạt động đúng và tiết kiệm. 0 lỗi console. PASS trên cả `qlva.html`/`qlva-dev.html`.
**Tiện thể bổ sung `.doc().get()` vào tracking của mock test dùng chung** (trước đó mock chỉ track
`query().get()`, không track `docRef.get()` — cần thiết để viết được assertion #2 ở trên).

**Ngoài phạm vi audit này (chấp nhận giữ nguyên, không sửa)**: `CanBoModule` tự mở listener riêng
thay vì qua cache dùng chung (dữ liệu nhỏ ~34 doc, chỉ 1 instance có thể mở cùng lúc, ảnh hưởng
không đáng kể — khác query shape với cache `"canbo:dang_cong_tac"` nên không dùng chung được thẳng,
cần thêm cacheKey mới nếu muốn gộp); `DashboardModule` cảnh báo hạn điều tra (1 listener, phạm vi
đã hẹp — chỉ Điều tra + đang giải quyết); trang đầu tab "Tất cả" của Danh sách vụ án (quyết định
thiết kế cũ, xem "Tối ưu Firestore Đợt 3" — cursor pagination thật).

## Bug đã sửa: "Mở tất cả" ở Bảng dữ liệu Excel tạo hàng trăm listener sống song song (2026-07-18)

Người dùng báo Firebase Console hiện "3 connections nhưng 121 listeners" — con số quá cao so với 3
kết nối thật. Đối chiếu bảng Query Insights người dùng dán vào: mọi query trên `canbo`/
`danhMucToiDanh`/`kybaocao` đều khớp đúng thiết kế cache dùng chung (Đợt 1) — 1 listener/collection,
bình thường. Riêng `boDemMaVu` (69 docs full-collection) không khớp bất kỳ query nào trong code
(app chỉ đọc `.doc(yymm)` theo transaction, không bao giờ query cả collection) — nhiều khả năng là
Firebase Console TỰ browse collection đó lúc người dùng mở tab Firestore Data, không phải app.

**Nguyên nhân thật (grep toàn bộ `onSnapshot` trong code, đối chiếu số lượng instance có thể mở
cùng lúc)**: `BangBiCanCon` (bảng bị can lồng trong "Cài đặt → Bảng dữ liệu" kiểu Excel) dùng
`onSnapshot` SỐNG cho MỖI dòng vụ án được mở rộng — khác hẳn 2 nơi `onSnapshot` theo `maVuAn` còn
lại trong app (`ChiTietPanel`, `ChiTietVuAnModal`) vốn chỉ mở đúng 1 vụ tại 1 thời điểm nên không
sao. Nút **"Mở tất cả"** ở Bảng dữ liệu Excel mở rộng MỌI dòng đang tải (`gioiHan` mặc định 500) —
mỗi dòng mở rộng là 1 listener sống mới, tồn tại tới khi thu gọn/rời trang. Đây đúng dạng gap đã
loại bỏ khắp app trong đợt tối ưu Firestore trước đó ("hot data không cần live") nhưng bị bỏ sót ở
tính năng Bảng dữ liệu Excel — vì nhánh đó (`bang-excel-cai-dat`) tách ra và phát triển độc lập
trước khi có tư duy "tải 1 lần" được thống nhất ở các module khác.

**Đã sửa**: `BangBiCanCon` đổi từ `onSnapshot` sang `.get()` tải 1 lần lúc mount/expand (hàm
`taiLai`, dùng `useCallback`), rồi gọi lại `taiLai()` NGAY SAU MỖI lần chính component này ghi
Firestore (`suaBiCanTruong`/`apDungGiaTri`) — giữ đúng UX cũ (cột "Loại khởi tố" tự tính vẫn cập
nhật ngay sau khi sửa, không cần chờ remount) mà KHÔNG còn giữ kết nối sống nào ở nền. Đánh đổi:
mất realtime với thay đổi từ NGƯỜI KHÁC khi đang mở rộng — chấp nhận được vì đây là công cụ sửa
hàng loạt cho 1 người thao tác tại 1 thời điểm, không phải màn hình xem chung nhiều người.

**Đã kiểm chứng bằng Playwright thật**: seed 8 vụ án + 8 bị can, bấm "Mở tất cả" — xác nhận **0
listener** xuất hiện trên `bican` (trước fix sẽ ra đúng 8, tỉ lệ thuận số dòng mở), thay vào đó
đúng 8 lượt `.get()` một lần (mỗi lượt lọc đúng 1 `maVuAn`); cả 8 vụ vẫn hiện đúng dữ liệu bị can;
sửa 1 ô vẫn ghi đúng Firestore VÀ UI tự cập nhật ngay (không cần remount) nhờ `taiLai()` sau ghi; 0
lỗi console. Chạy lại toàn bộ 2 bộ test hồi quy có sẵn của Bảng dữ liệu Excel (26 assertion cấu
trúc/filter/ghi dữ liệu) và kéo-fill (5 assertion) — không có gì bị phá vỡ. PASS trên cả
`qlva.html`/`qlva-dev.html`.

## Sự cố "deploy đè mất fix" + merge `toi-uu-firestore-read` vào `main` (2026-07-18, cuối ngày)

**Chuyện đã xảy ra**: sáng 2026-07-18, 1 phiên làm việc port 2 bug fix (thời hạn bảo quản floor-
lookup + race condition sửa bị can, xem mục "Port 2 bug fix" bên dưới) từ `bang-excel-cai-dat` vào
`main` rồi deploy production lúc ~09:xx. Đồng thời/sau đó, 1 phiên làm việc KHÁC (song song, không
biết về việc trên) tiếp tục phát triển trực tiếp trên nhánh `toi-uu-firestore-read` (Đợt 3 tối ưu
Firestore, Import Excel thay vụ trùng — 2 mục ngay trên) rồi **deploy production lúc 14:53** — vì
`toi-uu-firestore-read` lúc đó CHƯA merge với `bang-excel-cai-dat` nên KHÔNG có 2 bug fix, deploy
này đã **ghi đè mất** bản production đúng của buổi sáng. Phiên đó tự phát hiện qua chính commit
message, đã merge `bang-excel-cai-dat` (9 commit, gồm cả 2 fix + toàn bộ tính năng Bảng dữ liệu
Excel) vào `toi-uu-firestore-read` lúc 17:56 (`6642784`) để khôi phục, nhưng chưa kịp deploy lại.

**Phiên phát hiện & khôi phục** (đọc `git fetch` + đối chiếu trực tiếp qua `curl` cả 2 URL thật —
không chỉ tin tưởng lịch sử git): xác nhận cả `qlahsp2.web.app` VÀ `qlahs-test.web.app` đều đang
thiếu `mucAnThang`/`capNhatDieuLuatVaLoaiKhoiTo` (2 field/hàm đặc trưng của 2 fix), có
`mucAnCoSauThang` (field cũ trước khi sửa) — xác nhận đúng như commit message mô tả. Đã hỏi người
dùng qua AskUserQuestion, được xác nhận deploy ngay từ `toi-uu-firestore-read` — `./deploy.sh test`
rồi `./deploy.sh prod` + `firebase deploy --only firestore:indexes` cho cả 2 project, xác nhận lại
bằng `curl` + Playwright: production đã có đúng `mucAnThang`, hết `mucAnCoSauThang`, 0 lỗi console.

**Sự cố phụ tự gây ra rồi tự sửa lúc đồng bộ nhánh**: chạy nhầm `git merge --ff-only
toi-uu-firestore-read origin/toi-uu-firestore-read` (dạng 2 tham số) trong lúc đang đứng ở nhánh
`bang-excel-cai-dat` — lệnh 2-tham-số merge NHÁNH HIỆN TẠI với 2 ref đó, vô tình đẩy con trỏ local
`bang-excel-cai-dat` tiến lên trùng `toi-uu-firestore-read` (không mất commit nào — mọi thứ vẫn
nằm nguyên trên remote, chỉ là con trỏ nhánh local bị lệch định danh). Tự phát hiện qua đối chiếu
`git rev-parse bang-excel-cai-dat` với `origin/bang-excel-cai-dat`, sửa bằng `git reset --hard
origin/bang-excel-cai-dat` (an toàn vì working tree sạch lúc đó), rồi checkout đúng
`toi-uu-firestore-read` và fast-forward riêng nhánh đó bằng đúng lệnh 1-tham-số.
**Bài học cho phiên sau**: KHÔNG dùng `git merge <ref1> <ref2>` (2 tham số) để "cập nhật nhánh X
theo remote" trừ khi ĐANG đứng đúng trên nhánh X — luôn `git checkout <branch>` trước rồi mới
`git merge --ff-only origin/<branch>` (1 tham số).

**Merge `toi-uu-firestore-read` vào `main`** (theo yêu cầu người dùng, sau khi xác nhận production
đã khôi phục) — `main` lúc này chỉ còn 5 commit riêng (đúng phần "Port 2 bug fix" bên dưới, đã
TRỞ NÊN DƯ THỪA vì nội dung tương đương đã có sẵn trong `toi-uu-firestore-read` qua đường merge
`bang-excel-cai-dat` GỐC — khác hash commit nhưng cùng nội dung), còn `toi-uu-firestore-read` có 13
commit main chưa có. Merge `--no-ff`, xung đột thủ công ở 3 vùng quen thuộc (đều là main giữ bản
CŨ/ĐƠN GIẢN hơn của cùng 1 đoạn code, `toi-uu-firestore-read` đã có bản ĐẦY ĐỦ hơn — lấy nguyên bản
`toi-uu-firestore-read`, không giữ gì từ bản main cũ):
- `capNhatDieuLuatVaLoaiKhoiTo`: `toi-uu-firestore-read` có thêm cập nhật cache `tomTatBiCan`
  (Đợt 3) trong CÙNG transaction — main chưa biết field này.
- `DongGiaoNhan.batDauSua`: `toi-uu-firestore-read` đã đổi hẳn sang kiến trúc `dangSuaId` (module
  cha quản lý dòng nào đang sửa, tự lưu hộ khi chuyển dòng — xem mục ngay trên) qua `onYeuCauSua`,
  main vẫn còn bản cũ tự set state cục bộ trong `DongGiaoNhan` — bỏ hẳn bản cũ.
- CLAUDE.md: 2 chỗ chèn nội dung tài liệu khác nhau cùng vị trí (không phải xung đột logic) — gộp
  cả 2, không bỏ nội dung nào, đặt "Port 2 bug fix" xuống dưới "Tối ưu Firestore Đợt 3" (đúng thứ
  tự thời gian thật trong ngày).
Đã compile-check sạch cả `qlva.html`/`qlva-dev.html` qua `@babel/standalone@7.25.6` sau merge —
CHƯA deploy lại (không cần, vì `main` giờ chỉ đang "đuổi kịp" đúng những gì ĐÃ deploy thật từ
`toi-uu-firestore-read` phía trên, không có nội dung mới nào cần lên production thêm).
**Khuyến nghị cho phiên sau**: cân nhắc coi `toi-uu-firestore-read` là nhánh phát triển chính từ
nay (đổi tên/đặt làm default trên GitHub?) thay vì tiếp tục dùng tên `main` song song 2 nhánh dễ
lệch nhau — nguyên nhân gốc của sự cố hôm nay là 2 phiên làm việc không biết nhau đang tồn tại
CÙNG LÚC trên 2 nhánh gần giống nhau. `bang-excel-cai-dat` coi như đã "hết vai trò" (nội dung nằm
trọn trong `toi-uu-firestore-read` qua merge) nhưng CHƯA xoá, để dành xác nhận với người dùng.

## Import Excel: cho phép "thay thế" vụ trùng bằng cách đưa vụ cũ vào Thùng rác (2026-07-18)

Import Excel trước đây phát hiện vụ trùng (theo mã vụ HOẶC theo cặp Số+Ngày QĐ KTVA) thì LOẠI THẲNG
dòng đó, không có cách nào ghi đè. Dũng phản ánh: giai đoạn đầu dùng hệ thống, dữ liệu cũ lẫn
lộn/sai sót là bình thường — cần 1 lựa chọn chủ động "thay thế": đưa vụ cũ vào Thùng rác (soft-delete,
`daXoa:true`, vẫn khôi phục được), rồi nhập đúng dữ liệu mới từ file vào.

**Thiết kế** (`ImportExcelModule`): mỗi phần tử `ketQuaDoc.trung` giờ có thêm `_idTrung` (ID vụ đã
có, tách riêng khỏi chuỗi `_lyDoTrung` để dùng được trong code). Ngay sau khi tính `trung`, chạy 1
lần `where("vuGoc","in",...)` (chia lô 30 qua `chiaNhoDsId` có sẵn) để biết trước vụ trùng nào CÓ
vụ tách ra từ nó — các vụ đó bị vô hiệu hoá ô tích (không cho thay thế, tránh mồ côi hoá vụ tách,
đúng nguyên tắc `XoaVuAnModal` đã áp dụng cho xoá thủ công).
Bảng xem trước "vụ trùng" thêm cột checkbox "Thay vụ cũ" + nút "Chọn/Bỏ chọn tất cả (đủ điều
kiện)" (state `trungDuocChon`, Set các index). `ghiVaoCoSoDuLieu` gộp các dòng đã tích
(`dsThayThe`) vào `dsMoi` (xử lý y hệt vụ mới bình thường — sinh mã, ghi log...), thêm 1 vòng
`batch.update` soft-delete các vụ cũ bị thay thế (ĐÚNG field `XoaVuAnModal` dùng: `daXoa`,
`ngayXoaMem`, `nguoiXoaMem`, không đụng `bican`/log của vụ cũ) vào CHUNG batch/`commitNeu` đã có,
gọi `capNhatCucBoDsDangGiaiQuyet(id, null)` sau khi commit cho từng vụ bị thay thế (tránh vụ cũ còn
hiện sai trên chính máy vừa import cho tới khi remount — đúng cách `XoaVuAnModal` đã làm).
**Không cần mã xác nhận kiểu gõ lại** — đã xác nhận qua code `XoaVuAnModal`: xác nhận ngẫu nhiên chỉ
tồn tại ở tầng UI của modal đó, không phải điều kiện bắt buộc ở tầng ghi Firestore, và thao tác vẫn
hoàn toàn khôi phục được — giữ đúng tinh thần "ít xác nhận hơn xoá vĩnh viễn" khi làm hàng loạt lúc
import.

**Đã kiểm chứng bằng Playwright thật, đăng nhập thật vào `qlva-dev.html`** (không mock): import 1
vụ test tạo "vụ cũ" thật qua chính luồng import bình thường → import file thứ 2 trùng đúng Số/Ngày
QĐ KTVA → hệ thống nhận diện đúng "1 vụ trùng" → tích "Thay vụ cũ" → nút đổi đúng thành "Ghi 1 vụ
vào hệ thống (gồm 1 vụ thay vụ trùng)" → ghi thành công → xác nhận qua Firestore: vụ cũ có
`daXoa:true`, vụ mới tồn tại đúng dữ liệu, đúng tổng 2 vụ — dọn sạch dữ liệu test sau đó. Test riêng
kịch bản "vụ có con tách ra": tạo vụ gốc + 1 vụ con trỏ `vuGoc` về nó qua Firestore, import file
trùng Số/Ngày QĐ KTVA vụ gốc — xác nhận ô tích bị vô hiệu hoá đúng + hiện rõ "⚠ Có vụ tách ra từ vụ
này". Cả 2 kịch bản: 0 lỗi console.

## Tối ưu Firestore Đợt 3: cache tóm tắt bị can lên vụ án + cursor pagination thật (2026-07-18)

Đối chiếu 1 tài liệu hướng dẫn tối ưu chi phí Firestore của Dũng (offline persistence, denormalize,
tránh offset khi phân trang, debounce ghi liên tục, Firestore Bundles) với code thật — xác nhận 3/5
điểm đã làm hoặc không áp dụng được (persistence đã bật; không có ghi nào theo từng phím gõ để cần
debounce; Bundles đụng triết lý "không build step" nên bỏ), còn lại 2 điểm làm trong đợt này.

**Cache `soBiCan`/`biCanDaiDien` lên `vuan`** — cột "Bị can" ở Danh sách vụ án trước đây phải join
sang collection `bican` qua 1 listener LUÔN BẬT cho mọi dòng đang hiển thị (`biCanAll`, chia lô 30
id). Phát hiện quan trọng lúc đào sâu: listener đó không chỉ để hiển thị — ô tìm kiếm tự do CŨNG
dùng chính dữ liệu đó để tìm theo tên bị can, nên chỉ thêm field mà giữ nguyên listener sẽ KHÔNG
giảm đọc thật. Đã làm đầy đủ (theo yêu cầu Dũng): helper `tomTatBiCan(biCanList)` (đại diện = phần
tử ĐẦU mảng cuối cùng tại thời điểm ghi — không có quy ước sắp xếp sẵn nào để noi theo) gắn vào
ĐÚNG 1 object `batch.set`/`batch.update` đã có sẵn ở cả 6 nơi tạo/sửa/xoá/di chuyển bị can
(`ImportExcelModule`, `ThemVuAnForm`, `ThemBiCanForm`, `SuaBiCanForm`, `tachVuAn`, `NhapVuModal`) —
không thêm read/write nào. `BackfillTomTatBiCanTool` (Cài đặt → Import Excel, cạnh
`BackfillLoaiKhoiToTool`) điền cho dữ liệu cũ, idempotent.
`DanhSachPanel` bỏ hẳn listener `bican` luôn bật — cột mặc định đọc thẳng `v.soBiCan`/
`v.biCanDaiDien` (0 đọc thêm); "mở rộng xem hết bị can" tải 1 lần theo yêu cầu đúng lúc bấm (cache
phiên theo id vụ); tìm theo tên bị can debounce 350ms rồi tải 1 lần cho các vụ đang hiển thị CHƯA
có trong cache (không còn `onSnapshot`) — trong lúc chờ, vẫn khớp ngay theo `biCanDaiDien` để không
có cảm giác "0 kết quả".

**Cursor pagination thật cho tab "Tất cả"** — nút "Tải thêm 500" trước đây chỉ tăng `.limit()` rồi
mở lại `onSnapshot` từ đầu, khiến Firestore tính lại lượt đọc cho TOÀN BỘ số dòng đã đọc trước đó
mỗi lần bấm. Thiết kế mới: trang đầu (`dsCoBan`) vẫn LIVE y hệt trước, CHỈ khi chưa bấm "Tải thêm"
lần nào; bấm lần đầu sẽ huỷ subscribe live đó (đóng băng trang đầu — chấp nhận tab "Tất cả" hết
live từ lúc đó, đúng tinh thần "chấp nhận cũ, tự mới khi remount" đã dùng cho Đang giải quyết/cache
lạnh), rồi mọi trang sau tải 1 lần bằng `.startAfter(cursor)` — CHỈ đọc đúng phần MỚI. Cần tie-break
`orderBy(FieldPath.documentId())` cạnh `orderBy("ngayTao")` vì nhiều vụ import cùng lúc chia sẻ
ĐÚNG 1 giá trị `ngayTao` (tính 1 lần ngoài vòng lặp) — không có tie-break sẽ bỏ sót/trùng dòng đúng
tại ranh giới các nhóm đó.
**Bug tự phát hiện + tự sửa lúc test (không phải giả thuyết suông)**: callback `onSnapshot` của
trang đầu có thể "bắn muộn" (Firestore bắn lại cache-rồi-server hoặc 1 thay đổi thật) ĐÚNG lúc
React chưa kịp dọn effect live sau khi bấm "Tải thêm" — nếu không chặn, sẽ ghi đè `cursorRef` về
lại ranh giới trang 1. Sửa bằng 1 `useRef` cờ (`dangPhanTrangRef`) đặt `true` NGAY LÚC BẤM (đồng bộ,
không chờ re-render) để callback live tự bỏ qua nếu cờ đã bật.

**Đã kiểm chứng bằng Playwright thật, đăng nhập thật vào `qlva-dev.html` (project `qlahs-test`,
tài khoản `admintest@local.com`, 1386 vụ án thật)** — không phải mock: chạy `BackfillTomTatBiCanTool`
thật (cập nhật đúng 1386 vụ, 0 lỗi); cột "Bị can" hiện đúng tên đại diện/số lượng ngay từ `vuan`;
bấm "Tải thêm" liên tiếp tải đúng 500 → 1000 → 1386 (đúng tổng thật), xác nhận **0 ID trùng** qua
toàn bộ 1386 dòng; mở rộng 1 vụ 14 bị can hiện đúng đủ 14 tên; tìm theo tên bị can ("Thông") lọc
đúng còn 1 kết quả khớp; 0 lỗi console xuyên suốt. Cũng test cô lập bằng mock Node (trích nguyên
văn `tomTatBiCan` từ chính `qlva.html`, mock Firestore mô phỏng đúng ngữ nghĩa `orderBy`/
`startAfter`/tie-break) — xác nhận không trùng/sót dòng kể cả khi có nhóm doc chia sẻ đúng 1 giá
trị `ngayTao` (mô phỏng import hàng loạt).
**Ngoài phạm vi**: `toiDanhChinh` (tội danh chính, dùng trong thống kê `KyBaoCaoModule` qua
`_biCanCache`/`layBiCanInfo`/`batchLayBiCanList`) KHÔNG được denormalize trong đợt này — chỉ đúng
phạm vi đã bàn với Dũng (cột "Bị can" ở Danh sách vụ án), không mở rộng sang thống kê báo cáo.

## Port 2 bug fix từ nhánh `bang-excel-cai-dat` vào `main` (2026-07-18)

Nhánh `bang-excel-cai-dat` (tính năng Cài đặt → "Bảng dữ liệu" kiểu Excel, xem mục riêng ở "Tiến độ
đã code") có 2 commit sửa bug THẬT không liên quan gì tới tính năng Bảng dữ liệu — **chỉ port đúng 2
bug fix này vào `main` qua `git cherry-pick`, KHÔNG merge toàn bộ tính năng Bảng dữ liệu** (theo yêu
cầu người dùng, tính năng đó để merge riêng sau — xem "Cài đặt → 'Bảng dữ liệu' (2026-07-17)" ở dưới,
hiện chỉ tồn tại trên `bang-excel-cai-dat`, chưa có trên `main`/production):
- **Thời hạn bảo quản floor-lookup** (commit gốc `1344097`) — xem chi tiết đầy đủ ở mục "Nộp hồ sơ
  lưu trữ + cột 'Thời hạn bảo quản'" bên dưới, đoạn "Bug đã sửa (2026-07-16...) — bảng gốc là HÀM
  BẬC THANG".
- **Race condition lost-update khi sửa bị can** (commit gốc `b976726`) — xem mục "Audit 'tối ưu hệ
  thống'" bên dưới.

Cherry-pick trên nhánh tạm `fix-race-thoihan` (đã xoá sau khi merge xong), có xung đột thủ công ở
`DongGiaoNhan`/`ghiNhanVuVaoPhien` (field `mucAnThang` mới va chạm với field `khongTiepNhan`/
`lyDoKhongTiepNhan` thêm sau trên `main` — đã gộp cả 2, không mất field nào) và ở `SuaBiCanForm`/
`ThemBiCanForm` (đổi `batch.commit()` cũ sang gọi `capNhatDieuLuatVaLoaiKhoiTo` mới). CLAUDE.md cũng
xung đột ở 2 chỗ chèn nội dung cùng vị trí — gộp cả 2 phía, không bỏ nội dung nào.

**Đã kiểm chứng lại SAU KHI merge bằng Playwright thật qua UI** (không chỉ tin tưởng merge tự động
đúng) — kịch bản: (1) bắt đầu phiên Nhận + bật "Nộp hồ sơ lưu trữ", quét 1 vụ Đã xét xử, nhập mức án
"3 năm 5 tháng" ngay tại dòng, xác nhận cột Thời hạn bảo quản hiện đúng **"19 năm"** (mốc floor "3",
không phải `null`/không phải chỉ chấp nhận giá trị khớp tuyệt đối); (2) mở 1 vụ có 2 bị can, sửa 1 bị
can qua nút "Sửa" của đúng dòng bị can, xác nhận ghi cả `bican.update` LẪN `vuan.update` (bằng chứng
`capNhatDieuLuatVaLoaiKhoiTo` chạy qua transaction, không còn `batch.commit()` cũ) — cả 2 kịch bản
PASS trên cả `qlva.html` VÀ `qlva-dev.html`, 0 lỗi console.

**Đã deploy lên cả `qlahs-test.web.app` VÀ `qlahsp2.web.app` (production)** qua `./deploy.sh test`
rồi `./deploy.sh prod`, cộng thêm `firebase deploy --only firestore:indexes` cho cả 2 project (index
`lichsuChuyenGiaiDoan: kyThongKe+loaiSuKien+tuGiaiDoan` mới từ `b976726`). Smoke test bằng Playwright
sau deploy (không đăng nhập) trên cả 2 URL — trang tải đúng, 0 lỗi console.
**Lưu ý quan trọng (phát hiện ở phiên sau)**: bản deploy này SAU ĐÓ đã bị 1 phiên làm việc song song
khác deploy đè mất (từ nhánh `toi-uu-firestore-read` trước khi nó merge với `bang-excel-cai-dat`) —
xem mục "Sự cố 'deploy đè mất fix' + merge `toi-uu-firestore-read` vào `main`" ở đầu file để biết
cách đã khôi phục.

## Tối ưu Firestore ĐÃ LÊN PRODUCTION (2026-07-18)

Toàn bộ kế hoạch tối ưu Firestore (Đợt 1 gộp listener, Đợt 2 Thùng rác + cache lạnh IndexedDB, hot
data sentinel `meta/vuAnMoiNhat`) — xem đầy đủ ở các mục "Tối ưu Firestore..." bên dưới — **đã
deploy lên CẢ `qlahs-test.web.app` VÀ `qlahsp2.web.app` (production, dữ liệu thật)** qua
`./deploy.sh test` rồi `./deploy.sh prod`, dựa trên code của nhánh `toi-uu-firestore-read` (bản
thân nhánh git vẫn CHƯA merge vào `main` — hosting deploy độc lập với việc merge, chỉ copy nguyên
`qlva.html` hiện có trong thư mục làm việc lúc chạy `deploy.sh`, không quan tâm branch). Đã kiểm tra
lại production sau deploy bằng Playwright (không đăng nhập, không có tài khoản thật) — trang tải
đúng, màn hình đăng nhập hiện sạch, 0 lỗi console.
**Lưu ý cho phiên sau**: nếu merge nhánh `toi-uu-firestore-read` vào `main`, nhớ đối chiếu `main`
đã khớp đúng nội dung đã lên production hay chưa (deploy trước, merge sau — thứ tự ngược với quy
trình thông thường merge-rồi-mới-deploy) để tránh `main` và production lệch nhau về sau.
**Ý tưởng đã cân nhắc rồi CHỦ ĐỘNG bỏ**: timer đồng bộ định kỳ 60s cho cache lạnh "Án đã giải
quyết" — xem bộ nhớ dài hạn `toi-uu-firestore-effectiveness` (lý do: remount tự nhiên đã đủ cho hệ
thống ít user, chủ yếu xem/trích xuất).

## Tối ưu Firestore — "hot data" (vụ ĐANG giải quyết): bỏ live, dùng sentinel "có vụ mới" (2026-07-18)

Tiếp theo các mục "Tối ưu Firestore" bên dưới (Đợt 1: gộp listener; Đợt 2: Thùng rác + cache lạnh
cho vụ ĐÃ giải quyết) — mục này xử lý phần còn lại: vụ **ĐANG** giải quyết ("hot data"). Quyết định
thiết kế đã thống nhất với người dùng (hệ thống ít user, chủ yếu dùng để xem/trích xuất dữ liệu, ưu
tiên tiết kiệm đọc hơn độ mới tức thời): **danh sách "đang giải quyết" bỏ hẳn `onSnapshot` sống**,
chỉ tải 1 lần — CHỈ vụ án MỚI TẠO mới cần biết ngay, mọi thay đổi KHÁC của vụ đã có sẵn (đổi KSV,
chuyển giai đoạn, hoàn thành...) chấp nhận cũ, tự làm mới khi component remount (chuyển tab đi rồi
quay lại). `ChiTietPanel` (đang sửa 1 vụ cụ thể) KHÔNG đổi — vẫn `onSnapshot` riêng theo đúng 1 doc.

**Cơ chế sentinel** (`dsDangGiaiQuyetRegistry`/`dongBoDsDangGiaiQuyet`/`useDanhSachDangGiaiQuyet`,
đặt cạnh các cache khác ở đầu file) — 1 document cảm biến bé xíu `meta/vuAnMoiNhat` (field
`capNhatLuc`) được cập nhật kèm theo trong CÙNG batch ở **đúng 3 nơi tạo `vuan` mới**:
`ThemVuAnForm`, `ImportExcelModule`, `tachVuAn` (vụ tách ra cũng là 1 vụ "mới"). Mọi client chỉ giữ
**đúng 1 listener rẻ** trên sentinel này (không unsub — chi phí 1 document gần như bằng 0) thay vì
theo dõi cả danh sách; hễ đổi thì chạy 1 query nhỏ `where("trangThai","==","dang_giai_quyet")
.where("ngayTao", ">", lầnBiếtGầnNhất)` bổ sung đúng (các) vụ mới, không tải lại toàn bộ. Lần đầu
(chưa có cache) tải trọn 1 lần bằng `.where("trangThai","==","dang_giai_quyet")` không kèm điều
kiện `ngayTao`.

**`DanhSachPanel`** (Danh sách vụ án) tách 2 nhánh rõ ràng: tab "Đang giải quyết" dùng
`useDanhSachDangGiaiQuyet()` (nguồn mới), tab "Tất cả" GIỮ NGUYÊN `onSnapshot` có giới hạn như cũ
(trộn hot+cold, chưa áp dụng sentinel — xem "Ngoài phạm vi" ở mục cache lạnh). **`fetchWithTtlCache`
ban đầu dùng cho "Tìm thủ công" ở `GiaoNhanHoSoModule` đã bị TRIM/thay bằng chính
`useDanhSachDangGiaiQuyet()`** — 2 nơi cùng cần ĐÚNG 1 tập dữ liệu, gộp lại tránh 2 cơ chế cache
khác nhau tồn tại song song cho cùng 1 dữ liệu (dễ lệch nhau/khó hiểu về sau, đúng yêu cầu người
dùng "trim mọi phương án thừa và có khả năng gây conflict"). `fetchWithTtlCache` vẫn giữ lại, dùng
cho `NhapVuModal` (query khác hẳn — 300 vụ gần nhất theo `ngayTao`, không lọc `trangThai` trước).

**Cập nhật cục bộ cho đúng thao tác của CHÍNH người dùng** (`capNhatCucBoDsDangGiaiQuyet`) — phát
hiện qua test: "Đưa vào thùng rác"/"Khôi phục" 1 vụ đang có sẵn trong danh sách KHÔNG kích hoạt
sentinel (không phải vụ mới) — nếu không xử lý riêng, vụ vừa bị chính người dùng xoá vẫn nằm y
nguyên trước mắt họ cho tới khi remount, gây khó hiểu dù dữ liệu Firestore đã đúng. Đã thêm cập
nhật trực tiếp vào bộ nhớ (không qua Firestore) ngay sau khi `XoaVuAnModal`/`ThungRacModule.khoiPhuc`
ghi thành công — chỉ ảnh hưởng đúng trình duyệt của người vừa thao tác, người khác vẫn chờ remount
tự nhiên như thiết kế ban đầu (không phá vỡ nguyên tắc "hot data không cần live").

**Bug tự phát hiện + tự sửa trong lúc viết test (không phải giả thuyết suông)**: bản đầu tiên của
sentinel listener bị bắn **2 lần** ngay lúc khởi tạo (1 lần do gọi trực tiếp `dongBoDsDangGiaiQuyet()`
lúc mount, 1 lần do chính `onSnapshot` của sentinel tự bắn lại giá trị HIỆN CÓ ngay khi vừa subscribe
— hành vi chuẩn của Firestore, không phải lỗi) → tốn gấp đôi số `.get()` mỗi lần tải trang so với dự
kiến. Sửa bằng cách bỏ qua đúng lần bắn đầu tiên của sentinel (`laLanBanDau` flag).

**Composite index MỚI cần thiết** (đã thêm vào `firestore.indexes.json`, **đã deploy CẢ HAI**
`qlahs-test` VÀ `qlahsp2` production — an toàn vì chỉ thêm index, không đụng code/dữ liệu, và
`qlva.html` production hiện tại chưa có code dùng tới nên không ảnh hưởng gì tới người dùng thật
đang chạy): `vuan: trangThai ASC + ngayTao ASC` — Firestore yêu cầu vì query delta kết hợp 1 field
bằng (`trangThai`) với 1 field khoảng/bất đẳng thức khác (`ngayTao`). Phát hiện qua test dữ liệu
Firestore thật (mock không mô phỏng ràng buộc index nên không phát hiện được) — lúc index đang
build, sentinel tạm thời "lặng lẽ" không bổ sung được vụ mới (lỗi bị `catch` + `console.error`,
không crash UI) — tự khỏi khi build xong, không cần can thiệp gì thêm.

**Đã kiểm chứng bằng Playwright thật** (bộ mock: 9/9 assertion pass riêng cho sentinel + 26/26 pass
hồi quy toàn bộ Đợt 1/2 sau khi tích hợp — không có gì bị phá vỡ) VÀ **dữ liệu Firestore thật trên
`qlva-dev.html`** (project `qlahs-test`, 55 vụ đang giải quyết thật) — tạo 1 vụ án test thật, xác
nhận xuất hiện ngay qua sentinel SAU KHI index build xong (đã tự xác nhận lại bằng cách chạy lại
test — trước khi build xong sentinel bỏ qua vụ mới, không crash; sau khi build xong hoạt động đúng
100%), dọn dẹp sạch sau test. Trong lúc viết test mock cũng tự bổ sung `mock-firebase.js` (đếm
listener theo document riêng biệt với theo query, thêm `.add()`) — 2 chỗ mock thiếu, không phải bug
thật của app. Đã rà thêm các trường hợp biên qua suy luận (không chỉ test tự động): 2 vụ mới tạo sát
nhau nếu làm "nuốt" 1 tín hiệu sentinel thì lần đồng bộ kế tiếp (remount tự nhiên hoặc tín hiệu sau)
vẫn tự vét đủ nhờ query delta luôn hỏi "mọi thứ mới hơn mốc đã biết" chứ không phải "đúng 1 sự kiện
vừa báo" — tự lành, không mất dữ liệu vĩnh viễn.

**Ngoài phạm vi (chưa làm, chấp nhận là giới hạn hiện tại)**: tab "Tất cả" của Danh sách vụ án (trộn
hot+cold) chưa áp dụng cơ chế này. Khoá tránh xung đột sửa đồng thời ("ấn vào vụ X thì khoá cảnh báo
tài khoản khác") đã bàn và CHỦ ĐỘNG loại khỏi phạm vi tối ưu Firestore — dự án đã chọn hướng
transaction optimistic concurrency (xem "Audit tối ưu hệ thống") thay vì khoá thủ công.


## Tối ưu Firestore Đợt 1+2 — đã kiểm chứng bằng dữ liệu Firestore THẬT trên `qlva-dev.html` (2026-07-17)

Tiếp theo 2 mục "Tối ưu Firestore" bên dưới (Đợt 1: gộp listener + `ngayCapNhat`; Đợt 2: Thùng rác +
cache lạnh IndexedDB) — cả 2 trước đó mới chỉ kiểm chứng bằng mock Firestore trong bộ nhớ. Đã đăng
nhập THẬT vào `qlva-dev.html` (tài khoản có sẵn từ `seed-tool.html`: `admintest@local.com` /
`12345678`, project `qlahs-test`) qua Playwright tự dựng, thao tác trên dữ liệu thật (54 vụ đang
giải quyết, 1331 vụ đã giải quyết) — không phải bản mô phỏng nhỏ.

**Kết quả**: cache lạnh IndexedDB lưu đúng **1331 document thật** (không phải vài document giả lập),
field ngày tháng chuyển đúng sang `Date` gốc hợp lệ ở quy mô thật. Thùng rác test trọn vòng đời trên
2 vụ án tự tạo (tạo → đưa vào thùng rác → biến mất khỏi Danh sách vụ án trong vòng ~0.5s → hiện đúng
trong Thùng rác → Xoá vĩnh viễn → dọn sạch, không để lại rác trên `qlahs-test`) — đúng hoàn toàn,
không phát sinh lỗi console nào do các thay đổi Đợt 1/2 gây ra.

**Phát hiện 1 lỗi CÓ SẴN TỪ TRƯỚC, không liên quan tối ưu Firestore**: mở panel chi tiết bất kỳ vụ
án nào báo lỗi console thật `FirebaseError: The query requires an index` cho query
`lichsuChuyenGiaiDoan` (`maVuAn`+`thoiDiemGhi`). Index này **đã có sẵn đúng trong
`firestore.indexes.json`** (dòng 13-19) nhưng chưa từng được deploy lên project `qlahs-test` (có lẽ
chỉ deploy lên production `qlahsp2` trước đây) — nghĩa là tab "Lịch sử" trong panel chi tiết đã bị
lỗi thật trên môi trường test trong 1 khoảng thời gian không rõ từ khi nào. Đã chạy `firebase deploy
--only firestore:indexes --project test` để sửa — Firestore cần vài phút để build xong index mới
trên collection đã có nhiều document, nên lỗi có thể còn thấy tạm thời ngay sau khi deploy, tự hết
khi build xong (không cần làm gì thêm, kiểm tra lại sau vài phút nếu còn thấy lỗi này).

**Kết luận**: Đợt 1+2 tối ưu Firestore sẵn sàng cân nhắc đưa lên `qlva.html` production — đã qua đủ
2 lớp kiểm chứng (mock cô lập + dữ liệu Firestore thật quy mô lớn), không phát hiện lỗi nào do chính
các thay đổi này gây ra.

## Tối ưu Firestore — Đợt 2 (phần 2): Cache lạnh IndexedDB cho vụ án ĐÃ GIẢI QUYẾT (2026-07-17)

Mảnh cuối của kế hoạch tối ưu Firestore 4 giai đoạn — mục tiêu: vụ đã giải quyết gần như bất biến
nên lưu VĨNH VIỄN trên máy người dùng qua IndexedDB, chỉ hỏi lại Firestore đúng phần THAY ĐỔI thay
vì tải lại toàn bộ mỗi lần mở "Án đã giải quyết" — chi phí đồng bộ tỉ lệ với SỐ THAY ĐỔI THẬT, không
tỉ lệ với tổng số vụ đã giải quyết tích luỹ từ trước (sẽ càng quan trọng khi dữ liệu nhiều năm).

**Cơ chế (`dongBoColdCacheVuAnDaGiaiQuyet`, đặt cạnh `AnDaGiaiQuyetModule`)**: lần đầu (chưa có
cache) tải trọn 1 lần bằng `where("trangThai", "!=", "dang_giai_quyet")` — hợp lệ vì chỉ 1 field bất
đẳng thức. Lần sau, **Firestore KHÔNG cho kết hợp 2 field bất đẳng thức khác nhau trong 1 query**
(không thể vừa `trangThai != X` vừa `ngayCapNhat > Y`), nên đồng bộ tăng dần dùng ĐÚNG 1 field bất
đẳng thức duy nhất — `where("ngayCapNhat", ">", lầnSyncTrước)` cho MỌI vụ bất kể trạng thái — rồi tự
phân loại lại ở phía client: vụ vừa chuyển SANG "đã giải quyết" thì thêm/cập nhật vào cache; vụ vừa
chuyển VỀ "đang giải quyết" (Phục hồi/"Xoá hình thức giải quyết") thì xoá khỏi cache lạnh (không còn
lạnh nữa). Nhờ vậy các trường hợp đặc biệt (Phục hồi, nhập mức án lúc nộp lưu trữ...) tự động được
xử lý đúng mà không cần code riêng — cả 2 đều là 1 lần GHI vào `vuan`, tự cập nhật `ngayCapNhat`.

**Lưu ý kỹ thuật quan trọng phát hiện lúc code (không phải lý thuyết suông)**: Firestore `Timestamp`
là 1 class riêng, KHÔNG phải kiểu dữ liệu gốc trình duyệt — thuật toán "structured clone" mà
IndexedDB dùng để lưu dữ liệu không đảm bảo giữ nguyên prototype của class tự định nghĩa (khác
`Date` gốc — được hỗ trợ đúng, giữ nguyên `.getTime()`). Lưu thẳng `Timestamp` vào IndexedDB sẽ mất
`.toDate()`/`.toMillis()` khi đọc lại, làm hỏng MỌI chỗ hiển thị ngày tháng của dữ liệu lấy từ cache
— đã thêm `sanitizeChoIndexedDb(doc)` chuyển các field dạng Timestamp sang `Date` gốc TRƯỚC khi ghi
(an toàn vì `fmtDate`/`fmtNgayGio`/mọi so sánh ngày trong app đều đã viết theo kiểu
`x?.toDate?.() ?? (x instanceof Date ? x : new Date(x))` — tương thích sẵn cả 2 dạng).

**`AnDaGiaiQuyetModule` đấu nối vào cache lạnh** — bỏ hẳn `onSnapshot` theo TỪNG hình thức giải
quyết (5 listener khác nhau tuỳ tab, tải lại Firestore mỗi lần đổi tab); giờ đồng bộ 1 lần lúc mount
(toàn bộ vụ đã giải quyết mọi hình thức), 5 tab chuyển đổi CHỈ lọc lại phía client
(`listTheoHinhThuc`), **không gọi Firestore nữa khi đổi tab** — tác dụng phụ tốt: chuyển tab giờ tức
thời. Đánh đổi: không còn realtime — chấp nhận vì đúng tiền đề "gần như bất biến" của cache lạnh.
Vá 1 khe hở còn lại: nếu người dùng thao tác (Phục hồi/Xoá hình thức giải quyết) NGAY TẠI
`ChiTietPanel` bên phải của chính module này (không phải remount cả module) — bọc `onDoiSelected`
để tự đồng bộ lại (delta, rẻ) ngay sau đó, tránh danh sách bên trái vênh với trạng thái mới nhất.

**Đã kiểm chứng bằng Playwright thật + IndexedDB thật của trình duyệt** (không mock IndexedDB — dùng
API `indexedDB` thật trong Chromium headless) — 26/26 assertion pass tổng cộng cho cả Đợt 1+2, riêng
phần cache lạnh: xác nhận IndexedDB lưu đúng 1 document, field ngày là `Date` gốc hợp lệ (không phải
Timestamp hỏng/Invalid Date); lần mount tiếp theo KHÔNG lặp lại full-sync mà dùng đúng đường delta;
dữ liệu vẫn hiển thị đúng sau khi chuyển từ full-sync sang delta-sync. **Sự cố gặp phải khi tự viết
test (đã tự phát hiện và sửa, không phải bug thật của app)**: quên mirror thay đổi từ `qlva.html`
sang `qlva-dev.html` trước khi chạy test lần đầu — test "im lặng" báo 0 lượt gọi Firestore vì code
mới chưa tồn tại ở file đang test; sau khi mirror đúng thì pass sạch — bài học: LUÔN mirror trước
khi test, không chỉ trước khi commit.
**Còn lại chưa kiểm chứng**: dữ liệu Firestore THẬT trên `qlva-dev.html` (project `qlahs-test`) —
nên mở thử ít nhất 1 lần, xem "Án đã giải quyết" tải đúng, chuyển tab tức thời, và F12 → Application
→ IndexedDB xác nhận thấy đúng database `qlva_cold_cache_v1` trước khi tin tưởng lên production.

**Ngoài phạm vi Đợt 2 (không làm, chấp nhận là giới hạn hiện tại)**: cache lạnh CHƯA áp dụng cho
`baoCaoLuu` của kỳ báo cáo đã chốt (mục tiêu ban đầu có nhắc tới) — phần lớn lợi ích thực tế đã đạt
được gián tiếp qua Đợt 1 (cache `kybaocao` dùng chung, tránh đọc lặp `baoCaoLuu` giữa nhiều
component), phần còn thiếu chỉ là bền vững qua LẦN TẢI TRANG MỚI — giá trị tăng thêm nhỏ so với rủi
ro đụng vào logic Biểu B10 đã audit kỹ nhiều lần, nên dừng lại ở đây. Cache lạnh cũng CHƯA áp dụng
cho tab "Tất cả" của Danh sách vụ án (trộn lẫn vụ đang + đã giải quyết, khó tách hot/cold sạch như
`AnDaGiaiQuyetModule` — module dành riêng cho dữ liệu lạnh nên là ứng viên tự nhiên nhất).

## Tối ưu Firestore — Đợt 2 (phần 1): Thùng rác — xoá vụ án đổi từ xoá cứng sang soft-delete (2026-07-17)

Nền tảng bắt buộc cho cache lạnh IndexedDB (xem "Ngoài phạm vi Đợt 1" ở mục Đợt 1 bên dưới) —
query kiểu `where(ngayCapNhat > lầnSyncTrước)` không bao giờ thấy được việc XOÁ document, nên phải
biến "xoá" thành "ghi" trước khi cache lạnh có thể tin tưởng dùng delta-check.

**`XoaVuAnModal` đổi hẳn từ cascade xoá cứng sang đặt cờ** — không còn `batch.delete` lên
`bican`/`lichsuChuyenGiaiDoan`/`vuan`, chỉ `update({ daXoa: true, ngayXoaMem, nguoiXoaMem,
ngayCapNhat, nguoiCapNhatCuoi })` lên đúng `vuan`. Giữ nguyên `bican`/log để: (1) Khôi phục chỉ cần
gỡ cờ, không mất gì; (2) số liệu báo cáo kỳ (tính từ log) không bị ảnh hưởng cho tới khi thật sự
"Xoá vĩnh viễn". Xác nhận đổi từ "gõ lại đúng mã vụ" sang gõ lại **1 mã 4 ký tự SINH NGẪU NHIÊN**
hiển thị ngay trên màn hình (`taoMaXacNhanNgauNhien`, bộ ký tự `BO_KY_TU_MA_XAC_NHAN` loại bỏ
0/O/1/l/I để tránh gõ nhầm vì đọc nhầm) — vì giờ thao tác này CÓ THỂ hoàn tác, không cần mức xác
nhận chặt như trước. Giữ nguyên guard chặn xoá nếu còn vụ con tách ra từ vụ này (`vuGoc`).

**Module mới "Thùng rác"** (`ThungRacModule`, tab thứ 5 trong `CaiDatModule`, sau "Import Excel") —
liệt kê `vuan` có `daXoa == true` (query trực tiếp qua Firestore, KHÔNG có vấn đề như `!=` vì đây là
so khớp `==true`), mỗi dòng có 2 nút: **"Khôi phục"** (gỡ cờ `daXoa`/`ngayXoaMem`/`nguoiXoaMem`) và
**"Xoá vĩnh viễn"** (mở `XoaVinhVienModal` — logic cascade xoá y hệt `XoaVuAnModal` bản CŨ, giữ
nguyên mức xác nhận chặt "gõ lại đúng mã vụ" vì đây mới là hành động thật sự không thể hoàn tác).

**Lọc `daXoa` khỏi mọi nơi liệt kê `vuan` cho người dùng xem** — cố tình lọc phía **CLIENT**
(`.filter(v => !v.daXoa)` sau khi map dữ liệu), **KHÔNG dùng Firestore `where("daXoa","!=",true)`**:
query `!=` bỏ qua LUÔN mọi document không có field đó, mà toàn bộ dữ liệu cũ chưa từng có field
`daXoa` — lọc ở tầng Firestore sẽ làm mất trắng danh sách. Đã áp dụng ở: `DanhSachPanel` (cả query
chính lẫn `dsTimKiemDayDu`), `AnDaGiaiQuyetModule`, `DashboardModule` (2 nơi: đếm theo giai đoạn +
cảnh báo hạn điều tra), `tinhSnapTonTheoTD`/`tinhTonHienTaiTheoGD`/`tinhBaoCaoKyTuLog` (3 hàm tính
"tồn" của Kỳ báo cáo — dùng biến trung gian `demsDocs` để không phải sửa rải rác nhiều chỗ dùng lại
cùng 1 mảng snapshot), `GiaoNhanHoSoModule` (Tìm thủ công), `NhapVuModal` (tìm vụ đích), `xuatExcel`,
`ImportExcelModule` (đối chiếu trùng — vụ đã trashed KHÔNG tính là trùng, vì trash dùng để sửa sai
sót nên import lại đúng dữ liệu phải được cho phép).
**Cố tình CHƯA lọc** `vuAnTuLogDocs` (dùng bởi `tinhBaoCaoKyTuLog` để dựng các mảng `ds` xuất ra
sheet Excel báo cáo tháng, ảnh hưởng trực tiếp tới công thức SUMIF/COUNTIF của Biểu B10) — rủi ro
cao hơn hẳn các nơi trên vì đụng vào logic đã được audit kỹ nhiều lần trước đây (xem "Trạng thái
Biểu B10"), cần cân nhắc riêng nếu có nhu cầu thực tế (hiện chưa có vụ nào bị trash trên production).

**Đã kiểm chứng bằng Playwright thật** (cùng bộ mock Firestore/Auth dựng ở Đợt 1) — 18/18 assertion
pass, gồm cả kịch bản end-to-end đầy đủ: mở panel chi tiết → bấm "Đưa vào thùng rác" → xác nhận mã
ngẫu nhiên đúng định dạng 4 ký tự → gõ đúng mã → xác nhận vụ biến mất khỏi Danh sách vụ án → xác
nhận vụ hiện đúng trong tab Thùng rác → bấm "Khôi phục" → xác nhận vụ biến mất khỏi Thùng rác VÀ
hiện lại đúng trong Danh sách vụ án → xác nhận cả 2 lần ghi (`daXoa:true` lúc xoá, `daXoa:false` lúc
khôi phục) đều đúng field, lần xoá có kèm `ngayCapNhat`. **Còn lại chưa kiểm chứng**: dữ liệu
Firestore thật trên `qlva-dev.html` (project `qlahs-test`) — nên thử ít nhất 1 lần trước khi tin
tưởng lên `qlva.html` production, đặc biệt xác nhận Security Rules hiện tại (chỉ chặn theo
`request.auth != null`) không cần sửa gì để `update` field `daXoa` hoạt động (không có rule riêng
theo field nên nhiều khả năng không cần, nhưng chưa xác nhận thật).

## Tối ưu Firestore — Đợt 1: gộp listener trùng + chuẩn bị nền cho cache lạnh (2026-07-17)

Audit theo yêu cầu người dùng: tài khoản Firebase hết quota nhanh vì "bất kỳ thao tác nào cũng
truy vấn lại từ đầu". Đếm trực tiếp trong code xác nhận cụ thể (không phải áng chừng): `canbo` bị
gắn **6 listener độc lập** (`useDanhSachCanBo()` gọi ở `ThemVuAnForm`/`SuaVuAnForm`/`DanhSachPanel`/
`ChiTietVuAnModal`/`GiaoNhanHoSoModule` + 1 nơi riêng ở `CanBoModule`), `kybaocao` bị gắn **6 nơi
tốn đọc độc lập** (5 `onSnapshot` ở `DanhSachPanel`/`KyBaoCaoModule`/`AnDaGiaiQuyetModule`/
`DashboardModule`/`NhatKyModule`, **cộng thêm `ModalXacNhanKy` tự `.get()` lại TOÀN BỘ collection
MỖI LẦN MỞ** — modal này mở ở MỌI thao tác nghiệp vụ nên đây mới là điểm tốn quota nhiều nhất, dù
không lộ ra qua `onSnapshot` lúc grep ban đầu), `danhMucToiDanh` bị gắn 2 listener độc lập.

**Thiết kế: lớp cache/listener dùng chung** (`useFirestoreCollectionCache`/`useFirestoreCacheLoaded`,
đặt đầu file cạnh các hook dùng chung khác, dòng ~1129) — registry toàn cục (`firestoreCacheRegistry`,
ngoài React) giữ ĐÚNG 1 listener Firestore sống cho mỗi `cacheKey`, chia sẻ dữ liệu cho mọi hook
đang subscribe qua 1 tập callback nội bộ; giữ listener sống thêm 3 phút (`FIRESTORE_CACHE_GRACE_MS`)
sau khi subscriber cuối unmount (chuyển tab/mở-đóng form nhanh không phá rồi dựng lại từ đầu), chỉ
huỷ hẳn khi hết grace period mà không ai subscribe lại. Cleanup được gom vào 1 hàm dùng chung
(`lichHuyNeuKhongAiDung`) gọi từ CẢ 2 hook (dữ liệu lẫn "loaded") — cố tình không đặt logic này chỉ
trong 1 hook vì thứ tự chạy cleanup giữa nhiều hook cùng component lúc unmount không đảm bảo cố
định, đã viết test riêng xác nhận cả 2 thứ tự khai báo hook đều dọn dẹp đúng, không rò rỉ.

**Áp dụng**: `useDanhSachCanBo()`/`useDanhMucToiDanh()` (fallback về `DANH_MUC_TOI_DANH_MAM` khi
Firestore rỗng — giữ nguyên hành vi cũ, chỉ đổi cách lấy dữ liệu) đổi sang dùng cache, KHÔNG cần sửa
5+ call site vì đã là hook dùng chung. `CanBoModule` (dòng cũ tự mở listener riêng thay vì gọi hook)
đổi sang gọi thẳng hook. `kybaocao` **KHÔNG gộp về 1 query duy nhất kèm sort lại phía client** như
dự định ban đầu — phát hiện lúc code: `timKyTruoc` (dùng ở `KyBaoCaoModule`) có comment rõ ràng
"Không dùng so sánh timestamp để tránh bug khi data có format không đồng nhất", dựa hẳn vào thứ tự
Firestore trả về từ `orderBy` server-side. Sort lại phía client sẽ tái lập đúng lớp bug đó đã né
trước đây — thay vào đó dùng ĐÚNG 2 cacheKey khớp 2 query thật sự khác nhau: `"kybaocao:desc"`
(orderBy desc — dùng bởi `DanhSachPanel`/`KyBaoCaoModule`/`AnDaGiaiQuyetModule`/`NhatKyModule`/
**`ModalXacNhanKy`**, gộp 6 nơi thành 1 listener) và `"kybaocao:asc"` (orderBy asc — riêng
`DashboardModule` cần đúng chiều thời gian cho biểu đồ). `ModalXacNhanKy` đổi từ `.get()` một lần
sang cache sống, nhưng vẫn giữ đúng hành vi "chỉ tự đặt `kyChon` mặc định 1 LẦN mỗi lần mở modal"
qua 1 `useRef` cờ đánh dấu — tránh cache cập nhật sống trong lúc modal đang mở làm mất lựa chọn tay
của người dùng.

**Giai đoạn 2 — thêm `ngayCapNhat`/`nguoiCapNhatCuoi` vào toàn bộ 13 nơi ghi `bican`** (rà soát xác
nhận `bican` trước đây HOÀN TOÀN không có field mốc thời gian nào, khác `vuan` đã dùng nhất quán) —
điều kiện tiên quyết bắt buộc cho cache lạnh dựa trên delta ở Đợt 2 sau này (xem "Ngoài phạm vi Đợt
1" bên dưới): `tachVuAn` (3 chỗ), `BackfillDieuLuatBCTool`, `BackfillLoaiKhoiToTool`,
`ImportExcelModule`, `NhapVuModal` (2 chỗ), `ThemVuAnForm`, `SuaBiCanForm` (2 chỗ — quan trọng nhất
vì đây là chỗ sửa bị can điển hình nhất), `ThemBiCanForm` (2 chỗ). Không sửa `XoaVuAnModal` (chỉ
`batch.delete`, không phải create/update).

**Đã kiểm chứng**: (1) biên dịch cú pháp cả `qlva.html`/`qlva-dev.html` qua `esbuild` (JSX) — sạch,
không lỗi; (2) test độc lập bằng `react-test-renderer` + Firestore giả lập cho đúng cơ chế cache
dùng chung — 5 kịch bản/11 assertion pass (dedupe đúng 1 listener dù nhiều component subscribe,
remount trong grace period không tạo listener mới, unmount hẳn quá grace period thì huỷ đúng —
không rò rỉ, thứ tự khai báo 2 hook dữ liệu/loaded đảo ngược nhau vẫn dọn dẹp đúng, dữ liệu đúng
nội dung); (3) **test bằng Playwright THẬT trên `qlva-dev.html`** (không có tài khoản Firebase test
thật/MCP trình duyệt trong phiên này, nên tự dựng: chặn 3 script CDN Firebase compat qua
`page.route()`, thay bằng 1 file mock Firestore/Auth trong bộ nhớ — bypass đăng nhập, có
`.collection().where().orderBy().limit().onSnapshot()/.get()`, `batch()`, đếm số lần `onSnapshot()`
THẬT được gọi theo từng chữ ký query — chạy app THẬT qua Babel-in-browser thật, không phải mock cô
lập) — 6/6 assertion pass: không lỗi console (ngoại trừ 1 cảnh báo Babel vô hại về kích thước file,
không liên quan); **chuyển qua lại đúng 18 lần (3 vòng × 6 tab) chỉ tạo ĐÚNG 2 listener thật cho
`kybaocao` và 1 cho `canbo`** (không tăng theo số lần chuyển tab — xác nhận cơ chế gộp hoạt động
đúng trong runtime thật); mở lại form "Thêm vụ án" 3 lần không tạo thêm listener `canbo`; thực hiện
trọn luồng "Thêm bị can" thật qua UI — xác nhận CẢ 2 lần ghi `bican` do luồng này gây ra (tạo mới +
cập nhật lại `loaiKhoiTo` cho vụ) đều có đúng field `ngayCapNhat`/`nguoiCapNhatCuoi`.
**Còn lại chưa kiểm chứng**: dữ liệu Firestore THẬT (project `qlahs-test`) — test trên chỉ dùng mock
trong bộ nhớ, chưa xác nhận với rules/index/latency thật của Firestore. Nên mở thử `qlva-dev.html`
thật ít nhất 1 lần (đăng nhập thật, thao tác vài nghiệp vụ) trước khi tin tưởng tuyệt đối lên
`qlva.html` production.

**Ngoài phạm vi Đợt 1 (để dành phiên sau, xem plan gốc đã thống nhất với người dùng)**: Thùng rác
(soft-delete cho `XoaVuAnModal` — đổi `batch.delete` thành đặt cờ `daXoa`/`ngayXoa`, tab "Thùng rác"
mới trong `CaiDatModule`, lọc `daXoa` ở mọi nơi liệt kê `vuan` — bao gồm `xuatExcel`/
`ImportExcelModule` đối chiếu trùng/`NhapVuModal` tìm vụ đích) và cache lạnh IndexedDB (dựa trên
`ngayCapNhat` vừa thêm ở Giai đoạn 2) cho vụ đã giải quyết + `baoCaoLuu` của kỳ đã chốt — mục tiêu
cuối cùng đã thống nhất: vụ đã giải quyết gần như bất biến (trừ Tạm đình chỉ → Phục hồi, hoặc nhập
mức án lúc nộp lưu trữ — cả 2 đều là 1 lần GHI vào `vuan` nên tự động lọt vào delta-check theo
`ngayCapNhat`, không cần code riêng từng ngoại lệ) nên chỉ cần tải 1 lần, chỉ đồng bộ lại đúng phần
đổi qua query rẻ `where(ngayCapNhat > lầnSyncTrước)` thay vì tải lại toàn bộ mỗi lần.

## Kế hoạch tiếp theo (ghi lúc checkout nhánh `toi-uu-firestore-read`, 2026-07-17)

Đang đứng ở nhánh **`toi-uu-firestore-read`** (branch mới nhất trên remote, commit cuối `e09e53c`
lúc 15:50 17/07) — **CHƯA gộp với nhánh `bang-excel-cai-dat`** (đứng trước đó, có tính năng Cài
đặt → "Bảng dữ liệu" kiểu Excel mà nhánh này KHÔNG có, vì 2 nhánh tách nhau từ trước rồi phát
triển song song). Cần merge lại với nhau (hoặc cả 2 vào `main`) trước khi coi 1 trong 2 là đầy đủ.

**5 commit của nhánh này (toàn bộ đều CHƯA kiểm chứng bằng dữ liệu Firestore thật trên
`qlva-dev.html`, chỉ mới compile-check)**, đều thuộc module Giao nhận hồ sơ: "Không tiếp nhận" kèm
lý do, danh sách "Phiên gần đây" (mở lại phiên dở/đã lưu), fix in A4 bị cắt khi dài hơn 1 trang,
đặt tên phiên tự động theo ĐTV/KSV sau khi quét hồ sơ đầu, nút "Xoá hình thức giải quyết" (sửa lỗi
chọn nhầm hình thức Hoàn thành vụ án), ràng buộc "Đã xét xử" chỉ chọn được ở giai đoạn Xét xử. Chi
tiết đầy đủ nằm trong đúng các mục tương ứng bên dưới (tìm theo ngày `2026-07-17`).

**Việc cần làm tiếp theo (theo yêu cầu người dùng), gộp chung 2 việc**:
1. Kiểm chứng 5 commit trên bằng dữ liệu Firestore thật (`qlva-dev.html`), rồi merge nhánh này
   với `bang-excel-cai-dat` (hoặc vào `main`) để không mất tính năng "Bảng dữ liệu" đang có riêng
   ở nhánh kia.
2. **Phát triển lại phần Báo cáo** (module Kỳ báo cáo — hiện vẫn còn nhãn "🚧 Đang xây dựng" cạnh
   tiêu đề, xem mục "Trạng thái Biểu B10" ngay dưới đây và mục "Kỳ báo cáo" ở "Tiến độ đã code") —
   người dùng muốn làm lại phần này, chưa nói rõ phạm vi cụ thể (sửa tiếp bug còn tồn đọng ở B10 hay
   thiết kế lại toàn bộ UI/luồng) — **hỏi lại người dùng để làm rõ phạm vi trước khi bắt tay code**,
   đừng tự suy đoán quy mô thay đổi.

## Giao nhận hồ sơ — tự động lưu khi chuyển dòng + đổi nhãn/style Mức án (2026-07-17)

**Tự động lưu khi chuyển sang sửa dòng khác** — trước đây mỗi dòng (`DongGiaoNhan`) tự quản trạng
thái `dangSua` cục bộ, có thể mở sửa nhiều dòng cùng lúc không kiểm soát; người dùng bấm nhầm sang
dòng khác mà quên bấm "Lưu" ở dòng trước là mất trắng dữ liệu vừa nhập (đặc biệt khó chịu khi kiểm
kê nhiều hồ sơ lưu trữ liên tục, thao tác nhanh). Đổi thiết kế: `GiaoNhanHoSoModule` giữ 1 state
duy nhất `dangSuaId` (id dòng đang sửa, CHỈ 1 dòng được sửa cùng lúc trong toàn phiên) + 1 ref
`luuHandlersRef` (map id → hàm `luu()` MỚI NHẤT của đúng dòng đó, mỗi `DongGiaoNhan` tự đăng ký lại
qua `onDangKyLuu` mỗi lần render). Bấm sang dòng khác gọi `yeuCauSuaDong(id)`: nếu đang có dòng
KHÁC dở dang, tự gọi `luuHandlersRef.current[dangSuaId]()` trước — **lưu thất bại (VD mất mạng) thì
GIỮ NGUYÊN dòng cũ, không chuyển sang dòng mới**, để người dùng thấy toast lỗi và có cơ hội sửa lại
thay vì mất dữ liệu trong im lặng. `luu()` giờ trả về `true`/`false` để `yeuCauSuaDong` biết kết
quả. Riêng "Huỷ" KHÔNG tự lưu (đúng ý nghĩa huỷ bỏ) — chỉ gọi thẳng `ketThucSuaDong()`.
`dangSua` ở `DongGiaoNhan` từ state cục bộ chuyển thành PROP do cha điều khiển; nạp lại giá trị
hiện tại của dòng khi `dangSua` chuyển `false → true` chuyển từ logic trong `batDauSua` sang 1
`useEffect` theo dõi prop này (áp dụng đúng dù chuyển vào edit mode do người dùng bấm dòng này hay
do dòng khác vừa tự lưu xong rồi nhường sang). Nút "Lưu phiên" vẫn khoá khi `dangSuaId !== null`
(trường hợp bấm thẳng "Lưu phiên" mà không qua thao tác chuyển dòng — safeguard cũ ở
[[toi-uu-he-thong]] vẫn cần, không thay thế được bởi auto-save này).
**Đã kiểm chứng bằng Playwright + mock Firestore** (không chỉ đọc code): chuyển dòng A sang dòng B
mà không bấm "Lưu" → xác nhận dòng A tự lưu đúng giá trị vào Firestore rồi thoát sửa, dòng B vào
chế độ sửa; giả lập lỗi ghi Firestore cho dòng A rồi thử chuyển sang B → xác nhận dòng A VẪN ở chế
độ sửa (không mất dữ liệu, không chuyển "trót lọt"), dòng B không bị ảnh hưởng.

**Cột "Mức án" đổi tên thành "Mức án cao nhất"** (rõ nghĩa hơn — 1 vụ có thể nhiều bị can/nhiều
mức án khác nhau, field `mucAnLoai/mucAnNam/mucAnThang` trên `vuan` chỉ lưu ĐÚNG 1 mức, hiểu ngầm
là mức cao nhất dùng để tính thời hạn bảo quản) — đổi ở cả 4 chỗ: header bảng trên màn hình, header
cột Excel "Tải toàn bộ lịch sử", dòng gợi ý dưới công tắc "Nộp hồ sơ lưu trữ", và header bảng Biên
bản in A4.

**"Thời hạn bảo quản" hiện đỏ + in đậm + cỡ chữ to hơn** ở cả bảng trên màn hình
(`text-red-600 font-bold`, cỡ `text-sm` thay vì `text-xs`) lẫn Biên bản in A4 (thêm `text-base`,
cỡ to nhất so với các cột khác trong bảng in) — dễ nhận ra ngay khi liếc mắt, đúng vai trò là con
số quan trọng nhất của cả phiên nộp lưu trữ.

## Audit "tối ưu hệ thống" (nhánh `toi-uu-he-thong`, 2026-07-16)

Rà soát toàn bộ logic hệ thống theo yêu cầu người dùng — tìm vùng dễ xung đột (race condition khi
nhiều người dùng cùng lúc), rà lại CLAUDE.md/schema doc xem có chỗ nào lỗi thời không còn khớp
code thật. Dùng agent Explore quét toàn bộ file + tự kiểm chứng lại các claim quan trọng trước khi
sửa (không tin ngay báo cáo agent, đối chiếu code thật).

**Đã sửa — lost-update race condition thật (không phải lý thuyết) ở 3 nơi cùng 1 pattern:**
`SuaBiCanForm`, `ThemBiCanForm`, `NhapVuModal` đều đọc TOÀN BỘ bị can của 1 vụ, tính lại
`dieuLuat`/`loaiKhoiTo` ở phía client, rồi ghi lại bằng `batch.commit()` thường — không có gì đảm
bảo dữ liệu đọc được còn mới khi ghi, nếu 2 người cùng sửa bị can của CÙNG 1 vụ gần như đồng thời
thì người ghi sau (dựa trên dữ liệu đã cũ) sẽ ÂM THẦM ĐÈ MẤT kết quả của người ghi trước — không
báo lỗi, không ai biết. Gộp cả 3 nơi thành 1 hàm dùng chung `capNhatDieuLuatVaLoaiKhoiTo(maVuAn)`
(định nghĩa cạnh `tinhLoaiKhoiTo`), bọc trong `db.runTransaction` đúng cách: query lấy DANH SÁCH ID
bị can NGOÀI transaction (SDK compat đang dùng không hỗ trợ query trực tiếp trong transaction), rồi
đọc lại TỪNG bị can bằng `tx.get()` theo đúng ID đó BÊN TRONG transaction — Firestore tự phát hiện
nếu có doc nào bị đổi trước khi commit và tự động thử lại toàn bộ callback. Giới hạn còn lại (chấp
nhận được): bị can MỚI thêm vào đúng lúc giữa 2 bước không được tính vào lần gọi này — không sao vì
chính thao tác thêm đó cũng gọi lại hàm này ngay sau.
**Tiện thể sửa luôn 1 bug liên quan phát hiện trong lúc audit**: `NhapVuModal` trước đây CHỈ tính
lại `dieuLuat` cho vụ đích, bỏ sót `loaiKhoiTo` — bị can nhập vào có ngày khởi tố sớm hơn mọi bị
can sẵn có của vụ đích thì đúng ra phải đổi lại ai là "ban đầu"/"bổ sung", trước đây không tính.
Dùng chung `capNhatDieuLuatVaLoaiKhoiTo` nên tự động được sửa luôn.
**Đã kiểm chứng bằng 2 lớp test thật** (không chỉ đọc code): (1) mock Firestore có `runTransaction`
thật với version-check + tự động retry khi phát hiện xung đột (đúng ngữ nghĩa Firestore optimistic
concurrency) — mô phỏng đúng kịch bản race (client B ghi đè bị can B ngay giữa lúc client A đang
trong transaction), xác nhận transaction TỰ ĐỘNG THỬ LẠI (2 lần) và kết quả cuối cùng KHÔNG mất
thay đổi của B; (2) test tích hợp qua Playwright chạy thẳng `ThemBiCanForm` thật (component thật
trong `qlva.html`, không phải bản copy logic) với mock Firestore tương tự — xác nhận thêm 1 bị can
có ngày khởi tố sớm hơn khiến `loaiKhoiTo` được tính lại đúng cho CẢ HAI bị can (bị can cũ đổi từ
"ban_dau" sang "bo_sung", bị can mới thành "ban_dau") và `dieuLuat` gộp đúng tội danh cả 2.

**Đã thêm 1 composite index phòng ngừa** vào `firestore.indexes.json`:
`lichsuChuyenGiaiDoan: kyThongKe+loaiSuKien+tuGiaiDoan` (song song với index đã có
`kyThongKe+loaiSuKien+denGiaiDoan`) — Firestore có thể không thực sự cần index này cho truy vấn
chỉ toàn điều kiện bằng nhau (`==`), nhưng thêm vào không có mặt trái, còn nếu thiếu mà thật sự cần
thì sẽ gây lỗi runtime khi tra cứu ở module Kỳ báo cáo (`tinhBaoCaoKyTuLog`).

**Đã sửa 2 tài liệu lỗi thời:**
- CLAUDE.md dòng "nay 7 module" (mục Tiến độ đã code) — thực tế mảng `MODULES` chỉ có 5 phần tử,
  cộng thêm tab "Cài đặt" gắn cứng ngoài mảng (không tính trong `MODULES`) mới ra 6 tab hiển thị.
- `schema_csdl_he_thong_quan_ly_an_v2.md` — thêm ghi chú đầu file nói rõ đây là khung sườn cốt lõi,
  không liệt kê đầy đủ mọi field thêm sau này (tra CLAUDE.md để biết field/enum mới nhất); bổ sung
  field `nhomBiCanId` (mục 2) và 2 `loaiSuKien` còn thiếu là `giao_nhan_ho_so`/`duoc_nhap_vu` (mục
  3); sửa lại hẳn mục "Index cần tạo trước" (bản cũ liệt kê 2 index KHÔNG hề tồn tại trong
  `firestore.indexes.json` thật — `bican: maVuAn+ngayKhoiTo` và `vuan: maNganhCap` — cả 2 đều
  không có query nào trong code cần đến; đồng thời thiếu 3 index mới đã thêm cho tối ưu hiệu năng
  Danh sách vụ án/Án đã giải quyết/Giao nhận hồ sơ).

**Đã đối chiếu, xác nhận KHÔNG có vấn đề (không cần sửa)**: `qlva.html`/`qlva-dev.html` vẫn đồng bộ
hoàn toàn (chỉ khác đúng phần cấu hình Firebase + nhãn `[TEST]` cố ý); mọi composite query khác
trong code đều có index khớp trong `firestore.indexes.json`; không tìm thấy dead code khi lấy mẫu
ngẫu nhiên nhiều hàm giữa file; các nhánh git khác (`main`, `test-fix`, `bieu-10-audit`,
`bieu-10-tk`, `feature/hoan-tac-nhat-ky`, `feature/ky-baocao-excel`, `offline-indexeddb`,
`import-excel-fix`) đều đã nằm trọn trong lịch sử nhánh này qua các lần merge trước đó — không còn
rủi ro xung đột git giữa các nhánh tính năng. Riêng nhánh `mockdata` lệch xa (thiếu tới ~1600 dòng
so với hiện tại) — là nhánh thử nghiệm cũ bị bỏ dở, KHÔNG phải nhánh cần merge, cố tình bỏ qua.

**CHƯA kiểm chứng bằng dữ liệu Firestore thật** — mọi thứ ở trên mới kiểm chứng bằng mock trong bộ
nhớ (dù đã mô phỏng đúng ngữ nghĩa transaction/optimistic-concurrency của Firestore), chưa chạy thử
trên `qlva-dev.html` với project `qlahs-test` thật. Nên thử tạo 2 tab trình duyệt cùng sửa bị can
của 1 vụ gần như đồng thời trên `qlva-dev.html` trước khi hoàn toàn yên tâm.

## Trạng thái Biểu B10 (audit 2026-07-13 → đã sửa xong, để tham khảo lịch sử)

Nhánh `bieu-10-audit` từng audit ra 3 bug ở Biểu B10 (loaiKhoiTo import hardcode sai, thiếu xử lý
`an_huy`, sheet "TK tội danh" nhóm tội danh không đồng bộ với B10). Cả 3 đã được sửa và commit:
`1e87144` (loaiKhoiTo import + an_huy thiếu trong C3/C33/C60), `57ef5bb` (C4/C34/C61 thiếu an_huy
+ chuẩn hoá nhóm tội danh sheet TK tội danh qua `getDL()`/`normDL()`), `b8f3fdd` (B10 đếm vụ theo
tội danh CHÍNH — 1 vụ = 1 dòng), `d73c384` (tội danh chính của vụ dùng BC `loaiKhoiTo ===
"ban_dau"` thay vì `BC[0]`, đồng bộ giữa B10 và TK tội danh). Sau đó còn tái cấu trúc thêm: mỗi
loại sự kiện × giai đoạn thành 1 sheet riêng trong Xuất Excel báo cáo tháng (`531e4f0`), thêm cột
Đếm vụ (`465e0e6`), thêm 4 sheet RA chuyển giai đoạn + sheet Cân đối số liệu (`4a8e9eb`), thêm cột
Kỳ TK vào các sheet DS vào/ra (`6370775`) — xem "Xuất Excel báo cáo tháng" bên dưới cho mô tả hiện
tại của các sheet này.

Công cụ `TaiTaoTonTheoTDTool` ("Sửa lại tồn cuối kỳ theo tội danh (Biểu B10)" trong Cài đặt →
Import Excel, xem mục "Kỳ báo cáo") — **chưa xác nhận đã kiểm chứng bằng dữ liệu Firestore thật
trên `qlva-dev.html`** (không có commit nào ghi lại việc này vì bấm nút không tạo ra thay đổi
code). Nếu số liệu tồn cuối kỳ theo tội danh trên B10 còn nghi ngờ sai, kiểm chứng công cụ này
trước khi tin tưởng số liệu xuất ra từ nút đó trên `qlva.html` (production).

**Nhánh `fix-bao-cao` (2026-07-15, tiếp tục sau khi merge `bieu-10-audit` vào `main`)** — audit
tiếp bằng cách xem trực tiếp file Excel xuất ra: số vụ mới (C6 "ĐT khởi tố vụ") khớp đúng số dòng
sheet "DS khởi tố ĐT", nhưng khối nhân khẩu học C7-C24 (tuổi/trình độ/dân tộc...) ra 0/rỗng dù
vụ có bị can. Nguyên nhân: `seed-tool.html` (dùng để seed dữ liệu `qlva-dev.html`) có CÙNG bug
`loaiKhoiTo` hardcode sai đã audit ở `bieu-10-audit` (đã sửa `qlva.html`/`ImportExcelModule` từ
`1e87144`, nhưng chưa bao giờ sửa file seed riêng này) — bị can seed ra không bao giờ có
`loaiKhoiTo === "ban_dau"` nên bị lọc mất hết khỏi C7-C24. Đã sửa `seed-tool.html`, VÀ vì bug gốc
(`ImportExcelModule` trước `1e87144`) chỉ được chặn cho import MỚI chứ không backfill dữ liệu ĐÃ
import trước đó (kể cả production), nên đã thêm `BackfillLoaiKhoiToTool` (Cài đặt → Import Excel)
tính lại đúng `loaiKhoiTo` cho toàn bộ bị can hiện có, gom theo vụ, dùng đúng hàm
`tinhLoaiKhoiToTheoNgay` app đã dùng khi thêm/sửa bị can.

**Thiết kế lại khối C7-C24: bỏ hẳn tiêu chí `loaiKhoiTo` (2026-07-15)** — trong lúc thảo luận về
bug trên, người dùng đặt câu hỏi đúng trọng tâm: tại sao khối C7-C24 cần phân biệt "ban đầu"/
"bổ sung" theo `loaiKhoiTo`, trong khi hệ thống đã hỏi "tính vào kỳ thống kê nào" ngay lúc thêm
bị can (`ThemBiCanForm`/`ThemVuAnForm`/Import Excel) rồi? Đã xác nhận: (1) số vụ mới (C3/C6...)
hoàn toàn độc lập với sự kiện `khoi_to_bican` — chỉ phụ thuộc `khoi_to_vu`/`tach_vu`/
`chuyen_giai_doan`/`tra_ho_so`, nên thêm bị can bổ sung vào 1 vụ cũ KHÔNG làm đổi kỳ "vụ mới" của
vụ đó; (2) `loaiKhoiTo` chỉ được dùng để lọc BC ở ĐÚNG 1 khối duy nhất (C7-C24 "ĐT khởi tố mới")
— khối TT/XX tương ứng (C43-C52, C64...) đã đếm mọi BC của vụ, không lọc `loaiKhoiTo` từ trước.
Kết luận: thay `bc.loaiKhoiTo === "ban_dau"` bằng tiêu chí đúng bản chất hơn — **BC nào có sự
kiện `khoi_to_bican` với `kyThongKe` khớp đúng kỳ đang tính báo cáo thì mới đếm vào C7-C24 của kỳ
đó**, bất kể `loaiKhoiTo`. Nhờ vậy BC bổ sung thêm vào 1 vụ cũ ở kỳ SAU không còn bị đếm nhầm vào
kỳ vụ khởi tố (đằng nào cũng không nên tính, vì đó là BC "mới" của kỳ sau chứ không phải kỳ vụ
được mở). Chỉ áp dụng cho khối C7-C24 — usage KHÁC của `loaiKhoiTo` (`vuPrimaryDL`: chọn BC nào
đại diện tội danh chính của 1 vụ nhiều bị can/nhiều tội, dùng để nhóm B10/TK tội danh theo điều
luật) giữ nguyên, không liên quan gì tới câu hỏi này.
Triển khai: `tinhBieu10` nhận thêm `bcKyKhoiToMap` (Map BC id → kỳ id, từ hàm mới
`fetchKyKhoiToBiCan` — quét log `khoi_to_bican`, KHÔNG dùng field cache trên `bican` vì log là
nguồn sự thật duy nhất và có thể bị "Sửa kỳ" cập nhật sau) + `kyIdSetTrongBaoCao` (mặc định
`{ky.id}`, nhưng báo cáo TỔNG HỢP NHIỀU KỲ — `TongHopNhieuKyModal` — truyền cả set kỳ đã gộp, nếu
không sẽ luôn ra 0 vì `ky` của báo cáo gộp là object giả `{tenKy}` không có `id` thật). Biến
`dt_ktBcBanDau` đổi tên thành `dt_ktBcMoiKy` cho đúng ý nghĩa mới.
Phía Excel: thêm cột **"Kỳ TK BC"** (cột AF, cuối `BC_H`, 21 cột thay vì 20 — KHÁC cột "Kỳ TK"
cấp vụ đã có ở `extraHeaders`, vì cột đó lấy kỳ của chính VỤ, giống nhau cho mọi dòng BC của cùng
1 vụ, không phản ánh đúng BC bổ sung thêm ở kỳ khác) ghi qua `tenKyBcRieng(bc)`. Công thức COUNTIFS
của C7-C24 đổi từ tiêu chí cột W (`"ban_dau"`) sang cột AF khớp tên kỳ hiện tại — helper mới
`mkCfBcKy(sheets, r, dsKyTen, ...extra)` tự OR-sum COUNTIFS qua từng kỳ trong `dsKyTen` (đáp ứng cả
báo cáo gộp nhiều kỳ, không chỉ 1 kỳ). Đã viết test độc lập kiểm chứng cả sinh công thức lẫn logic
lọc theo tập kỳ (đơn kỳ / gộp nhiều kỳ / BC không có kỳ do dữ liệu cũ dựng lại lịch sử) trước khi
mirror sang `qlva-dev.html` — CHƯA kiểm chứng bằng dữ liệu Firestore thật, cần seed lại hoặc chạy
`BackfillLoaiKhoiToTool` trên `qlva-dev.html` rồi xem thử trước khi tin tưởng số liệu trên
`qlva.html` (production).

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

- [x] `qlva.html`: đăng nhập Firebase Auth + khung sidebar (5 module trong mảng `MODULES`: Danh
      sách vụ án/Án đã giải quyết/Giao nhận hồ sơ/Kỳ báo cáo/Dashboard — cộng thêm tab "Cài đặt"
      gắn cứng ngoài mảng này, xem `CaiDatModule`, tổng cộng 6 tab hiển thị; đã sửa lại từ nhãn "7
      module" cũ không khớp thực tế nữa, audit 2026-07-16) +
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
      **Tối ưu cho dữ liệu lớn (10k+ dòng, 2026-07-16, nhánh `giao-nhan-ho-so`)** — `DanhSachPanel`
      trước đây mở real-time listener trên TOÀN BỘ 4 collection (`vuan`, `bican`, `kybaocao`, và
      `lichsuChuyenGiaiDoan` lọc theo loại sự kiện nhưng vẫn không giới hạn số dòng), rồi mới lọc/
      tìm kiếm ở phía trình duyệt — càng nhiều năm dữ liệu tích luỹ, càng phải tải và giữ sống
      càng nhiều dữ liệu mỗi lần mở màn hình, dù người dùng chỉ cần xem "đang giải quyết". Đã sửa
      thành 2 phần, KHÔNG đụng tới bất kỳ nơi ghi dữ liệu nào (chỉ đổi cách đọc, không rủi ro cho
      tính đúng đắn của số liệu):
      (1) **`vuan` lọc/giới hạn ngay ở Firestore** — toggle "Đang giải quyết" (mặc định) giờ dùng
      `.where("trangThai","==","dang_giai_quyet")` thay vì tải hết rồi lọc client (tập này tự
      nhiên bị chặn, không tăng vô hạn vì vụ giải quyết xong sẽ rời khỏi tập). Tab "Tất cả" thêm
      giới hạn an toàn `gioiHanTatCa` (mặc định 500, tăng dần qua nút "Tải thêm 500" — không phải
      cursor pagination thật, chỉ tăng `.limit()` rồi tải lại, đơn giản hơn nhiều và đủ dùng ở quy
      mô hiện tại). Cần index mới `vuan(trangThai ASC, ngayTao DESC)` — đã thêm vào
      `firestore.indexes.json`, PHẢI deploy (`firebase deploy --only firestore:indexes`) trước khi
      bật toggle này trên dữ liệu thật, nếu không Firestore sẽ báo lỗi thiếu index kèm link tạo.
      (2) **`bican`/`lichsuChuyenGiaiDoan` (cột Bị can + Kỳ mới/Kỳ giải quyết/Kỳ vào Truy tố/Kỳ
      chuyển Xét xử) đổi từ tải nguyên collection sang chia lô theo id (`chiaNhoDsId`, lô 30 —
      đúng giới hạn mệnh đề `in` của Firestore, cùng cỡ lô đã dùng ở `batchLayBiCanList` có sẵn từ
      trước) chỉ hỏi ĐÚNG những vụ đang hiển thị (`idsHienTaiKey`)** — không còn tải bị can/log của
      những vụ không nằm trong danh sách đang xem. Bỏ hẳn mệnh đề `where("loaiSuKien","in",[...])`
      trên query log (Firestore giới hạn tổng số nhánh khi kết hợp 2 mệnh đề `in` cùng lúc — lô 30
      id × 4 loại sự kiện = 120 nhánh, vượt quá giới hạn 30), lọc loại sự kiện ở phía client
      (`timSuKienKyTheoVuAn`) như cũ, rẻ vì đã được thu hẹp đúng theo các vụ cần hiển thị.
      **Tìm kiếm vẫn đầy đủ dù đã giới hạn/phân trang** — nếu đang ở tab "Tất cả" VÀ đã vượt
      `gioiHanTatCa` VÀ có gõ từ khoá, tự động tải bù 1 lần (`.get()`, KHÔNG realtime, không giữ
      sống liên tục) toàn bộ `vuan` vào `dsTimKiemDayDu`, dùng thay cho bản đã giới hạn cho tới
      khi xoá từ khoá — tránh bỏ sót kết quả nằm ngoài giới hạn hiển thị mặc định. "Đang giải
      quyết" không cần bước này vì tập đó vốn đã đầy đủ (không bị giới hạn). Bị can dùng cho tìm
      kiếm theo tên vẫn qua đúng cơ chế chia lô ở (2) (chia lô theo `dsTimKiemDayDu` khi đang tìm
      kiếm đầy đủ), không cần tải riêng.
      Tác dụng phụ nhỏ: sắp xếp theo cột (bấm tiêu đề Mã vụ/Ngày KTVA/Hạn ĐT) giờ CHỈ sắp xếp các
      dòng đang tải (`nguonDanhSach`) — ở tab "Tất cả" khi đã vượt `gioiHanTatCa`, các dòng ngoài
      giới hạn chưa tải sẽ không tham gia sắp xếp cho tới khi bấm "Tải thêm" hoặc gõ tìm kiếm. Ô
      lọc KSV đổi nguồn: gộp roster `canbo` (vai trò KSV, luôn đầy đủ, không phụ thuộc số dòng
      đang tải) với các tên KSV thấy được trong dữ liệu đang hiển thị (phòng dữ liệu cũ/nhập tay
      có tên KSV không có trong danh mục Cán bộ) — tránh mất tên KSV khỏi ô lọc khi bị giới hạn.
      **CHƯA kiểm chứng bằng dữ liệu Firestore thật** (chỉ mới kiểm tra cú pháp bằng cách biên
      dịch qua đúng bản `@babel/standalone@7.25.6` app đang dùng) — cần mở thử `qlva-dev.html`
      (sau khi deploy lại `firestore.indexes.json` cho project `qlahs-test`), thử cả 2 tab "Đang
      giải quyết"/"Tất cả", bấm "Tải thêm", gõ tìm kiếm ở cả 2 tab, trước khi tin tưởng và đưa lên
      `qlva.html` production.
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
      **Chặn quét trùng trong cùng 1 phiên (2026-07-15, nhánh `giao-nhan-ho-so`)** — trước đây
      quét/chọn lại 1 vụ ĐÃ có sẵn trong phiên sẽ ghi thêm 1 dòng `giao_nhan_ho_so` mới (trùng),
      thường do quét nhầm/quét đi quét lại. `xuLyQuet` và `chonVuThuCong` giờ kiểm tra
      `dsQuet.some(d => d.maVuAn === ma)` (dữ liệu đã có sẵn qua `onSnapshot` theo `phien.id`,
      không cần query thêm) trước khi ghi — nếu đã có thì chỉ hiện toast cảnh báo (loại `"warn"`,
      màu hổ phách), không ghi gì thêm. Không chặn ở tầng Firestore (không phải constraint cứng)
      — chỉ chặn phía client trong session hiện tại, đúng phạm vi vấn đề thực tế nêu ra (quét
      nhầm trong lúc thao tác, không phải yêu cầu 1 vụ chỉ được giao/nhận đúng 1 lần trong lịch
      sử toàn hệ thống).
      **Tải toàn bộ lịch sử giao nhận ra Excel, cột Mã vụ = ẢNH QR (2026-07-15, cùng nhánh)** —
      nút "⬇ Tải toàn bộ lịch sử" (hiện cả ở màn chưa có phiên lẫn trong phiên đang mở, vì đây là
      lịch sử TOÀN HỆ THỐNG mọi phiên, không phải riêng phiên hiện tại) — `taiLichSuGiaoNhan`
      query thẳng `lichsuChuyenGiaiDoan` where `loaiSuKien == "giao_nhan_ho_so"` (không lọc theo
      `phienGiaoNhanId`, không giới hạn 300 dòng như Nhật ký thao tác vì đây là export file chứ
      không phải bảng hiển thị), `loaiGiaoDich` đọc thẳng từ field đã lưu sẵn trên chính sự kiện
      (không cần join `phienGiaoNhan`). Dùng **ExcelJS** (không phải XLSX/SheetJS — lý do giống
      Xuất Excel báo cáo tháng: cần nhúng ảnh, XLSX bản CDN đang dùng không hỗ trợ). Cột "Mã vụ"
      để trống CHỮ, nhúng đè ảnh QR lên đúng ô đó qua `wb.addImage`/`ws.addImage` (anchor
      `tl:{col,row}` 0-based) — mục đích: sau này chỉ cần quét thẳng từ file/bản in ra là tra
      được vụ ngay, không cần gõ tay. Ảnh QR sinh bằng hàm mới `taoQrDataUrl(text, size)` (cạnh
      `KhoiQR`) — tái dùng `qrcodejs` (`new QRCode(...)`) nhưng vẽ vào 1 `<div>` KHÔNG gắn vào DOM
      thật (canvas 2D vẫn vẽ/đọc `toDataURL()` được dù không attach), khác `KhoiQR` vốn render lên
      màn hình qua `ref`. Đã kiểm chứng riêng phần dựng workbook + nhúng ảnh bằng test Node dùng
      thẳng package `exceljs` thật (ghi buffer xong load lại, xác nhận đúng số ảnh + đúng vị trí
      cột/dòng) — phần sinh ảnh QR qua `qrcodejs` (cần canvas trình duyệt thật) chưa test được
      bằng cách này, chỉ tái dùng nguyên pattern đã chạy ổn định ở `KhoiQR`.
      **Thêm cột "Số bút lục" (2026-07-16)** — field mới `soButLuc` trên sự kiện `giao_nhan_ho_so`,
      cùng nhóm với `nguoiNhanThucTe` (để trống mặc định, ghi tay lúc giao/nhận, KHÔNG bắt buộc,
      không ảnh hưởng số liệu báo cáo kỳ) — dùng để cán bộ ghi lại hồ sơ thực tế có bao nhiêu
      trang/bút lục tại đúng thời điểm giao/nhận, tiện đối chiếu sau này nếu nghi ngờ thất lạc
      trang. Có mặt ở cả 3 chỗ hiển thị dòng giao nhận: bảng "đã quét trong phiên" (sửa được y hệt
      3 field người liên quan, qua `DongGiaoNhan`), "Biên bản giao nhận hồ sơ" bản in A4
      (`BienBanGiaoNhanIn`, cột riêng cạnh "Người nhận thực tế / Ký tên" — đúng chỗ cần nhất vì đây
      là bản có chữ ký, dùng đối chiếu về sau), và Excel "Tải toàn bộ lịch sử" (`taiLichSuGiaoNhan`,
      cột sau "Người nhận thực tế").
      **Thêm cột "Hình thức giải quyết" (2026-07-16, cùng đợt)** — trước khi giao/nhận 1 hồ sơ đã
      có kết quả, cán bộ cần biết ngay đã giải quyết theo hình thức nào (Đã xét xử/Chuyển đi/Tạm
      đình chỉ/Đình chỉ/Án huỷ) kèm số QĐ tương ứng mà không cần mở lại vụ án. KHÁC HẲN "Số bút
      lục"/"Người nhận thực tế" — đây là 2 field MỚI **snapshot tự động** lúc quét/chọn
      (`trangThaiVu` = `vuAn.trangThai`, `soQdGiaiQuyet` = giá trị field tương ứng qua
      `fieldSoQuyetDinhTrenVuAn` đã có sẵn từ module Án đã giải quyết), không phải ô nhập tay —
      hiển thị qua helper dùng chung `moTaHinhThucGiaiQuyet(dong)` ("Đang giải quyết" nếu chưa có
      kết quả, hoặc "<Nhãn> — <Số QĐ>" nếu đã có). Có ở bảng phiên (cột riêng, luôn hiện bất kể
      đang sửa dòng hay không — khác nhóm 4 field editable), Excel lịch sử (cột riêng sau "Tên
      vụ"); riêng **Biên bản in A4** đặt làm dòng phụ trong ô "Tên vụ" (không phải cột riêng) vì
      khổ A4 đã khá chật với 7 cột hiện có.
      **Biên bản in A4: cột Mã vụ đổi thành ảnh QR + tách "Trạng thái HS" thành cột riêng
      (2026-07-16, cùng đợt)** — ban đầu đặt "Hình thức giải quyết" làm dòng phụ trong ô "Tên vụ"
      vì lo khổ A4 chật (xem ngay trên), nhưng theo yêu cầu người dùng đã tách hẳn thành cột riêng
      "Trạng thái HS" (dùng lại đúng `moTaHinhThucGiaiQuyet`) — bù lại, cột "Mã vụ" đổi từ hiện
      chữ sang **ảnh QR** (`taoQrDataUrl(d.maVuAn, 120)`, cùng hàm đã dùng cho Excel "Tải toàn bộ
      lịch sử" — sinh data URL PNG đồng bộ, không cần gắn DOM thật) để tiết kiệm bề ngang, đồng
      thời tiện quét lại thẳng từ bản giấy sau này. Các cột KSV/ĐTV/Số bút lục/Người nhận thực tế
      thu hẹp bớt độ rộng cố định (`w-*`) để nhường chỗ cho cột mới — chưa in giấy thật để xác
      nhận có vừa khổ A4 hay không, nên in thử 1 bản trước khi dùng cho nhiều hồ sơ.
      **Đổi sang khổ ngang/landscape (2026-07-16, cùng đợt)** — theo yêu cầu người dùng sau khi
      bảng lên 8 cột. Đổi container từ `width:210mm;minHeight:297mm` sang `width:297mm;
      minHeight:210mm`, và thêm `<style>{"@page { size: landscape; }"}</style>` NGAY TRONG nội
      dung được portal vào `#qr-print-root` (không sửa khối `@media print` chung trong `<head>`)
      — vì `@page` là at-rule toàn cục, nếu đặt chung sẽ ép cả `InQRModal` (in mã QR, vẫn cần khổ
      dọc) sang ngang theo. Đặt `<style>` bên trong chính component này thì quy tắc chỉ tồn tại
      trong DOM khi ĐÚNG biên bản này đang mở — 2 modal in không portal cùng lúc nên không xung
      đột. Nếu sau này có thêm màn in khác cần khổ riêng, dùng lại đúng pattern này (style cục bộ
      theo từng component in), đừng gộp chung vào khối `@media print` ở `<head>`.
      **Nộp hồ sơ lưu trữ + cột "Thời hạn bảo quản" (2026-07-16, cùng đợt)** — thêm tick "Nộp hồ
      sơ lưu trữ" ở màn bắt đầu phiên (chỉ áp dụng khi bắt đầu phiên **Nhận** — nộp lưu trữ nghĩa
      là bộ phận lưu trữ NHẬN hồ sơ từ KSV/ĐTV), lưu thành field `laLuuTru` trên `phienGiaoNhan`.
      Khi `laLuuTru`, bảng phiên + Biên bản in A4 hiện thêm cột **"Thời hạn bảo quản"** (Excel
      "Tải toàn bộ lịch sử" thì LUÔN có cột này, không điều kiện theo `laLuuTru`, vì đó là dump
      toàn bộ lịch sử mọi phiên, không riêng phiên đang mở).
      **Nguồn tính**: file **`thoi han bao quan.xlsx`** (thư mục gốc dự án, sheet "Bang doi
      chieu") — chép nguyên văn thành 2 hằng số `BANG_THOI_HAN_BAO_QUAN_THEO_NAM` (mức án theo
      năm, key là số năm đã cộng sẵn phần tháng lẻ dạng thập phân — VD `7.5` cho "7 năm 6 tháng")
      và `THOI_HAN_BAO_QUAN_DAC_BIET` (tử hình/chung thân/án treo/phạt tiền).
      **Bug đã sửa (2026-07-16, cùng ngày, phát hiện qua người dùng phản hồi trực tiếp) — bảng gốc
      là HÀM BẬC THANG (mốc → áp dụng cho tới trước mốc kế tiếp), KHÔNG PHẢI danh sách giá trị khớp
      tuyệt đối.** Bản đầu tiên hiểu sai: coi mỗi key trong bảng là 1 giá trị mức án CỐ ĐỊNH duy
      nhất được công nhận (VD chỉ đúng "3 năm" hoặc đúng "3 năm 6 tháng" mới tra được, "3 năm 5
      tháng" hay "4 năm" thì trả `null` vì không khớp key nào) — SAI với ý nghĩa thật của bảng: mốc
      "3" (19 năm) áp dụng cho MỌI mức án từ "3 năm 0 tháng" đến hết "3 năm 5 tháng"; đúng từ "3 năm
      6 tháng" mới chuyển sang mốc "3.5" (23 năm), áp dụng tới hết "4 năm 5 tháng" (mốc kế tiếp là
      "4.5", không phải "4" — bảng gốc không có mốc "4" riêng vì không cần, dùng mốc "3.5" cho cả
      dải đó). Đã sửa `tinhThoiHanBaoQuanTheoMucAn` sang tra theo **mốc LỚN NHẤT không vượt quá
      mức án** (floor lookup qua mảng `MOC_THOI_HAN_BAO_QUAN_NAM` các mốc tăng dần), không còn tra
      khớp tuyệt đối (`BANG[...][n]`). Chỉ trả `null` khi mức án THẤP HƠN mốc nhỏ nhất trong bảng
      (hiện là "3 năm") — bảng gốc không phủ mức án dưới 3 năm, KHÔNG suy đoán/nội suy công thức vì
      đây là hồ sơ pháp lý thật, đoán sai thời hạn bảo quản là sai thật. Đình chỉ/Tạm đình chỉ luôn
      "Vĩnh viễn" theo bảng (không cần mức án). Đang giải quyết/Chuyển đi/Án huỷ/Đã nhập vụ khác
      KHÔNG có dòng tương ứng trong bảng gốc, trả `null` (không tính).
      **⚠ Lưu ý khi mirror/deploy**: lúc đọc file này thấy có `~$thoi han bao quan.xlsx` (file khoá
      tạm của Excel) tồn tại cùng thư mục — dấu hiệu file gốc **đang được mở** trên máy Dũng, có
      thể đang sửa dở. Nếu bảng đối chiếu trong code sai khác với file thật sau này, kiểm tra lại
      file gốc đã lưu (Ctrl+S) chưa trước khi kết luận code sai.
      **Nhập mức án**: thêm field `mucAnLoai`/`mucAnNam`/`mucAnThang` trên `vuan` (`mucAnThang` là
      số THÁNG LẺ 0-11, KHÔNG PHẢI cờ nhị phân +6 tháng — đã đổi thiết kế cùng đợt sửa bug ở trên,
      xem ngay dưới). `ghiNhanVuVaoPhien` snapshot kết quả tính (`thoiHanBaoQuan`) VÀ chính 3 field
      mức án này vào sự kiện `giao_nhan_ho_so` ngay lúc quét/chọn — giống cách
      `trangThaiVu`/`soQdGiaiQuyet` đã làm, KHÔNG tính lại lúc hiển thị/in.
      **Sửa lại (2026-07-16, cùng ngày) — chuyển hẳn việc nhập mức án ra khỏi `SuaVuAnForm`, vào
      thẳng dòng giao nhận** (`DongGiaoNhan`) cho tiện nhập liệu đúng lúc cần (nộp lưu trữ), thay
      vì phải mở riêng modal "Sửa thông tin vụ án" — mức án chỉ thật sự cần biết vào đúng thời điểm
      này. Cột **"Mức án"** đặt giữa "Hình thức giải quyết" và "Thời hạn bảo quản", chỉ hiện khi
      phiên `laLuuTru`; vụ không phải Đã xét xử hiện "—" (không sửa được, vì mức án không áp dụng).
      Sửa dùng chung nút Sửa/Lưu của cả dòng (cùng `dangSua` với KSV/ĐTV/Số bút lục) nhưng khác
      hẳn ở chỗ **ghi vào 2 nơi khi Lưu**: (1) `db.collection("vuan").doc(dong.maVuAn).update(...)`
      — vì mức án là thuộc tính của VỤ ÁN, không phải chỉ của dòng log như KSV/ĐTV/số bút lục; (2)
      `onSua` như cũ để cập nhật lại `mucAnLoai/mucAnNam/mucAnThang` VÀ tính lại `thoiHanBaoQuan`
      ngay trên chính dòng log đang xem — để cột Thời hạn bảo quản đổi ngay tại chỗ, không cần quét
      lại vụ mới thấy số mới. Nếu ghi `vuan` thất bại (lỗi mạng...), dừng lại không gọi `onSua`
      (tránh trạng thái 2 nơi lệch nhau: log nói đã có mức án X nhưng `vuan` thì chưa lưu được).
      **Ô Năm + ô Tháng riêng thay vì checkbox "+6 tháng" (2026-07-16, sửa cùng lúc với bug floor-
      lookup ở trên, theo phản hồi trực tiếp của người dùng)** — bản đầu tiên chỉ cho tick 1
      checkbox "+6 tháng" (nhị phân, cộng đúng 0.5 năm), không nhập được mức án lẻ tháng khác (VD
      "3 năm 5 tháng", "4 năm 11 tháng"). Đổi UI: 2 ô số riêng "... năm" + "... tháng" (0-11), lưu
      thẳng thành field `mucAnThang` (số tháng lẻ), quy đổi sang năm thập phân bằng `+ mucAnThang/12`
      trước khi tra bảng — kết hợp với floor-lookup ở trên cho phép nhập BẤT KỲ mức án lẻ tháng nào
      mà vẫn tra đúng thời hạn bảo quản.
      **Toggle "Nộp hồ sơ lưu trữ" đổi từ checkbox sang công tắc (2026-07-16, cùng ngày)** — thêm
      component dùng chung `CongTac` (nút bo tròn kiểu switch, không phải `<input
      type="checkbox">`) cho "hiện đại" hơn theo yêu cầu người dùng; đồng thời gom nút "Bắt đầu
      phiên — Nhận hồ sơ" + công tắc vào chung 1 khung viền riêng (tách khỏi nút "Giao hồ sơ") để
      rõ ràng công tắc này chỉ áp dụng cho việc bắt đầu phiên Nhận, không phải Giao.
      **Bug đã sửa (2026-07-16, cùng ngày) — bấm nhầm "Lưu phiên" (khoá cả phiên) trong lúc còn
      đang sửa dở 1 dòng làm mất trắng dữ liệu vừa nhập, không cách nào lưu lại.** Phát hiện qua
      Playwright tái hiện thực tế (không chỉ đọc code): nút "Lưu phiên" (to, luôn hiện góc trên) và
      nút "Lưu" của từng dòng (nhỏ, chỉ hiện khi đang sửa) tên gần giống nhau — bấm nhầm "Lưu phiên"
      giữa lúc sửa Mức án sẽ khoá phiên ngay lập tức, dòng đó kẹt lại ở chế độ sửa dở mà KHÔNG CÒN
      nút Lưu/Huỷ để bấm nữa (cột đó chỉ hiện khi phiên chưa khoá). Đã sửa: `GiaoNhanHoSoModule`
      đếm số dòng đang sửa (`soDongDangSua`, `DongGiaoNhan` tự báo qua `onBatDauSua`/`onKetThucSua`)
      và khoá nút "Lưu phiên" trong lúc đó, kèm dòng cảnh báo hướng dẫn.
      **Đã kiểm chứng bằng Playwright + mock Firestore trong bộ nhớ** (không chỉ đọc code, cả 2 bug
      trên đều tái hiện được lỗi TRƯỚC khi sửa và xác nhận hết lỗi SAU khi sửa) — riêng việc chạy
      thật trên `qlva-dev.html` với dữ liệu Firestore thật thì vẫn **CHƯA làm** (nên thử lại các
      kịch bản trên qua UI thật ít nhất 1 lần trước khi tin tưởng tuyệt đối trên `qlva.html` production).
      **CHƯA kiểm chứng bằng dữ liệu Firestore thật** — cần thử trên `qlva-dev.html`: bắt đầu phiên
      Nhận bật công tắc lưu trữ, quét/chọn 1 vụ Đã xét xử chưa có mức án, sửa dòng đó nhập mức án
      ngay tại bảng, xem cột Thời hạn bảo quản cập nhật đúng ngay (không cần quét lại), rồi kiểm
      tra tiếp biên bản in/Excel đều ra đúng số theo bảng gốc.
      **Thêm lựa chọn "Không tiếp nhận" kèm lý do (2026-07-17)** — chỉ áp dụng cho giao dịch NHẬN
      (bên nhận là người quyết định có nhận hồ sơ hay không, VD hồ sơ KSV/ĐTV mang sang còn thiếu
      thông tin), giao dịch Giao không có khái niệm này. Không phải 1 modal chặn ngay lúc quét
      (sẽ phá nhịp quét nhanh của đầu đọc QR) — vẫn quét/ghi nhận bình thường như cũ (mặc định
      `khongTiepNhan: false`), rồi đánh dấu NGAY TẠI DÒNG qua đúng cơ chế "sửa dòng" đã có (bấm cả
      dòng → `dangSua`): thêm 1 cột **"Tiếp nhận"** (chỉ hiện khi `dong.loaiGiaoDich === "nhan"`)
      với `CongTac` "Không tiếp nhận" (đỏ) + ô nhập lý do hiện ra khi bật — **bắt buộc gõ lý do**
      mới lưu được (chặn bằng toast lỗi, khác các trường KSV/ĐTV/số bút lục khác của dòng vốn
      không bắt buộc, vì đánh dấu "không tiếp nhận" mà không rõ lý do thì vô nghĩa). Lưu 2 field
      mới trên chính sự kiện `giao_nhan_ho_so`: `khongTiepNhan`/`lyDoKhongTiepNhan`.
      **Quan trọng: đây chỉ là 1 ghi chú/annotation thêm vào đúng dòng đó, KHÔNG xoá/ẩn dòng khỏi
      phiên, không đổi trạng thái vụ án `vuan`, không ảnh hưởng số liệu báo cáo kỳ** (giống mọi
      field khác của sự kiện `giao_nhan_ho_so` — log hành chính, không phải sự kiện nghiệp vụ) —
      hồ sơ vẫn hiện bình thường ở mọi nơi (bảng phiên, biên bản in, Excel lịch sử), chỉ thêm nội
      dung ghi chú giải thích tại sao chưa được nhận, để bên giao biết mà bổ sung rồi mang lại.
      Helper dùng chung `moTaTiepNhan(dong)` (cùng pattern `moTaHinhThucGiaiQuyet`) áp dụng ở cả 3
      nơi: cột "Tiếp nhận" trong bảng phiên (Badge xanh "✓ Đã tiếp nhận" / đỏ "✗ Không tiếp nhận"
      kèm lý do), cột "Tiếp nhận" trong Biên bản in A4 (chỉ hiện khi `phien.loaiGiaoDich ===
      "nhan"`, dùng chữ "⚠ Không tiếp nhận — <lý do>" thay vì Badge vì bản in không có màu nền),
      và cột "Tiếp nhận" trong Excel "Tải toàn bộ lịch sử" (luôn có cột, rỗng với giao dịch Giao).
      Đã kiểm chứng cú pháp bằng cách biên dịch qua đúng bản `@babel/standalone@7.25.6` app đang
      dùng — **CHƯA kiểm chứng bằng dữ liệu Firestore thật**, cần thử trên `qlva-dev.html`: bắt
      đầu phiên Nhận, quét 1 vụ, sửa dòng bật "Không tiếp nhận" mà bỏ trống lý do (phải bị chặn),
      gõ lý do rồi lưu (phải thành công), kiểm tra cột hiện đúng ở bảng/biên bản in/Excel.
      **Danh sách "Phiên gần đây" để mở lại phiên đã lưu/bỏ dở (2026-07-17)** — trước đây bấm
      "Phiên mới" hoặc lỡ đóng trình duyệt là MẤT hẳn đường vào lại 1 phiên đã có: phiên đã "Lưu
      phiên" chỉ còn xem/in được nhưng không có danh sách nào để bấm vào, phiên "Đang mở" bị bỏ dở
      giữa chừng (đóng nhầm tab, tưởng đã lưu) coi như mất luôn, chỉ tra được qua Nhật ký thao tác
      (liệt kê từng SỰ KIỆN lẻ, không theo phiên) hoặc Excel lịch sử (dump phẳng, không mở lại
      được). Thêm state `dsPhienGanDay` (`onSnapshot` trên `phienGiaoNhan`, `orderBy
      thoiDiemBatDau desc` + `limit(30)` — chỉ 1 field orderBy, KHÔNG kèm `where` nên không cần
      composite index mới) hiện ở màn hình chưa mở phiên, dưới 2 nút "Bắt đầu phiên". Bấm vào 1
      dòng = `setPhien(p)` — tái dùng nguyên state/effect sẵn có (đổi `phien` tự kích hoạt lại
      subscribe `dsQuet` theo `phien.id`), nên phiên "Đang mở" mở lại tiếp tục quét/sửa được ngay
      (đúng UI cũ vì `khoaSua = phien.trangThai !== "dang_mo"`), phiên "Đã lưu" chỉ xem/bấm "In
      phiên" lại (nút này vốn đã không phụ thuộc `trangThai`, chỉ cần `dsQuet.length > 0`) — không
      cần sửa gì thêm ở phần render đã có, chỉ cần đường vào lại phiên.
      **Fix bản in A4 bị cắt mất vụ án khi danh sách dài hơn 1 trang (2026-07-17, cùng đợt)** —
      `BienBanGiaoNhanIn` dùng `fixed inset-0 ... overflow-auto` cho khung xem trước/backdrop
      trên MÀN HÌNH, nhưng lúc IN THẬT, `position:fixed` ép khối cao đúng 1 viewport rồi
      `overflow-auto` chỉ hiện phần cuộn được trong đó — khiến các dòng vụ án vượt quá 1 trang A4
      bị CẮT MẤT khỏi bản in thay vì tự sang trang. Sửa bằng cách thêm biến thể Tailwind
      `print:static print:overflow-visible print:block print:bg-white print:p-0` (chỉ áp dụng khi
      in, giữ nguyên hành vi xem trước trên màn hình) để nội dung tự tràn ra nhiều trang bình
      thường — `<thead>` của bảng tự lặp lại đầu mỗi trang mới (hành vi mặc định trình duyệt với
      bảng HTML, không cần code thêm). Thêm `tr { break-inside: avoid; page-break-inside: avoid; }`
      vào đúng khối `<style>{"@page..."}</style>` cục bộ đã có (xem ghi chú `@page` ở trên) để 1
      dòng vụ án không bị cắt ngang giữa 2 trang. Đã kiểm chứng cú pháp bằng compile qua đúng bản
      `@babel/standalone@7.25.6` — **CHƯA in thử giấy thật với danh sách đủ dài (>1 trang A4
      ngang) để xác nhận việc sang trang + lặp header đúng như mong đợi**, cần thử trên
      `qlva-dev.html` với 1 phiên có nhiều vụ án trước khi tin tưởng trên production.
      **Đặt tên phiên (2026-07-17, cùng đợt) — tự động điền sau khi quét hồ sơ đầu tiên** — field
      mới `tenPhien` trên `phienGiaoNhan`. Bản đầu tiên hỏi tên ngay lúc bắt đầu phiên (trước khi
      quét vụ nào) nhưng người dùng chỉ ra vấn đề: lúc đó CHƯA quét hồ sơ nào nên chưa biết KSV/ĐTV
      là ai để đặt tên có nghĩa — đã đổi hẳn sang **tự động tính ngay sau khi quét/chọn hồ sơ ĐẦU
      TIÊN của phiên** (trong `ghiNhanVuVaoPhien`, điều kiện `!phien.tenPhien && dsQuet.length ===
      0` — chỉ tự đặt khi phiên CHƯA có tên, không ghi đè tên đã sửa tay): `Giao hồ sơ cho <tên>`
      (phiên Giao) hoặc `Nhận hồ sơ của <tên>` (phiên Nhận), với `<tên>` ưu tiên **ĐTV**
      (`vuAn.dtvCbdt`), không có thì **KSV** (`vuAn.ksvChinh`) — theo đúng yêu cầu người dùng. CỐ Ý
      KHÔNG dùng "Người nhận thực tế" (`nguoiNhanThucTe`) làm nguồn vì field đó không tồn tại trên
      `vuan`, chỉ là ghi chú tay thêm SAU trên từng dòng log (`DongGiaoNhan`), luôn rỗng đúng lúc
      quét nên vô nghĩa làm nguồn tự động tại thời điểm này. Cả 2 vụ (nếu vụ không có cả ĐTV lẫn
      KSV) thì bỏ qua, không đặt tên trống nghĩa.
      **CỐ Ý thuần tuý là nhãn để tra cứu** (theo yêu cầu người dùng: "không ảnh hưởng đến
      heading") — `<h2>Giao nhận hồ sơ</h2>` + dòng badge loại giao dịch/lưu trữ/đã lưu giữ nguyên
      y hệt trước, KHÔNG ảnh hưởng field nào khác của phiên hay của từng dòng hồ sơ đã quét, không
      xuất hiện trên biên bản in A4 hay Excel lịch sử. Hiện + **sửa tay được sau đó** (khác bản đầu
      tiên "chỉ đặt được lúc khởi tạo, không sửa được nữa") ở 1 dòng nhỏ ngay dưới "Phiên hiện tại"
      (không phải trong `<h2>`) — bấm vào để bật input inline (`dangSuaTenPhien`/`tenPhienDangSua`),
      Lưu/Huỷ, dùng được bất kể phiên đang mở hay đã lưu (chỉ là nhãn tra cứu, không phải dữ liệu
      nghiệp vụ nên không khoá theo `trangThai` như các dòng log khác) — hữu ích để tự sửa lại nếu
      tên tự động không đúng ý, hoặc đặt tên cho phiên lỡ không tự đặt được (vụ thiếu cả ĐTV/KSV).
      Cũng dùng ở danh sách **"Phiên gần đây"** (đã có sẵn, xem mục ngay trên) — hiện tên (nếu có)
      làm dòng đậm phía trên các Badge của mỗi phiên, kèm 1 ô **tìm theo tên phiên** (`tuKhoaPhien`,
      lọc client-side, case-insensitive) đặt cạnh tiêu đề "Phiên gần đây" — chỉ tìm được trong 30
      phiên gần nhất đã tải sẵn (giới hạn của chính danh sách "Phiên gần đây", không phải hạn chế
      riêng của tìm kiếm; đã ghi rõ trên UI), KHÔNG query full-collection để tìm phiên cũ hơn. Đã
      kiểm chứng cú pháp bằng compile qua đúng bản `@babel/standalone@7.25.6` — **CHƯA kiểm chứng
      bằng dữ liệu Firestore thật**, cần thử trên `qlva-dev.html`: bắt đầu phiên Giao, quét 1 vụ có
      ĐTV, xác nhận tên phiên tự điền đúng "Giao hồ sơ cho <ĐTV>" ngay sau khi quét; thử tiếp 1 vụ
      chỉ có KSV không có ĐTV, xác nhận rơi xuống dùng KSV; bấm sửa tên tại dòng "Tên phiên" dưới
      header, lưu lại, xác nhận cập nhật đúng cả trên UI lẫn khi mở lại từ "Phiên gần đây".
      **Bug đã sửa (2026-07-16) — bấm nhầm "Lưu phiên" (khoá cả phiên) trong lúc còn
      đang sửa dở 1 dòng làm mất trắng dữ liệu vừa nhập, không cách nào lưu lại.** Phát hiện qua
      Playwright tái hiện thực tế (không chỉ đọc code): nút "Lưu phiên" (to, luôn hiện góc trên) và
      nút "Lưu" của từng dòng (nhỏ, chỉ hiện khi đang sửa) tên gần giống nhau — bấm nhầm "Lưu phiên"
      giữa lúc sửa Mức án sẽ khoá phiên ngay lập tức, dòng đó kẹt lại ở chế độ sửa dở mà KHÔNG CÒN
      nút Lưu/Huỷ để bấm nữa (cột đó chỉ hiện khi phiên chưa khoá). Đã sửa: `GiaoNhanHoSoModule`
      đếm số dòng đang sửa (`soDongDangSua`, `DongGiaoNhan` tự báo qua `onBatDauSua`/`onKetThucSua`)
      và khoá nút "Lưu phiên" trong lúc đó, kèm dòng cảnh báo hướng dẫn. Sau đó tiếp tục nâng cấp lên
      hẳn thành **tự động lưu khi chuyển dòng** (xem mục "Giao nhận hồ sơ — tự động lưu khi chuyển
      dòng..." phía trên, 2026-07-17) — cơ chế khoá này vẫn giữ lại làm safeguard cho trường hợp bấm
      thẳng "Lưu phiên" mà không qua thao tác chuyển dòng.
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
      tô đỏ + thêm icon ⚠ + tooltip ở đúng ô "Ngày quyết định" khi `true`.
      **Sửa được ngay trong `SuaVuAnForm` (2026-07-14)** — thêm khối "Thông tin giải quyết" (chỉ
      hiện khi `vuAn.trangThai !== "dang_giai_quyet"`, đặt ngay dưới ô cảnh báo "chỉ sửa thông tin
      thường" đầu form) gồm **Ngày giải quyết** (`ngayQuyetDinh`) + ô Số QĐ giải quyết có nhãn động
      theo hình thức (dùng lại `NHAN_SO_QUYET_DINH_HOAN_THANH[vuAn.trangThai]`, field ghi qua
      `fieldSoQuyetDinhTrenVuAn(vuAn.trangThai)` — xem mục Án đã giải quyết ở trên). Lưu form này
      **luôn xoá cờ `ngayQuyetDinhUocTinh`** (set `false`) bất kể có đổi ngày hay không — coi việc
      mở form sửa thông tin giải quyết là hành động "đã xác nhận lại" của người dùng, đúng gợi ý
      đã ghi ở đây trước đó.
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
      **Xoá hình thức giải quyết (2026-07-17, `XoaHinhThucGiaiQuyetModal`)** — nhu cầu thực tế:
      chọn NHẦM hình thức lúc bấm "Hoàn thành vụ án" (VD chọn "Đã xét xử" nhưng đúng ra phải là
      "Tạm đình chỉ") — trước đây KHÔNG có cách nào tự sửa, vì 1 khi vụ đã ở trạng thái đã giải
      quyết, panel chi tiết chỉ còn 3 nút (In mã QR/Sửa thông tin/Xóa vụ án), "Sửa thông tin vụ án"
      cố tình chặn sửa giai đoạn/trạng thái, và "Phục hồi" chỉ hiện cho riêng "Tạm đình chỉ". Nút
      mới **"Xoá hình thức giải quyết"** hiện cho cả 5 trạng thái do "Hoàn thành vụ án" tạo ra
      (điều kiện `FIELD_SO_QD_HOAN_THANH[vuAn.trangThai]` — tự động KHÔNG áp dụng cho "Đã nhập vào
      vụ khác" vì trạng thái đó không có entry trong map này, đúng vì đó là luồng khác hẳn, xem
      `NhapVuModal`). **KHÁC HẲN "Phục hồi"** (giữ nguyên như cũ, không đụng vào — theo yêu cầu
      người dùng đây là 1 tính năng riêng sẽ phát triển tiếp sau này): Phục hồi là hành động
      NGHIỆP VỤ chính thức (ghi sự kiện `phuc_hoi` mới, giữ nguyên sự kiện `hoan_thanh` cũ trong
      lịch sử, cần nhập ngày/số quyết định phục hồi điều tra, đi qua `ModalXacNhanKy` hỏi kỳ) —
      còn "Xoá hình thức giải quyết" là công cụ SỬA SAI SÓT thuần tuý (không hỏi kỳ, không ghi sự
      kiện mới): xoá hẳn `ngayQuyetDinh`/`kyHoanThanh`/`ngayQuyetDinhUocTinh`/`noiChuyenDen` + field
      số quyết định tương ứng (qua `fieldSoQuyetDinhTrenVuAn`) trên `vuan`, set `trangThai:
      "dang_giai_quyet"`, VÀ XOÁ LUÔN đúng sự kiện `hoan_thanh` đã gây ra trạng thái hiện tại khỏi
      `lichsuChuyenGiaiDoan` (đúng nguyên tắc thiết kế #1 — nếu không xoá log, số liệu báo cáo kỳ
      vẫn tính vụ này là "đã giải quyết" dù `vuan.trangThai` đã về "đang giải quyết", gây lệch số
      giữa `tinhTonHienTaiTheoGD` (đọc live `vuan`) và `tinhBaoCaoKyTuLog` (đọc log)). Sau khi xoá,
      bấm lại "Hoàn thành vụ án" để nhập đúng hình thức từ đầu.
      Tìm đúng sự kiện `hoan_thanh` cần xoá bằng cách lọc trên `lichSu` **ĐÃ CÓ SẴN** trong
      `ChiTietPanel` (đã tải, sắp xếp `desc` theo `thoiDiemGhi`) — lấy phần tử `hoan_thanh` ĐẦU
      TIÊN gặp trong mảng (= gần nhất), KHÔNG query Firestore riêng để tránh phải thêm composite
      index mới (`maVuAn` + `loaiSuKien` + `orderBy`) chỉ dùng 1 chỗ này. Cách này cũng tự nhiên
      không đụng tới các lần `hoan_thanh` CŨ HƠN nếu vụ từng Phục hồi rồi Hoàn thành lại nhiều lần
      trong lịch sử (chỉ xoá đúng sự kiện gần nhất). Không bắt gõ lại mã vụ để xác nhận như
      `XoaVuAnModal` (ít phá huỷ hơn — chỉ ảnh hưởng 1 vụ, không cascade xoá bị can/toàn bộ lịch
      sử) nhưng vẫn cảnh báo rõ không thể hoàn tác + nhắc "Tính lại số liệu" nếu vụ đã tính vào kỳ
      đã chốt (giống cảnh báo ở `XoaVuAnModal`). Đã kiểm chứng cú pháp bằng compile qua đúng bản
      `@babel/standalone@7.25.6` — **CHƯA kiểm chứng bằng dữ liệu Firestore thật**, cần thử trên
      `qlva-dev.html`: Hoàn thành 1 vụ (chọn nhầm hình thức), bấm "Xoá hình thức giải quyết", xác
      nhận vụ về "Đang giải quyết" đúng, sự kiện `hoan_thanh` cũ biến mất khỏi Lịch sử, rồi bấm lại
      "Hoàn thành vụ án" chọn đúng hình thức xem lưu bình thường không.
      **Ràng buộc "Đã xét xử" chỉ chọn được ở giai đoạn Xét xử (2026-07-17)** — trước đây
      `HoanThanhVuAnModal` cho chọn cả 5 hình thức (`TUY_CHON_HOAN_THANH`) bất kể vụ đang ở giai
      đoạn nào, dẫn tới việc lỡ chọn "Đã xét xử" cho vụ còn ở Điều tra/Truy tố (vô lý về nghiệp vụ
      — chưa ra toà thì chưa thể có bản án). Đã thêm điều kiện lọc: nút "Đã xét xử" chỉ hiện trong
      `HoanThanhVuAnModal` khi `vuAn.coQuanThuLy === "xet_xu"` (biến `tuyChonKhaDung`, lọc từ
      `TUY_CHON_HOAN_THANH` — KHÔNG sửa hằng số gốc vì `ThemVuAnForm` dùng chung hằng số này cho 1
      tình huống khác, xem ngay dưới). Vụ chưa tới giai đoạn Xét xử thì mặc định `hinhThuc` đổi
      sang `"chuyen_di"` (đặt lúc tải xong `vuAn` trong `useEffect`, không phải lúc khởi tạo
      `useState` vì lúc đó chưa biết `coQuanThuLy`), kèm dòng chú thích nhỏ giải thích lý do ẩn.
      Chặn thêm ở `luu()` (phòng trường hợp state cũ còn sót lại) để không lọt xuống Firestore dù
      UI có bị bypass thế nào. **Áp dụng tương tự cho `ThemVuAnForm`** (khối "Vụ án đã có kết quả
      giải quyết" — nhập bổ sung án cũ đã xong ngay lúc tạo vụ, dùng lại `TUY_CHON_HOAN_THANH`):
      dropdown "Hình thức giải quyết" lọc theo `coQuanThuLy` đang CHỌN trên form (khác
      `HoanThanhVuAnModal` — ở đó đọc từ 1 `vuAn` đã lưu, ở đây đọc từ state đang nhập), đổi
      `coQuanThuLy` sang khác "Xét xử" thì tự bỏ chọn "Đã xét xử" nếu đang chọn (tránh kẹt lựa
      chọn không còn hiện trên UI), đổi mặc định `trangThaiKetQua` từ `"da_xet_xu"` sang
      `"chuyen_di"` (khớp mặc định `coQuanThuLy` là Điều tra), và chặn thêm ở `onBamLuu()`. Đã
      kiểm chứng cú pháp bằng compile — **CHƯA kiểm chứng bằng dữ liệu Firestore thật**.
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
      mới (lọc trên `list` đã tải sẵn theo `hinhThuc`). **Thêm 4 cột + tìm theo Số QĐ KTVA
      (2026-07-14)** — bảng giờ có thêm **Số QĐ KTVA**/**Ngày KTVA** (đọc thẳng `v.soQdKtva`/
      `v.ngayQdKtva` có sẵn trên `vuan`) và **Số QĐ giải quyết**/**Ngày giải quyết** (cột "Ngày
      quyết định" cũ đổi tên hiển thị thành "Ngày giải quyết", cùng 1 dữ liệu `v.ngayQuyetDinh`).
      "Số QĐ giải quyết" cần field mới trên `vuan` vì trước đây **chỉ "Đã xét xử" có field riêng
      trên `vuan`** (`soBanAn`, set qua `fieldSoQuyetDinhTrenVuAn`) — 4 hình thức còn lại
      (Chuyển đi/Tạm đình chỉ/Đình chỉ/Án huỷ) chỉ lưu "Số QĐ" trên sự kiện log, không có trên
      `vuan`, nên không đọc thẳng được như cột trong bảng này cần (đọc thẳng `vuan`, không query
      log — xem lý do ở đầu module). Đã tổng quát hoá `fieldSoQuyetDinhTrenVuAn`/thêm hằng
      `FIELD_SO_QD_HOAN_THANH` để **cả 5 hình thức đều có field riêng trên `vuan`**
      (`soBanAn`/`soQuyetDinhChuyenDi`/`soQuyetDinhTamDinhChi`/`soQuyetDinhDinhChi`/
      `soQuyetDinhAnHuy`) — `HoanThanhVuAnModal` và `ImportExcelModule` đều dùng chung hàm này nên
      tự động ghi đúng field cho mọi hình thức từ nay về sau, không cần sửa gì thêm ở 2 nơi đó.
      **Vụ đã hoàn thành TRƯỚC ngày sửa này** (mọi hình thức trừ Đã xét xử) sẽ không có field mới
      → cột "Số QĐ giải quyết" hiện "—", vẫn tra được qua cột "Số QĐ" ở bảng Lịch sử (Nhật ký thao
      tác) của vụ đó như trước — chưa có công cụ backfill hàng loạt cho việc này, nếu cần thì làm
      tương tự cách backfill `ngayQuyetDinh`/`kyHoanThanh` đã có ("Cập nhật index" ở module Cài
      đặt). Ô tìm kiếm tự do thêm khớp `v.soQdKtva`.
- [x] Module Kỳ báo cáo (mở kỳ mới có chặn trùng kỳ đang mở, chốt kỳ tự snapshot tồn cuối kỳ
      theo từng cơ quan vào `tonCuoiKy`). **Có nhãn "🚧 Đang xây dựng" cạnh tiêu đề (2026-07-14)**
      — do B10 vẫn đang trong quá trình sửa/kiểm chứng số liệu (xem mục "Trạng thái Biểu B10" ở
      đầu file), nhắc người dùng số liệu module này có thể còn thay đổi; gỡ nhãn này khi thấy đã
      ổn định. Bấm vào 1 dòng kỳ mở ra **báo cáo chi tiết theo giai
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
      định trên mọi ô** của báo cáo tháng cho dễ đọc, xem hàm `themSheetDanhSach`) — **~45 sheet
      (2026-07-13/14: tái cấu trúc thành 1 sheet/loại sự kiện/giai đoạn, sau đó bổ sung thêm để
      kiểm chứng chéo được)**: Biểu B10 + TK tội danh + Tổng hợp báo cáo + **Cân đối số liệu**,
      sau đó cho mỗi giai đoạn ĐT/TT/XX: DS khởi tố, DS phục hồi, DS vụ tách, DS chuyển đến
      (TT/XX), DS trả về (ĐT/TT), DS đã xét xử, DS chuyển đi, DS tạm đình chỉ, DS đình chỉ, DS án
      huỷ, DS nhập vụ, DS tồn — cộng thêm **4 sheet RA** nhìn từ giai đoạn nguồn (DS ĐT chuyển TT/
      DS TT chuyển XX/DS TT trả ĐT/DS XX trả TT — cùng dữ liệu với DS chuyển đến/DS trả về của
      giai đoạn NHẬN, chỉ đổi nhãn sang góc nhìn giai đoạn nguồn, để mỗi giai đoạn tự cân đối được
      Vào/Ra của riêng nó). Không còn "DS mới" gộp chung hay "DS giải quyết" gộp chung — mỗi loại
      là 1 sheet riêng, đếm rows của sheet = số liệu của loại đó, giúp kiểm chứng từng con số trên
      sheet Tổng hợp bằng cách đếm trực tiếp trên sheet con.
      Helper nội bộ `addSheetVu(tenSheet, vuArr, extraHeaders, extraFn)` (mọi sheet danh sách có
      cột **"Đếm vụ"** đầu tiên — 1 vụ N bị can = N rows, cột này = 1 ở row BC đầu tiên của mỗi vụ
      và rỗng ở các row sau, nên phải `SUM(cột Đếm vụ)` để đếm số vụ, KHÔNG dùng `COUNTA` toàn
      sheet) và `addSheetVuKy` (bọc thêm cột **"Kỳ TK"** đầu tiên — tên kỳ báo cáo của sự kiện qua
      `tenKyBaoCao()`, áp dụng cho mọi sheet DS vào/ra, KHÔNG áp dụng cho DS tồn vì đó là số live
      không gắn với 1 kỳ). Toàn bộ danh sách dựng từ CHÍNH object `baoCao` mà `tinhBaoCaoKy` đã
      trả về (field `ds` trong mỗi `baoCao[gd]`, thu thập song song lúc tính số liệu qua
      `vuAnTuLogDocs`) — không tính lại riêng — nên số dòng mỗi sheet danh sách LUÔN khớp đúng số
      trên sheet Tổng hợp và trên báo cáo đang xem trên màn hình. Nếu sửa công thức
      `tinhBaoCaoKy` sau này, nhớ cập nhật đồng bộ cả phần `ds` tương ứng, đừng để 2 bên lệch
      nhau. Sheet **"Biểu B10"** có thêm cột ẩn/nhạt **"Mã ĐL"** (điều luật chính chuẩn hoá, dùng
      làm khoá tra cứu) — nhiều cột "Vụ" của B10 dùng công thức Excel `SUMIF` tham chiếu ngược lại
      các sheet danh sách theo cột "Mã ĐL vụ" (thay vì chỉ ghi giá trị JS tĩnh), để người xem có
      thể click-trace trong Excel từ B10 ra đúng danh sách vụ đã cộng vào ô đó. Sheet **"Cân đối
      số liệu"** dùng công thức Excel `SUM` tự kiểm: `Tồn đầu + Σ(DS vào) − Σ(DS ra) = Tồn cuối
      (chốt)` cho mỗi giai đoạn, tô xanh nếu chênh lệch = 0, đỏ nếu ≠ 0 (dấu hiệu có sự kiện log
      với `kyThongKe = null`, thường do dữ liệu cũ dựng lại lịch sử — xem `DungLaiLichSuTool`).
      **Sheet "Tổng hợp báo cáo" — thêm cột BC + hết phụ thuộc số JS xuất thẳng từ hệ thống
      (2026-07-15)** — trước đây mỗi giai đoạn chỉ 1 cột (chỉ có số Vụ, không dòng nào có tổng Bị
      can trừ riêng khối "Tồn" tách thành 2 HÀNG "— Vụ"/"— Bị can"), và nhiều dòng ("Án khởi tố
      mới", "Tin báo khởi tố lên", "Án nơi khác chuyển đến", "Số tồn hiện tại"...) đọc thẳng số JS
      từ `baoCao` dù ĐÃ có DS sheet tương ứng chứa đủ dữ liệu để tính ra cùng con số bằng công
      thức Excel — nghĩa là những dòng đó không tự kiểm chứng được, khác triết lý "công thức Excel"
      áp dụng cho B10/TK tội danh. Đã đổi cấu trúc cột thành **7 cột**: nhãn + `ĐT-Vụ/ĐT-BC/TT-Vụ/
      TT-BC/XX-Vụ/XX-BC` (mỗi giai đoạn 2 cột thay vì 1), và chuyển MỌI ô có DS sheet tương ứng
      sang công thức `SUM`/`COUNTIF`/`COUNTIFS`/`SUMIF` — cột BC đếm bị can THẬT trong sheet qua
      `COUNTIF(sheet!$M:$M,"<>(Chưa có BC)")` (cột M = Họ tên BC, loại trừ dòng giả của vụ 0 BC).
      Khối "Án khởi tố mới/Tin báo/Án nơi khác" lọc thêm theo cột **"Nguồn"** (cột AH của sheet
      "DS khởi tố {gs}", xem `addSheetVuKy`) qua `SUMIF`/`COUNTIF(S)`. **Chỉ còn 2 cặp dòng KHÔNG
      sheet-hoá được** vì bản chất là snapshot tại 1 thời điểm chốt kỳ (không phải danh sách sự
      kiện của kỳ này để đếm lại): "Tồn đầu kỳ" (snapshot `tonCuoiKy`/`tonCuoiBiCan` của KỲ TRƯỚC)
      và "Tồn cuối kỳ" (snapshot của CHÍNH kỳ này) — nhãn dòng đã ghi rõ "(snapshot chốt kỳ
      trước/này)" để không ai tưởng nhầm là thiếu sót. Riêng "Số tồn hiện tại" KHÔNG phải snapshot
      (luôn tính live) nên ĐÃ chuyển sang công thức qua sheet "DS tồn {gs}" có sẵn — trước đây bị
      bỏ sót dù sheet đã tồn tại.
      **Cột BC của khối ĐT "mới" áp dụng đúng nguyên tắc lọc theo kỳ vừa sửa ở B10 (xem "Trạng
      thái Biểu B10" đầu file)** — Điều tra là giai đoạn DUY NHẤT bị can có thể được "Thêm bị can"
      bổ sung vào 1 vụ đã có sẵn ở kỳ SAU kỳ vụ được mở, nên các dòng Án khởi tố mới/Tin báo/Án
      nơi khác/Phục hồi điều tra/Khởi tạo trực tiếp/Tổng số mới ở CỘT ĐT dùng `demBcSheetKy`
      (COUNTIFS theo cột "Kỳ TK BC" khớp đúng kỳ đang tính, dùng chung `bcKyKhoiToMap`/
      `kyIdSetTrongBaoCao`/`dsKyTenTrongBaoCao` đã thêm cho B10) — cột TT/XX của CÙNG các dòng đó
      dùng `demBcSheetM` thường (đếm mọi BC trong sheet, không lọc kỳ), đúng như B10 chưa từng lọc
      loaiKhoiTo cho khối TT/XX. Đã viết test độc lập cho toàn bộ formula helper mới trước khi
      mirror sang `qlva-dev.html` — CHƯA kiểm chứng bằng dữ liệu Firestore thật.
      **Biểu B10 vẫn còn 1 nhóm ô chưa sheet-hoá được audit nhưng CHƯA sửa** (out of scope đợt
      này, cần quyết định riêng nếu muốn làm tiếp) — 2 loại: (1) "Tồn kỳ trước"/"Tồn kỳ này" (vals
      index 0-3, 34-37, 65-68) — snapshot, giống lý do "Tồn đầu/cuối kỳ" ở Tổng hợp báo cáo, không
      sheet-hoá được; (2) "Tổng thụ lý" C3/C4/C33/C34/C60/C61 (vals index 4,5,34,35,65,66... — số
      thực ra là phép cộng/trừ CÁC CỘT B10 KHÁC trong CÙNG dòng, VD C3 = tồn trước + C6 − nhập vụ
      − chuyển đi − án huỷ) — về lý thuyết có thể viết thành công thức Excel tham chiếu chéo cột
      trong cùng 1 dòng (không cần DS sheet mới), nhưng chưa làm vì cần rà soát cẩn thận việc ánh
      xạ từng thành phần C3 sang đúng cột vals[] khác trong cùng hàng, quy mô tương đương lần sửa
      B10 gốc — nếu cần, hỏi lại rõ trước khi làm để tránh sai sót trên báo cáo chính thức.
- [x] **Cài đặt → "Bảng dữ liệu" (2026-07-17, `BangExcelModule`, nhánh `bang-excel-cai-dat`)** —
      công cụ sửa nhanh hàng loạt kiểu bảng tính Excel cho người dùng thành thạo, thêm 1 tab mới
      trong `CaiDatModule` (5 tab: Nhật ký/Cán bộ/Danh mục/Import/**Bảng dữ liệu**). Mỗi vụ án 1
      dòng, bấm nút mở rộng (▸) hiện bảng con bị can lồng bên dưới (giống Excel outline/group) —
      component `BangBiCanCon` tự query/`onSnapshot` riêng theo `maVuAn`, chỉ tải khi dòng vụ được
      mở rộng, không tải trước toàn bộ `bican`. **Mọi ô LUÔN ở trạng thái sửa** (không có bước bấm
      "Sửa" riêng như mọi form khác trong app — đúng cảm giác 1 bảng tính, click vào ô là gõ được
      ngay, blur/onChange mới commit Firestore tuỳ loại ô: `OCellText`/`OCellDate` commit lúc blur/
      onChange hợp lệ, `OSelectExcelEnum` commit ngay lúc chọn). **Kéo fill kiểu Excel** (hook dùng
      chung `useKeoFillNgang`, 1 phạm vi riêng cho bảng vụ và bảng con bị can của từng vụ — không
      trộn giữa 2 phạm vi) — giữ chuột ở tay cầm góc dưới-phải 1 ô (`TayKeoFill`, hiện khi hover
      qua `group-hover`) rồi kéo qua các dòng khác, thả chuột ghi hàng loạt qua 1 `batch.commit()`
      duy nhất cho toàn bộ đoạn kéo.
      **2 loại combobox KHÔNG lẫn lộn** (theo đúng yêu cầu người dùng): enum CỐ ĐỊNH (Nguồn/Giai
      đoạn/Trạng thái/Mức độ nghiêm trọng/Giới tính/Đảng viên/Biện pháp ngăn chặn) dùng `<select>`
      qua `OSelectExcelEnum`, KHÔNG cho gõ giá trị lạ (các giá trị này có ý nghĩa cố định trong
      logic thống kê ở khắp nơi trong app); danh sách tham chiếu MỞ (KSV chính/ĐTV/Dân tộc — dùng
      `<input list>` + `<datalist>` qua `OCellCombo`, 3 datalist `ds-ksv-excel`/`ds-dtv-excel`/
      `ds-dantoc-excel`) cho CHỌN có sẵn HOẶC GÕ MỚI tự do, vì đây là tên người/tên dân tộc, KSV/
      ĐTV mới vẫn hợp lệ dù chưa có trong danh mục Cán bộ.
      **Quyết định thiết kế đã hỏi rõ người dùng trước khi làm (KHÔNG tự suy đoán)**: (1) phạm vi
      Vụ án + Bị can lồng nhau (không phải chỉ 1 trong 2 — người dùng chọn đúng lựa chọn khuyến
      nghị); (2) **cho sửa CẢ Giai đoạn/Trạng thái ngay trên bảng — NGƯỢC với khuyến nghị ban đầu**
      của Claude (2 field này điều khiển số liệu báo cáo kỳ, đúng nguyên tắc thiết kế cốt lõi #1/#3
      thì phải qua đúng luồng nghiệp vụ có hỏi kỳ + ghi log vào `lichsuChuyenGiaiDoan`) — người
      dùng xác nhận muốn sửa trực tiếp để dọn dữ liệu cũ hàng loạt nhanh hơn. Vì vậy: sửa 2 field
      này ở `BangExcelModule` **KHÔNG ghi log sự kiện**, số liệu Kỳ báo cáo/Dashboard/Biểu B10 (đều
      tính từ log, không phải từ field hiện tại của `vuan`) **SẼ KHÔNG phản ánh thay đổi này** —
      đã thêm banner cảnh báo màu vàng cố định đầu bảng (`CANH_BAO_GIAI_DOAN_TRANG_THAI`) nhắc rõ
      điều này, chỉ nên dùng để sửa dữ liệu lịch sử/lỗi nhập liệu cũ, KHÔNG dùng thay cho nút
      "Chuyển giai đoạn"/"Hoàn thành vụ án" ở Danh sách vụ án cho nghiệp vụ đang diễn ra.
      Sửa bị can qua bảng này vẫn gọi `capNhatDieuLuatVaLoaiKhoiTo` (helper transaction dùng chung,
      xem mục "tối ưu hệ thống" trên) khi field ảnh hưởng `dieuLuat`/`loaiKhoiTo` (`ngayKhoiTo`,
      `toiDanhChinh`) bị đổi — kể cả khi đổi hàng loạt qua kéo fill, không chỉ khi sửa từng ô.
      Cột **KSV hỗ trợ** (`ksvHoTro`, field mảng trên `vuan`) hiển thị/sửa dạng chuỗi nối bằng dấu
      phẩy, nhưng thao tác **kéo fill** phải tự parse lại thành mảng trước khi ghi (bug thật gặp
      phải lúc viết tính năng: kéo fill ban đầu ghi thẳng chuỗi nguồn vào field mảng, làm hỏng
      field — phát hiện qua Playwright test dựng `TypeError: (vuAn.ksvHoTro || []).join is not a
      function` ở nơi khác trong app đọc field này — đã sửa `apDungGiaTriVu` đặc cách riêng field
      `ksvHoTro`: parse `String(giaTri).split(",").map(s => s.trim()).filter(Boolean)` trước khi
      đưa vào batch, giống hệt cách ô đơn `OCellCombo` của cột này đã tự làm đúng từ đầu). Nếu
      thêm cột mảng mới vào bảng vụ/bị can sau này, nhớ áp dụng cùng cách xử lý này ở hàm
      `apDungGiaTri`/`apDungGiaTriVu` tương ứng, đừng để lặp lại lỗi này.
      Bảng vụ tải `orderBy("ngayTao", "desc").limit(gioiHan)` (mặc định 500, nút "Tải thêm 500" ở
      cuối bảng khi còn có thể còn dữ liệu) — không tải toàn bộ `vuan` cùng lúc để tránh chậm với
      dữ liệu lớn, có ô tìm kiếm tự do (`tuKhoa`, khớp mã vụ/tên vụ/KSV chính/số QĐ KTVA) lọc trên
      `list` đã tải. Đã kiểm chứng đầy đủ bằng Playwright thật (không chỉ đọc code): sửa ô text/
      select/combobox, mở/thu gọn bị can, kéo fill cả ở bảng vụ (KSV hỗ trợ, xuyên qua dòng ở giữa
      không bị kéo) lẫn bảng con bị can (Dân tộc dạng chuỗi, Tội danh chính dạng object `{ten,
      dieuLuat}`) — không còn lỗi console sau khi sửa bug `ksvHoTro` ở trên.
      **Mở rộng đầy đủ mọi trường + nhóm cột + filter theo cột (2026-07-18, theo yêu cầu người
      dùng: "bảng phải gồm tất cả trường có trong hệ thống, chia thành các nhóm... thêm filter ở
      từng cột")** — bảng vụ án từ 15 cột phẳng lên **33 cột chia 9 nhóm** (Định danh/Nguồn & khởi
      tố/Cán bộ - đơn vị thụ lý/Giai đoạn & trạng thái/Phân loại/Điều luật/Kết quả giải quyết/Mức
      án & lưu trữ/Khác), bảng bị can từ 8 cột lên **17 cột chia 4 nhóm** (Nhân thân/Đảng viên &
      trình độ/Loại bị can-pháp nhân/Địa chỉ & ngăn chặn/Khởi tố & tội danh — gộp cả tội danh vào
      nhóm cuối). Cột mới thêm cho vụ án: Mã ngành cấp, Uỷ quyền xét xử, Nơi chuyển đến (chỉ hiện
      khi Chuyển đi), Án điểm/Phiên toà rút KN (checkbox), Điều luật (readonly, tự tính), Ngày giải
      quyết/Số QĐ giải quyết (field ẢO — tên field Firestore thật đổi theo `trangThai` từng dòng
      qua `fieldSoQuyetDinhTrenVuAn`)/Số kết luận ĐT/Số cáo trạng, Mức án loại-năm-tháng + Thời hạn
      bảo quản (readonly, tự tính qua `tinhThoiHanBaoQuanVu`), Ngày/người tạo + Ngày/người cập nhật
      cuối (readonly). Cột mới cho bị can: Quốc tịch, Giữ chức vụ QL (chỉ hiện khi Đảng viên=Có),
      Trình độ, Tái phạm, Loại bị can + Tên pháp nhân/Mã số thuế (chỉ hiện khi Pháp nhân), Địa chỉ,
      Hạn tạm giam (chỉ hiện khi Tạm giam), Số QĐ khởi tố BC, Loại khởi tố (readonly, tự tính).
      **CỐ Ý bỏ qua các field nội bộ/quan hệ** do luồng nghiệp vụ riêng quản lý (`vuGoc`/
      `nhapVaoVu`/`soDemTach`/`daXoa`+field kèm theo, `maNoiSinh` riêng — đã gộp vào cột "Mã vụ" qua
      `hienThiMa`) — sửa tay trực tiếp các field này trong bảng Excel dễ phá vỡ bất biến do Tách
      vụ/Nhập vụ/Thùng rác quản lý, phải sửa qua đúng luồng hành động chuyên trách.
      **Kiến trúc metadata dùng chung** (`NHOM_COT_VU`/`NHOM_COT_BICAN`, đặt trước
      `DongBiCanBangExcel`) — 1 mảng `{nhom, cols:[{id, label, filter, options?, getValue}]}` mô tả
      MỌI cột, dùng để tự sinh cả 3 việc: (1) `TheadNhomCot` — `<thead>` 3 tầng (hàng nhóm colSpan +
      hàng nhãn + hàng ô filter), (2) `apDungLocCot` — hàm lọc dùng chung cho cả 2 bảng, (3) hiển
      thị số cột/số filter đang dùng. **CỐ Ý KHÔNG gộp phần RENDER/GHI của từng ô vào metadata** —
      `DongVuBangExcel`/`DongBiCanBangExcel` vẫn viết JSX tường minh từng field như thiết kế gốc, vì
      mỗi field có logic ghi khác nhau (field mảng `ksvHoTro`, field cần tính lại `dieuLuat` sau khi
      đổi, field theo cặp bật/tắt như `dangVien`→`dangVienGiuChucVu`) — chỉ metadata hoá đúng phần
      THUẦN HIỂN THỊ/LỌC, không đụng cách ghi dữ liệu đã kiểm chứng từ trước.
      **3 kiểu filter theo đúng kiểu dữ liệu cột**: `text` (chứa, không phân biệt hoa/thường, commit
      lúc blur/Enter — không lọc lại mỗi phím gõ để tránh giật với bảng nhiều dòng), `enum` (dropdown
      khớp tuyệt đối, tái dùng đúng `options` đã có ở ô sửa cùng cột), `bool` (dropdown 3 trạng thái
      Tất cả/Có/Không), `date` (khoảng từ-đến, so `getTime()`). `apDungGiaTriVu` (kéo fill) xử lý
      thêm 3 trường hợp đặc biệt khi field kéo qua là field ẢO/cần biến đổi: `soQuyetDinhGQ` (map
      sang đúng field Firestore theo `trangThai` TỪNG DÒNG bị kéo qua, bỏ qua dòng không áp dụng
      được — VD kéo qua cả dòng "Đang giải quyết" thì dòng đó không ghi gì), `mucAnLoai` (chuỗi rỗng
      → `null`), `ngayQuyetDinh` (kèm xoá cờ `ngayQuyetDinhUocTinh`, đúng hành vi `SuaVuAnForm` đã
      có). Header nhóm cột dùng chung (`TheadNhomCot`) có prop `dinhTren` (mặc định `true`, sticky
      top) — bảng con bị can lồng bên trong đặt `dinhTren={false}` vì `sticky top-0` của nó tính
      theo cùng 1 scroll-ancestor với bảng vụ án cha, 2 header sticky cùng lúc sẽ đè nhau.
      Bảng con bị can cũng có bộ lọc riêng độc lập với bảng vụ án cha (dùng chung code
      `apDungLocCot`/`useColumnFilters` nhưng state tách biệt theo từng instance `BangBiCanCon`).
      **Đã kiểm chứng bằng Playwright thật qua UI** (không chỉ đọc code) — 26/26 assertion: đủ 9
      nhóm cột vụ án + 4 nhóm cột bị can hiện đúng, cột mới (Uỷ quyền xét xử/Thời hạn bảo quản/Ngày
      tạo/Quốc tịch...) hiện đúng, filter text lọc đúng theo KSV chính, filter enum lọc đúng theo
      Trạng thái, "Bỏ toàn bộ lọc cột" khôi phục đúng, sửa 1 ô mới ghi đúng field Firestore, mở rộng
      bị can hiện đúng nhóm cột + dữ liệu — 0 lỗi console. **Riêng kéo fill (autofill) được test lại
      độc lập bằng thao tác chuột thật** (`page.mouse.move/down/up`, không giả lập sự kiện) — kéo từ
      ô "Đơn vị thụ lý" dòng 1 xuyên qua dòng 2 tới dòng 3, xác nhận CẢ 2 dòng bị kéo qua đều được
      ghi đúng giá trị — xác nhận việc viết lại toàn bộ 2 component không làm hỏng tính năng
      autofill đã có từ trước. Cả 2 bộ test PASS giống hệt trên `qlva.html` VÀ `qlva-dev.html`.
      **CHƯA kiểm chứng bằng dữ liệu Firestore thật** (chỉ mock trong bộ nhớ) — nên mở thử
      `qlva-dev.html` thật (project `qlahs-test`) trước khi merge tính năng "Bảng dữ liệu" (toàn bộ,
      không riêng phần mở rộng hôm nay) vào `main`. **Ngoài phạm vi (chưa làm)**: cột đóng băng/ghim
      (pin) mấy cột đầu khi cuộn ngang — bảng 33+1 cột khá rộng, cần cuộn ngang nhiều; chưa làm vì
      không nằm trong yêu cầu ban đầu, cân nhắc thêm nếu người dùng phản hồi khó thao tác vì phải
      cuộn ngang quá nhiều.
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

**Cheat-sheet lệnh hay dùng** (luôn test trên `qlva-dev.html`/project `qlahs-test` trước, đừng
chạy thẳng lên `qlva.html`/production):

```bash
# Mở app cục bộ để test (chọn 1 trong 2)
#   - double-click qlva-dev.html trong File Explorer, HOẶC:
python -m http.server 8765        # rồi mở http://localhost:8765/qlva-dev.html

# Deploy (Bash, dùng chung với deploy.bat mà Dũng double-click trên Windows)
./deploy.sh test                  # đưa lên https://qlahs-test.web.app
./deploy.sh prod                  # đưa lên https://qlahsp2.web.app (dữ liệu thật)
./deploy.sh all                   # test trước, rồi prod

# Deploy riêng Firestore rules/index (không đụng tới hosting)
firebase deploy --only firestore:rules --project test   # hoặc --project prod
firebase deploy --only firestore:indexes --project test # hoặc --project prod
```

## Môi trường dev/test & công cụ hỗ trợ

- **`README.md`** — hướng dẫn nhanh viết cho Dũng (không phải lập trình viên): cách mở app bằng
  double-click, cách deploy qua `deploy.bat`, link production/test. Không lặp lại nội dung đó ở
  đây, chỉ tham khảo nếu cần trả lời câu hỏi kiểu "làm sao để xem thay đổi trên mạng".
- **`mo_qlva.bat`** — launcher Dũng double-click để mở phiên làm việc với Claude Code: tự `git
  pull` rồi chạy `claude "/init"`. Nghĩa là `/init` có thể được gọi lại ở ĐẦU MỖI PHIÊN làm việc,
  không chỉ 1 lần khi khởi tạo repo — khi việc này xảy ra, chỉ nên **bổ sung/tinh chỉnh** file này
  (như đang làm), đừng viết lại toàn bộ hay xoá mất lịch sử quyết định nghiệp vụ đã ghi ở trên.
- **`qlva-dev.html`** — bản sao gần như y hệt `qlva.html`, chỉ khác `firebaseConfig` trỏ sang
  project Firebase riêng **`qlahs-test`** (thay vì `qlahsp2` production). Dùng để thử tính năng
  mới/thao tác phá hoại (xoá, seed dữ liệu giả) mà không đụng dữ liệu thật. Khi sửa `qlva.html`,
  nhớ áp lại thay đổi tương ứng vào `qlva-dev.html` nếu muốn test trên project `qlahs-test` (2
  file không tự đồng bộ, không có build step nào gộp chúng lại — xem "Deploy lên Firebase
  Hosting" bên dưới, `deploy.sh`/`deploy.bat` cũng không tự đồng bộ code, chỉ tự đồng bộ việc
  đưa 2 file này lên đúng chỗ deploy).
- **`seed-tool.html`** — công cụ độc lập (không phải module trong `qlva.html`) để seed dữ liệu
  test hàng loạt hoặc xoá sạch collection, kết nối được tới **cả 2 project** (`qlahsp2` production
  VÀ `qlahs-test`, chọn qua UI). Có hàm `xoaProd()` xoá dữ liệu trên project **production** — mở
  file này cẩn thận, xác nhận đang thao tác đúng project trước khi bấm nút xoá/seed. **Không host
  công khai file này** — xem "Deploy lên Firebase Hosting" bên dưới.
- **`firebase.json`** / **`firestore.indexes.json`** / **`firestore.rules`** — config Firebase
  CLI dùng chung cho cả 2 project khi deploy qua `firebase deploy --only firestore:rules` hoặc
  `--only firestore:indexes` (cần `firebase use <project-id>` trước để chọn đích, hoặc dùng alias
  `prod`/`test` đã khai trong `.firebaserc`). Rules hiện tại chỉ chặn theo `request.auth != null`
  (đã đăng nhập là đọc/ghi được toàn bộ), không phân quyền theo vai trò — xem ghi chú ở mục hạ
  tầng bên dưới. `firebase.json` còn có mục `hosting` (mảng 2 target `prod`/`test`) — xem ngay
  dưới đây.

## Deploy lên Firebase Hosting (2026-07-14)

App được host công khai qua Firebase Hosting, tách biệt 2 project như đã có sẵn cho Firestore ở
trên: **production** (`qlahsp2`) tại **https://qlahsp2.web.app**, và **test** (`qlahs-test`) tại
**https://qlahs-test.web.app**.

**KHÔNG host thẳng thư mục gốc repo** — `seed-tool.html` (có hàm xoá sạch dữ liệu production) và
tài liệu nội bộ (`CLAUDE.md`, `schema_csdl_...md`) sẽ bị lộ công khai qua URL nếu làm vậy. Thay
vào đó dùng 2 thư mục riêng, mỗi thư mục CHỈ chứa đúng 1 file `index.html` — bản sao của app:
- `public-prod/index.html` = bản sao `qlva.html` (trỏ Firebase config production `qlahsp2`)
- `public-test/index.html` = bản sao `qlva-dev.html` (trỏ Firebase config test `qlahs-test`)

Cấu hình 2 hosting target trong `firebase.json` (mảng `hosting`, mỗi phần tử 1 `target`) +
`.firebaserc` (mục `targets` ánh xạ target → project + site, mục `projects` đặt alias `prod`/
`test` để deploy bằng `--project prod`/`--project test` thay vì gõ project ID đầy đủ).

**2 thư mục `public-prod`/`public-test` là bản sao TĨNH sinh ra lúc deploy, KHÔNG commit vào git**
(nằm trong `.gitignore` — tự tạo lại từ `qlva.html`/`qlva-dev.html` mỗi lần chạy script, tránh
commit 2 bản sao ~500KB trùng lặp rồi bị lệch ngay khi sửa file gốc). Dùng script có sẵn thay vì
làm tay từng bước, script tự `mkdir` thư mục nếu chưa có (VD sau khi clone lại repo):
- **`deploy.sh`** (chạy qua Git Bash/terminal, ví dụ Claude Code dùng lệnh này) — `./deploy.sh
  test` / `./deploy.sh prod` / `./deploy.sh all` (all = test trước, production sau). Tự copy đúng
  file nguồn vào đúng thư mục `public-*` rồi gọi `firebase deploy --only hosting:<target>
  --project <alias>` tương ứng — không cần nhớ tên project/target/thư mục mỗi lần.
- **`deploy.bat`** (Dũng dùng — double-click chạy trực tiếp trên Windows, không cần gõ lệnh) —
  hiện menu chọn 1/2/3 (test / production / cả hai), riêng nhánh production bắt gõ `YES` xác nhận
  trước khi deploy vì đây là dữ liệu thật, mọi người đang dùng.

Nếu sau này đổi cấu trúc file (VD app tách thành nhiều file, không còn 1 file HTML duy nhất),
nhớ cập nhật lại logic copy trong cả 2 script, đừng để lệch nhau.

## Tài liệu & dữ liệu tham khảo chưa vào code (chưa commit, ở ngoài `qlva.html`)

Vài file gốc mới thêm vào thư mục, chưa được nhắc tới ở đâu khác trong file này — đọc để biết vì
sao chúng tồn tại trước khi động vào:

- **`bieu_B10_mo_ta.md`** — đặc tả chi tiết từng cột A–BT của Biểu B10 (tài liệu ngành), đối chiếu
  trực tiếp với `tinhBaoCaoKyTuLog`/`chotKyBaoCao`/`tinhTonHienTaiTheoGD` trong `qlva.html`. Đọc
  file này trước khi sửa bất kỳ công thức tính cột nào của B10 — xem thêm mục "Trạng thái Biểu
  B10" ở đầu file.
- **`B10 2025.xlsx`** — file mẫu Biểu B10 gốc của ngành (nguồn cho `bieu_B10_mo_ta.md` ở trên).
- **`danh_muc_toi_danh.js`** — bản sao/nháp của danh mục tội danh, KHÔNG PHẢI nguồn thật đang chạy
  — nguồn thật là hằng số `DANH_MUC_TOI_DANH_MAM` nhúng thẳng trong `qlva.html` (dòng ~527, module
  Danh mục tội danh dùng trực tiếp từ đó; file `.js` này không được `<script src>` nạp vào app).
  **Đang lệch nhau**: `qlva.html` đã cập nhật sang đánh số **BLHS 2025** (thêm field `soDieu`,
  `namBLHS:"2025"`), còn `danh_muc_toi_danh.js` vẫn còn nhãn `namBLHS:"2015"` cũ — có vẻ là bản
  nháp/backup trước khi cập nhật. Đừng copy ngược nội dung file này vào `qlva.html` mà không kiểm
  tra kỹ, sẽ làm mất bản cập nhật BLHS 2025.
- **`BLHS 1999.md`** / **`BLHS 2025.md`** — mục lục điều luật Bộ luật hình sự (trích từ file
  `.docx` gốc, chỉ có tên + số điều, không có nội dung điều luật đầy đủ), dùng để tra cứu/đối
  chiếu số điều khi cập nhật `DANH_MUC_TOI_DANH_MAM`. Tên file dễ gây nhầm — nội dung 2 file có số
  điều khác nhau đáng kể (VD "Điều 9 - Phân loại tội phạm" chỉ có ở 1 trong 2 bản) — đối chiếu kỹ
  đang cập nhật CHIỀU nào trước khi dùng làm căn cứ sửa mã tội danh, đừng suy đoán theo tên file.
- **`mo_qlva.bat`** — launcher Dũng dùng để mở Claude Code (double-click): tự `cd` vào đúng thư
  mục, `git pull` lấy bản mới nhất, rồi chạy `claude "/init"`. Đây là lý do lệnh `/init` được gọi
  lặp lại mỗi lần Dũng mở Claude Code — khi review CLAUDE.md do lệnh này kích hoạt, ưu tiên bổ
  sung/sửa nhỏ (file đã rất đầy đủ), đừng viết lại từ đầu làm mất lịch sử quyết định nghiệp vụ đã
  tích luỹ qua nhiều phiên làm việc.

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
