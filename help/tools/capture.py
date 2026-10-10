#!/usr/bin/env python3
"""Chụp ảnh cho trang trợ giúp theo chương:  python3 capture.py <chương> [<chương>...]   (hoặc: all)

Chạy trên MÔI TRƯỜNG THỬ RIÊNG đã có dữ liệu mẫu (landing/video/seed_demo.py, landing/video/prep_scenes.py,
help/tools/seed_help_extra.py) — một số bước tạo dữ liệu thật (đơn nghỉ, yêu cầu…) nên không chạy vào DB dev / prod.
Ảnh ra help/img/<id>.webp; id dùng trong các trang help/*.html."""
import asyncio
import sys

import os
import shoot_lib as L
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'landing', 'video'))  # seed_demo_lib dùng chung
from seed_demo_lib import call, login as api_login

CH = {}


def chapter(fn):
    CH[fn.__name__] = fn
    return fn


ADMIN, GD, HR, KT, QD, KD, CN = ('admin@anphat.local', 'gd@anphat.local', 'ns@anphat.local', 'ktt@anphat.local',
                                 'qd@anphat.local', 'kd@anphat.local', 'cn1@anphat.local')


async def safe(coro):
    try:
        return await coro
    except Exception as e:  # tiếp tục chương khi một bước phụ hỏng, in ra để sửa
        print('  !!', e)


# ── 1. Bắt đầu ─────────────────────────────────────────────────────────────
@chapter
async def bat_dau(sh):
    await sh.goto('/login')
    await sh.type('Email', CN)
    await sh.type('Mật khẩu', L.PW)
    await sh.shot('login', ['Email', 'Mật khẩu', ('Đăng nhập', 'button')])

    A = api_login(ADMIN)
    u = next(x for x in call('GET', '/api/v1/users', A) if x['email'] == 'cn3@anphat.local')
    tmp = call('POST', f"/api/v1/users/{u['id']}/reset-password", A)['password']
    await sh.login('cn3@anphat.local', tmp)
    await sh.shot('first-login', [('Mật khẩu hiện tại', 'textbox'), ('Mật khẩu mới', 'textbox')])
    # đổi luôn để tài khoản dùng tiếp được
    call('POST', f"/api/v1/users/{u['id']}/reset-password", A)

    await sh.login(CN)
    await sh.shot('home-employee', [sh.box(0, 40, 220, 330, 'Menu')])
    await sh.click('P', role='button')
    await sh.shot('account-menu', [('Thông tin cá nhân', None, 0, False, 3000, None, True), ('Ngôn ngữ', None, 0, False, 3000, None, True),
                                   ('Đăng xuất', None, 0, False, 3000, None, True)])
    await sh.esc()

    await sh.login(ADMIN)
    await sh.shot('home-admin', [sh.box(0, 40, 220, 860, 'Menu')])
    hdr = await sh.click('NHÂN SỰ', ocr=True)
    await sh.shot('menu-collapse', [sh.box(4, hdr['y'] - 8, 206, hdr['h'] + 16, 'Nhóm thu gọn')])
    await sh.click('NHÂN SỰ', ocr=True)
    await sh.click('Thông báo', role='button')
    await sh.shot('notifications', [])
    await sh.esc()


# ── 2. Thông tin cá nhân ───────────────────────────────────────────────────
@chapter
async def ca_nhan(sh):
    await sh.login(CN)
    await sh.goto('/profile')
    await sh.shot('profile', [])
    await sh.type('Số điện thoại', '0909123456')
    await sh.scroll(300)
    await sh.shot('profile-edit-request', [('Số điện thoại', 'textbox'), ('Gửi yêu cầu chỉnh sửa', 'button')])
    await sh.scroll(1200)
    await sh.shot('profile-more', [])
    await sh.scroll(1500)
    await sh.shot('profile-bottom', [])
    await sh.login(GD)
    await sh.goto('/profile')
    await sh.scroll(1400)
    await sh.shot('profile-dependents', [])
    await sh.scroll(1400)
    await sh.shot('profile-security', [])


