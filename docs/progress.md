# Checklist GenOffice Mobile

Cập nhật: 22/10/2026. Giữ đúng lộ trình 9 bước đã thống nhất sau khi tạm hoãn AI. Bước chưa đánh dấu có thể đã làm một phần; chỉ đánh dấu hoàn tất khi đủ các mục con.

Tài liệu theo dõi tiến độ được lưu cùng source Flutter. Phát triển trên nhánh `dev`; chỉ merge sang nhánh chính khi chủ dự án chấp thuận.

## Phạm vi phát triển hiện tại

Ưu tiên xây dựng và hoàn thiện ứng dụng trên **Android**. Tạm hoãn phát triển, build và kiểm thử iOS cho đến khi chủ dự án yêu cầu tiếp tục. Giữ lại mã nguồn, cấu hình và kết quả iOS đã có; các kết quả cũ không xác nhận những thay đổi mới đã tương thích iOS.

## Các mục tạm hoãn theo yêu cầu

- **Bước 5:** tạm hoãn toàn bộ phần chưa hoàn thành, gồm share sheet, chọn nơi xuất trên iOS/macOS và kiểm tra kết quả bằng Microsoft Word. Giữ nguyên các chức năng mở/lưu đã triển khai; tạm hoãn không có nghĩa là hoàn tất bước này.
- **Điện thoại Android thật:** chủ dự án đã mở lại kiểm thử ngày 22/10/2026. Đã kiểm thử tự động trên Samsung SM-A075F/Android 16/ARM64; nghiệm thu bàn phím/cảm ứng và đối chiếu Microsoft Word vẫn chưa hoàn thành. Xem [kết quả máy thật](android-device-qa.md).
- **iOS:** tạm hoãn toàn bộ công việc còn lại ở bước 9 và việc kiểm thử lại các tính năng mới trên iOS. Các dấu hoàn thành cũ được giữ như lịch sử kết quả đã làm.
- **AI:** tiếp tục tạm hoãn như đã thống nhất.

## Lộ trình đã thống nhất

- [x] **Bước 1. Tách editor DOCX khỏi Electron**
  - [x] Tái sử dụng editor React/Tiptap và engine DOCX của GenOffice.
  - [x] Chuyển phụ thuộc IPC, Node và filesystem thành adapter trình duyệt.
  - [x] Kiểm thử editor độc lập: mở, chỉnh sửa, định dạng, bảng, undo/redo, xuất và mở lại DOCX.

- [ ] **Bước 2. Nhúng editor vào Flutter bằng WebView**
  - [x] Đóng gói editor, font và worker trong ứng dụng.
  - [x] Nối bridge Flutter ↔ editor cho mở/lưu/undo/redo/trạng thái.
  - [x] Kiểm thử luồng DOCX trên Android emulator và iOS Simulator.
  - [x] Sửa menu cuộn ngang, nhãn nằm trên một dòng.
  - [ ] Kiểm tra bàn phím tiếng Việt, chọn chữ, cảm ứng, cuộn và zoom trên điện thoại thật.

- [x] **Bước 3. Thêm chọn và mở file DOCX thật**
  - [x] Chọn DOCX bằng file picker native và mở trong editor.
  - [x] Android giữ liên kết và quyền đọc/ghi file gốc; kho riêng giữ cache và metadata.
  - [x] Lưu metadata và hiển thị lại tài liệu sau khi khởi động app; thay danh sách mẫu bằng thư viện thật, có nút Mở tài liệu.
  - Yêu cầu đã chỉnh lại: Android **Lưu ghi đè chính file nguồn đã mở** bằng SAF; đọc lại từ nguồn khi mở gần đây. Bản cũ trong app cần chọn lại file gốc. **Lưu thành bản mới** chọn nơi lưu qua Android. Xem [kho tài liệu](document-library.md).

