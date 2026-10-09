#!/usr/bin/env python3
"""Chuẩn bị trạng thái cho từng cảnh quay (chạy sau seed_demo.py, ngay trước capture.py).

- Mô tả vai trò dễ hiểu, mẫu xoay ca + đơn đổi ca cho xưởng.
- NV "Nguyễn Thu Trang" có ca hôm nay bắt đầu ~15 phút sau giờ chạy để quay cảnh chấm công đúng giờ.
"""
import datetime as dt, sys
sys.path.insert(0, __import__('os').path.dirname(__file__))
from seed_demo_lib import call, login, items

A = login('admin@anphat.local')
today = dt.datetime.now(dt.timezone(dt.timedelta(hours=7))).date()

print('== Vai trò')
desc = {'Quản lý': 'Duyệt công, nghỉ phép, xếp ca cho phòng mình',
        'Kế toán': 'Tính lương, duyệt và chi trả bảng lương'}
for r in items(call('GET', '/api/v1/roles', A)):
    if r['name'] in desc and r.get('description') != desc[r['name']]:
        perms = [p['code'] if isinstance(p, dict) else p for p in (r.get('permissions') or [])]
        call('PUT', f'/api/v1/roles/{r["id"]}', A, {'name': r['name'], 'description': desc[r['name']],
             'permissions': perms, 'roleViewAllCompany': r.get('roleViewAllCompany', True)})

print('== Xoay ca + đổi ca')
shifts = {s['code']: s for s in items(call('GET', '/api/v1/shifts', A))}
emps = items(call('GET', '/api/v1/employees', A, params={'size': 100}))
by_email = {e.get('email') or e.get('workEmail'): e for e in emps}
if not items(call('GET', '/api/v1/shift-rotations', A)):
    rot = call('POST', '/api/v1/shift-rotations', A, {'name': 'Xoay ca xưởng (6 ngày ca 1 – 6 ngày ca 2)',
               'days': [[shifts['CA1']['id']]] * 6 + [[]] + [[shifts['CA2']['id']]] * 6 + [[]]})
    nxt = (today.replace(day=1) + dt.timedelta(days=32)).replace(day=1)
    end = (nxt + dt.timedelta(days=32)).replace(day=1) - dt.timedelta(days=1)
    sx = [e['id'] for e in emps if (e.get('departmentName') or '').startswith('Xưởng')]
    call('POST', f'/api/v1/shift-rotations/{rot["id"]}/generate', A, {'employeeIds': sx, 'from': nxt.isoformat(),
         'to': end.isoformat(), 'startOffset': 0, 'staggerPerEmployee': 7})
t = login('cn1@anphat.local')
if not items(call('GET', '/api/v1/shift-swaps', t, ok=(200, 403)) or []):
    mine = [s for s in call('GET', '/api/v1/shift-swaps/my-shifts', t) if s['date'] > (today + dt.timedelta(days=2)).isoformat()]
    target = by_email['cn2@anphat.local']['id']
    for m in mine:
        cols = call('GET', '/api/v1/shift-swaps/colleagues', t, params={'assignmentId': m['assignmentId']})
        c = next((c for c in cols if c['employeeId'] == target and c.get('shifts')), None)
        if c:
            call('POST', '/api/v1/shift-swaps', t, {'requesterAssignmentId': m['assignmentId'], 'targetEmployeeId': target,
                 'targetAssignmentId': c['shifts'][0]['assignmentId'], 'reason': 'Đưa con đi khám buổi sáng'})
            break

print('== Ca hôm nay cho cảnh chấm công điện thoại')
trang = by_email['kd1@anphat.local']
now = dt.datetime.now(dt.timezone(dt.timedelta(hours=7))).replace(tzinfo=None)   # giờ VN
start = (now + dt.timedelta(minutes=15)).replace(second=0, microsecond=0)
start -= dt.timedelta(minutes=start.minute % 5)
code = 'GK' + start.strftime('%H%M')
if code not in shifts:
    shifts[code] = call('POST', '/api/v1/shifts', A, {'code': code, 'name': 'Ca gặp khách',
                        'startTime': start.strftime('%H:%M'), 'endTime': (start + dt.timedelta(hours=8)).strftime('%H:%M')})
for a in items(call('GET', '/api/v1/attendances', A, params={'year': today.year, 'month': today.month,
                                                              'employeeId': trang['id'], 'size': 60})):
    if a['date'][:10] == today.isoformat():
        call('POST', '/api/v1/attendances/unapprove', A, {'attendanceId': a['id']}, ok=(200, 204, 400))
        call('DELETE', f'/api/v1/attendances/{a["id"]}', A)
for sa in items(call('GET', f'/api/v1/shifts/assignments/employee/{trang["id"]}', A,
                     params={'from': today.isoformat(), 'to': today.isoformat()})):
    if (sa.get('workDate') or sa.get('date'))[:10] == today.isoformat():
        call('DELETE', f'/api/v1/shifts/assignments/{sa["id"]}', A)
call('POST', '/api/v1/shifts/assignments', A, {'employeeId': trang['id'], 'shiftId': shifts[code]['id'],
     'workDate': today.isoformat()})
for c, sh in shifts.items():          # dọn ca gặp khách của lần chạy trước
    if c.startswith('GK') and c != code:
        call('DELETE', f'/api/v1/shifts/{sh["id"]}', A, ok=(200, 204, 400, 409))
print('   Ca gặp khách', start.strftime('%H:%M'))
