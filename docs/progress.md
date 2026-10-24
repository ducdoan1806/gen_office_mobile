# Checklist GenOffice Mobile

Cập nhật: 24/10/2026. Giữ đúng lộ trình 9 bước đã thống nhất; AI công ty vẫn tạm hoãn; ChatGPT cá nhân đã triển khai, AI sửa file được yêu cầu tiếp tục trong ghi chú bàn giao. Bước chưa đánh dấu có thể đã làm một phần; chỉ đánh dấu hoàn tất khi đủ các mục con.

Tài liệu theo dõi tiến độ được lưu cùng source Flutter. Phát triển trên nhánh `dev`; chỉ merge sang nhánh chính khi chủ dự án chấp thuận.

## Bàn giao phiên tiếp theo — ưu tiên theo yêu cầu ngày 24/10/2026

Phiên này chỉ ghi chú; ba mục dưới chưa được sửa hoặc triển khai. Khi tiếp tục, ưu tiên lần lượt:

1. [ ] **Làm đẹp trang callback 127.0.0.1 và tự quay về app.**
   - Thêm CSS phù hợp nhận diện VPIC1 Office, bố cục đẹp trên điện thoại, trạng thái đăng nhập rõ ràng.
   - Sau khi xử lý kết quả đăng nhập thành công, thử tự điều hướng về app. Hiển thị trạng thái đang chuyển hướng/chờ 5 giây; nếu sau 5 giây chưa quay về thì mới hiện nút quay lại thủ công.
   - Giữ xác thực PKCE/state/nonce, Custom Tabs/KeepAlive và đường quay về không mang code/token; không đưa trạng thái thành công trước khi xác thực hoàn tất.
   - Kiểm tra trên Samsung thật: tự quay về, fallback sau 5 giây, trường hợp người dùng hủy hoặc đăng nhập lỗi.

2. [ ] **Sửa lỗi “Bottom overflowed by 36 pixels” khi mở bàn phím chat AI.**
   - Đây là lỗi chủ dự án vừa ghi nhận; chưa tái hiện/định vị trong phiên ghi chú này.
   - Kiểm tra chiều cao bảng AI, SafeArea và viewInsets khi bàn phím mở; ô nhập/nút Gửi luôn sử dụng được, nội dung chat cuộn được, không tràn.
   - Nghiệm thu bàn phím mở/đóng, nhập nhiều dòng và màn hình nhỏ trên điện thoại thật; giữ editor/hội thoại khi thu gọn.

3. [ ] **Cho AI sửa file theo yêu cầu.**
   - Đây là yêu cầu tiếp tục mới của chủ dự án cho phần AI thao tác tài liệu; không còn coi toàn bộ mục này là tạm hoãn. Chưa có mã áp dụng sửa file.
   - Bổ sung lấy đúng ngữ cảnh tài liệu/vùng chọn và chuyển yêu cầu thành thao tác chỉnh sửa có cấu trúc; thống nhất phạm vi định dạng khi triển khai, vì PDF hiện vẫn chỉ đọc.
   - Có kiểm tra thao tác và revision để tránh sửa nhầm khi tài liệu đã thay đổi; xem trước thay đổi/Áp dụng và Hoàn tác.
   - Dùng pipeline Lưu hiện có để cập nhật file nguồn người dùng đã mở; kiểm tra sửa → lưu → mở lại trên file mẫu, giữ các phần không chỉnh sửa.
   - AI công ty, nhà cung cấp khác, iOS và các hạng mục hoãn còn lại không tự mở lại theo ghi chú này.

Trạng thái nền để tiếp tục: ChatGPT đăng nhập/chat thật đã đạt trên Samsung Android 16; 59 test Flutter và analyze đạt ở lần kiểm chứng trước. Danh sách chi tiết ở mục ChatGPT bên dưới. Ghi chú này không xác nhận ba mục trên đã hoàn tất.

## Phạm vi phát triển hiện tại