- [ ] **Bước 4. Hoàn thiện chỉnh sửa cơ bản**
  - [x] Tích hợp sửa nội dung, định dạng chữ, đoạn và bảng từ editor gốc.
  - [x] Có kiểm thử engine/browser cho định dạng và bảng, kiểm thử mobile cho sửa nội dung.
  - [x] Cải thiện vùng bấm mobile; kiểm thử Android WebView cho định dạng nghiêng/gạch chân, cỡ chữ 18 pt, căn giữa, sửa ô bảng và chèn bảng 2×2; đối chiếu XML DOCX và mở lại kết quả. Xem [chỉnh sửa cơ bản](basic-editing.md).
  - [x] Kiểm thử bộ 6 DOCX do chủ dự án cung cấp trên Android emulator: lưu nguyên trạng giữ nguyên các phần ZIP; sửa/lưu/mở lại đạt, ảnh/style/header/footer/liên kết và các phần không chỉnh sửa được giữ nguyên. SHA-256 của 6 file nguồn không đổi.
  - [ ] Nghiệm thu đầy đủ trên điện thoại thật với bộ DOCX nhà máy, đối chiếu định dạng Word.

- [ ] **Bước 5. Lưu, xuất và chia sẻ DOCX — TẠM HOÃN phần còn lại**
  - [x] Android Lưu cập nhật file nguồn đã chọn; Lưu thành bản mới chọn đích bằng ACTION_CREATE_DOCUMENT.
  - [x] Kiểm thử lưu native và mở lại file kết quả.
  - [x] Cảnh báo thay đổi chưa lưu khi quay lại/mở file khác.
  - [ ] Thêm share sheet; chọn nơi xuất trên iOS/macOS.
  - [ ] Kiểm tra file kết quả bằng Microsoft Word với tài liệu thực tế.

- [x] **Bước 6. Thêm undo/redo và khôi phục phiên**
  - [x] Nối và kiểm thử undo/redo.
  - [x] Android giữ URI và quyền truy cập file nguồn qua các lần khởi động; chỉ báo Lưu thành công sau khi ghi/đọc xác minh nguồn.
  - [x] Tạo bản tạm DOCX mỗi 5 giây và khi chuyển nền; khôi phục qua màn hình chính, giữ dirty cho đến khi Lưu vào nguồn.
  - [x] Kiểm thử phục hồi mất tiến trình bằng force-stop Android rồi chạy tiến trình mới; kiểm tra nguồn thay đổi, lỗi/hủy Lưu và dọn bản tạm sau Lưu thành công. Đây là mô phỏng crash/thu hồi app trên emulator, chưa ép crash native/LMK thật. Xem [khôi phục phiên](session-recovery.md).

- [x] **Bước 7. Tích hợp PDF viewer trên Android**
  - [x] Mở tài liệu thật qua SAF với quyền đọc; lưu danh sách gần đây và đọc lại từ nguồn khi mở.
  - [x] Hiển thị offline bằng PDF.js; cuộn, phóng to/thu nhỏ và vừa chiều rộng trang.
  - [x] Tìm chữ toàn tài liệu, tô sáng, đếm và chuyển kết quả; trang trước/sau và nhập số trang.
  - [x] Kiểm thử WebView Android với PDF 3 trang có chữ/hình, tìm kiếm/chuyển trang và báo lỗi file hỏng; 36 unit/widget test đạt. Xem [PDF viewer](pdf-viewer.md).
  - [x] Kiểm thử SAF native với PDF trong Downloads: giữ quyền đọc, chặn ghi, thu hồi quyền và giữ nguyên file nguồn; 4 bài DOCX WebView hồi quy đạt.
  - Giới hạn 20 MB, chỉ đọc; chưa OCR, chưa hỗ trợ PDF có mật khẩu. Đã kiểm thử tự động cơ bản trên Samsung Android 16; thao tác cảm ứng bằng tay chưa nghiệm thu. iOS vẫn hoãn.

- [ ] **Bước 8. Kiểm thử trên Android thực tế**
  - [x] Build APK và kiểm thử DOCX trên emulator.
  - [x] Kiểm thử tự động trên Samsung Android 16/ARM64: DOC offline, 4 ca DOCX, 3 ca PDF và khôi phục qua force-stop. 6 DOCX mẫu và fixture 10,9 MB đã đạt integration mở/sửa/lưu/mở lại; đã sửa lỗi rơi lệnh khi React thay bộ nhận lệnh. SAF native và quyền DOC/XLSX/PPTX qua hai tiến trình đạt. Xem [máy thật](android-device-qa.md).
  - [x] Bài integration corpus 7 file, gồm file 10,9 MB, đạt trên Samsung thật; lưu nguyên trạng và sửa/lưu/mở lại, giữ các phần ZIP không sửa.
  - [ ] Nghiệm thu bàn phím tiếng Việt, cảm ứng; stress bộ nhớ/LMK và chuyển nền dài trên thiết bị mục tiêu.
  - [ ] Xử lý lỗi trên thiết bị mục tiêu và nghiệm thu.

