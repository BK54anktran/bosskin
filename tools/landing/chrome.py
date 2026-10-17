"""Phần khung dùng chung của trang giới thiệu (landing/index.html, /en/) và trang trợ giúp (help/): MỘT danh sách mục menu.
Sửa menu ở đây → `python3 tools/landing/build_i18n.py` (ghi lại menu trong landing/index.html + dựng /en/) và
`python3 help/tools/build_help.py` (menu đầu trang + menu trượt của trợ giúp). CI `build_i18n.py --check` báo nếu index.html lệch."""

# (neo trên trang giới thiệu, nhãn tiếng Việt, nhãn tiếng Anh); mục cuối "Trợ giúp" trỏ sang /help/
NAV = [
    ('cai-dat', 'Cài đặt', 'Install'),
    ('video', 'Video', 'Video'),
    ('tinh-nang', 'Tính năng', 'Features'),
    ('vai-tro', 'Cho ai', "Who it's for"),
    ('bang-gia', 'Bảng giá', 'Pricing'),
    ('hoi-dap', 'Hỏi đáp', 'FAQ'),
]
HELP = ('Trợ giúp', 'Help')


def landing_nav():
    """<nav class="links"> của landing/index.html (bản tiếng Việt, nguồn)."""
    return ''.join(f'<a href="#{a}">{vi}</a>' for a, vi, _ in NAV) + f'<a href="help/">{HELP[0]}</a>'


def help_nav(lang, up='../'):
    """Liên kết đầu trang trợ giúp: mục trang giới thiệu (neo ở `up`) + "Trợ giúp" (trang hiện tại)."""
    i = 1 if lang == 'vi' else 2
    return (''.join(f'<a href="{up}#{n[0]}">{n[i]}</a>' for n in NAV)
            + f'<a class="on" href="index.html">{HELP[0 if lang == "vi" else 1]}</a>')


def help_side(lang, up='../'):
    i = 1 if lang == 'vi' else 2
    return (f'<a href="{up}">{"Trang chủ" if lang == "vi" else "Home"}</a>'
            + ''.join(f'<a href="{up}#{n[0]}">{n[i]}</a>' for n in NAV))
