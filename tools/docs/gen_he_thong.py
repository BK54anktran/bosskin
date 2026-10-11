#!/usr/bin/env python3
"""Sinh phần tài liệu hệ thống lấy thẳng từ code + DB, để docs không lệch khỏi code:

  docs/he-thong/api.md    ← @RequestMapping / @GetMapping… + requirePermission(...) trong controller
  docs/he-thong/csdl.md   ← information_schema của DB đã chạy hết migration Flyway
  docs/he-thong/quyen.md  ← bảng permissions + nơi dùng mã quyền trong BE / FE

Kèm kiểm tra chéo: mã quyền dùng trong code mà DB không có (và ngược lại), migration mới nhất trong repo
khác với flyway_schema_history của DB.

    MYSQL_CMD="docker exec -i bk-help mysql -uroot -phelppw bosskin" python3 tools/docs/gen_he_thong.py
    python3 tools/docs/gen_he_thong.py --check     # CI: báo lỗi nếu file đã commit khác kết quả sinh lại

Không có MYSQL_CMD → chỉ sinh api.md (csdl.md, quyen.md giữ nguyên). DB dùng để sinh phải là DB trống vừa migrate
(vd. container test), không cần dữ liệu thật.
"""
import os
import re
import subprocess
import sys
from collections import defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
JAVA = os.path.join(ROOT, 'backend/src/main/java/com/bosskin')
DART = os.path.join(ROOT, 'frontend/lib')
MIG = os.path.join(ROOT, 'backend/src/main/resources/db/migration')
OUT = os.path.join(ROOT, 'docs/he-thong')
HEAD = '<!-- Tự sinh bởi tools/docs/gen_he_thong.py — không sửa tay; sửa code rồi chạy lại. -->\n\n'
MAP_RE = re.compile(r'@(Get|Post|Put|Patch|Delete|Request)Mapping\s*(?:\(([^)]*)\))?')
PERM_RE = re.compile(r'require(Any|Approve)?Permission\s*\(\s*\w+\s*,\s*([^;]*?)\)\s*;')


def paths_of(args):
    if not args:
        return ['']
    m = re.search(r'(?:value|path)\s*=\s*(\{[^}]*\}|"[^"]*")', args) or re.match(r'\s*(\{[^}]*\}|"[^"]*")', args)
    return re.findall(r'"([^"]*)"', m.group(1)) if m else ['']


def method_of(kind, args):
    if kind != 'Request':
        return kind.upper()
    m = re.search(r'RequestMethod\.(\w+)', args or '')
    return m.group(1) if m else 'ANY'


def known_codes():
    """Mã quyền khai báo trong migration (INSERT INTO permissions …) — không cần DB."""
    codes = set()
    for f in os.listdir(MIG):
        for blk in re.findall(r'INSERT INTO permissions[^;]*;', open(os.path.join(MIG, f), encoding='utf-8').read(), re.S):
            codes |= set(re.findall(r"\(\s*'([A-Z][A-Z0-9_]+)'\s*,", blk))
    return codes


def body_at(src, i):
    """Thân hàm bắt đầu từ dấu { đầu tiên sau vị trí i (bỏ qua ngoặc trong chữ ký và trong chuỗi)."""
    depth, j, n = 0, i, len(src)
    def skip_str(k):
        q = src[k]
        k += 1
        while k < n and src[k] != q:
            k += 2 if src[k] == '\\' else 1
        return k + 1
    while j < n and src[j] != '{':
        if src[j] in '"\'':
            j = skip_str(j)
            continue
        if src[j] == ';' and depth == 0:
            return ''
        depth += {'(': 1, ')': -1}.get(src[j], 0)
        j += 1
    k, depth = j, 0
    while k < n:
        if src[k] in '"\'':
            k = skip_str(k)
            continue
        depth += {'{': 1, '}': -1}.get(src[k], 0)
        if depth == 0:
            return src[j:k + 1]
        k += 1
    return src[j:]