Ưu tiên xây dựng và hoàn thiện ứng dụng trên **Android**. Tạm hoãn phát triển, build và kiểm thử iOS cho đến khi chủ dự án yêu cầu tiếp tục. Giữ lại mã nguồn, cấu hình và kết quả iOS đã có; các kết quả cũ không xác nhận những thay đổi mới đã tương thích iOS.

## Các mục tạm hoãn theo yêu cầu

- **Bước 5:** tạm hoãn toàn bộ phần chưa hoàn thành, gồm share sheet, chọn nơi xuất trên iOS/macOS và kiểm tra kết quả bằng Microsoft Word. Giữ nguyên các chức năng mở/lưu đã triển khai; tạm hoãn không có nghĩa là hoàn tất bước này.
- **Điện thoại Android thật:** chủ dự án đã mở lại kiểm thử ngày 22/10/2026. Đã kiểm thử tự động trên Samsung SM-A075F/Android 16/ARM64; nghiệm thu bàn phím/cảm ứng và đối chiếu Microsoft Word vẫn chưa hoàn thành. Xem [kết quả máy thật](android-device-qa.md).
- **iOS:** tạm hoãn toàn bộ công việc còn lại ở bước 9 và việc kiểm thử lại các tính năng mới trên iOS. Các dấu hoàn thành cũ được giữ như lịch sử kết quả đã làm.
- **AI:** AI công ty tiếp tục tạm hoãn; AI sửa file được yêu cầu tiếp tục ngày 24/10/2026, chưa triển khai, xem ghi chú bàn giao. ChatGPT cá nhân đã có đăng nhập, chat và kiểm thử thật trên Samsung ngày 24/10/2026; các giới hạn và phần chưa nghiệm thu được ghi đầy đủ ở mục ChatGPT cuối tài liệu.

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

## AI công ty — tiếp tục tạm hoãn

Giữ interface/mock/API stub AI nhà máy hiện có; chưa nối máy chủ. AI sửa tài liệu chưa triển khai và vừa được yêu cầu tiếp tục trong ghi chú bàn giao. ChatGPT cá nhân trên Android được bổ sung riêng theo yêu cầu ngày 24/10/2026; xem [ChatGPT Android](chatgpt-android.md). Không chạy model trên điện thoại.

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

Bước 6 đã hoàn thành trong luồng DOCX trên Android emulator và đã kiểm thử phục hồi qua force-stop trên Samsung Android 16. Bước 7 đã có PDF viewer offline, tìm kiếm và điều hướng trang trên Android. Đã chuyển PDF/XLSX/PPTX sang App/ribbon gốc GenOffice như DOCX, giữ giới hạn PDF chỉ đọc. Đã tích hợp XLSX/PPTX cơ bản từ source GenOffice và kiểm thử trên Samsung thật; bài integration DOCX lớn đã đạt sau khi sửa bridge. Còn nghiệm thu bàn phím/cảm ứng, stress bộ nhớ/chuyển nền và mở rộng các công cụ nâng cao Sheets/Slides. Phần iOS tiếp tục tạm hoãn. ChatGPT cá nhân đã nghiệm thu đăng nhập/quay về app, chat thật và khôi phục kết nối/model trên Samsung ngày 24/10/2026; còn các ca refresh/revoke/mạng lỗi và AI thao tác tài liệu ở checklist cuối.

Chưa tiếp tục bước 5, đối chiếu Word, nghiệm thu thủ công điện thoại hoặc AI công ty cho đến khi chủ dự án yêu cầu. AI sửa file đã được yêu cầu tiếp tục, theo ghi chú bàn giao đầu tài liệu. Bước 3 đã có lưu trữ metadata và liên kết file gốc Android. Giữ nguyên số bước và các dấu hoàn thành đã ghi nhận; không đánh dấu hoàn tất những bước còn hạng mục bị hoãn.

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

## ChatGPT cá nhân trên Android — tổng hợp đến 24/10/2026

### Yêu cầu và cách sử dụng đã thống nhất

