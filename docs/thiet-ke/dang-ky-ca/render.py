"""Chụp từng khung (.frame) trong mockup.html thành PNG cùng thư mục.

Chạy: python3 render.py [thư-mục-font-Roboto]
Không có mạng thì truyền thư mục chứa roboto-latin(-ext|vietnamese)-*-normal.woff2 (fontsource) để có đúng font.
"""
import pathlib, sys
from playwright.sync_api import sync_playwright

HERE = pathlib.Path(__file__).resolve().parent
FRAMES = ["quan-ly-danh-sach", "tao-dot", "quan-ly-chi-tiet", "nhan-vien", "cai-dat"]

def font_css(d):
    if not d:
        return ""
    css = []
    for w in (400, 500, 600, 700):
        for sub in ("vietnamese", "latin-ext", "latin"):
            f = pathlib.Path(d) / f"roboto-{sub}-{w}-normal.woff2"
            if f.exists():
                css.append(f"@font-face{{font-family:Roboto;font-weight:{w};src:url('{f.as_uri()}')}}")
    return "\n".join(css)

with sync_playwright() as p:
    import glob, os
    exe = os.environ.get("CHROME") or next(iter(glob.glob("/opt/pw-browsers/chromium-*/chrome-linux*/chrome")), None)
    b = p.chromium.launch(executable_path=exe) if exe else p.chromium.launch()
    pg = b.new_page(viewport={"width": 1600, "height": 1000}, device_scale_factor=1.5)
    pg.goto((HERE / "mockup.html").as_uri(), wait_until="domcontentloaded")
    css = font_css(sys.argv[1] if len(sys.argv) > 1 else None)
    if css:
        pg.add_style_tag(content=css)
    pg.evaluate("document.fonts.ready")
    pg.wait_for_timeout(500)
    for f in FRAMES:
        pg.locator(f"#{f}").screenshot(path=str(HERE / f"{f}.png"))
        print("ok", f)
    b.close()