def java_consts():
    """static final String X = "CODE" trong toàn BE → để hiểu require(user, DocumentService.VIEW)."""
    out = {}
    for d, _, fs in os.walk(JAVA):
        for f in fs:
            if f.endswith('.java'):
                for n, v in re.findall(r'static\s+final\s+String\s+([A-Z_]+)\s*=\s*"([A-Z][A-Z0-9_]+|/[\w/{}.-]+)"',
                                       open(os.path.join(d, f), encoding='utf-8').read()):
                    out[(f[:-5], n)] = v
    return out


def normalize(src, consts, cls):
    """can("dashboard.view") → "DASHBOARD_VIEW"; DocumentService.VIEW / VIEW → "EMPLOYEE_DOCUMENT_VIEW"."""
    src = re.sub(r'\bcan\s*\(\s*"([a-z][a-z0-9_.]*)"', lambda m: 'can("' + m.group(1).upper().replace('.', '_') + '"', src)
    src = re.sub(r'\b([A-Z]\w+)\.([A-Z_]{2,})\b', lambda m: f'"{consts[(m.group(1), m.group(2))]}"'
                 if (m.group(1), m.group(2)) in consts else m.group(0), src)
    return re.sub(r'(?<![\w."])([A-Z_]{3,})(?![\w"(])', lambda m: f'"{consts[(cls, m.group(1))]}"'
                  if (cls, m.group(1)) in consts else m.group(0), src)


def parse_controllers():
    codes = known_codes()
    consts = java_consts()
    code_re = re.compile(r'"([A-Z][A-Z0-9_]+)"')
    res = []
    files = []
    for d, _, fs in os.walk(JAVA):
        files += [os.path.join(d, f) for f in fs if f.endswith('Controller.java')]
    for f in sorted(files):
        src = open(f, encoding='utf-8').read()
        cls = re.search(r'\bclass\s+(\w+)', src)
        if not cls:
            continue
        src = normalize(src, consts, cls.group(1))
        cls = re.search(r'\bclass\s+(\w+)', src)
        head, body = src[:cls.start()], src[cls.start():]
        base = ['']
        for m in MAP_RE.finditer(head):
            if m.group(1) == 'Request':
                base = paths_of(m.group(2))
        # Hàm phụ private trong controller (require, requireEdit, canView…) → mã quyền chúng kiểm
        helpers = {}
        for hm in re.finditer(r'private\s+(?:static\s+)?[\w<>, ?]+\s+(\w+)\s*\(', body):
            helpers[hm.group(1)] = body_at(body, hm.end() - 1)
        def codes_in(text, seen=()):
            out = []
            for pm in re.finditer(r'require(Any)?Permission\s*\(\s*\w+\s*,\s*([^;]*?)\)\s*;', text):
                cs = [c for c in code_re.findall(pm.group(2)) if c in codes]
                if pm.group(1) and len(cs) > 1:
                    out.append(' hoặc '.join(cs))
                    text = text.replace(pm.group(0), '')
            out += [c for c in code_re.findall(text) if c in codes]
            for name, hb in helpers.items():
                if name not in seen and re.search(r'\b' + name + r'\s*\(', text):
                    out += codes_in(hb, seen + (name,))
            return out
        rows = []
        for m in MAP_RE.finditer(body):
            if m.group(1) == 'Request' and not re.search(r'\s(?:public|private|protected)?\s*[\w<>, ?.]+\s+\w+\s*\(', body[m.end():m.end() + 400].split('{')[0]):
                continue
            mb = body_at(body, m.end())
            name = re.search(r'\s(\w+)\s*\(', body[m.end():m.end() + 600])
            perms = codes_in(mb)
            if 'requireApprovePermission' in mb and not perms:
                perms = ['quyền duyệt theo loại đơn']
            if base[0].startswith('/admin') or 'SystemAdmin' in os.path.basename(f):
                perms = perms or ['SYSTEM_ADMIN']
            for p in paths_of(m.group(2)):
                path = base[0] + p
                if path.startswith('/admin') and not path.startswith('/admin/auth') and not perms:
                    perms = ['SYSTEM_ADMIN']
                rows.append((method_of(m.group(1), m.group(2)), path, ', '.join(dict.fromkeys(perms)) or '—',
                             name.group(1) if name else ''))
        if rows:
            res.append((cls.group(1), os.path.relpath(f, ROOT).replace(os.sep, '/'), base, rows))
    return res


