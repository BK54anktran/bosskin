#!/usr/bin/env python3
"""Chụp các trạng thái màn hình điện thoại cho video (390x844, @2x). Ảnh ra thư mục argv[1]."""
import asyncio, sys
from playwright.async_api import async_playwright
OUT = sys.argv[1]; WEB = 'http://localhost:3000'
W, H = 390, 844
async def shot(page, name, wait=2500):
    await page.wait_for_timeout(wait); await page.screenshot(path=f'{OUT}/{name}.png'); print('  ', name)
async def login(page, email):
    await page.goto(WEB + '/login', wait_until='networkidle'); await page.wait_for_timeout(4000)
    await page.mouse.click(W // 2, H // 2 + 33); await page.keyboard.type(email, delay=5)
    await page.mouse.click(W // 2, H // 2 + 97); await page.keyboard.type('AnPhat2026demo', delay=5)
    await page.keyboard.press('Enter'); await page.wait_for_timeout(5000)
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(args=['--no-proxy-server', '--hide-scrollbars'])
        ctx = await b.new_context(viewport={'width': W, 'height': H}, device_scale_factor=2, locale='vi-VN',
                                  geolocation={'latitude': 10.77695, 'longitude': 106.70098, 'accuracy': 8},
                                  permissions=['geolocation'])
        page = await ctx.new_page()
        if 'payslip' not in sys.argv[2:]:
          await login(page, 'kd1@anphat.local')
          await page.goto(WEB + '/check-in-out', wait_until='networkidle'); await shot(page, 'p_checkin_before', 5000)
          await page.mouse.click(104, 697); await shot(page, 'p_checkin_after', 4000)
        if 'payslip' not in sys.argv[2:]:
          await ctx.clear_cookies(); await page.evaluate('localStorage.clear()')
        await login(page, 'ktv@anphat.local')        # NV văn phòng: 22/22 công
        await page.goto(WEB + '/payroll/self', wait_until='networkidle'); await shot(page, 'p_payslips', 4000)
        await page.mouse.click(200, 156); await shot(page, 'p_payslip_detail', 3500)
        await b.close()
asyncio.run(main())
