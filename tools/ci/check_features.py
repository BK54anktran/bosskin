#!/usr/bin/env python3
"""V26: danh mục tính năng công ty phải giống nhau ở backend (core/CompanyFeatures.java) và app (company_feature_utils.dart):
cùng mã, cùng nhóm, cùng thứ tự, cùng tính năng 'cần'; mọi mã có nhãn dịch vi + en; mọi mã nằm trong bảng đường dẫn hoặc được liệt kê
là tính năng 'theo hành vi' (không có API riêng). Chạy: python3 tools/ci/check_features.py"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
java = (ROOT / "backend/src/main/java/com/bosskin/core/CompanyFeatures.java").read_text(encoding="utf-8")
dart = (ROOT / "frontend/lib/core/utils/company_feature_utils.dart").read_text(encoding="utf-8")
routes = (ROOT / "backend/src/main/java/com/bosskin/core/FeatureRoutes.java").read_text(encoding="utf-8")

# Java: f(ATT_SELF, "ATTENDANCE", CompanyModules.X|null, REQ...)
const = dict(re.findall(r'(\w+) = "(\w+)"', java))
jf = []
for m in re.finditer(r'f\((\w+), "(\w+)", [\w.]+((?:, \w+)*)\)', java):
    code = const[m.group(1)]
    req = [const[x.strip()] for x in m.group(3).split(",") if x.strip()]
    jf.append((code, m.group(2), req))

# Dart: CompanyFeatureDef('ATT_SELF', 'ATTENDANCE', ['ATT_SHEET'])
df = []
for m in re.finditer(r"CompanyFeatureDef\('(\w+)', '(\w+)'(?:, \[([^\]]*)\])?\)", dart):
    req = re.findall(r"'(\w+)'", m.group(3) or "")
    df.append((m.group(1), m.group(2), req))

errors = []
if jf != df:
    jc, dc = [x[0] for x in jf], [x[0] for x in df]
    errors.append(f"Danh mục backend ({len(jf)}) và app ({len(df)}) lệch nhau.")
    errors += [f"  chỉ backend: {c}" for c in jc if c not in dc] + [f"  chỉ app: {c}" for c in dc if c not in jc]
    errors += [f"  khác nhóm / 'cần': {a[0]}" for a, b in zip(jf, df) if a[0] == b[0] and a != b]

for lang in ("vi", "en"):
    arb = (ROOT / f"frontend/lib/l10n/app_{lang}.arb").read_text(encoding="utf-8")
    for code, group, _ in jf:
        key = "feature" + "".join(w.capitalize() for w in code.split("_"))
        if f'"{key}"' not in arb:
            errors.append(f"app_{lang}.arb thiếu {key}")
    for g in {x[1] for x in jf}:
        if f'"featureGroup{g.capitalize()}"' not in arb:
            errors.append(f"app_{lang}.arb thiếu featureGroup{g.capitalize()}")

# Tính năng không có đường dẫn riêng vì được kiểm trong nghiệp vụ / job / cài đặt (V26 giai đoạn 2 gắn dần).
BEHAVIOUR_ONLY = {"ATT_DEVICE", "ATT_NOSHIFT", "SHIFT_ADVANCED", "SHIFT_REMINDER", "PAY_TAX_INS", "PAY_EMPLOYER_COST",
                  "HR_CONTRACT_ALERT", "HR_DOCUMENT_ALERT"}
used = {const[x] for x in re.findall(r"CompanyFeatures\.(\w+)\)", routes) if x in const}
for code, _, _ in jf:
    if code not in used and code not in BEHAVIOUR_ONLY:
        errors.append(f"{code} không có trong bảng đường dẫn FeatureRoutes và không nằm trong BEHAVIOUR_ONLY")

if errors:
    print("\n".join(errors)); sys.exit(1)
print(f"OK: {len(jf)} tính năng khớp giữa backend và app, đủ nhãn vi + en.")
