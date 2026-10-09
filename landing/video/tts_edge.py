#!/usr/bin/env python3
"""Lồng tiếng tiếng Việt qua dịch vụ đọc của Microsoft Edge, CHỈ dùng thư viện chuẩn Python (không cần pip edge-tts):
chạy được cả trong môi trường cloud không cài được gói. Tự đi qua HTTPS_PROXY nếu có.

  tts_edge.py "<lời đọc>" <file .mp3> [--voice vi-VN-NamMinhNeural] [--rate +2%]
"""
import base64, hashlib, os, secrets, socket, ssl, struct, sys, time, uuid
from datetime import datetime, timezone
from urllib.parse import urlparse
from xml.sax.saxutils import escape

TOKEN = '6A5AA1D4EAFF4E9FB37E23D68491D6F4'
VER = '143.0.3650.75'
HOST, PATH = 'speech.platform.bing.com', '/consumer/speech/synthesize/readaloud/edge/v1'

def sec_ms_gec():
    t = time.time() + 11644473600
    t -= t % 300
    return hashlib.sha256(f'{t * 1e7:.0f}{TOKEN}'.encode()).hexdigest().upper()

def connect():
    ctx = ssl.create_default_context(cafile=os.environ.get('SSL_CERT_FILE') or (
        '/root/.ccr/ca-bundle.crt' if os.path.exists('/root/.ccr/ca-bundle.crt') else None))
    proxy = os.environ.get('HTTPS_PROXY') or os.environ.get('https_proxy')
    if proxy:
        p = urlparse(proxy); raw = socket.create_connection((p.hostname, p.port or 80), timeout=30)
        auth = ''
        if p.username: auth = 'Proxy-Authorization: Basic ' + base64.b64encode(f'{p.username}:{p.password or ""}'.encode()).decode() + '\r\n'
        raw.sendall(f'CONNECT {HOST}:443 HTTP/1.1\r\nHost: {HOST}:443\r\n{auth}\r\n'.encode())
        resp = b''
        while b'\r\n\r\n' not in resp: resp += raw.recv(4096)
        if b' 200' not in resp.split(b'\r\n')[0]: raise RuntimeError('proxy: ' + resp.split(b'\r\n')[0].decode())
    else:
        raw = socket.create_connection((HOST, 443), timeout=30)
    s = ctx.wrap_socket(raw, server_hostname=HOST)
    key = base64.b64encode(os.urandom(16)).decode()
    q = f'{PATH}?TrustedClientToken={TOKEN}&ConnectionId={uuid.uuid4().hex}&Sec-MS-GEC={sec_ms_gec()}&Sec-MS-GEC-Version=1-{VER}'
    major = VER.split('.')[0]
    s.sendall((f'GET {q} HTTP/1.1\r\nHost: {HOST}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
               f'Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n'
               f'Origin: chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold\r\n'
               f'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{major}.0.0.0 Safari/537.36 Edg/{major}.0.0.0\r\n'
               f'Accept-Language: en-US,en;q=0.9\r\nCookie: muid={secrets.token_hex(16).upper()};\r\n\r\n').encode())
    resp = b''
    while b'\r\n\r\n' not in resp: resp += s.recv(4096)
    head, rest = resp.split(b'\r\n\r\n', 1)
    if b' 101' not in head.split(b'\r\n')[0]: raise RuntimeError('websocket: ' + head.split(b'\r\n')[0].decode())
    return s, rest

def send_text(s, txt):
    data = txt.encode(); mask = os.urandom(4); n = len(data)
    hdr = bytes([0x81]) + (bytes([0x80 | n]) if n < 126 else bytes([0x80 | 126]) + struct.pack('>H', n) if n < 65536 else bytes([0x80 | 127]) + struct.pack('>Q', n))
    s.sendall(hdr + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

class Reader:
    def __init__(self, s, buf): self.s, self.buf = s, buf
    def need(self, n):
        while len(self.buf) < n:
            c = self.s.recv(65536)
            if not c: raise RuntimeError('kết nối đóng sớm')
            self.buf += c
        out, self.buf = self.buf[:n], self.buf[n:]; return out
    def frame(self):
        b0, b1 = self.need(2); n = b1 & 0x7F
        if n == 126: n = struct.unpack('>H', self.need(2))[0]
        elif n == 127: n = struct.unpack('>Q', self.need(8))[0]
        if b1 & 0x80: self.need(4)
        return b0 & 0x0F, self.need(n)

def synth(text, out, voice='vi-VN-NamMinhNeural', rate='+2%'):
    s, rest = connect(); rd = Reader(s, rest)
    ts = datetime.now(timezone.utc).strftime('%a %b %d %Y %H:%M:%S GMT+0000 (Coordinated Universal Time)')
    send_text(s, f'X-Timestamp:{ts}\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n'
                 '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},'
                 '"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r\n')
    lang = '-'.join(voice.split('-')[:2]); name = f'Microsoft Server Speech Text to Speech Voice ({lang}, {voice.split("-", 2)[2]})'
    ssml = (f"<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><voice name='{name}'>"
            f"<prosody pitch='+0Hz' rate='{rate}' volume='+0%'>{escape(text)}</prosody></voice></speak>")
    send_text(s, f'X-RequestId:{uuid.uuid4().hex}\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:{ts}Z\r\nPath:ssml\r\n\r\n{ssml}')
    audio = bytearray(); msg = bytearray(); op0 = None
    while True:
        op, data = rd.frame()
        if op == 8: break
        if op in (1, 2): op0, msg = op, bytearray(data)
        elif op == 0: msg += data
        else: continue
        if op0 == 1 and b'Path:turn.end' in msg: break
        if op0 == 2 and len(msg) >= 2:
            hl = struct.unpack('>H', msg[:2])[0]
            if b'Path:audio' in msg[2:2 + hl]: audio += msg[2 + hl:]
    s.close()
    if not audio: raise RuntimeError('không nhận được âm thanh')
    open(out, 'wb').write(audio)

if __name__ == '__main__':
    a = sys.argv[1:]; voice, rate = 'vi-VN-NamMinhNeural', '+2%'
    if '--voice' in a: i = a.index('--voice'); voice = a[i + 1]; del a[i:i + 2]
    if '--rate' in a: i = a.index('--rate'); rate = a[i + 1]; del a[i:i + 2]
    for k in range(3):
        try: synth(a[0], a[1], voice, rate); print('ok', a[1]); break
        except Exception as e:
            print('lỗi:', e, file=sys.stderr); time.sleep(2)
    else: sys.exit(1)
