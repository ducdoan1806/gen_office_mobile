# ChatGPT cá nhân trên Android

Bổ sung 24/10/2026. Chỉ tích hợp ChatGPT trong đợt này; AI nội bộ tiếp tục giữ interface/mock chưa kết nối. Claude/Gemini/Copilot chưa triển khai.

## Trải nghiệm

- Trong editor Word/Excel/PowerPoint: nút Trợ lý AI ở thanh dưới. PDF: nút AI nổi.
- Bảng modal gần toàn màn hình, đóng bằng kéo xuống/nút Thu gọn/Back; editor không được tải lại. Phiên chat và bản nháp giữ trong bộ nhớ của editor, tiếp tục nhận phản hồi khi thu bảng. Đóng editor/kết thúc process chưa lưu lịch sử chat vào đĩa.
- Continue with ChatGPT mở trình duyệt hệ thống. Đăng nhập/cấp quyền trên tên miền OpenAI rồi quay về VPIC1 Office. Không lấy phiên đăng nhập từ app ChatGPT hoặc WebView; không thu mật khẩu hay yêu cầu API key.
- Tải model theo quyền tài khoản. Lựa chọn model lưu làm mặc định, các cuộc trò chuyện đã mở giữ model riêng; không đổi theo mạng.
- Chế độ chat gửi câu hỏi/nội dung Đính kèm. Mặc định gửi ngữ cảnh file đang mở mỗi lượt hỏi, không cần bật chế độ; hỏi thì trả lời, yêu cầu sửa mới có đề xuất Trước/Sau; chỉ bấm Áp dụng mới thay nội dung và dùng Lưu để ghi file gốc. Phạm vi hỗ trợ ở [AI chỉnh sửa tài liệu](ai-document-editing.md). PDF vẫn chỉ đọc.
- Có Dừng, Cuộc trò chuyện mới, tải lại model, kết nối lại/ngắt kết nối. Hạn mức/quyền ứng dụng do tài khoản ChatGPT quyết định; không tự chuyển nhà cung cấp.

## Luồng chính thức và giới hạn nghiệm thu

Dùng SIWC public client, đăng ký động cho ứng dụng chạy cục bộ với tên thật VPIC1 Office, host ID ổn định; không giả danh Codex hay ứng dụng khác. OpenAI hiện giới hạn phạm vi triển khai/loại tài khoản; chưa coi đây là xác nhận mọi tài khoản hoặc triển khai doanh nghiệp đều được chấp thuận. Cần nghiệm thu tài khoản thật trước phân phối.

- OAuth PKCE S256, state/nonce ngẫu nhiên, callback chỉ bind 127.0.0.1, timeout/hủy đăng nhập.
- ID token phải qua chữ ký RSA/JWKS từ discovery OpenAI, issuer/audience/expiration/nonce và quyền plan usage; mã lỗi không chứa token hoặc nội dung raw từ server.
- Token/host/model được mã hóa AES-GCM, khóa Android Keystore; loại preferences xác thực khỏi cloud backup/device transfer. Refresh có xử lý token xoay vòng, không đưa token vào repo/log.
- Responses API công khai: store=false, stream=true, giữ lịch sử cần thiết phía client. Không dùng backend-api/cookie web.
- Bộ kiểm thử Dart/Widget dùng API giả và token giả, không truy cập tài khoản hoặc tiêu tốn hạn mức. Kiểm thử đó không thay thế đăng nhập/gọi model thật.
- Bản này tập trung Android; chưa tích hợp đăng nhập iOS.

Nguồn chính thức:
- https://developers.openai.com/siwc/quickstart
- https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations

## Kiểm chứng ban đầu 24/10/2026 (máy ảo)

- 58 test Flutter (gồm 7 ca ChatGPT) đạt; analyze không có vấn đề.
- APK debug x86_64 build/cài đè đạt; bảng AI hiển thị đúng trong editor và nút đăng nhập mở trình duyệt đến auth.openai.com/log-in.
- Chrome emulator ANR trong bước đăng nhập; WebView tài liệu chưa khởi động xong trên cùng emulator. Chưa có kiểm chứng tài khoản thật, model/stream thật, refresh/revoke thực tế hay Android ARM64 trong đợt này.