- [ ] **Bước 9. Mở rộng Sheets, Slides và iOS sau khi luồng DOCX ổn định**
  - [x] Tích hợp Sheets/XLSX trên Android bằng App/ribbon gốc GenOffice và gateway/Univer: mở, sửa ô/công thức, undo/redo, phục hồi, lưu và mở lại đã đạt trên Samsung Android 16. Công cụ nâng cao desktop chưa được tích hợp đầy đủ.
  - [x] Tích hợp Slides/PPTX trên Android bằng App/ribbon/canvas gốc GenOffice và engine/ops: mở, sửa văn bản, undo/redo, phục hồi, lưu và mở lại đã đạt trên Samsung Android 16. Công cụ nâng cao desktop chưa được tích hợp đầy đủ.
  - [x] Cấu hình và sửa build iOS với Flutter 3.35.3 / Xcode 27, deployment target iOS 15.
  - [x] Build Debug và kiểm thử DOCX trên iPhone 18 Pro Simulator / iOS 27.
  - [x] Build iOS Release không ký (`--no-codesign`).
  - [ ] Thiết lập signing, cài và kiểm thử iPhone thật.

## Mốc DOCX đầu tiên

- [x] Mở → sửa → lưu → mở lại đạt trong integration test Android emulator và iOS Simulator.
- [ ] Nghiệm thu cùng luồng trên điện thoại thật với file nhà máy và đối chiếu Microsoft Word.

## AI — tạm hoãn theo yêu cầu

Giữ interface/mock/API stub hiện có. Chưa nối API và chưa triển khai AI thao tác tài liệu. AI sẽ chạy trên máy chủ nội bộ nhà máy, mobile gọi API; không chạy model trên điện thoại. Chỉ tiếp tục khi chủ dự án yêu cầu.

## Công việc bổ sung đã làm

- [x] 22/10/2026: thay giao diện PDF/Excel/PowerPoint rút gọn bằng nguyên App, ribbon và CSS của source GenOffice cùng commit với DOCX; thêm vuốt ngang công cụ trên điện thoại. Đã kiểm tra 9 ca WebView riêng biệt trên Samsung Android 16 (2 XLSX/PPTX, 3 PDF, 4 DOCX), 43 test Flutter, 8 test web và 3 bài trình duyệt: đạt. Xem [phạm vi port giao diện](sheets-slides-android.md).

- [x] 22/10/2026: gộp nút mở DOCX/PDF thành **Mở tài liệu**; nhận diện DOCX/DOC/PDF từ cùng picker, kể cả nút thư mục trong editor.
- [x] Tích hợp chuyển đổi DOC ↔ DOCX native offline trong process riêng; Lưu giữ định dạng DOC và URI nguồn, Save As xuất DOCX; giữ cờ/hash phục hồi và bản DOC lúc nhập trong kho riêng. Xem [DOC offline](legacy-doc.md).
- [x] Kiểm thử mở/sửa/lưu/mở lại DOC khi tắt Wi-Fi và dữ liệu di động trên emulator; 39 unit/widget test, 3 integration PDF và 4 integration DOCX đạt. Runtime ARM64/x86_64 đã có script chuẩn bị kèm SHA-256; ARM64 đã đạt luồng DOC offline trên Samsung Android 16; Word thực tế chưa nghiệm thu.

- [x] Tạo cấu trúc dự án Flutter.
- [x] Đưa source lên GitHub, thêm `.gitignore` và README hướng dẫn clone/cài/chạy/build.
- [x] Thiết lập nhánh `dev`; chỉ đưa lên nhánh chính khi chủ dự án chấp thuận.
- [x] Merge PR #1 và [PR #2 sửa iOS](https://github.com/ducdoan1806/gen_office_mobile/pull/2) theo yêu cầu.

