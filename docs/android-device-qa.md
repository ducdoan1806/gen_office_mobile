# Kiểm thử điện thoại Android ngày 22/10/2026

Thiết bị: Samsung SM-A075F, Android 16, ARM64. Chạy bản debug trên máy thật qua USB. Không gỡ app hoặc xóa dữ liệu app; các bài test dùng kho/fixture riêng. Đợt này mở lại phần kiểm thử Android thật theo yêu cầu chủ dự án; iOS, AI, share sheet và đối chiếu Word vẫn hoãn.

## Kết quả đã xác nhận

- DOC offline: tắt Wi-Fi và dữ liệu di động, mở DOC nhị phân từ nút chung, sửa tiếng Việt, lưu DOC và mở lại. Converter LibreOfficeKit ARM64 thật; provider nguồn trong bài Flutter là fixture mô phỏng. Đã khôi phục trạng thái kết nối ban đầu.
- 4 bài DOCX WebView đạt: mở/sửa/định dạng/bảng/undo-redo/lưu/mở lại, chuyển tài liệu, Save As riêng và xử lý bản tạm hỏng. Nhập và chọn chữ qua DOM, không thay thế nghiệm thu bàn phím/cảm ứng.
- 3 bài PDF đạt: mở PDF từ editor bằng nút chung, render/tìm kiếm/điều hướng trang, giữ nguồn không đổi và báo lỗi PDF hỏng.
- Khôi phục phiên qua hai tiến trình đạt: tạo checkpoint, host force-stop, chạy mới, khôi phục; nguồn bị sửa bên ngoài, hủy xác nhận ghi đè, lỗi ghi giữ bản tạm, Lưu thành công dọn bản tạm. Provider nguồn mô phỏng bằng file fixture riêng. Không phải thử LMK hoặc crash native ngẫu nhiên.
- 5 DOCX mẫu có bảng/ảnh trong Downloads đạt mở/sửa/lưu/mở lại và bảo toàn các phần OOXML không chỉnh sửa. SHA-256 của cả 6 DOCX nguồn trong Downloads không đổi. File `test.docx` cuối danh sách corpus chưa chạy trong lượt này do tách ca lớn phía trước.
- Native ARM64 DOCX ↔ DOC giữ tiếng Việt/bảng đạt. SAF thật: DOCX lưu đè và thu hồi quyền đạt; PDF giữ quyền chỉ đọc, chặn ghi và thu hồi quyền đạt.
- DOC nguồn thật: chọn file DOC riêng trong Download, ghi DOC nhị phân bằng handler sản phẩm, force-stop rồi instrumentation mới đọc/ghi lại bằng quyền đã lưu đạt. Hai pha prepare/verify dùng file UUID và tự dọn fixture/quyền riêng.
- Analyze không có lỗi. Sửa selector của các test native để nhận cả Search/Tìm kiếm, Show roots/Hiển thị gốc, Downloads/Download/Tải xuống; chờ kết quả tìm kiếm trên Samsung tải xong. Đây là sửa bộ test, không phải lỗi chọn file của app.

## Lần kiểm tra DOCX lớn trước khi sửa bridge

Tạo fixture riêng 10.854.066 byte (~10,9 MB): một ảnh PNG 2000×1800 chứa dữ liệu ngẫu nhiên, 500 đoạn tiếng Việt và một bảng 3×3. Không thêm fixture hoặc bản xuất QA vào Git.

Trong bài integration corpus, file mở được nhưng lần lưu đầu không hoàn tất trong khoảng theo dõi trên 2 phút; host chủ động force-stop để chạy các ca còn lại. Đã lặp lại sau khi đổi so sánh byte lớn sang SHA-256 và thêm log từng chặng; log dừng sau `CORPUS OPEN` và trước `CORPUS UNCHANGED SAVE`. Không ghi nhận bài integration này là đạt; chưa xác định chính xác chặng gây chờ trong test harness.

Đã kiểm tra riêng trên bản app thường, thao tác bằng ADB qua UI Android: chọn bản QA trong Download, mở file, bấm Lưu; sau chưa tới 8 giây đã thấy thông báo lưu vào file gốc. Kéo file kết quả về đối chiếu SHA-256 từng phần ZIP: cả 18 phần giữ nguyên. Sau đó chạm đoạn văn, nhập marker ASCII qua Android input, bấm Lưu và mở lại từ thư viện: marker xuất hiện; XML chứa marker và chỉ `word/document.xml`/`docProps/core.xml` thay đổi, ảnh/bảng và các phần khác giữ nguyên. File QA là bản sao riêng, không phải tài liệu của người dùng.