- Ưu tiên Android; trước mắt chỉ tích hợp ChatGPT. AI công ty vẫn là interface/mock/API stub; Claude, Gemini, Copilot và nhà cung cấp khác chưa triển khai.
- AI công ty chỉ khả dụng khi truy cập được máy chủ nội bộ; tài khoản AI cá nhân do người dùng tự kết nối và sử dụng, không dùng chung tài khoản hoặc hạn mức do công ty quản lý.
- Kết nối mạng không được tự đổi AI/model người dùng đã chọn. Khi mở rộng nhiều nhà cung cấp sau này, giữ lựa chọn của người dùng và chỉ cập nhật trạng thái khả dụng; không tự chuyển yêu cầu/lịch sử sang AI khác.
- Dùng bảng AI trượt lên, có thể gần toàn màn hình; thu gọn để quay lại tài liệu liền mạch, không tải lại editor. Mỗi cuộc trò chuyện giữ model đã chọn; bản nháp/hội thoại tiếp tục tồn tại khi đóng/mở bảng trong cùng phiên editor.
- Ưu tiên đăng nhập tài khoản ChatGPT chính thức, không bắt người dùng tìm API key; không lấy cookie/token từ app ChatGPT đã cài hoặc thu mật khẩu trong VPIC1 Office.
- Các yêu cầu trên không đồng nghĩa đã hoàn tất kết nối AI công ty, hệ thống chọn nhiều nhà cung cấp hoặc AI tự chỉnh sửa tài liệu.

### Chức năng đã triển khai

- [x] Nút Trợ lý AI ở thanh dưới của editor Word/Excel/PowerPoint; nút AI nổi ở PDF. Có thể mở AI cả khi editor đang tải.
- [x] Bảng modal gần toàn màn hình, có thanh nắm, nút Thu gọn và Back. Giữ editor bên dưới, bản nháp, hội thoại và model khi thu gọn/mở lại; tiếp tục nhận câu trả lời khi bảng đóng.
- [x] Continue with ChatGPT mở luồng Sign in with ChatGPT (SIWC) bằng trình duyệt chính thức qua Custom Tab; người dùng tự đăng nhập/cấp quyền, không nhập API key.
- [x] Lấy danh sách model theo quyền tài khoản. Lưu lựa chọn làm mặc định; cuộc trò chuyện đã mở giữ model riêng, không đổi theo mạng hoặc khi mặc định của cuộc trò chuyện khác thay đổi.
- [x] Gửi câu hỏi, nhận phản hồi streaming; Dừng trả lời, Cuộc trò chuyện mới, sao chép, tải lại model, kết nối lại và ngắt kết nối tài khoản.
- [x] Cho người dùng chủ động dán nội dung văn bản/vùng ô/slide vào mục Đính kèm. Không tự tải toàn bộ tài liệu; chưa tự lấy vùng chọn canvas.
- [x] Lưu thông tin kết nối/model để dùng lại sau khi mở app. Đổi/ngắt tài khoản dọn ngữ cảnh chat trong bộ nhớ để không chuyển lịch sử sang tài khoản khác.
- [x] Giới hạn hiện tại: câu hỏi 6.000 ký tự, phần đính kèm 20.000 ký tự, tổng ngữ cảnh một yêu cầu 120.000 ký tự; báo lỗi khi vượt giới hạn.
- Kết quả AI hiện chỉ đọc/sao chép. Chưa có xem trước diff, áp dụng sửa vào tài liệu hoặc hoàn tác thao tác do AI tạo.

### Xác thực và lưu trữ