### Kiểm tra ChatGPT trên Samsung — 24/10/2026 (lần đầu)

- APK debug ARM64 build thành công và cài đè bằng adb install -r trên Samsung SM-A075F/Android 16 sau khi máy cập nhật. Hai mục tài liệu gần đây được giữ nguyên.
- Đã mở/thu gọn/mở lại bảng AI trong DOCX; nút Continue with ChatGPT mở Chrome và tải trang đăng nhập auth.openai.com bình thường.
- Chủ tài khoản đăng nhập được nhưng callback 127.0.0.1 lỗi: Android ghi nhận LOW_MEMORY, dừng tiến trình app lúc Chrome ở foreground. Kết quả sửa và nghiệm thu ở mục dưới.
- Chưa gửi nội dung tài liệu công ty hoặc bấm lưu/sửa file trong lượt kiểm tra này.

## Sửa vòng đời đăng nhập và nghiệm thu Samsung — 24/10/2026

Nguyên nhân được xác nhận bằng ApplicationExitInfo: lúc 09:56:15 Android dừng tiến trình chính vì LOW_MEMORY (importance=400) khi trình duyệt độc lập đang ở trước. Listener loopback sống trong tiến trình app nên không còn nhận được callback.

- Chuyển sang Custom Tabs có session/binding thực, dùng AndroidX Browser 1.9.0 và KeepAlive extra của Chrome. Empty bound service chỉ giữ vòng đời, không cung cấp phương thức hoặc dữ liệu xác thực, không thêm foreground service hay quyền chạy nền. Đã kiểm tra trực tiếp Chrome bind ChatGptKeepAliveService và cùng PID app tồn tại qua đăng nhập.
- MainActivity singleTask và tắt Flutter deep-link routing cho đường quay về; URI vpic1office://chatgpt-return chỉ mở lại app, không mang code/token. OAuth vẫn dùng loopback 127.0.0.1 + PKCE/state/nonce như hợp đồng SIWC.
- Cửa sổ chờ 15 phút, cleanup binding khi kết thúc/hủy; trang callback có nút quay lại app. Ghi marker đăng nhập vào kho mã hóa để nhận biết phiên bị process death; khi mở lại báo thử lại, không khôi phục code/state không còn hợp lệ.
- 59 test Flutter (8 ca ChatGPT), analyze và APK debug ARM64 đạt. Bài mới kiểm tra nhận biết process death/giữ host ID.
- Samsung SM-A075F/Android 16: cài đè giữ nguyên hai mục tài liệu; chủ tài khoản tự đăng nhập/cấp quyền, quay về app thành công, nhận danh sách model và chọn mặc định GPT-6.1-Sol.
- Gọi AI thật với câu hỏi mẫu không có tài liệu: nhận chính xác Hello VPIC1. Bản nháp/hội thoại/model được giữ khi thu gọn/mở lại; yêu cầu đếm 1–150 hoàn tất trong lúc bảng đóng, mở lại nhận đủ đến 150.
- Force-stop rồi mở app: khôi phục tài khoản và model GPT-6.1-Sol mà không đăng nhập lại. Lịch sử chat chỉ ở bộ nhớ nên không giữ qua process restart, đúng phạm vi hiện tại.
- DOCX trên máy thật tải xong, trạng thái Lưu sẽ cập nhật file gốc; không bấm lưu, không thay nội dung nguồn và không gửi tài liệu công ty lên AI.
- Chưa nghiệm thu refresh token khi hết hạn thực tế, revoke, quá hạn 15 phút hoặc lỗi mạng giữa đăng nhập. KeepAlive giảm rủi ro bị thu hồi bộ nhớ; không bảo đảm sống qua force-stop hoặc lỗi hệ thống.

Tham chiếu:
- https://developer.chrome.com/docs/android/custom-tabs/guide-warmup-prefetch
- https://chromium.googlesource.com/custom-tabs-client/+/master/README.md
## Bổ sung giao diện callback, bàn phím và AI sửa tài liệu — 24/10/2026