# ── 3. Chấm công & đơn từ của nhân viên ───────────────────────────────────
@chapter
async def nhan_vien_tu_phuc_vu(sh):
    await sh.login('kd1@anphat.local')
    await sh.goto('/check-in-out', 5000)
    await sh.shot('checkin', [('Check-in', 'button')])

    await sh.login(CN)
    await sh.goto('/attendance-requests')
    await sh.click('Tạo yêu cầu', role='button')
    await sh.shot('att-request-new', [('Loại yêu cầu', 'button'), ('Giờ check-in yêu cầu', 'textbox'),
                                      ('Gửi yêu cầu chỉnh sửa', 'button')])
    await sh.esc()

    await sh.goto('/leaves')
    await sh.click('Số dư phép hiện tại')
    await sh.shot('leave-balance', [])
    await sh.goto('/leaves')
    await sh.click('Tạo đơn nghỉ phép', role='button')
    await sh.click('Loại nghỉ phép', role='button')
    await safe(sh.click('Phép năm', ocr=True))
    await sh.type('Lý do', 'Về quê có việc gia đình')
    await sh.shot('leave-new', [('Loại nghỉ phép', 'button'), ('Từ ngày', 'button'), ('Đến ngày', 'button'), ('Lý do', 'textbox'),
                                ('Tạo', 'button', 0, True)])
    await sh.esc()

    await sh.goto('/shift-swaps')
    await sh.shot('swaps', [('Xin đổi / nhường ca', 'button')])
    await sh.click('Xin đổi / nhường ca', role='button')
    await sh.shot('swap-new', [('Ca của tôi', 'button'), ('Gửi yêu cầu', 'button')])
    await sh.esc()

    await sh.goto('/payroll/self')
    await sh.shot('self-payroll', [('Tháng 9', None, 0, False, 3000, None, True)])
    await sh.click('Tháng 9', ocr=True, wait=2000)
    await sh.shot('payslip', [('Lương thực nhận', None, 0, False, 3000, None, True)])


# ── 4. Quản lý trực tiếp ──────────────────────────────────────────────────
@chapter
async def quan_ly(sh):
    for who in (QD, KD):
        await sh.login(who)
        await sh.goto('/team-approvals')
        items = await sh.dump()
        if any(i['label'] in ('Duyệt',) for i in items):
            await sh.shot('team-approvals', [('Duyệt', 'button'), ('Từ chối', 'button')])
            break
    else:
        await sh.shot('team-approvals', [])


# ── 5. Ca làm ─────────────────────────────────────────────────────────────
@chapter
async def ca_lam(sh):
    await sh.login(ADMIN)
    await sh.goto('/shifts')
    await sh.click('Danh sách ca')
    await sh.shot('shift-list', [('Tạo ca mới', 'button')])
    await sh.click('Tạo ca mới', role='button')
    await sh.shot('shift-new', [])
    await sh.esc()
    await sh.goto('/shifts')
    await sh.shot('shift-assign', [('Phân công ca', 'tab'), ('10/2026', 'button'), ('Điền nhanh ca', None, 0, False, 3000, None, None)])
    await safe(sh.click('Điền nhanh ca'))
    await sh.shot('shift-quickfill', [])
    await sh.esc()
    await sh.goto('/shifts')
    await sh.click('Xoay ca')
    await sh.shot('shift-rotation', [('Thêm mẫu xoay', 'button')])
    await sh.goto('/shift-swaps')
    await sh.shot('swap-approve', [])


# ── 6. Chấm công (quản lý) ────────────────────────────────────────────────
@chapter
async def cham_cong(sh):
    await sh.login(ADMIN)
    await sh.goto('/attendance')
    await sh.shot('att-day', [('Theo ngày', 'tab'), ('Thứ Bảy, 10/10/2026', 'button'), ('Phòng ban', 'button')])
    await sh.click('Theo tháng', role='tab')
    await sh.shot('att-month', [('Theo tháng', 'tab')])
    await sh.click('Tuần', role='tab')
    await sh.shot('att-week', [])
    await sh.goto('/attendance')
    await sh.click('Duyệt cả kỳ', role='button')
    await sh.shot('att-bulk-approve', [('Kỳ công', 'button'), ('Phòng ban', 'button'), ('Duyệt', 'button', 0, True)])
    await sh.esc()
    await sh.goto('/attendance')
    await sh.click('Khoá kỳ công', role='button')
    await sh.shot('att-lock', [('Mở lại', 'button'), ('Khoá', 'button', 0, True)])
    await sh.esc()
    await sh.goto('/attendance-requests')
    await sh.shot('att-requests-approve', [('Duyệt', 'button'), ('Từ chối', 'button')])


# ── 7. Nghỉ phép (quản lý / HR) ───────────────────────────────────────────
@chapter
async def nghi_phep(sh):
    await sh.login(ADMIN)
    await sh.goto('/leaves')
    await sh.shot('leave-approve', [('Duyệt', 'button'), ('Từ chối', 'button')])
    await sh.click('Số dư phép hiện tại')
    await sh.shot('leave-balances-hr', [])
    await sh.click('Loại nghỉ phép', role='tab')
    await sh.shot('leave-types', [])
    await sh.click('Thiết lập cộng phép', role='tab')
    await sh.shot('leave-accrual', [])
    await sh.goto('/leaves')
    await sh.click('Cấp phép thủ công', role='button')
    await sh.shot('leave-grant', [('Nhân viên', 'button'), ('Quỹ cho loại phép', 'button'), ('Cấp phép thủ công', 'button', 1)])
    await sh.esc()