- [x] OAuth public-client SIWC với tên VPIC1 Office, host ID ổn định; PKCE S256, state/nonce ngẫu nhiên, callback chỉ bind 127.0.0.1. Không giả danh ứng dụng khác.
- [x] Kiểm tra chữ ký ID token bằng RSA/JWKS từ OpenAI discovery, issuer/audience/expiration/nonce, danh tính tài khoản và quyền dùng gói ChatGPT trước khi sử dụng.
- [x] Token/host/model lưu mã hóa AES-GCM với Android Keystore; loại preferences xác thực khỏi cloud backup/device transfer. Không ghi token, mật khẩu, email tài khoản hoặc mã đăng nhập vào tài liệu tiến độ/log kiểm thử.
- [x] Có xử lý refresh/rotation token trong mã và lỗi quyền/hạn mức/kết nối; chưa nghiệm thu refresh khi hết hạn thực tế hoặc revoke.
- [x] Dùng Responses API công khai, store=false và stream=true; giữ ngữ cảnh cần thiết ở client, không dùng backend-api/cookie web.
- SIWC có phạm vi tài khoản/quyền triển khai riêng. Kết quả đạt với tài khoản đã nghiệm thu không xác nhận mọi tài khoản, mọi gói hoặc mọi hình thức phân phối đều được hỗ trợ.
- Lịch sử chat và bản nháp chỉ giữ trong bộ nhớ phiên editor. Thu gọn không mất; đóng editor hoặc process restart chưa khôi phục lịch sử/bản nháp từ đĩa. Tài khoản và model được lưu riêng, có khôi phục sau restart.

### Lỗi 127.0.0.1 và bản sửa đã nghiệm thu

- [x] Lần đầu trên emulator: mở được trang auth.openai.com nhưng Chrome ANR, WebView tài liệu kẹt khởi động; không coi đó là nghiệm thu đăng nhập thật.
- [x] Lần đầu trên Samsung: người dùng đăng nhập được trên web nhưng callback 127.0.0.1 báo lỗi kết nối. ApplicationExitInfo xác nhận lúc 09:56:15 ngày 24/10/2026 Android dừng tiến trình chính vì LOW_MEMORY (importance=400), làm listener loopback biến mất.
- [x] Đổi từ Chrome task độc lập sang Custom Tabs có session/binding, AndroidX Browser 1.9.0 và KeepAlive extra. Empty bound service chỉ giữ vòng đời, không cung cấp phương thức hoặc dữ liệu xác thực; không thêm foreground service hay quyền chạy nền.
- [x] Kiểm tra trực tiếp trên Samsung: Chrome CustomTabActivity cùng task với app, bind ChatGptKeepAliveService và tiến trình VPIC1 giữ nguyên qua đăng nhập.
- [x] MainActivity singleTask, tắt Flutter deep-link routing cho đường quay về để giữ màn hình đang làm việc. URI vpic1office://chatgpt-return chỉ mở app, không mang code/token; OAuth vẫn nhận kết quả qua loopback và kiểm tra PKCE/state/nonce.
- [x] Tăng thời gian chờ lên 15 phút; dọn kết nối khi kết thúc/hủy; trang nhận kết quả có nút Quay lại VPIC1 Office.
- [x] Ghi marker vào kho mã hóa để phát hiện phiên bị process death. Nếu phiên đã mất, báo đăng nhập lại; không tái sử dụng code/state không còn hợp lệ.
- KeepAlive giảm rủi ro thu hồi bộ nhớ khi trình duyệt đang hoạt động; không bảo đảm app sống qua force-stop hoặc lỗi hệ thống.

### Kết quả kiểm thử đã đạt

