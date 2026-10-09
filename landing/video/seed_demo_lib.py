"""Hàm gọi API dùng chung cho các script dữ liệu mẫu video (seed_demo.py, prep_scenes.py)."""
import os, time
import requests

API = os.environ.get('DEMO_API', 'http://localhost:8080').rstrip('/')
PW = 'AnPhat2026demo'
S = requests.Session(); S.trust_env = False


def call(m, path, tok=None, body=None, params=None, ok=(200, 201, 204), headers=None):
    h = {'Accept-Language': 'vi'}
    if tok: h['Authorization'] = 'Bearer ' + tok
    if headers: h.update(headers)
    for _ in range(3):
        r = S.request(m, API + path, json=body, params=params, headers=h, timeout=120)
        if r.status_code != 429: break
        time.sleep(2)
    if r.status_code not in ok:
        raise SystemExit(f'{m} {path} -> {r.status_code} {r.text[:300]}')
    try: return r.json() if r.content else None
    except ValueError: return None


def login(email, pw=PW, device=None):
    return call('POST', '/api/v1/auth/login', body={'email': email, 'password': pw,
                'deviceId': device or 'demo-' + email})['accessToken']


def items(r):
    return r['content'] if isinstance(r, dict) and 'content' in r else (r or [])
