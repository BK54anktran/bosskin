#!/usr/bin/env python3
"""Dữ liệu mẫu cho video giới thiệu: công ty hư cấu "Nội thất An Phát" (24 NV).

Chỉ chạy trên môi trường THỬ RIÊNG (DB riêng, không phải DB dev/prod) — script tạo công ty mới qua API.
  python3 seed_demo.py http://localhost:8080 <email system admin> <mật khẩu system admin> [khoá TOTP]
System admin bắt buộc 2FA: lần đầu script tự cài và in khoá TOTP (lưu vào .demo-totp cạnh script).
Hôm nay (ngày chạy) có sẵn ~19 người đã chấm công; NV kinh doanh "Nguyễn Thu Trang" để trống để quay cảnh
chấm công trên điện thoại. Tháng trước: công đã duyệt + khoá kỳ, lương đã duyệt/trả. Tháng này: công chưa duyệt.
"""
import base64, datetime as dt, hashlib, hmac, os, random, struct, sys, time
import requests

API = sys.argv[1].rstrip('/')
SYS_EMAIL, SYS_PW = sys.argv[2], sys.argv[3]
HERE = os.path.dirname(os.path.abspath(__file__))
TOTP_FILE = os.path.join(HERE, '.demo-totp')
PW = 'AnPhat2026demo'
TMP = PW + 'Tmp1'
LAT, LNG = 10.7769, 106.7009          # toạ độ văn phòng mẫu (TP.HCM)
random.seed(7)
S = requests.Session(); S.trust_env = False


def call(m, path, tok=None, body=None, params=None, ok=(200, 201, 204), headers=None):
    h = {'Accept-Language': 'vi'}
    if tok: h['Authorization'] = 'Bearer ' + tok
    if headers: h.update(headers)
    for attempt in range(3):
        r = S.request(m, API + path, json=body, params=params, headers=h, timeout=120)
        if r.status_code != 429: break
        time.sleep(2)
    if r.status_code not in ok:
        raise SystemExit(f'{m} {path} -> {r.status_code} {r.text[:300]}')
    return r.json() if r.content else None


