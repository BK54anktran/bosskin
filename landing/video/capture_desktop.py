#!/usr/bin/env python3
"""Chụp các trạng thái màn hình máy tính cho video (1600x900, @2x).
  capture_desktop.py <thư mục ảnh> <bước>   — bước: views | leave | approve | payroll | profile
Toạ độ bấm là toạ độ CSS của bản web hiện tại (thay giao diện thì chụp lại và chỉnh)."""
import asyncio, sys
from playwright.async_api import async_playwright
OUT, STEP = sys.argv[1], sys.argv[2]; WEB = 'http://localhost:3000'
W, H = 1600, 900
async def shot(page, name, wait=2500):
    await page.wait_for_timeout(wait); await page.screenshot(path=f'{OUT}/{name}.png'); print('  ', name)
async def login(page, email):
    await page.goto(WEB + '/login', wait_until='networkidle'); await page.wait_for_timeout(4000)
    await page.mouse.click(W // 2, H // 2 + 33); await page.keyboard.type(email, delay=5)
    await page.mouse.click(W // 2, H // 2 + 97); await page.keyboard.type('AnPhat2026demo', delay=5)
    await page.keyboard.press('Enter'); await page.wait_for_timeout(5000)
async def go(page, route, name, wait=4500):
    await page.goto(WEB + route, wait_until='networkidle'); await shot(page, name, wait)
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(args=['--no-proxy-server', '--hide-scrollbars'])
        ctx = await b.new_context(viewport={'width': W, 'height': H}, device_scale_factor=2, locale='vi-VN')
        page = await ctx.new_page()
        if STEP == 'profile':
            await login(page, 'gd@anphat.local'); await go(page, '/profile', 'd_profile')
            await page.mouse.move(800, 600)
            for _ in range(12): await page.mouse.wheel(0, 250); await page.wait_for_timeout(120)
            await shot(page, 'd_profile_2fa'); await b.close(); return
        await login(page, 'admin@anphat.local')
        if STEP == 'views':
            await shot(page, 'd_dashboard', 2000)
            await go(page, '/shifts', 'd_shifts')
            await page.mouse.click(483, 87); await shot(page, 'd_shift_rotation')
            await go(page, '/shift-swaps', 'd_swaps')
            await go(page, '/leaves', 'd_leaves')
            await go(page, '/attendance', 'd_attendance')
            await page.mouse.click(1083, 91); await shot(page, 'd_bulk_dialog')
            await go(page, '/payroll', 'd_payroll')
            await page.mouse.click(300, 137); await shot(page, 'd_payroll_month_menu', 1500)
            await go(page, '/reports', 'd_reports')
            await go(page, '/roles', 'd_roles')
            await page.mouse.click(1255, 79); await shot(page, 'd_users')
            await go(page, '/audit-logs', 'd_audit')
        if STEP == 'leave':
            await go(page, '/leaves', 'd_leaves')
            await page.mouse.click(580, 391); await shot(page, 'd_leaves_after', 3000)
        if STEP == 'approve':
            await go(page, '/attendance', 'd_attendance')
            await page.mouse.click(1083, 91); await page.wait_for_timeout(2000)
            await page.mouse.click(998, 564); await shot(page, 'd_bulk_result', 15000)
            await page.keyboard.press('Escape'); await page.wait_for_timeout(1000)
            await go(page, '/attendance', 'd_attendance_after')
            await go(page, '/audit-logs', 'd_audit')
        if STEP == 'payroll':
            await go(page, '/payroll', 'd_payroll')
            await page.mouse.click(300, 137); await page.wait_for_timeout(1500)
            await page.mouse.click(266, 518); await shot(page, 'd_payroll9', 4000)
        await b.close()
asyncio.run(main())
