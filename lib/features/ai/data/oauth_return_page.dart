/// Static content only: never include OAuth query parameters in browser HTML.
String oauthReturnPage({required bool success, required String nonce}) =>
    '''<!doctype html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>VPIC1 Office</title>
<style nonce="$nonce">
*{box-sizing:border-box}body{margin:0;min-height:100dvh;display:grid;place-items:center;padding:24px;background:#f3faf7;color:#203832;font:16px/1.6 system-ui,sans-serif}.card{width:min(100%,440px);padding:36px 28px;background:white;border:1px solid #e0ece7;border-radius:28px;box-shadow:0 20px 60px #173e2612;text-align:center}.brand{font-weight:700;letter-spacing:.08em;font-size:13px;color:#bc1423}.badge{margin:24px auto;width:64px;height:64px;display:grid;place-items:center;border-radius:50%;background:#e6f6ed;color:#167349;font-size:32px}h1{font-size:24px;line-height:1.3}p{color:#597067}a{display:block;margin-top:24px;padding:14px 16px;background:#087e69;border-radius:14px;color:white;text-decoration:none;font-weight:600}[hidden]{display:none}small{color:#768b82}</style></head>
<body><main class="card"><div class="brand">VPIC1 OFFICE</div><div class="badge">${success ? '✓' : '!'}</div><h1>${success ? 'Đã kết nối ChatGPT' : 'Chưa hoàn tất đăng nhập'}</h1><p>${success ? 'Tài khoản của bạn đã được xác thực. Đang quay lại tài liệu…' : 'Phiên đăng nhập bị hủy hoặc không hợp lệ. Quay lại ứng dụng để thử lại.'}</p>
<p id="status">${success ? 'Đang chuyển về ứng dụng · 5 giây' : 'Bạn có thể đóng trang này.'}</p>
<a id="back" href="vpic1office://chatgpt-return" ${success ? 'hidden' : ''}>Quay lại VPIC1 Office</a><small>Tài khoản AI cá nhân của bạn</small></main>
${success ? '<script nonce="$nonce">let left=5; const timer=setInterval(()=>{left--;document.getElementById("status").textContent=left>0?"Đang chuyển về ứng dụng · "+left+" giây":"Nếu ứng dụng chưa mở, hãy bấm nút bên dưới.";if(left<=0){clearInterval(timer);document.getElementById("back").hidden=false;}},1000);setTimeout(()=>{window.location.href="vpic1office://chatgpt-return";},250);</script>' : ''}
</body></html>''';
