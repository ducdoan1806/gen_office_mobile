# Checklist GenOffice Mobile

Cập nhật: 22/10/2026. Giữ đúng lộ trình 9 bước đã thống nhất sau khi tạm hoãn AI. Bước chưa đánh dấu có thể đã làm một phần; chỉ đánh dấu hoàn tất khi đủ các mục con.

Tài liệu theo dõi tiến độ được lưu cùng source Flutter. Phát triển trên nhánh `dev`; chỉ merge sang nhánh chính khi chủ dự án chấp thuận.

## Phạm vi phát triển hiện tại

Ưu tiên xây dựng và hoàn thiện ứng dụng trên **Android**. Tạm hoãn phát triển, build và kiểm thử iOS cho đến khi chủ dự án yêu cầu tiếp tục. Giữ lại mã nguồn, cấu hình và kết quả iOS đã có; các kết quả cũ không xác nhận những thay đổi mới đã tương thích iOS.

## Các mục tạm hoãn theo yêu cầu

- **Bước 5:** tạm hoãn toàn bộ phần chưa hoàn thành, gồm share sheet, chọn nơi xuất trên iOS/macOS và kiểm tra kết quả bằng Microsoft Word. Giữ nguyên các chức năng mở/lưu đã triển khai; tạm hoãn không có nghĩa là hoàn tất bước này.
- **Nghiệm thu DOCX trên điện thoại thật và đối chiếu Microsoft Word:** tiếp tục tạm hoãn các mục tương ứng ở bước 2, 4, 8 và mốc DOCX đầu tiên. Các mục này vẫn để chưa hoàn thành.
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
  - Giới hạn 20 MB, chỉ đọc; chưa OCR, chưa hỗ trợ PDF có mật khẩu. Chưa nghiệm thu trên điện thoại thật; iOS vẫn hoãn.

- [ ] **Bước 8. Kiểm thử trên Android thực tế**
  - [x] Build APK và kiểm thử DOCX trên emulator.
  - [ ] Kiểm thử điện thoại thật: file lớn, bàn phím tiếng Việt, bộ nhớ và chuyển nền.
  - [ ] Xử lý lỗi trên thiết bị mục tiêu và nghiệm thu.

- [ ] **Bước 9. Mở rộng Sheets, Slides và iOS sau khi luồng DOCX ổn định**
  - [ ] Tích hợp Sheets/XLSX thực tế.
  - [ ] Tích hợp Slides/PPTX thực tế.
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

- [x] 22/10/2026: gộp nút mở DOCX/PDF thành **Mở tài liệu**; nhận diện DOCX/DOC/PDF từ cùng picker, kể cả nút thư mục trong editor.
- [x] Tích hợp chuyển đổi DOC ↔ DOCX native offline trong process riêng; Lưu giữ định dạng DOC và URI nguồn, Save As xuất DOCX; giữ cờ/hash phục hồi và bản DOC lúc nhập trong kho riêng. Xem [DOC offline](legacy-doc.md).
- [x] Kiểm thử mở/sửa/lưu/mở lại DOC khi tắt Wi-Fi và dữ liệu di động trên emulator; 39 unit/widget test, 3 integration PDF và 4 integration DOCX đạt. Runtime ARM64/x86_64 đã có script chuẩn bị kèm SHA-256; ARM64/Word thực tế chưa nghiệm thu.

- [x] Tạo cấu trúc dự án Flutter.
- [x] Đưa source lên GitHub, thêm `.gitignore` và README hướng dẫn clone/cài/chạy/build.
- [x] Thiết lập nhánh `dev`; chỉ đưa lên nhánh chính khi chủ dự án chấp thuận.
- [x] Merge PR #1 và [PR #2 sửa iOS](https://github.com/ducdoan1806/gen_office_mobile/pull/2) theo yêu cầu.

## Điểm tiếp tục

Bước 6 đã hoàn thành trong luồng DOCX trên Android emulator. Bước 7 đã có PDF viewer offline, tìm kiếm và điều hướng trang trên Android. Khi chủ dự án yêu cầu tiếp tục, ưu tiên các mục XLSX/PPTX của **bước 9** trên Android. Phần iOS tiếp tục tạm hoãn.

Chưa tiếp tục bước 5, các mục nghiệm thu điện thoại thật/Word đang hoãn hoặc AI cho đến khi chủ dự án yêu cầu. Bước 3 đã có lưu trữ metadata và liên kết file gốc Android. Giữ nguyên số bước và các dấu hoàn thành đã ghi nhận; không đánh dấu hoàn tất những bước còn hạng mục bị hoãn.

Đây là tổng hợp kết quả kiểm thử đã ghi nhận; phạm vi và ngày kiểm chứng được ghi trong tài liệu từng tính năng. Xem thêm [README](../README.md), [tách editor](docx-web-extraction.md), [WebView mobile](mobile-webview.md), [PDF viewer](pdf-viewer.md) và [build iOS](ios-build.md).