Chi tiết phần Sheets/Slides và giới hạn hiện tại: [Android Sheets/Slides](sheets-slides-android.md). Source gốc được cố định tại cùng commit với DOCX để giữ tương thích giữa các engine.

## Điểm tiếp tục

Bước 6 đã hoàn thành trong luồng DOCX trên Android emulator và đã kiểm thử phục hồi qua force-stop trên Samsung Android 16. Bước 7 đã có PDF viewer offline, tìm kiếm và điều hướng trang trên Android. Đã chuyển PDF/XLSX/PPTX sang App/ribbon gốc GenOffice như DOCX, giữ giới hạn PDF chỉ đọc. Đã tích hợp XLSX/PPTX cơ bản từ source GenOffice và kiểm thử trên Samsung thật; bài integration DOCX lớn đã đạt sau khi sửa bridge. Còn nghiệm thu bàn phím/cảm ứng, stress bộ nhớ/chuyển nền và mở rộng các công cụ nâng cao Sheets/Slides. Phần iOS tiếp tục tạm hoãn.

Chưa tiếp tục bước 5, đối chiếu Word, nghiệm thu thủ công điện thoại hoặc AI cho đến khi chủ dự án yêu cầu. Bước 3 đã có lưu trữ metadata và liên kết file gốc Android. Giữ nguyên số bước và các dấu hoàn thành đã ghi nhận; không đánh dấu hoàn tất những bước còn hạng mục bị hoãn.

Đây là tổng hợp kết quả kiểm thử đã ghi nhận; phạm vi và ngày kiểm chứng được ghi trong tài liệu từng tính năng. Xem thêm [README](../README.md), [tách editor](docx-web-extraction.md), [WebView mobile](mobile-webview.md), [PDF viewer](pdf-viewer.md) và [build iOS](ios-build.md).

## Bổ sung 23/10/2026: cảm ứng Excel và định dạng cũ

- [x] Lưới Excel: vuốt ngang/dọc một ngón, khóa trục, quán tính; chạm chọn ô, chạm hai lần sửa, giữ rồi kéo chọn vùng. Dùng bộ cuộn/selection/editor gốc Univer.
- [x] Mở/sửa/lưu XLS và PPT bằng chuyển đổi offline hai chiều trên Android; Lưu giữ định dạng và URI file nguồn, Save As xuất XLSX/PPTX. DOC tiếp tục dùng cùng runtime.
- [x] Mở/sửa/lưu CSV bằng codec Unicode offline; giữ dấu phân cách/BOM/mã hóa, xử lý quoting/xuống dòng và mã có số 0 đầu. Lưu giá trị một sheet; cảnh báo giới hạn và yêu cầu Save As XLSX nếu có nhiều sheet.
- Phạm vi/giới hạn: [XLS/PPT/CSV và thao tác cảm ứng](legacy-office-formats.md). Nghiệm thu thủ công và đối chiếu Office vẫn chưa hoàn thành; các hạng mục hoãn ở bước 5/iOS/AI giữ nguyên.
- Kiểm chứng 23/10/2026: 51 unit/widget test Flutter, 8 test web/engine, 5 bài trình duyệt production và Dart analyze đều đạt. Bộ Android tổng hợp đạt **13 ca** trên Samsung SM-A075F/Android 16/ARM64: XLSX, PPTX, XLS, PPT, CSV; 3 PDF; 4 DOCX; DOC offline. Xem [QA máy thật](android-device-qa.md).

### Sửa chọn ô/vùng Excel trên Android WebView — 23/10/2026

- [x] Sửa tọa độ canvas của sự kiện PointerEvent được tạo từ touch. Trên Samsung DPR 1,875, WebView đã áp thêm page scale vào offsetX/offsetY, khiến điểm chạm rơi ra ngoài ô; bộ chuyển tiếp nay cung cấp offset theo CSS pixel của canvas.
- [x] Thêm regression mô phỏng lỗi offset của WebView; 6 bài Playwright production đạt, gồm chạm chọn, giữ kéo vùng, chạm hai lần sửa và hồi quy cuộn/lưu.
- [x] Cài APK thường bằng install -r và kiểm tra bằng input Android thật trên Samsung: chạm chọn B2, giữ rồi kéo chọn B2:C3, vuốt dọc/ngang giữ nguyên vùng chọn. Nghiệm thu cảm ứng/bàn phím toàn bộ ứng dụng trong bước 8 vẫn chưa hoàn tất.