def gen_api():
    ctrls = parse_controllers()
    n = sum(len(c[3]) for c in ctrls)
    out = [HEAD, '# Danh sách API\n\n',
           f'{len(ctrls)} controller, {n} endpoint. Cột **Quyền** là mã quyền kiểm ở controller (`requirePermission`); '
           '"—" nghĩa là chỉ cần đăng nhập, phần kiểm tra (chính chủ, phạm vi phòng ban, vai trò) nằm ở service. '
           '`/api/v1/public/**`, `/api/v1/auth/login|refresh|logout|2fa/**`, `/admin/auth/**`, `/actuator/health` không cần đăng nhập; '
           '`/admin/**` chỉ nhận token quản trị hệ thống (xem [bảo mật](bao-mat.md)).\n\n']
    out.append('| Controller | Gốc | Số endpoint |\n|---|---|---|\n')
    for c, f, base, rows in ctrls:
        out.append(f'| [{c}](#{c.lower()}) | `{" , ".join(base) or "/"}` | {len(rows)} |\n')
    for c, f, base, rows in ctrls:
        out.append(f'\n## {c}\n\n`{f}`\n\n| Method | Đường dẫn | Quyền | Hàm |\n|---|---|---|---|\n')
        for meth, path, perm, name in rows:
            out.append(f'| {meth} | `{path}` | {perm} | `{name}` |\n')
    return ''.join(out), ctrls


def mysql(sql):
    cmd = os.environ.get('MYSQL_CMD')
    r = subprocess.run(cmd + ' -N -B --default-character-set=utf8mb4', shell=True, input=sql, capture_output=True, text=True)
    if r.returncode:
        sys.exit('MYSQL_CMD lỗi: ' + r.stderr)
    return [l.split('\t') for l in r.stdout.splitlines() if l]


GROUPS = [
    ('Công ty & tài khoản', r'^(compan|users|system_admins|roles|role_|user_|permissions|login_|refresh|trusted|two_factor|fcm|trial)'),
    ('Tổ chức & nhân viên', r'^(departments|positions|employee|dependents|job_hist|profile_edit|document_types|employee_documents)'),
    ('Hợp đồng', r'^(labor_contract|contract)'),
    ('Ca làm', r'^(work_shifts|shift)'),
    ('Chấm công', r'^(attendance)'),
    ('Nghỉ phép', r'^(leave)'),
    ('Lịch & ngày lễ', r'^(holiday|work_calendar)'),
    ('Lương & thuế', r'^(salary|payroll|formula|tax_)'),
    ('Nhật ký, Excel, khác', r''),
]


