# Sheets và Slides trên Android

Source: https://github.com/genspark-ai/genoffice — commit `1cb2925afe173b266c1545a3871a397429e11b7e`, cùng phiên bản với phần DOCX đã tách trước đó.

## Module được tái sử dụng

- XLSX: `xlsx-gateway` đọc/ghi OOXML; `create-univer.ts` của Sheets và giao diện lưới/thanh công thức Univer.
- PPTX: `pptx-engine`, `pptx-ops` kiểm tra và áp dụng transaction, `pptx-render`, các thành phần `SlideCanvas`/Konva của Slides.
- Không chạy Electron hoặc Rust sidecar desktop. Adapter trình duyệt cung cấp Buffer, SHA-256 và zlib; gọi filesystem trực tiếp sẽ báo lỗi. Lưu file đi qua bridge Flutter và SAF Android.

## Các luồng đã có

Một nút **Mở tài liệu** nhận DOC/DOCX/PDF/XLSX/PPTX. XLSX sửa ô và công thức; PPTX hiển thị canvas gốc và sửa văn bản đoạn. Có undo/redo, Lưu ghi đè URI nguồn, Lưu thành bản mới, bản tạm phục hồi và mở lại đúng định dạng. File XLSX/PPTX không bị đổi thành DOCX. Mở rồi lưu khi chưa sửa giữ nguyên byte gốc.

Bản Android dùng giao diện bao ngoài cho mobile. Chưa đưa đầy đủ ribbon, sửa cấu trúc/định dạng/biểu đồ của Sheets, các công cụ nâng cao Slides hoặc Rust streaming sidecar sang Android. Bố cục hiển thị và tính năng Excel/PowerPoint chưa hỗ trợ cần nghiệm thu với tài liệu thực tế; không coi đây là bản desktop đầy đủ. AI và iOS tiếp tục tạm hoãn.

## Kiểm thử

22/10/2026: đạt 43 test Flutter, 9 test web/engine và 2 ca integration trên Samsung SM-A075F/Android 16/ARM64. Hai ca integration kiểm tra mở từ thư viện, sửa qua editor/runtime thật, undo/redo, tạo bản phục hồi, lưu và mở lại; provider nguồn được mô phỏng để đối chiếu byte. Các phần ZIP biểu đồ/ảnh/ghi chú không sửa được giữ nguyên. SAF native cho cả XLSX/PPTX đã đạt chọn/ghi file thật và kiểm tra quyền persisted qua hai tiến trình (4 phase); xem [QA Android](android-device-qa.md).

Các test tự động không thay thế nghiệm thu bàn phím tiếng Việt, kéo chọn chữ và cảm ứng bằng tay.

## Nguồn và giấy phép

Source vendored giữ giấy phép Apache-2.0 và NOTICE tại `editor_web/vendor`. Hai import của Slides được đổi đường dẫn từ cấu trúc monorepo sang vendor; tsconfig gateway/ops được điều chỉnh cho bundle trình duyệt. Các file có thay đổi đã được ghi chú. `assets/editor/THIRD-PARTY-LICENSES.txt` được tạo lại từ dependency đã cài khi đóng gói asset.
