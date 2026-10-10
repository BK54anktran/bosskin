#!/usr/bin/env python3
"""Dữ liệu bổ sung cho ảnh chụp trang trợ giúp (chạy SAU landing/video/seed_demo.py, cùng môi trường thử riêng).

Thêm vào công ty hư cấu "Nội thất An Phát": quản lý trực tiếp + chế độ duyệt 2 bước, hợp đồng (1 HĐ sắp hết hạn,
1 phụ lục tăng lương), người phụ thuộc, tài liệu chờ duyệt, yêu cầu sửa hồ sơ, lịch làm việc "T7 làm sáng" cho
xưởng, mốc chuyển phòng tương lai. Không chạy vào DB dev / prod.
  DEMO_API=http://localhost:8080 python3 seed_help_extra.py
"""
import datetime as dt
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'landing', 'video'))  # seed_demo_lib dùng chung
from seed_demo_lib import call, login, items, API, S

A = login('admin@anphat.local')
today = dt.date.today()
emps = {e['email'].split('@')[0]: e for e in items(call('GET', '/api/v1/employees', A, params={'size': 200}))}
print('NV:', len(emps))


def emp_detail(k):
    return call('GET', f"/api/v1/employees/{emps[k]['id']}", A)


def job(k, eff, ctype, note, manager=None, dept=None):
    d = emp_detail(k)
    body = {'effectiveFrom': eff.isoformat(), 'changeType': ctype, 'note': note,
            'departmentId': dept or d['departmentId'], 'positionId': None if dept else d.get('positionId'),
            'salaryGradeId': d.get('salaryGradeId'),
            'managerId': manager if manager is not None else d.get('managerId')}
    call('POST', f"/api/v1/employees/{d['id']}/job-histories", A, body)


# ── Quản lý trực tiếp: GĐ → trưởng phòng; quản đốc → công nhân; TP kinh doanh → NV kinh doanh
print('== Quản lý trực tiếp')
heads = ['ns', 'ktt', 'kd', 'qd']
for k in heads:
    job(k, today, 'MANAGER_CHANGE', 'Báo cáo Giám đốc', manager=emps['gd']['id'])
for k, e in emps.items():
    if k in heads or k in ('gd', 'admin'): continue
    dep = e.get('departmentName') or ''
    boss = 'qd' if 'xuất' in dep.lower() else 'kd' if 'kinh doanh' in dep.lower() else 'ktt' if 'kế toán' in dep.lower() else 'ns'
    job(k, today, 'MANAGER_CHANGE', 'Gắn quản lý trực tiếp', manager=emps[boss]['id'])

# Chế độ duyệt: quản lý trực tiếp trước, rồi nhân sự
st = call('GET', '/api/v1/company-settings', A)
st['approval'] = {'mode': 'MANAGER_THEN_HR'}
call('PUT', '/api/v1/company-settings', A, st)

# ── Hợp đồng
print('== Hợp đồng')
n = 0
for k, e in list(emps.items())[:14]:
    if k == 'admin': continue
    d = emp_detail(k)
    fixed = n % 3 == 1
    start = dt.date(2025, 1, 1) if not fixed else dt.date(2025, 11, 1)
    body = {'employeeId': d['id'], 'contractNo': f'HD-2025-{n + 1:03d}', 'contractType': 'FIXED_TERM' if fixed else 'INDEFINITE',
            'signDate': (start - dt.timedelta(days=3)).isoformat(), 'startDate': start.isoformat(),
            'endDate': (today + dt.timedelta(days=18)).isoformat() if n == 1 else ((start + dt.timedelta(days=364)).isoformat() if fixed else None),
            'baseSalary': 12000000 + n * 1000000, 'positionTitle': d.get('positionName') or 'Nhân viên',
            'allowances': [{'code': 'AN_TRUA', 'name': 'Phụ cấp ăn trưa', 'amount': 730000, 'insurable': False, 'taxable': False},
                           {'code': 'DIEN_THOAI', 'name': 'Phụ cấp điện thoại', 'amount': 300000, 'insurable': False, 'taxable': True}]}
    c = call('POST', '/api/v1/contracts', A, body)
    call('POST', f"/api/v1/contracts/{c['id']}/activate", A)
    if n == 0:
        call('POST', f"/api/v1/contracts/{c['id']}/appendices", A, {
            'appendixNo': 'PL-01', 'effectiveFrom': today.replace(day=1).isoformat(), 'baseSalary': 13500000,
            'note': 'Điều chỉnh lương theo đánh giá năm'})
    n += 1