### Gọn các nút lưu trên mobile — 23/10/2026

- [x] Ẩn Quick Access Save/Save As, Undo/Redo, AutoSave và dấu phân cách bị trùng trong ribbon DOCX/Sheets/Slides/PDF trên mobile. Giữ các tab và công cụ định dạng gốc; PDF tiếp tục chỉ đọc.
- [x] Giữ một nút Lưu trên AppBar Flutter; thêm **⋮ → Lưu thành bản mới** cho DOCX/XLSX/PPTX và các file chuyển đổi tương ứng. Gọi pipeline Save As gốc, không đổi chức năng Lưu ghi đè nguồn. Hoàn tác/Làm lại giữ ở thanh Flutter dưới; bản tạm khôi phục nền vẫn hoạt động.
- [x] 51 test Flutter, 8 test web/engine, 7 bài trình duyệt và analyze đạt; 13 ca Android đạt. Ca DOCX kiểm tra menu Flutter mới thực sự tạo bản sao, Lưu tiếp cập nhật bản đang mở và không nhân thêm mục thư viện.
- Quy trình test: bắt buộc `--no-uninstall`; SDK hiện tại mặc định tự gỡ app khi kết thúc test. Đã ghi nhận việc reset danh sách gần đây ở lần này, mở lại file Excel gốc qua SAF và bổ sung quy định vào AGENTS.md/README. File nguồn vẫn còn trong Downloads.

### Nhận diện VPIC1 Office — 23/10/2026

- [x] Đổi tên hiển thị Android và tiêu đề màn hình chính thành **VPIC1 Office**; dùng icon do chủ dự án cung cấp cho launcher và trang Giới thiệu. Giữ applicationId và phiên bản 1.0.0+1.
- [x] Thêm nút **ⓘ Giới thiệu** tại màn hình chính: mô tả nội bộ đã duyệt, đơn vị VPIC1, nền tảng Android, phiên bản/bản dựng đọc từ APK và giấy phép phần mềm. Bỏ các thông tin liên hệ còn là placeholder theo yêu cầu.
- [x] Analyze và 51 test Flutter đạt; build APK debug ARM64 thành công. Cài APK thường bằng `adb install -r`, kiểm tra trực tiếp tên, icon, nội dung Giới thiệu, cuộn trang và phiên bản **1.0.0 (bản dựng 1)** trên Samsung SM-A075F/Android 16. Không chạy integration test thiết bị cho thay đổi nhận diện này.

### Bo góc logo và màn hình khởi động — 23/10/2026

- [x] Tách splash khỏi launcher icon: logo bo góc 25% trên nền sáng cùng màu app; Android 12+ dùng splash native với vùng an toàn và tên VPIC1 Office phía dưới, Android 7–11 dùng layer-list tương ứng. Không thêm thời gian chờ khởi động.
- [x] Thêm Adaptive Icon cho Android 8+ để launcher áp mask theo thiết bị; icon legacy Android 7 bo góc, trang Giới thiệu bo góc 25%. Script tạo lại đầy đủ PNG từ icon nguồn, giữ nguyên file gốc.
- [x] Analyze và build APK debug ARM64 đạt; cài bằng `adb install -r`, cold launch trên Samsung SM-A075F/Android 16 và chụp kiểm tra splash thực tế: logo bo góc, không bị cắt, có tên ứng dụng. Android 7–11 chưa kiểm tra trực tiếp trong đợt này.

### Giữ trọn logo ngoài launcher — 23/10/2026

- [x] Thu logo adaptive xuống 54dp trong layer 108dp, bo góc 25%, nằm trọn trong vòng an toàn 66dp; thêm nền sáng đồng bộ app để mask của launcher không cắt vào hình. Giữ tỉ lệ vuông và nguyên hình nguồn, không đổi splash/trang Giới thiệu.
- [x] Build APK debug ARM64 đạt, cài bằng `adb install -r` và kiểm tra trực tiếp trong danh sách ứng dụng Samsung Android 16: logo đầy đủ, đúng tỉ lệ, không bị phóng/cắt như bản trước. Icon nguồn giữ nguyên SHA-256.
