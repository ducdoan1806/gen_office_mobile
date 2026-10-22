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

## DOCX lớn: app thường đạt, bài integration cần điều tra

Tạo fixture riêng 10.854.066 byte (~10,9 MB): một ảnh PNG 2000×1800 chứa dữ liệu ngẫu nhiên, 500 đoạn tiếng Việt và một bảng 3×3. Không thêm fixture hoặc bản xuất QA vào Git.

Trong bài integration corpus, file mở được nhưng lần lưu đầu không hoàn tất trong khoảng theo dõi trên 2 phút; host chủ động force-stop để chạy các ca còn lại. Đã lặp lại sau khi đổi so sánh byte lớn sang SHA-256 và thêm log từng chặng; log dừng sau `CORPUS OPEN` và trước `CORPUS UNCHANGED SAVE`. Không ghi nhận bài integration này là đạt; chưa xác định chính xác chặng gây chờ trong test harness.

Đã kiểm tra riêng trên bản app thường, thao tác bằng ADB qua UI Android: chọn bản QA trong Download, mở file, bấm Lưu; sau chưa tới 8 giây đã thấy thông báo lưu vào file gốc. Kéo file kết quả về đối chiếu SHA-256 từng phần ZIP: cả 18 phần giữ nguyên. Sau đó chạm đoạn văn, nhập marker ASCII qua Android input, bấm Lưu và mở lại từ thư viện: marker xuất hiện; XML chứa marker và chỉ `word/document.xml`/`docProps/core.xml` thay đổi, ảnh/bảng và các phần khác giữ nguyên. File QA là bản sao riêng, không phải tài liệu của người dùng.

Kết luận: mở/sửa/lưu nguồn/mở lại file 10,9 MB trên app thường đạt trong ca đã thử. Không còn kết luận lỗi lưu app từ lần integration bị dừng. Chưa coi đây là benchmark hay bảo đảm mọi file dưới 20 MB đều đạt; bài integration file lớn cần điều tra riêng.

## Các phần còn lại

- Bàn phím tiếng Việt thật, kéo chọn chữ, cảm ứng, cuộn và pinch zoom bằng tay.
- Nghiệm thu bố cục với Microsoft Word và bộ tài liệu nhà máy đầy đủ.
- Hoàn thiện bài integration file lớn, benchmark/stress bộ nhớ, LMK, chuyển nền dài, thiết bị khác và Android phiên bản thấp hơn.
- Không đánh dấu hoàn tất bước 2, 4 hoặc 8 chỉ từ những bài tự động này.

## Trạng thái bàn giao

Đã khôi phục kết nối ban đầu (Wi-Fi tắt, dữ liệu di động bật), đóng server QA và gỡ adb reverse riêng. App thường đã cài trên điện thoại. Giữ hai mẫu riêng trong Download: GenOffice_DOC_phone_test_20261022.doc và GenOffice_large_QA_20261022.docx (có marker kiểm thử); chỉ mẫu lớn xuất hiện trong thư viện app do đã mở trực tiếp.