def gen_db():
    ver = mysql("SELECT version, description FROM flyway_schema_history WHERE success=1 ORDER BY installed_rank DESC LIMIT 1;")[0]
    tables = mysql("SELECT table_name, IFNULL(table_comment,'') FROM information_schema.tables WHERE table_schema=DATABASE() "
                   "AND table_type='BASE TABLE' AND table_name<>'flyway_schema_history' ORDER BY table_name;")
    cols = defaultdict(list)
    for t, c, ty, nl, d, k, ex, cm in mysql(
            "SELECT table_name, column_name, column_type, is_nullable, IFNULL(column_default,'∅'), column_key, extra, IFNULL(column_comment,'') "
            "FROM information_schema.columns WHERE table_schema=DATABASE() ORDER BY table_name, ordinal_position;"):
        cols[t].append((c, ty, nl, d, k, ex, cm))
    fks = defaultdict(dict)
    for t, c, rt, rc, dr in mysql(
            "SELECT k.table_name, k.column_name, k.referenced_table_name, k.referenced_column_name, r.delete_rule "
            "FROM information_schema.key_column_usage k JOIN information_schema.referential_constraints r "
            "ON r.constraint_schema=k.constraint_schema AND r.constraint_name=k.constraint_name "
            "WHERE k.table_schema=DATABASE() AND k.referenced_table_name IS NOT NULL;"):
        fks[t][c] = (rt, rc, dr)
    uniq = defaultdict(list)
    for t, name, cs in mysql(
            "SELECT table_name, index_name, GROUP_CONCAT(column_name ORDER BY seq_in_index) FROM information_schema.statistics "
            "WHERE table_schema=DATABASE() AND non_unique=0 AND index_name<>'PRIMARY' GROUP BY table_name, index_name ORDER BY 1,2;"):
        uniq[t].append(cs.replace(',', ', '))
    grouped = defaultdict(list)
    for t, cm in tables:
        g = next(name for name, rx in GROUPS if re.search(rx, t))
        grouped[g].append((t, cm))
    out = [HEAD, '# Cơ sở dữ liệu\n\n',
           f'MySQL 8, utf8mb4. Lược đồ tại migration **V{ver[0]} – {ver[1]}**, {len(tables)} bảng (không kể `flyway_schema_history`). '
           'Mọi thay đổi lược đồ đi qua file Flyway mới `backend/src/main/resources/db/migration/V<n>__<mô_tả>.sql`, '
           'không sửa file cũ; Hibernate chạy `ddl-auto: validate` nên entity lệch DB thì app không khởi động. '
           'Hầu hết bảng nghiệp vụ có `company_id` (tách dữ liệu theo công ty — xem [kiến trúc](kien-truc.md#da-cong-ty)).\n\n'
           'Ký hiệu: 🔑 khoá chính · ↗ khoá ngoại (bảng.cột, hành vi khi xoá) · `∅` không có mặc định.\n\n'
           '## Mục lục\n\n']
    for g, _ in GROUPS:
        if grouped[g]:
            out.append(f'- **{g}**: ' + ', '.join(f'[`{t}`](#{t})' for t, _ in grouped[g]) + '\n')
    for g, _ in GROUPS:
        if not grouped[g]:
            continue
        out.append(f'\n## {g}\n')
        for t, cm in grouped[g]:
            out.append(f'\n### {t}\n\n' + (f'{cm}\n\n' if cm else ''))
            if uniq[t]:
                out.append('Duy nhất: ' + ' · '.join(f'({u})' for u in uniq[t]) + '\n\n')
            out.append('| Cột | Kiểu | Null | Mặc định | Ghi chú |\n|---|---|---|---|---|\n')
            for c, ty, nl, d, k, ex, ccm in cols[t]:
                note = []
                if k == 'PRI':
                    note.append('🔑')
                if c in fks[t]:
                    rt, rc, dr = fks[t][c]
                    note.append(f'↗ [{rt}](#{rt}).{rc}' + (f' ({dr.lower()})' if dr != 'RESTRICT' and dr != 'NO ACTION' else ''))
                if 'auto_increment' in ex:
                    note.append('tự tăng')
                if ccm:
                    note.append(ccm.replace('|', '/'))
                out.append(f'| `{c}` | {ty} | {"có" if nl == "YES" else ""} | {d.replace("|", "/")} | {" ".join(note)} |\n')
    return ''.join(out), ver