# ── 8. Nhân viên, sơ đồ, phòng ban ────────────────────────────────────────
@chapter
async def nhan_su(sh):
    await sh.login(ADMIN)
    await sh.goto('/employees')
    await sh.shot('employees', [('Thêm nhân viên', 'button'), ('Tìm theo tên', 'textbox'), sh.box(1172, 202, 232, 34, 'Nút thao tác')])
    await sh.click('Thêm nhân viên', role='button', wait=2500)
    await sh.shot('employee-new', [('Họ và tên', 'textbox'), ('Email công việc', 'textbox'), ('Phòng ban', 'button'),
                                   ('Quản lý trực tiếp', 'button'), ('Tạo', 'button', 0, True)])
    await sh.scroll(900)
    await sh.shot('employee-new-2', [])
    await sh.goto('/employees')
    # Nút thao tác trên dòng đầu: quá trình công tác · người phụ thuộc · tài liệu · lương · sửa · nghỉ việc
    await sh.click(sh.box(1180, 211, 16, 16))
    await sh.shot('job-history', [])
    await sh.esc()
    await sh.type('Tìm theo tên', 'Trần Quốc Bảo')
    await sh.page.wait_for_timeout(1500)
    await sh.click(sh.box(1220, 211, 16, 16))
    await sh.shot('dependents', [('Thêm người phụ thuộc', None, 0, False, 3000, None, None)])
    await sh.esc()
    await sh.goto('/employees')
    await sh.click(sh.box(1260, 211, 16, 16))
    await sh.shot('employee-documents', [])
    await sh.esc()
    await sh.click(sh.box(1340, 211, 16, 16), wait=2500)
    await sh.shot('employee-edit', [])
    await sh.goto('/org-chart')
    await sh.shot('org-chart', [('Theo người', 'button'), ('Theo phòng ban', 'button')])
    await sh.click('Theo phòng ban', role='button')
    await sh.shot('org-chart-dept', [])
    await sh.goto('/departments')
    await sh.shot('departments', [('Thêm phòng ban', 'button'), ('Quản lý chức vụ', 'button'), ('Thêm phòng con', 'button'),
                                  ('Chỉnh sửa', 'button')])
    await sh.click('Thêm phòng ban', role='button')
    await sh.shot('department-new', [('Tên phòng ban', 'textbox'), ('Mã phòng ban', 'textbox'), ('Phòng ban cha', 'button'),
                                     ('Lấy vị trí hiện tại', 'button')])
    await sh.esc()
    await sh.goto('/departments')
    await sh.click('Quản lý chức vụ', role='button')
    await sh.shot('positions', [])
    await sh.esc()


# ── 9. Hợp đồng & tài liệu ────────────────────────────────────────────────
@chapter
async def hop_dong(sh):
    await sh.login(ADMIN)
    await sh.goto('/contracts')
    await sh.shot('contracts', [('hợp đồng sắp hết hạn', 'button'), ('Thêm hợp đồng', 'button'), ('Xuất Excel', 'button'),
                                ('Nhập Excel', 'button')])
    await sh.click('Thêm hợp đồng', role='button')
    await sh.shot('contract-new', [('Nhân viên', 'button'), ('Số hợp đồng', 'textbox'), ('Loại hợp đồng', 'button'),
                                   ('Ngày hiệu lực', 'button'), ('Lương cơ bản', 'textbox'), ('Thêm phụ cấp', 'button'),
                                   ('Lưu', 'button', 0, True)])
    await sh.esc()
    await sh.goto('/contracts')
    await sh.click('HD-2025-001', role='button')
    await sh.shot('contract-detail', [('Thêm phụ lục', 'button'), ('Chấm dứt', 'button'), ('Chỉnh sửa', 'button')])
    await sh.click('Thêm phụ lục', role='button')
    await sh.shot('appendix-new', [])
    await sh.esc(); await sh.esc()

    await sh.goto('/documents')
    await sh.shot('docs-expiring', [('Sắp hết hạn', 'tab'), ('Tải về', 'button')])
    await sh.click('Thiếu bắt buộc', role='tab')
    await sh.shot('docs-missing', [])
    await sh.click('Chờ duyệt', role='tab')
    await sh.shot('docs-pending', [])
    await sh.click('Loại tài liệu', role='tab')
    await sh.shot('docs-types', [])