- Callback dùng trang HTML/CSS phù hợp VPIC1 Office; thành công chỉ sau khi danh tính/quyền/token đã xác thực và lưu. Tự thử quay về app; 5 giây sau mới hiện nút thủ công. Trang lỗi không tự báo thành công. CSS/JS có nonce, CSP giữ default-src none; không đưa OAuth code, state hoặc token vào HTML.
- Bảng AI trừ chiều cao bàn phím và thích ứng màn hình thấp; lời chào có thể cuộn, giữ ô nhập/nút gửi/dừng; thông báo lỗi dài có vùng cuộn giới hạn. Widget test bàn phím/nhiều dòng/màn hình nhỏ đạt.
- Chế độ Sửa tài liệu gửi ngữ cảnh trực tiếp từ editor khi bấm Gửi. Model trả JSON đề xuất; người dùng xem Trước/Sau rồi Áp dụng. Chỉ nút Lưu tài liệu mới ghi file nguồn. Hoàn tác dùng lịch sử editor.
- Phạm vi sửa văn bản/ô và kết quả kiểm thử ở [AI chỉnh sửa tài liệu](ai-document-editing.md); PDF vẫn chỉ đọc. Lịch sử chat còn chỉ ở bộ nhớ, giới hạn 120.000 ký tự tính cả ngữ cảnh và đề xuất.

### Nghiệm thu bổ sung Samsung với chế độ sửa

- APK debug ARM64 cài đè; giữ nguyên tài liệu, bản khôi phục chưa lưu và tài khoản/model cá nhân. Đã sửa hiện tượng mất focus khi bố cục thay đổi theo bàn phím bằng key ổn định cho composer.
- Trên Samsung SM-A075F/Android 16, GPT-6.1-Sol thật: gửi yêu cầu sửa DOCX mẫu riêng `VPIC1-AI-QA.docx` trong Downloads, xem Trước/Sau, Áp dụng, Hoàn tác/Làm lại và Lưu vào chính nguồn SAF. Trước Lưu, SHA-256 file vẫn giống ban đầu. Sau Lưu, XML có câu mới và các phần ZIP khác nguyên byte. Không gửi tài liệu công ty.
- 63 test Flutter (12 ca ChatGPT), 10 Vitest và 16 Playwright production đạt; analyze sạch. Callback mobile/CSP/countdown được kiểm thử trình duyệt; chưa nghiệm thu lại đăng nhập thật với trang mới trên Samsung. Sửa Excel/PPTX và định dạng cũ chưa gọi AI thật trên máy trong lượt này.

### Điều chỉnh mặc định ngữ cảnh tài liệu — 24/10/2026

Mở AI từ file được hiểu là đang hỏi về file đó. Đã bỏ công tắc Sửa tài liệu, lấy snapshot mới mỗi lượt hỏi, phân biệt trả lời và đề xuất thay đổi bằng hợp đồng summary/changes. Đính kèm là phần bổ sung; nếu không đọc được file thì báo lỗi, không âm thầm hỏi AI thiếu ngữ cảnh. PDF trích chữ các trang và giữ chỉ đọc; Excel mặc định dữ liệu sheet hiện tại, vùng nhiều ô được chọn sẽ ưu tiên phạm vi đó; PowerPoint trích văn bản bài trình chiếu. Giới hạn chi tiết ở ai-document-editing.md.

- Kiểm chứng đợt ngữ cảnh mặc định: 66 Flutter (15 ca ChatGPT), 10 Vitest, 16 Playwright production; ca hỏi tiếp giữ revision chạy lại trên 3 editor đạt; analyze sạch. PDF fixture trích chữ đủ 3 trang, Excel mặc định có nhiều ô ngữ cảnh.
- APK debug ARM64 cài đè Samsung. ChatGPT thật trả đúng câu trong DOCX mẫu khi hỏi nội dung mà không bật công tắc/đính kèm, không tạo changes. Yêu cầu đổi chữ tiếp theo tự tạo đề xuất Trước/Sau. Không áp dụng hay lưu đề xuất thử này; chưa thử gọi AI thật với PDF/Excel/PowerPoint trong đợt điều chỉnh.