Kết luận: mở/sửa/lưu nguồn/mở lại file 10,9 MB trên app thường đạt trong ca đã thử. Không còn kết luận lỗi lưu app từ lần integration bị dừng. Chưa coi đây là benchmark hay bảo đảm mọi file dưới 20 MB đều đạt; bài integration file lớn cần điều tra riêng.

## Các phần còn lại

- Bàn phím tiếng Việt thật, kéo chọn chữ, cảm ứng, cuộn và pinch zoom bằng tay.
- Nghiệm thu bố cục với Microsoft Word và bộ tài liệu nhà máy đầy đủ.
- Benchmark/stress bộ nhớ, LMK, chuyển nền dài, thiết bị khác và Android phiên bản thấp hơn. Bài integration file lớn đã đạt ở lần cập nhật bên dưới.
- Không đánh dấu hoàn tất bước 2, 4 hoặc 8 chỉ từ những bài tự động này.

## Trạng thái bàn giao

Đã khôi phục kết nối ban đầu (Wi-Fi tắt, dữ liệu di động bật), đóng server QA và gỡ adb reverse riêng. App thường đã cài trên điện thoại. Giữ hai mẫu riêng trong Download: GenOffice_DOC_phone_test_20261022.doc và GenOffice_large_QA_20261022.docx (có marker kiểm thử); chỉ mẫu lớn xuất hiện trong thư viện app do đã mở trực tiếp.

## Cập nhật bước 8–9: source GenOffice Sheets/Slides và sửa bridge

22/10/2026, cùng Samsung SM-A075F/Android 16/ARM64:

- 43 unit/widget test Flutter và 9 test web/engine đạt; Dart analyze không có lỗi.
- Hai integration XLSX/PPTX đạt: mở, sửa, undo/redo, tạo bản phục hồi, lưu nguồn qua provider mô phỏng và mở lại. Đối chiếu phần ZIP giữ nguyên biểu đồ/ảnh/ghi chú không sửa.
- Chạy lại 4 ca DOCX và 3 ca PDF: đạt.
- Corpus 7 file (6 DOCX người dùng đã cung cấp ở dạng bản sao kiểm thử và một fixture 10.854.066 byte) đã đạt toàn bộ mở → lưu nguyên trạng → sửa tiếng Việt → lưu → mở lại. Từng phần ZIP được so sánh SHA-256; metadata thời gian/revision được chuẩn hóa; bản nguồn không bị ghi.

Nguyên nhân bài corpus lớn từng bị chờ: lệnh Lưu có thể tới đúng khoảng React tạm tháo bộ nhận lệnh khi đổi tài liệu. Mobile host nay xếp hàng lệnh trong khoảng này và chuyển tiếp khi renderer phát tín hiệu sẵn sàng. Có test riêng cho việc ngắt/nối lại bộ nhận lệnh. Bộ test corpus cũng được chỉnh để chỉ bơm khung hình quanh thao tác WebView, không chạy assertion đồng thời với pump. Lần chạy cuối hoàn tất corpus trong khoảng 38 giây, không tính build/cài APK; đây không phải benchmark.

Một ảnh chụp meminfo trong lần điều tra file lớn ghi nhận PSS tiến trình chính 543.020 KiB ở bản debug. Con số này không bao gồm đầy đủ mọi tiến trình WebView và không xác nhận stress/LMK hay cấu hình máy thấp hơn. Các mục nghiệm thu thủ công/bộ nhớ/chuyển nền dài vẫn chưa đánh dấu hoàn tất.

### SAF XLSX/PPTX qua hai tiến trình

Cả hai định dạng đạt hai phase instrumentation riêng: prepare chọn fixture riêng bằng trình chọn Android thật, kiểm tra byte đọc và ghi đè; host force-stop ứng dụng; verify ở tiến trình mới kiểm tra grant persisted đọc/ghi, đọc lại byte đã sửa và ghi lại cùng URI. Mỗi phase báo OK (1 test), tổng 4 phase đạt. Các fixture UUID và grant của riêng bài test được xóa/thu hồi sau kiểm tra; không gỡ app hoặc xóa dữ liệu ứng dụng.