# ── 10. Lương ─────────────────────────────────────────────────────────────
@chapter
async def luong(sh):
    await sh.login(KT)
    await sh.goto('/payroll')
    await sh.click('Tháng', role='button')
    await safe(sh.click('Tháng 9', ocr=True))
    await sh.shot('payroll-list', [('Tháng', 'button'), ('Xuất phiếu lương', 'button'), ('Tạo phiếu lương', 'button')])
    await sh.click('Bậc lương', role='tab')
    await sh.shot('salary-grades', [])
    await sh.click('Biến số', role='tab')
    await sh.shot('salary-variables', [])
    await sh.click('Công thức lương', role='tab')
    await sh.shot('salary-formulas', [])
    await sh.goto('/payroll')
    await sh.click('Tạo phiếu lương', role='button')
    await sh.shot('payroll-generate', [('Tháng', 'button'), ('Tìm nhân viên để thêm', 'textbox'), ('Tạo', 'button', 0, True)])
    await sh.esc()


# ── 11. Báo cáo, tổng quan, excel, nhật ký ─────────────────────────────────
@chapter
async def bao_cao(sh):
    await sh.login(ADMIN)
    await sh.goto('/dashboard', 5000)
    await sh.shot('dashboard', [('Tổng quan', 'tab'), ('Chấm công', 'tab'), ('Phân tích', 'tab'), ('Lọc theo phòng ban', 'button')])
    await sh.click('Chấm công', role='tab')
    await sh.shot('dashboard-attendance', [])
    await sh.click('Phân tích', role='tab')
    await sh.shot('dashboard-analytics', [])
    await sh.goto('/reports')
    await sh.shot('reports', [('Xuất Excel', 'button')])
    await sh.goto('/excel')
    await sh.shot('excel', [('Chọn & Xuất', 'button'), ('Nhập dữ liệu', 'button')])
    await sh.goto('/audit-logs')
    await sh.shot('audit', [('Tất cả thao tác', 'button'), ('Người thực hiện', 'textbox')])


# ── 12. Phân quyền, người dùng, yêu cầu chỉnh sửa ─────────────────────────
@chapter
async def phan_quyen(sh):
    await sh.login(ADMIN)
    await sh.goto('/roles')
    await sh.shot('roles', [('Thêm vai trò', 'button'), ('Chỉnh sửa', 'button')])
    await sh.click('Thêm vai trò', role='button')
    await sh.shot('role-new', [('Tên vai trò', 'textbox'), ('Phòng ban', 'button'), ('Xem danh sách nhân viên', 'checkbox')])
    await sh.esc()
    await sh.goto('/roles')
    await sh.click('Người dùng', role='tab')
    await sh.shot('users', [('Xuất mật khẩu tạm', 'button'), ('Đặt lại mật khẩu', 'button')])
    await sh.click('Trần Quốc Bảo', ocr=True, wait=2500)
    await sh.shot('user-roles', [])
    await sh.esc()
    await sh.goto('/profile/edit-requests')
    await sh.shot('edit-requests', [('Duyệt', 'button'), ('Từ chối', 'button')])


# ── 13. Cài đặt công ty ───────────────────────────────────────────────────
@chapter
async def cai_dat(sh):
    await sh.login(ADMIN)
    await sh.goto('/company-settings')
    await sh.shot('settings-general', [])
    await sh.scroll(600)
    await sh.shot('settings-general-2', [])
    await sh.scroll(1500)
    await sh.shot('settings-general-3', [])
    await sh.goto('/company-settings')
    await sh.click('Lịch làm việc', role='tab')
    await sh.shot('settings-calendar', [('Thêm lịch', 'button'), ('Thêm ngày lễ', 'button')])
    await sh.click('Thêm lịch', role='button')
    await sh.shot('calendar-new', [])
    await sh.esc()


# ── 14. Quản trị hệ thống (/admin) ────────────────────────────────────────
@chapter
async def quan_tri(sh):
    await sh.goto('/admin/login')
    await sh.type('Email', 'sysadmin@bosskin.local')
    await sh.type('Mật khẩu', 'HelpDocs@2026x')
    await sh.shot('admin-login', [])
    await sh.page.keyboard.press('Enter')
    await sh.page.wait_for_timeout(5000)
    await sh.semantics()
    await sh.shot('admin-dashboard', [])
    items = await sh.dump('admin_dash')
    tabs = [i['label'] for i in items if i['role'] == 'tab']
    print('  tabs', tabs)
    for k, lab in enumerate(tabs):
        await safe(sh.click(lab, role='tab', wait=2500))
        await sh.shot(f'admin-tab-{k + 1}', [(lab, 'tab')])


async def main(names):
    if names == ['all']:
        names = list(CH)
    for n in names:
        print('==', n)
        await L.run(CH[n.replace('-', '_')])


if __name__ == '__main__':
    asyncio.run(main(sys.argv[1:]))