print('  ', n, 'hợp đồng')

# ── Người phụ thuộc (Giám đốc: 2 con)
print('== Người phụ thuộc')
for name, dob in [('Trần Bảo An', '2015-04-12'), ('Trần Bảo Ngọc', '2018-09-30')]:
    call('POST', '/api/v1/dependents', A, {'employeeId': emps['gd']['id'], 'fullName': name, 'relationship': 'CHILD',
         'dateOfBirth': dob, 'deductionFrom': '2026-01-01', 'registrationStatus': 'REGISTERED'})

# ── Tài liệu: NV tự gửi (chờ duyệt) + HR tải lên giấy khám sắp hết hạn
print('== Tài liệu')
types = {t['code']: t for t in call('GET', '/api/v1/document-types', A)}
pdf = b'%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n'
first_type = next(iter(types.values()))
for k, code, title, exp in [('cn1', 'CCCD', 'CCCD mặt trước + sau', '2036-06-01'), ('ktv', 'BANG_CAP', 'Bằng cử nhân Kế toán', None)]:
    if k not in emps or code not in types: continue
    t = login(emps[k]['email'])
    data = {'typeId': types[code]['id'], 'title': title, 'issuedOn': '2021-06-01'}
    if exp: data['expiresOn'] = exp
    r = S.post(API + '/api/v1/employee-documents/self', headers={'Authorization': 'Bearer ' + t},
               data=data, files={'file': ('tai-lieu.pdf', pdf, 'application/pdf')})
    print('  gửi', k, r.status_code)
ksk = next((t for t in types.values() if t.get('hasExpiry') and t['code'] != first_type['code']), None)
if ksk:
    r = S.post(API + '/api/v1/employee-documents', headers={'Authorization': 'Bearer ' + A},
               data={'employeeId': emps['qd']['id'], 'typeId': ksk['id'], 'title': ksk['name'] + ' 2025',
                     'issuedOn': (today - dt.timedelta(days=340)).isoformat(),
                     'expiresOn': (today + dt.timedelta(days=12)).isoformat()},
               files={'file': ('giay-kham.pdf', pdf, 'application/pdf')})
    print('  HR tải lên', r.status_code)

# ── Yêu cầu sửa hồ sơ
print('== Yêu cầu sửa hồ sơ')
k = next(x for x in emps if x.startswith('cn'))
call('POST', '/api/v1/profile/edit-requests', login(emps[k]['email']), {'phone': '0912345678', 'personalEmail': 'ca.nhan@gmail.com'})

# ── Lịch làm việc: xưởng làm sáng thứ 7
print('== Lịch làm việc')
depts = items(call('GET', '/api/v1/departments/flat', A))
sx = next(d for d in depts if 'xuất' in d['name'].lower())
call('POST', '/api/v1/work-calendars', A, {'name': 'Xưởng: T7 làm sáng', 'weekPattern': 'FFFFFHO', 'departmentIds': [sx['id']]})

# ── Mốc chuyển phòng tương lai
print('== Quá trình công tác')
kd = next(d for d in depts if 'kinh doanh' in d['name'].lower())
job('ns2' if 'ns2' in emps else 'ktt', (today.replace(day=1) + dt.timedelta(days=40)).replace(day=1), 'TRANSFER', 'Chuyển sang phòng Kinh doanh', manager=emps['kd']['id'], dept=kd['id'])
print('XONG')