Đã build APK debug thường với entrypoint lib/main.dart và cài lại bằng install -r. Các file runtime đã stage khớp đủ 343 SHA-256 trong manifest; .gitattributes giữ nguyên byte bundle khi clone trên máy khác. Các kiểm thử này không thay thế nghiệm thu thủ công hay xác nhận iOS.

## Cập nhật giao diện gốc GenOffice — 22/10/2026

PDF, Sheets và Slides hiện dùng nguyên App/ribbon/CSS của commit upstream đã ghim, thay cho màn hình rút gọn. Đã chạy 43 unit/widget test Flutter, 8 test web/engine, 3 bài Playwright production và Dart analyze: đạt. Đã kiểm tra bố cục 390×800 và vuốt thanh tab. Manifest 500 tài nguyên runtime được đối chiếu SHA-256 với blob đã stage trong Git.

Hai điều chỉnh phát hiện khi kiểm thử mobile: chỉ báo PDF nhận đúng trang cuối khi các trang được fit nhỏ; PowerPoint chốt overlay văn bản qua callback gốc trước Save/recovery kể cả khi Flutter lấy native focus mà không phát DOM blur. Source renderer có thể giữ cờ chưa lưu sau Undo; bài kiểm thử undo/redo đối chiếu nội dung thực tế.

Kết quả WebView trên Samsung SM-A075F/Android 16/ARM64 sau đổi giao diện: **9 ca riêng biệt đều đạt** — 2 XLSX/PPTX, 3 PDF và 4 DOCX hồi quy. Các ca XLSX/PPTX kiểm tra nội dung undo/redo, tạo bản phục hồi tự động, lưu nguồn qua provider mô phỏng, mở lại và giữ các phần ZIP không sửa. PDF kiểm tra chuyển thumbnail tới trang cuối, tìm cụm chữ, nhiều kết quả/không có kết quả, tô sáng, file hỏng và byte nguồn không đổi. Luồng PowerPoint còn kiểm tra chốt đoạn chữ khi DOM mất focus trước bản phục hồi. Ba ca PDF được chạy riêng sau khi sửa scope biến trong script nhập truy vấn của test harness.

Đã build APK thường từ `lib/main.dart`, xác minh manifest editor trong APK trùng bản hiện tại và không chứa entrypoint integration. Không gỡ app/clear data trong quá trình cài đè.

## XLS/PPT/CSV và cảm ứng Excel — 23/10/2026

51 unit/widget test Flutter, 8 test web/engine, 5 Playwright production và Dart analyze đạt. Playwright dùng sự kiện touch qua Chromium CDP: vuốt dọc/ngang với khóa trục, quán tính, không đổi ô chọn khi cuộn; chạm chọn, giữ kéo chọn vùng và chạm hai lần rồi nhập giá trị. Có kiểm tra công thức mới xuất kèm cached value; các bài UI gốc PDF/Sheets/Slides tiếp tục đạt.

Bộ `integration_test/original_ui_test.dart` đạt 13 ca trên Samsung SM-A075F/Android 16/ARM64: XLSX/PPTX/XLS/PPT/CSV, 3 PDF, 4 DOCX và một DOC binary. Các ca Office kiểm tra mở/sửa, nội dung undo/redo, bản phục hồi, lưu cùng ID/URI và mở lại. XLS/PPT dùng LibreOfficeKit thật để tạo binary fixture và chuyển đổi hai chiều; đối chiếu OLE magic và giá trị/chữ sau khi chuyển lại OOXML. PPT sau LibreOffice có chữ trong shape, test đọc/sửa cả shape có text. CSV có tiếng Việt, dấu chấm phẩy, sửa ô và SUM; Lưu giữ dữ liệu CSV và mở lại được. Các ca này mô phỏng provider đọc/ghi nguồn để cô lập tài liệu kiểm thử; chưa bổ sung instrumentation picker/grant thật riêng cho XLS/PPT/CSV.

Codec CSV còn được kiểm tra UTF-8 BOM, UTF-16 LE/BE, quoting/xuống dòng, mã số 0 đầu, formula-like literal, cache công thức rỗng/mất và từ chối xuất nhiều sheet. Test repository kiểm tra ID/định dạng nguồn, rollback khi lưu lỗi và tên file ngắn hợp lệ. Manifest runtime 501 tài nguyên khớp SHA-256. Không đánh dấu hoàn tất nghiệm thu cảm ứng/bàn phím bằng tay hoặc đối chiếu Microsoft Office; xem [giới hạn và cách dùng](legacy-office-formats.md).
