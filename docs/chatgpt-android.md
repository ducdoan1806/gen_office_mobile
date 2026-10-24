# ChatGPT cá nhân trên Android

Bổ sung 24/10/2026. Chỉ tích hợp ChatGPT trong đợt này; AI nội bộ tiếp tục giữ interface/mock chưa kết nối. Claude/Gemini/Copilot chưa triển khai.

## Trải nghiệm

- Trong editor Word/Excel/PowerPoint: nút Trợ lý AI ở thanh dưới. PDF: nút AI nổi.
- Bảng modal gần toàn màn hình, đóng bằng kéo xuống/nút Thu gọn/Back; editor không được tải lại. Phiên chat và bản nháp giữ trong bộ nhớ của editor, tiếp tục nhận phản hồi khi thu bảng. Đóng editor/kết thúc process chưa lưu lịch sử chat vào đĩa.
- Continue with ChatGPT mở trình duyệt hệ thống. Đăng nhập/cấp quyền trên tên miền OpenAI rồi quay về VPIC1 Office. Không lấy phiên đăng nhập từ app ChatGPT hoặc WebView; không thu mật khẩu hay yêu cầu API key.
- Tải model theo quyền tài khoản. Lựa chọn model lưu làm mặc định, các cuộc trò chuyện đã mở giữ model riêng; không đổi theo mạng.
- Gửi câu hỏi và nội dung người dùng chủ động dán ở mục Đính kèm. Không tự tải toàn file hoặc trích vùng chọn từ canvas. Kết quả chỉ đọc/sao chép; chưa có áp dụng sửa file tự động.
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

## Kiểm chứng 24/10/2026

- 58 test Flutter (gồm 7 ca ChatGPT) đạt; analyze không có vấn đề.
- APK debug x86_64 build/cài đè đạt; bảng AI hiển thị đúng trong editor và nút đăng nhập mở trình duyệt đến auth.openai.com/log-in.
- Chrome emulator ANR trong bước đăng nhập; WebView tài liệu chưa khởi động xong trên cùng emulator. Chưa có kiểm chứng tài khoản thật, model/stream thật, refresh/revoke thực tế hay Android ARM64 trong đợt này.
