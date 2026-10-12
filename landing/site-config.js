/* Cấu hình trang giới thiệu + trang trợ giúp (/help/ đọc ../site-config.js) — sửa ở đây khi triển khai (xem landing/README.md) */
window.BOSSKIN = {
  // Trang đăng nhập app web. '' = ẩn nút "Đăng nhập" (khi app chưa lên mạng). 8099 = chạy thử trên máy dev.
  appUrl: location.port === '8099' ? 'http://localhost:3000/login' : 'https://app.bosskin.io.vn/login',
  // File cài cho Android (nút "Tải cho Android" ở mục Cài đặt). '' = nút Android chỉ hướng dẫn thêm lối tắt trình duyệt.
  // File do máy dev build + ký khoá phát hành rồi đưa lên release "app-latest" (landing/README.md).
  apkUrl: 'https://github.com/BK54anktran/bosskin/releases/download/app-latest/bosskin.apk',
  // Nơi nhận form dùng thử (phải có một trong hai), theo thứ tự ưu tiên:
  //  1. apiUrl — backend BossKin (vd 'https://api.ten-mien.vn'), xem ở /admin → Yêu cầu dùng thử;
  //  2. supabaseUrl + supabaseKey — bảng trial_requests trên Supabase.
  apiUrl: '',                 // đang dùng Supabase làm nơi lưu chung (app BossKin đọc từ đó)
  supabaseUrl: 'https://apcppqwwnoyliwlhqtyx.supabase.co',
  supabaseKey: 'sb_publishable_lmZvVB_ao3EZrwiKl4174A_1dCrGFWV',   // khoá công khai: chỉ được THÊM dòng (RLS)
  contactEmail: '',          // email liên hệ (mục dùng thử + chân trang), vd 'lienhe@ten-mien.vn'
  contactPhone: '0865 854 002',   // số điện thoại / Zalo (mục dùng thử + chân trang)
  // Mạng xã hội ở chân trang — để '' thì ẩn biểu tượng đó
  facebookUrl: 'https://www.facebook.com/1353132977886335',   // trang Facebook BossKin (id trang)
  tiktokUrl: 'https://www.tiktok.com/@bosskin_hrm',
  youtubeUrl: 'https://www.youtube.com/channel/UClzGlcmyIlkL85HvTe-bQVg',
};
