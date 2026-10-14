{{flutter_js}}
{{flutter_build_config}}

// Assets (font icon rút gọn, ảnh, bản dịch) trùng tên giữa các bản build → nạp qua đường dẫn riêng mỗi bản
// (v<build_number>/assets/…, nginx bỏ tiền tố) để trình duyệt không dùng file cũ đã lưu. Lỗi đọc version.json → đường dẫn thường.
(async () => {
  let assetBase;
  try {
    const v = await (await fetch('version.json', { cache: 'no-store' })).json();
    if (v && v.build_number) assetBase = 'v' + v.build_number + '/';
  } catch (_) {}
  _flutter.loader.load(assetBase ? { config: { assetBase } } : {});
})();