def gen_perm(ctrls):
    perms = mysql("SELECT code, module, IFNULL(required_rule,''), description FROM permissions ORDER BY module, id;")
    codes = {p[0] for p in perms}
    used_be, used_fe = defaultdict(set), defaultdict(set)
    lit = re.compile(r'"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)"')
    for base, store, ext in ((JAVA, used_be, '.java'), (DART, used_fe, '.dart')):
        for d, _, fs in os.walk(base):
            for f in fs:
                if f.endswith(ext):
                    for c in re.findall(r"""["']([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)["']""", open(os.path.join(d, f), encoding='utf-8').read()):
                        store[c].add(f.rsplit('.', 1)[0])
    ep = defaultdict(int)
    for _, _, _, rows in ctrls:
        for r in rows:
            for c in re.findall(r'[A-Z][A-Z0-9_]+', r[2]):
                ep[c] += 1
    out = [HEAD, '# Danh mục quyền\n\n',
           f'{len(perms)} mã quyền (bảng `permissions`, thêm bằng migration). Vai trò của công ty gom một tập quyền + phạm vi phòng ban; '
           'cách kiểm tra quyền và phạm vi ở [phân quyền](phan-quyen.md). **Cần** = quyền phải có kèm (`required_rule`), '
           'màn Phân quyền tự tích theo. Cột **Endpoint** đếm số API kiểm mã này trực tiếp ở controller.\n\n']
    cur = None
    for code, mod, req, desc in perms:
        if mod != cur:
            out.append(f'\n## {mod}\n\n| Mã | Mô tả | Cần | Endpoint | Dùng ở FE |\n|---|---|---|---|---|\n')
            cur = mod
        fe = ', '.join(sorted(used_fe.get(code, ())))[:80]
        out.append(f'| `{code}` | {desc} | {f"`{req}`" if req else ""} | {ep.get(code, "") or ""} | {fe} |\n')
    # Kiểm tra chéo: chỉ xét chuỗi xuất hiện trong ngữ cảnh quyền
    ctx = re.compile(r'(?:requirePermission|requireAnyPermission|hasPermission|can|permissions?\.contains|hasAny)\s*\([^;]*?["\']([A-Z][A-Z0-9_]+)["\']')
    missing = set()
    for base, ext in ((JAVA, '.java'), (DART, '.dart')):
        for d, _, fs in os.walk(base):
            for f in fs:
                if f.endswith(ext):
                    s = open(os.path.join(d, f), encoding='utf-8').read()
                    s = re.sub(r'\bcan\s*\(\s*["\']([a-z][a-z0-9_.]*)["\']', lambda m: 'can("' + m.group(1).upper().replace('.', '_') + '"', s)
                    for c in ctx.findall(s):
                        if c not in codes and not c.startswith('ROLE_'):
                            missing.add((c, f))
    unused = sorted(c for c in codes if c not in used_be and c not in used_fe)
    out.append('\n## Kiểm tra đồng bộ\n\n')
    out.append('- Mã quyền dùng trong code nhưng DB không có: ' + (', '.join(f'`{c}` ({f})' for c, f in sorted(missing)) or 'không có ✔') + '\n')
    out.append('- Mã quyền có trong DB nhưng không code nào dùng: ' + (', '.join(f'`{c}`' for c in unused) or 'không có ✔') + '\n')
    return ''.join(out), missing


def latest_migration():
    vs = [int(re.match(r'V(\d+)__', f).group(1)) for f in os.listdir(MIG) if re.match(r'V\d+__', f)]
    return max(vs)


def main():
    check = '--check' in sys.argv
    files = {}
    api, ctrls = gen_api()
    files['api.md'] = api
    problems = []
    if os.environ.get('MYSQL_CMD'):
        db, ver = gen_db()
        files['csdl.md'] = db
        if int(ver[0]) != latest_migration():
            problems.append(f'DB đang ở V{ver[0]} nhưng repo có V{latest_migration()} — chạy app một lần cho Flyway migrate rồi sinh lại')
        files['quyen.md'], missing = gen_perm(ctrls)
        if missing:
            problems.append('mã quyền không có trong DB: ' + ', '.join(sorted(c for c, _ in missing)))
    elif check:
        # Không có DB: vẫn kiểm csdl.md ghi đúng migration mới nhất
        p = os.path.join(OUT, 'csdl.md')
        if os.path.exists(p):
            m = re.search(r'migration \*\*V(\d+)', open(p, encoding='utf-8').read())
            if m and int(m.group(1)) != latest_migration():
                problems.append(f'docs/he-thong/csdl.md ghi V{m.group(1)} nhưng repo có V{latest_migration()} — sinh lại với MYSQL_CMD')
    os.makedirs(OUT, exist_ok=True)
    for name, text in files.items():
        p = os.path.join(OUT, name)
        old = open(p, encoding='utf-8').read() if os.path.exists(p) else None
        if check:
            if old != text:
                problems.append(f'docs/he-thong/{name} lệch code — chạy lại tools/docs/gen_he_thong.py')
        elif old != text:
            open(p, 'w', encoding='utf-8').write(text)
            print('ghi', name)
    for p in problems:
        print('✘', p)
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()
