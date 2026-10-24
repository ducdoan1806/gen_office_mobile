# AI sửa tài liệu trên Android

Triển khai 24/10/2026 cho ChatGPT cá nhân. Mở AI từ tài liệu rồi nhập yêu cầu và bấm Gửi; mặc định câu hỏi nói về file đang mở. Không còn công tắc Sửa tài liệu. Mỗi lượt gửi lấy lại nội dung hiện tại, kể cả thay đổi chưa lưu, và gửi đến tài khoản ChatGPT đang chọn. Hỏi/tóm tắt chỉ trả lời, chỉ khi người dùng yêu cầu sửa mới tạo đề xuất. Phản hồi chỉ tạo đề xuất. Bấm **Xem trước thay đổi** để xem từng mục Trước/Sau, rồi **Áp dụng** nếu phù hợp. Trở về editor, dùng **Hoàn tác** nếu cần; **Lưu** ghi vào chính nguồn SAF đang mở theo pipeline hiện có. Không tự lưu khi nhận đề xuất.

## Phạm vi

| Editor | Nội dung gửi và sửa |
| --- | --- |
| Word/DOCX | Văn bản được chọn; nếu con trỏ không chọn chữ thì văn bản thân tài liệu đã tải. Chỉnh từng text run, giữ marks và phần cấu trúc không sửa. |
| Excel/XLSX | Nếu chọn nhiều ô: vùng đang chọn; nếu chỉ đặt con trỏ ở một ô: dữ liệu sheet hiện tại (nêu rõ phạm vi), có tải đủ vùng từ lazy loader. Sửa giá trị hoặc công thức. Giới hạn 500 ô; bỏ qua ô rich text cần adapter riêng. Giữ kiểu/style ô, journal và undo/redo của Univer. Chuỗi bắt đầu = là công thức; số thuần chuyển thành số, còn lại giữ chuỗi. |
| PowerPoint/PPTX | Văn bản các shape/text box cấp trên của bài trình chiếu, kèm số slide hiện tại. Áp dụng một batch giao dịch; giữ paragraph/run không sửa. Chưa sửa bảng, group, ghi chú và ảnh. |
| PDF | Tự trích chữ tất cả trang để hỏi/tóm tắt, tối đa 500 trang/60.000 ký tự; PDF scan không có chữ báo chưa OCR. Chưa sửa PDF. |

Đây là chỉnh nội dung có cấu trúc giới hạn, chưa phải agent thiết kế toàn bộ tài liệu: không tạo/xóa slide, đổi bố cục, thêm bảng/ảnh, hoặc tùy ý thực thi mã do AI sinh. Định dạng cũ và CSV tiếp tục dùng bộ chuyển đổi/lưu hiện có; bộ kiểm thử AI hiện tập trung DOCX/XLSX/PPTX.

## Kiểm tra trước khi áp dụng

- Ngữ cảnh có token riêng và danh sách id/văn bản chính xác, tối đa 500 mục và 60.000 ký tự JSON. Không âm thầm cắt ngữ cảnh; vùng quá lớn yêu cầu chọn nhỏ lại.
- Phản hồi phải là JSON summary/changes, chỉ dùng id đã gửi và before khớp nguyên văn. Chặn trùng id, null character, payload lớn, kết quả dở hoặc JSON không hợp lệ. Chỉ chuyển after thành nội dung, không evaluate HTML/JavaScript/model code.
- Editor kiểm tra lại token, fingerprint nội dung và before ở lần Áp dụng; đổi/mở lại tài liệu hoặc thay đổi phạm vi ngữ cảnh làm hết hạn đề xuất trước. Hỏi tiếp với nội dung/phạm vi không đổi giữ hiệu lực bản xem trước. Không tự tìm gần đúng và sửa nhầm vị trí.
- Word áp dụng một transaction, cô lập nhóm lịch sử để Hoàn tác không gộp vào lần gõ trước. Sheets chạy lệnh set-range-values một lần với tọa độ tuyệt đối và journal của app; Slides dùng transaction của pptx-ops và undo stack hiện có.
- Áp dụng chỉ làm thay đổi bản đang mở. Pipeline checkpoint, lưu nguồn và kiểm tra xung đột file nguồn vẫn xử lý như sửa thủ công. File nguồn chỉ thay đổi khi Lưu thành công.

## Kiểm thử

- Unit/widget Flutter: từ chối id/nội dung giả, JSON sai và thay đổi lặp; chờ stream hoàn tất mới có đề xuất; chỉ gọi apply khi người dùng chọn; lỗi bàn phím 300 px, ô nhập nhiều dòng và màn hình 360×640/360×480.
- Vitest: guard từ chối fingerprint khác, id lạ, trùng id, before sai và ngữ cảnh quá lớn.
- Playwright production: DOCX/XLSX/PPTX sửa → Hoàn tác → Làm lại → chặn đề xuất xung đột → Lưu → mở lại có nội dung mới; so sánh byte các phần ZIP không chỉnh sửa. Hồi quy ribbon/chọn ô/PDF tiếp tục chạy.
- Callback dùng HTML thật có CSP: thành công đợi đủ 5 giây mới hiện fallback, lỗi có đường quay lại; ảnh chụp mobile được kiểm tra.
- Kết quả máy thật và phần chưa nghiệm thu được cập nhật trong [progress.md](progress.md). Không dùng tài liệu công ty trong kiểm thử gọi AI thật.

## Ngữ cảnh mặc định theo file đang mở

- Mỗi lượt hỏi lấy snapshot mới. Lịch sử giữ câu hỏi/câu trả lời, không lặp lại toàn bộ snapshot cũ trong mỗi request; snapshot mới nhất là căn cứ hiện tại.
- Có tên file/phạm vi trong ngữ cảnh; giao diện ghi AI đang làm việc với tài liệu này. Đính kèm vẫn dùng để bổ sung nội dung ngoài file, không bắt buộc.
- JSON trả về dùng summary cho câu trả lời bình thường và changes rỗng. Chỉ yêu cầu sửa rõ ràng mới có đề xuất/Áp dụng; PDF chỉ đọc và đề xuất sửa từ phản hồi sai bị chặn.
- Nếu không lấy được nội dung hoặc vượt giới hạn, báo lỗi và giữ câu hỏi; không âm thầm gửi yêu cầu thiếu tài liệu hay suy đoán phần chưa đọc.
- Word trích thân/vùng chọn; Excel trích sheet hiện tại hoặc vùng chọn, chưa gửi toàn bộ mọi sheet; PowerPoint còn giới hạn loại phần tử như bảng trên. Các giới hạn này được ghi rõ thay vì nói đã hiểu toàn bộ nội dung không được cung cấp.
