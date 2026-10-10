"""Khám phá nhanh: đăng nhập, mở từng route, lưu ảnh + danh sách nhãn semantics (thư mục .raw/explore)."""
import asyncio, json, os, sys
import shoot_lib as L
EMAIL = sys.argv[1]; ROUTES = sys.argv[2:]
OUTD = os.path.join(L.HERE, '.raw', 'explore'); os.makedirs(OUTD, exist_ok=True)
async def job(sh):
    await sh.login(EMAIL)
    for r in ROUTES:
        await sh.goto(r)
        name = (EMAIL.split('@')[0] + r.replace('/', '_'))
        await sh.page.screenshot(path=os.path.join(OUTD, name + '.png'))
        items = await sh.dump()
        print('##', r, '→', ' | '.join(f"{i['role'][:6]}:{i['label'][:40]}@{i['x']},{i['y']}" for i in items if True) [:2500])
asyncio.run(L.run(job))