- [x] 59 unit/widget test Flutter, gồm 8 ca ChatGPT; analyze không có vấn đề. APK debug ARM64 build thành công.
- [x] Kiểm thử protocol: PKCE theo vector RFC7636, scope/state/nonce, từ chối callback giả mạo, xử lý từ chối cấp quyền mà không lưu token; request Responses đúng hợp đồng; SSE bị chia nhỏ UTF-8/CRLF.
- [x] Kiểm thử trạng thái: giữ model theo cuộc trò chuyện, loại phần trả lời bị hủy khỏi lịch sử gửi tiếp, đóng bảng giữ bản nháp/yêu cầu đang chạy, nhận biết process death và giữ host ID.
- [x] Máy thật Samsung SM-A075F/Android 16/ARM64: cài đè bằng adb install -r, giữ nguyên hai mục tài liệu gần đây. Không uninstall/clear data.
- [x] Chủ tài khoản tự đăng nhập/cấp quyền trên điện thoại, quay về app bằng luồng mới thành công; app nhận kết nối và tải danh sách model, hiển thị GPT-6.1-Sol.
- [x] Gọi ChatGPT thật bằng câu hỏi mẫu không đính kèm tài liệu: nhận chính xác Hello VPIC1.
- [x] Thu gọn/mở lại giữ hội thoại, model và bản nháp chưa gửi.
- [x] Yêu cầu mẫu đếm 1–150 tiếp tục chạy khi bảng đóng; mở lại nhận đủ kết quả đến 150 và yêu cầu đã hoàn tất.
- [x] Force-stop rồi mở app: khôi phục tài khoản và đúng model GPT-6.1-Sol, không yêu cầu đăng nhập lại. Không coi đây là kiểm chứng refresh token đã hết hạn.
- [x] DOCX trên máy thật tải xong; thu bảng AI trở lại editor với trạng thái Lưu sẽ cập nhật file gốc.
- Trong lượt kiểm tra AI không bấm lưu, không sửa file nguồn, không gửi nội dung tài liệu công ty lên ChatGPT. Chỉ dùng câu hỏi/văn bản mẫu.
- Các nút Dừng/ngắt kết nối đã có mã và kiểm thử trạng thái ở mức unit/widget; chưa ghi nhận đầy đủ các ca Dừng/revoke bằng dịch vụ thật.

### Chưa làm hoặc chưa nghiệm thu

- [ ] Refresh token khi access token hết hạn thực tế; refresh thất bại/rotation; thu hồi quyền trên OpenAI và kết nối lại.
- [ ] Timeout đăng nhập đủ 15 phút; lỗi mạng giữa đăng nhập/trao đổi token/tải model/streaming; tài khoản hết hạn mức hoặc không đủ quyền trên dịch vụ thật.
- [ ] Hủy/Dừng trên kết nối thật, kiểm tra dọn tài nguyên và các trường hợp hệ thống đóng app/trình duyệt khác.
- [ ] Đăng nhập/đổi giữa nhiều tài khoản hoặc workspace thuận tiện hơn; hiện đổi tài khoản bằng ngắt kết nối rồi kết nối lại.
- [ ] Tự trích nội dung/vùng chọn chính xác từ DOCX, Sheets, Slides và PDF; dữ liệu bảng và định dạng có cấu trúc.
- [ ] AI đề xuất diff, áp dụng sửa vào file, kiểm tra revision xung đột và hoàn tác; hiện chỉ đọc/sao chép phản hồi.
- [ ] Lưu/khôi phục lịch sử chat và bản nháp sau khi đóng editor hoặc khởi động lại app.
- [ ] Nghiệm thu AI đầy đủ trên XLSX/PPTX/PDF và các thiết bị/trình duyệt mục tiêu; test máy thật đợt này tập trung DOCX + chat.
- [ ] Kết nối máy chủ AI công ty; tích hợp Claude/Gemini/Copilot hoặc nhà cung cấp khác. Chỉ tiếp tục theo phạm vi được chủ dự án yêu cầu.
- [ ] Build và nghiệm thu APK release có thay đổi AI; APK release 1.0.0 đã build trước ngày 24/10 không bao gồm phần AI mới. Chưa có khóa ký phát hành riêng, cấu hình release vẫn dùng khóa debug.
- [ ] Tích hợp/kiểm thử đăng nhập AI trên iOS; iOS tiếp tục tạm hoãn.

### Phiên bản và source

- Phiên bản dự án giữ 1.0.0+1; không thay applicationId com.example.gen_office_mobile.
- Commit triển khai ban đầu: d2cd589; ghi nhận lần test Samsung đầu: 64f7fea; sửa vòng đời và nghiệm thu đăng nhập/chat thật: 820a056.
- Công việc nằm trên nhánh dev, chưa đưa lên nhánh chính. Các lần push hiện bị lỗi Git Credential Manager/MSYS; commit đã lưu cục bộ, chưa xác nhận đồng bộ origin/dev.
- Chi tiết kỹ thuật và nguồn chính thức: [ChatGPT Android](chatgpt-android.md). AI là phần mở rộng riêng, không tự đánh dấu hoàn tất các bước 2/4/5/8/9 còn hạng mục chưa nghiệm thu.