def totp(secret):
    k = base64.b32decode(secret + '=' * (-len(secret) % 8))
    h = hmac.new(k, struct.pack('>Q', int(time.time()) // 30), hashlib.sha1).digest()
    o = h[19] & 15
    return f'{(struct.unpack(">I", h[o:o + 4])[0] & 0x7fffffff) % 1000000:06d}'


def sys_login():
    r = call('POST', '/admin/auth/login', body={'email': SYS_EMAIL, 'password': SYS_PW})
    if not r.get('twoFactor'): return r['accessToken']
    ch = r['challengeToken']
    if r['twoFactor'] == 'SETUP_REQUIRED':
        st = call('POST', '/admin/auth/2fa/setup', body={'challengeToken': ch})
        done = call('POST', '/admin/auth/2fa/enable', body={'challengeToken': ch, 'code': totp(st['secret'])})
        open(TOTP_FILE, 'w').write(st['secret'])
        print('Đã cài 2FA system admin, khoá:', st['secret'])
        return done['accessToken']
    secret = sys.argv[4] if len(sys.argv) > 4 else open(TOTP_FILE).read().strip()
    return call('POST', '/admin/auth/2fa/verify', body={'challengeToken': ch, 'code': totp(secret)})['accessToken']


def login(email, pw=PW, device=None):
    r = call('POST', '/api/v1/auth/login', body={'email': email, 'password': pw, 'deviceId': device or 'demo-' + email})
    return r['accessToken']


def activate(email):
    t = login(email, TMP)
    call('PATCH', '/api/v1/profile/password', t, {'currentPassword': TMP, 'newPassword': PW, 'confirmPassword': PW})


def items(r):
    return r['content'] if isinstance(r, dict) and 'content' in r else r


today = dt.datetime.now(dt.timezone(dt.timedelta(hours=7))).date()   # giờ VN
first_this = today.replace(day=1)
last_prev = first_this - dt.timedelta(days=1)
first_prev = last_prev.replace(day=1)
end_this = (first_this + dt.timedelta(days=32)).replace(day=1) - dt.timedelta(days=1)

print('== Công ty')
sys_tok = sys_login()
if any(c.get('code') == 'ANPHAT' for c in items(call('GET', '/admin/companies', sys_tok))):
    raise SystemExit('Công ty ANPHAT đã có — dùng DB thử mới nếu muốn tạo lại.')
call('POST', '/admin/companies', sys_tok, {
    'name': 'Nội thất An Phát', 'code': 'ANPHAT', 'domain': 'anphat.local',
    'address': '25 Lê Lợi, Quận 1, TP.HCM', 'phone': '02873009999', 'companyEmail': 'nhansu@anphat.local',
    'adminEmail': 'admin@anphat.local', 'adminPassword': TMP, 'adminFullName': 'Quản trị An Phát'})
activate('admin@anphat.local')
A = login('admin@anphat.local')

print('== Cài đặt chấm công')
st = call('GET', '/api/v1/company-settings', A)
st['attendance'].update({'locationCheckEnabled': True, 'deviceBindingEnabled': True, 'checkInLatitude': LAT,
                         'checkInLongitude': LNG, 'checkInRadiusMeters': 150})
call('PUT', '/api/v1/company-settings', A, st)
call('PATCH', '/api/v1/attendances/self/setting', A, {'enabled': True})

print('== Phòng ban, chức danh, vai trò, ca, bậc lương')
dept = {c: call('POST', '/api/v1/departments', A, {'code': c, 'name': n})['id'] for c, n in [
    ('BGD', 'Ban giám đốc'), ('HCNS', 'Hành chính - Nhân sự'), ('KT', 'Kế toán'),
    ('KD', 'Kinh doanh'), ('SX', 'Xưởng sản xuất')]}
pos = {c: call('POST', '/api/v1/positions', A, {'code': c, 'name': n, 'departmentId': dept[d]})['id'] for c, n, d in [
    ('GD', 'Giám đốc', 'BGD'), ('TPNS', 'Trưởng phòng nhân sự', 'HCNS'), ('CVNS', 'Chuyên viên nhân sự', 'HCNS'),
    ('KTT', 'Kế toán trưởng', 'KT'), ('KTV', 'Kế toán viên', 'KT'), ('TPKD', 'Trưởng phòng kinh doanh', 'KD'),
    ('NVKD', 'Nhân viên kinh doanh', 'KD'), ('QD', 'Quản đốc', 'SX'), ('TT', 'Tổ trưởng', 'SX'), ('CN', 'Thợ mộc', 'SX')]}
roles = items(call('GET', '/api/v1/roles', A))
role_nv = next((r['id'] for r in roles if r.get('isDefault') or r.get('default') or r.get('name') == 'Nhân viên'), None)
def new_role(name, perms):
    return call('POST', '/api/v1/roles', A, {'name': name, 'description': 'Dữ liệu mẫu', 'permissions': perms,
                                               'roleViewAllCompany': True})['id']
role_ql = new_role('Quản lý', ['ATTENDANCE_VIEW', 'ATTENDANCE_MANAGE', 'ATTENDANCE_APPROVE', 'ATTENDANCE_REQUEST_APPROVE',
                               'SHIFT_VIEW', 'SHIFT_MANAGE', 'EMPLOYEE_VIEW', 'DEPARTMENT_VIEW', 'LEAVE_VIEW',
                               'LEAVE_REQUEST_APPROVE', 'DASHBOARD_VIEW', 'REPORT_VIEW'])
role_kt = new_role('Kế toán', ['PAYROLL_VIEW', 'PAYROLL_CREATE', 'PAYROLL_APPROVE', 'PAYROLL_PAY', 'EMPLOYEE_VIEW',
                               'ATTENDANCE_VIEW', 'DASHBOARD_VIEW', 'EXCEL_EXPORT', 'REPORT_VIEW'])
shift = {c: call('POST', '/api/v1/shifts', A, {'code': c, 'name': n, 'startTime': s, 'endTime': e,
                                                'breakStart': bs, 'breakEnd': be})['id'] for c, n, s, e, bs, be in [
    ('HC', 'Hành chính', '08:00', '17:00', '12:00', '13:00'),
    ('CA1', 'Ca 1', '06:00', '14:00', None, None),
    ('CA2', 'Ca 2', '09:30', '17:30', None, None)]}
shift['LH'] = call('POST', '/api/v1/shifts', A, {'code': 'LH', 'name': 'Linh hoạt 8 tiếng', 'startTime': '07:00',
                                                  'endTime': '20:00', 'shiftType': 'FLEXIBLE', 'requiredMinutes': 480})['id']
g_vp = call('POST', '/api/v1/salary-grades', A, {'code': 'VP', 'name': 'Khối văn phòng', 'payType': 'DAILY', 'baseRate': 500000})['id']
g_sx = call('POST', '/api/v1/salary-grades', A, {'code': 'SX', 'name': 'Khối sản xuất', 'payType': 'DAILY', 'baseRate': 350000})['id']
formula = {g: call('POST', '/api/v1/salary-formulas', A, {
    'salaryGradeId': g, 'name': n, 'effectiveDate': '2026-01-01',
    'expressionGross': 'ROUND(CONTRACT_SALARY / STANDARD_WORK_DAYS * (PRESENT_DAYS + PAID_LEAVE_DAYS))',
    'expressionNet': 'GROSS - TOTAL_INSURANCE - PIT'})['id'] for g, n in [(g_vp, 'Lương tháng văn phòng'), (g_sx, 'Lương tháng sản xuất')]}

print('== Nhân viên')
P = [  # key, họ tên, giới tính, phòng, chức danh, lương HĐ, vai trò thêm
    ('gd', 'Trần Quốc Bảo', 'MALE', 'BGD', 'GD', 45000000, role_ql),
    ('ns', 'Lê Thanh Hương', 'FEMALE', 'HCNS', 'TPNS', 22000000, role_ql),
    ('ns2', 'Phan Ngọc Ánh', 'FEMALE', 'HCNS', 'CVNS', 12000000, None),
    ('ktt', 'Đặng Minh Khoa', 'MALE', 'KT', 'KTT', 26000000, role_kt),
    ('ktv', 'Ngô Thị Thanh', 'FEMALE', 'KT', 'KTV', 13500000, None),
    ('kd', 'Võ Hoàng Long', 'MALE', 'KD', 'TPKD', 24000000, role_ql),
    ('kd1', 'Nguyễn Thu Trang', 'FEMALE', 'KD', 'NVKD', 12000000, None),
    ('kd2', 'Lý Gia Huy', 'MALE', 'KD', 'NVKD', 11500000, None),
    ('kd3', 'Trịnh Mỹ Linh', 'FEMALE', 'KD', 'NVKD', 11500000, None),
    ('qd', 'Hồ Văn Thắng', 'MALE', 'SX', 'QD', 19000000, role_ql),
    ('tt1', 'Mai Đức Tín', 'MALE', 'SX', 'TT', 12500000, None),
    ('tt2', 'Châu Văn Lộc', 'MALE', 'SX', 'TT', 12500000, None),
] + [(f'cn{i}', n, g, 'SX', 'CN', 9500000 + (i % 3) * 500000, None) for i, (n, g) in enumerate([
    ('Phạm Văn Hải', 'MALE'), ('Đinh Thị Hồng', 'FEMALE'), ('Lâm Quốc Việt', 'MALE'), ('Tạ Văn Phúc', 'MALE'),
    ('Dương Thị Yến', 'FEMALE'), ('Kiều Minh Nhật', 'MALE'), ('Huỳnh Văn Sang', 'MALE'), ('La Thị Kim', 'FEMALE'),
    ('Trương Văn Đạt', 'MALE'), ('Âu Thành Nam', 'MALE'), ('Quách Thị Diệu', 'FEMALE'), ('Lục Văn Bình', 'MALE')], 1)]
E = {}
for i, (k, name, g, d, p, sal, extra) in enumerate(P):
    email = f'{k}@anphat.local'
    e = call('POST', '/api/v1/employees', A, {'fullName': name, 'email': email, 'password': TMP, 'gender': g,
             'joinDate': '2024-0%d-0%d' % (1 + i % 9, 1 + i % 8), 'departmentId': dept[d], 'positionId': pos[p],
             'phone': '09%08d' % random.randint(10000000, 99999999)})
    grade = g_sx if d == 'SX' else g_vp
    call('PUT', f'/api/v1/employees/{e["id"]}', A, {'positionId': pos[p], 'salaryGradeId': grade, 'contractSalary': sal})
    E[k] = dict(id=e['id'], email=email, name=name, dept=d, grade=grade, extra=extra)
    activate(email)
users = items(call('GET', '/api/v1/users', A))
for k, e in E.items():
    u = next(x for x in users if x['email'] == e['email'])
    call('PUT', f'/api/v1/users/{u["id"]}/roles', A, {'roleIds': [role_nv] + ([e['extra']] if e['extra'] else [])})

print('== Phân ca tháng trước + tháng này')
office = [e['id'] for e in E.values() if e['dept'] in ('BGD', 'HCNS', 'KT')]
sales = [e['id'] for e in E.values() if e['dept'] == 'KD']
sx = [e['id'] for e in E.values() if e['dept'] == 'SX']
sx_a, sx_b = sx[::2], sx[1::2]
def bulk(ids, sh, a, b, exclude):
    call('POST', '/api/v1/shifts/assignments/bulk', A, {'employeeIds': ids, 'shiftId': shift[sh], 'startDate': a.isoformat(),
         'endDate': b.isoformat(), 'excludeWeekdays': exclude})
bulk(office, 'HC', first_prev, end_this, [6, 7])
bulk(sales, 'LH', first_prev, end_this, [7])
d = first_prev - dt.timedelta(days=first_prev.weekday())
while d <= end_this:                       # xưởng: 2 nhóm đổi ca sáng/chiều theo tuần, làm T2–T7
    a, b = max(d, first_prev), min(d + dt.timedelta(days=6), end_this)
    wk = (d - first_prev).days // 7
    bulk(sx_a, 'CA1' if wk % 2 == 0 else 'CA2', a, b, [7])
    bulk(sx_b, 'CA2' if wk % 2 == 0 else 'CA1', a, b, [7])
    d += dt.timedelta(days=7)

print('== Phép')
lt = call('POST', '/api/v1/leaves/types', A, {'code': 'PN', 'name': 'Phép năm', 'unit': 'DAY', 'deductPerDay': 1,
          'paid': True, 'requiresBalance': True, 'active': True})['id']
call('POST', '/api/v1/leaves/types', A, {'code': 'OM', 'name': 'Nghỉ ốm', 'unit': 'DAY', 'deductPerDay': 1,
     'paid': False, 'requiresBalance': False, 'active': True})
for e in E.values():
    call('POST', '/api/v1/leaves/grants/manual', A, {'employeeId': e['id'], 'leaveTypeId': lt, 'grantDays': 12,
         'validFrom': '2026-01-01', 'validTo': '2026-12-31', 'note': 'Phép năm 2026'})
def leave(k, a, b, reason, approve=True):
    t = login(E[k]['email'])
    r = call('POST', '/api/v1/leaves/requests', t, {'leaveTypeId': lt, 'mode': 'DAY_RANGE', 'fromDate': a.isoformat(),
             'toDate': b.isoformat(), 'reason': reason})
    if approve: call('PUT', f'/api/v1/leaves/requests/{r["id"]}/approve', A, {})
def wd(base, n):                            # ngày làm việc thứ n (T2–T6) của tháng
    x = base
    while True:
        if x.weekday() < 5:
            n -= 1
            if n == 0: return x
        x += dt.timedelta(days=1)
leave('ktv', wd(first_prev, 6), wd(first_prev, 6), 'Việc gia đình')
leave('cn3', wd(first_prev, 12), wd(first_prev, 13), 'Về quê')
leave('ns2', today, today, 'Đưa con đi khám') if today.weekday() < 5 else None
leave('kd2', today + dt.timedelta(days=4), today + dt.timedelta(days=5), 'Đi đám cưới', approve=False)
leave('cn6', today + dt.timedelta(days=7), today + dt.timedelta(days=7), 'Khám sức khoẻ', approve=False)

print('== Chấm công')
TIMES = {'HC': ('08:00', '17:00'), 'CA1': ('06:00', '14:00'), 'CA2': ('09:30', '17:30'), 'LH': ('08:30', '17:30')}
def jitter(hhmm, lo, hi):
    h, m = map(int, hhmm.split(':')); t = h * 60 + m + random.randint(lo, hi)
    return f'{t // 60 % 24:02d}:{t % 60:02d}'
skip_today = {E['kd1']['id'], E['ns2']['id'], E['cn9']['id'], E['cn11']['id'], E['kd3']['id']}
late_today = {E['cn4']['id'], E['tt2']['id']}
def shift_of(e, day):
    if e['dept'] in ('BGD', 'HCNS', 'KT'): return 'HC' if day.weekday() < 5 else None
    if e['dept'] == 'KD': return 'LH' if day.weekday() < 6 else None
    if day.weekday() == 6: return None
    mon = day - dt.timedelta(days=day.weekday())
    wk = (mon - first_prev).days // 7
    grp_a = e['id'] in sx_a
    return ('CA1' if (wk % 2 == 0) == grp_a else 'CA2')
for k, e in E.items():
    days = []
    d = first_prev
    while d <= today:
        if shift_of(e, d): days.append(d)
        d += dt.timedelta(days=1)
    for d in days:      # tạo dòng công gắn với phân ca (giống seed-th)
        call('POST', '/api/v1/attendances/approve', A, {'employeeId': e['id'], 'date': d.isoformat()}, ok=(200, 201, 400))
    ids = {}
    for m in (first_prev, first_this):
        for a in items(call('GET', '/api/v1/attendances', A, params={'year': m.year, 'month': m.month,
                                                                       'employeeId': e['id'], 'size': 400})):
            ids.setdefault(a['date'][:10], a)
    n = 0
    for day, a in sorted(ids.items()):
        dday = dt.date.fromisoformat(day)
        code = a.get('shiftCode') or shift_of(e, dday) or 'HC'
        start, end = TIMES.get(code, TIMES['HC'])
        if dday == today:
            if e['id'] in skip_today: continue
            cin = jitter(start, 6, 25) if e['id'] in late_today else jitter(start, -20, -2)
            body = {'overrideCheckIn': cin, 'overrideCheckOut': None}
        else:
            if random.random() < 0.03: continue
            cin = jitter(start, 8, 30) if random.random() < 0.06 else jitter(start, -18, -1)
            body = {'overrideCheckIn': cin, 'overrideCheckOut': jitter(end, 0, 25)}
        call('PATCH', f'/api/v1/attendances/{a["id"]}/override', A, body)
        n += 1
    print('  ', e['name'], len(days), 'ngày ca,', n, 'ngày có giờ')

print('== Duyệt + khoá kỳ tháng trước, lương')
r = call('POST', '/api/v1/attendances/approve-bulk', A, {'from': first_prev.isoformat(), 'to': last_prev.isoformat()})
print('   duyệt công', {k: v for k, v in r.items() if k != 'errors'}, r.get('errors', [])[:2])
call('POST', f'/api/v1/attendance-periods/{last_prev.year}/{last_prev.month}/lock', A, {})
for e in E.values():
    p = call('POST', '/api/v1/payrolls/generate', A, {'employeeId': e['id'], 'year': last_prev.year,
             'month': last_prev.month, 'formulaId': formula[e['grade']]})
    call('POST', f'/api/v1/payrolls/{p["id"]}/approve', A, {})
    call('POST', f'/api/v1/payrolls/{p["id"]}/pay', A, {})

print('== Đơn chờ duyệt')
t = login(E['cn2']['email'])
call('POST', '/api/v1/attendance-requests', t, {'requestDate': wd(first_this, 2).isoformat(), 'requestType': 'CHECK_OUT',
     'requestedCheckOut': '14:05', 'reason': 'Quên chấm công ra'}, ok=(200, 201, 400))
print('XONG. Đăng nhập admin@anphat.local /', PW)
