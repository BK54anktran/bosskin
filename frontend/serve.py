#!/usr/bin/env python3
"""SPA-aware static server: serves index.html for all unknown paths."""
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

BUILD_DIR = os.path.join(os.path.dirname(__file__), 'build', 'web')

class SPAHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BUILD_DIR, **kwargs)

    def do_GET(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) or os.path.isdir(path) and not os.path.exists(os.path.join(path, 'index.html')):
            self.path = '/index.html'
        super().do_GET()

    # F12 — Flutter web không gắn hash vào tên file (main.dart.js, assets/...),
    # nên mọi file dùng "no-cache": trình duyệt vẫn giữ bản cũ nhưng hỏi lại server
    # (If-Modified-Since → 304) thay vì tải lại toàn bộ mỗi lần như "no-store".
    # Thư mục canvaskit/ và icons/ đổi theo phiên bản Flutter / hiếm khi đổi → cache 1 ngày.
    LONG_CACHE_PREFIXES = ('/canvaskit/', '/icons/')

    def end_headers(self):
        path = self.path.split('?', 1)[0]
        if path.startswith(self.LONG_CACHE_PREFIXES):
            self.send_header('Cache-Control', 'public, max-age=86400')
        else:
            self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

    def log_message(self, fmt, *args):
        pass

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 3000), SPAHandler)
    print('Serving Flutter Web at http://localhost:3000')
    server.serve_forever()
