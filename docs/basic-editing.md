# Bước 4 — chỉnh sửa cơ bản trên mobile

Editor tiếp tục dùng React/Tiptap và pipeline DOCX gốc. Không thay engine, không bật AI, không ghi đè tài liệu gốc.

## Cải thiện giao diện

- Nút định dạng chữ, căn đoạn, tab và nút xổ xuống có vùng bấm tối thiểu 44×44 px trong mobile host.
- Tăng chiều cao ribbon để hai hàng điều khiển không bị cắt; ribbon gọn vẫn giữ chiều cao riêng. Giữ cuộn ngang để truy cập đủ chức năng.
- Ô cỡ chữ dễ bấm hơn; input dùng chữ 16 px để tránh zoom tự động trên iOS khi nhập. Việc xác nhận trên iPhone thật vẫn còn chờ.
- Ô chọn kích thước bảng có vùng bấm 44×44 px và nhãn đọc được bằng công cụ hỗ trợ. Menu bảng giới hạn theo viewport và có thể cuộn.
- Nút in đậm/nghiêng/gạch chân và căn đoạn công bố trạng thái bật/tắt qua `aria-pressed`.

## Kiểm tra tự động

`integration_test/docx_webview_test.dart` chạy trên Android WebView thật trong emulator:

1. Nhập tài liệu qua màn hình thư viện, mở editor, quay lại và tải lại danh sách.
2. Nhập tiếng Việt, undo/redo, chọn chữ và dùng nút ribbon để định dạng nghiêng/gạch chân, căn giữa và chọn 18 pt.
3. Sửa nội dung ô bảng có sẵn, thêm đoạn và chèn bảng 2×2 bằng menu của editor.
4. Đọc ZIP/XML của DOCX đã lưu để xác nhận nội dung, `w:i`, `w:u`, `w:jc`, `w:sz=36`, số bảng và giữ custom XML.
5. Mở lại file xuất, kiểm tra định dạng và nội dung bảng còn nguyên; bản nhập gốc không thay đổi.

Các thao tác chọn chữ/nhập văn bản và bấm ribbon trong test được thực hiện qua DOM. Đây không phải kiểm thử bàn phím tiếng Việt, kéo chọn chữ hay thao tác cảm ứng bằng tay. Test có kiểm tra kích thước vùng bấm trên WebView.

## Kiểm tra bộ tài liệu riêng

`integration_test/factory_docx_test.dart` nhận tài liệu từ một server localhost qua `adb reverse`; không đưa tài liệu nhà máy vào source, assets hoặc Git. Khi không có biến cấu hình, test này được bỏ qua.

Trên Windows, mở terminal thứ nhất tại gốc dự án:

```powershell
node tool/serve_docx_corpus.mjs --source-dir "C:\duong-dan\tai-lieu" --results-dir "C:\duong-dan\ket-qua-qa"
```

Trong terminal thứ hai:

```powershell
adb -s emulator-5554 reverse tcp:8943 tcp:8943
flutter test integration_test/factory_docx_test.dart -d emulator-5554 --dart-define=GENOFFICE_TEST_CORPUS_URL=http://127.0.0.1:8943
```

Mỗi tài liệu được mở, lưu nguyên trạng và so sánh từng phần ZIP với nguồn. Sau đó test thêm một dấu kiểm thử vào đoạn văn, lưu/mở lại và xác nhận các phần OOXML ngoài `word/document.xml` không đổi. Riêng `docProps/core.xml` cho phép thay đổi thời điểm lưu và số revision theo hành vi lưu tài liệu; các metadata khác vẫn được so sánh. File nguồn được giữ nguyên. Bản kết quả dùng tên số thứ tự; `manifest.json` ánh xạ sang tên nguồn và SHA-256. Chỉ server kiểm thử đọc nguồn; mọi chỉnh sửa diễn ra trên bản sao trong app.

Sau khi xong, dừng server bằng Ctrl+C và chạy `adb -s emulator-5554 reverse --remove tcp:8943`.

## Nghiệm thu còn lại

Kết quả ngày 21/10/2026: 12 unit/widget test đạt; 4 test engine DOCX đạt; 2 integration test Android đạt (bao gồm định dạng và bảng, 50 giây). Bộ 6 tài liệu trong Downloads cũng đạt trên `emulator-5554` (80 giây): 5 tài liệu có bảng và ảnh, 1 tài liệu văn bản đơn giản. SHA-256 xác nhận cả 6 file nguồn không đổi. Tài liệu riêng và bản xuất QA không được commit vào Git.

Browser e2e độc lập chưa chạy được trong sandbox Windows vì trình duyệt không kết nối được với runner; không ghi nhận chúng là đạt trong lần này. Các kiểm tra định dạng, bảng và OOXML nêu trên đã chạy trong Android WebView.

- Dùng điện thoại thật, bàn phím tiếng Việt và thao tác chọn chữ bằng cảm ứng; kiểm tra định dạng trước/sau khi cuộn hoặc đổi tab.
- Mở kết quả bằng Microsoft Word, đối chiếu font, căn đoạn, bảng, ảnh, header/footer và phân trang với tài liệu gốc.
- Thử sửa ô bảng, thêm/xóa hàng/cột, đổi định dạng ở các vị trí trong tài liệu thực tế.

Bước 4 chỉ được đánh dấu hoàn tất sau khi nghiệm thu các mục còn lại. So sánh OOXML không xác nhận bố cục hiển thị giống Word từng pixel.
