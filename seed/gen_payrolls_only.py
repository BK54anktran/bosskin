"""
Generate payroll-only INSERTs for companies 2-10 that already exist in DB.
Reads employee/salary_grade info from DB, generates payroll rows for Jan 2025 - May 2026.
Usage: python gen_payrolls_only.py [company_id_start] [company_id_end]
       python gen_payrolls_only.py   # generates for all companies 2-10
"""

import sys, io, random, subprocess
from datetime import date, datetime, timedelta

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def q(s):
    if s is None: return "NULL"
    return "'" + str(s).replace("'", "''") + "'"
def qd(d):
    if d is None: return "NULL"
    return q(d.strftime("%Y-%m-%d"))
def qdt(dt):
    if dt is None: return "NULL"
    return q(dt.strftime("%Y-%m-%d %H:%M:%S"))

def run_sql(sql):
    result = subprocess.run(
        ["mysql", "-ubosskin", "-pngocanhbk54", "bosskin", "-e", sql, "--skip-column-names", "-s"],
        capture_output=True, text=True
    )
    return result.stdout.strip()

def get_companies(start_idx, end_idx):
    sql = f"SELECT id, name FROM companies WHERE id BETWEEN {start_idx} AND {end_idx} ORDER BY id;"
    out = run_sql(sql)
    rows = []
    for line in out.splitlines():
        parts = line.split('\t')
        if len(parts) >= 2:
            rows.append({"id": int(parts[0]), "name": parts[1]})
    return rows

def get_employees(company_id):
    sql = (f"SELECT e.id, e.join_date, sg.base_rate, sg.id as sg_id "
           f"FROM employees e JOIN salary_grades sg ON e.salary_grade_id = sg.id "
           f"WHERE e.company_id = {company_id} AND e.deleted = 0 ORDER BY e.id;")
    out = run_sql(sql)
    rows = []
    for line in out.splitlines():
        parts = line.split('\t')
        if len(parts) >= 4:
            rows.append({
                "id": int(parts[0]),
                "join_date": date.fromisoformat(parts[1]),
                "base_salary": int(float(parts[2])),
                "sg_id": int(parts[3]),
            })
    return rows

def get_max_payroll_id():
    out = run_sql("SELECT COALESCE(MAX(id), 0) FROM payrolls;")
    return int(out.strip() or 0)

def get_existing_payroll_keys(company_id):
    sql = (f"SELECT employee_id, year, month FROM payrolls p "
           f"JOIN employees e ON p.employee_id = e.id "
           f"WHERE e.company_id = {company_id};")
    out = run_sql(sql)
    keys = set()
    for line in out.splitlines():
        parts = line.split('\t')
        if len(parts) == 3:
            keys.add((int(parts[0]), int(parts[1]), int(parts[2])))
    return keys

def generate_payrolls(company_id, emp_rows, existing_keys, prc_start, rng):
    payroll_months = []
    cur = date(2025, 1, 1)
    while cur <= date(2026, 6, 1):
        payroll_months.append((cur.year, cur.month))
        cur = (cur.replace(day=28) + timedelta(days=4)).replace(day=1)

    prv = []
    prc = prc_start

    for (yr, mo) in payroll_months:
        pf = date(yr, mo, 1)
        pt = (pf.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)

        for emp in emp_rows:
            if emp["join_date"] > pt:
                continue
            key = (emp["id"], yr, mo)
            if key in existing_keys:
                continue

            prid = prc + 1; prc += 1
            base = emp["base_salary"]
            work_days = rng.randint(18, 22)
            day_h = round(work_days * 8.0, 2)
            day_ot = round(rng.uniform(0, 8), 2)
            allow = rng.choice([0, 500_000, 1_000_000])
            bonus = 0 if mo != 12 else rng.choice([0, 1_000_000, 3_000_000])
            ot_pay = round(base / 22 / 8 * day_ot * 1.5, 0)
            gross = round(base * work_days / 22 + allow + bonus + ot_pay, 0)
            si = round(gross * 0.08, 0)
            hi = round(gross * 0.015, 0)
            ui = round(gross * 0.01, 0)
            txbl = max(0, gross - si - hi - ui - 11_000_000)
            if txbl <= 5e6:       pit = txbl * 0.05
            elif txbl <= 10e6:    pit = 250000 + (txbl - 5e6) * 0.10
            elif txbl <= 18e6:    pit = 750000 + (txbl - 10e6) * 0.15
            elif txbl <= 32e6:    pit = 1950000 + (txbl - 18e6) * 0.20
            elif txbl <= 52e6:    pit = 4750000 + (txbl - 32e6) * 0.25
            elif txbl <= 80e6:    pit = 9750000 + (txbl - 52e6) * 0.30
            else:                 pit = 18150000 + (txbl - 80e6) * 0.35
            pit = round(pit, 0)
            net = round(gross - si - hi - ui - pit, 0)

            recent = yr == 2026 and mo >= 5
            if recent:
                st = "DRAFT"; app_at = "NULL"; paid_at = "NULL"
            elif yr == 2026 and mo == 4:
                st = "APPROVED"
                app_at = qdt(datetime(2026, 4, 5, 9, 0)); paid_at = "NULL"
            else:
                nxt_mo = mo + 1 if mo < 12 else 1
                nxt_yr = yr if mo < 12 else yr + 1
                st = "PAID"
                app_at = qdt(datetime(nxt_yr, nxt_mo, 5, 9, 0))
                paid_at = qdt(datetime(nxt_yr, nxt_mo, 10, 14, 0))

            prv.append(
                f"({prid},{emp['id']},{yr},{mo},{base},"
                f"{allow},{bonus},{ot_pay},{gross},"
                f"{si},{hi},{ui},{pit},0,{net},"
                f"{q(st)},NULL,{paid_at},{app_at},NOW(),NOW(),"
                f"{work_days},0,NULL,"
                f"{day_h},0,{day_ot},0,"
                f"'DAILY',22,"
                f"{qd(pf)},{qd(pt)},"
                f"NULL,NULL,NULL,"
                f"{emp['sg_id']},NULL,NULL)"
            )

    return prv, prc

def main():
    start_cid = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    end_cid   = int(sys.argv[2]) if len(sys.argv) > 2 else 13  # company IDs up to 13

    companies = get_companies(start_cid, end_cid)
    if not companies:
        print(f"-- No companies found between id {start_cid} and {end_cid}")
        return

    max_pr_id = get_max_payroll_id()
    prc = max_pr_id

    lines = []
    e = lines.append
    e("SET FOREIGN_KEY_CHECKS=0;")
    e("")

    CHUNK = 500

    for c in companies:
        cid = c["id"]
        cname = c["name"]
        e(f"-- ═══════════════ Payrolls for {cname} (id={cid}) ═══════════════")

        emp_rows = get_employees(cid)
        if not emp_rows:
            e(f"-- No employees found for company {cid}, skipping")
            e("")
            continue

        existing_keys = get_existing_payroll_keys(cid)
        rng = random.Random(cid * 9999)

        prv, prc = generate_payrolls(cid, emp_rows, existing_keys, prc, rng)

        if not prv:
            e(f"-- All payrolls already exist for company {cid}")
            e("")
            continue

        for i in range(0, len(prv), CHUNK):
            e("INSERT INTO payrolls (id,employee_id,year,month,base_salary,")
            e("  allowance,bonus,overtime_pay,gross_salary,")
            e("  social_insurance,health_insurance,unemployment_insurance,personal_income_tax,other_deductions,net_salary,")
            e("  status,note,paid_at,approved_at,created_at,updated_at,")
            e("  present_days,total_overtime_hours,custom_deductions,")
            e("  day_hours,night_hours,day_ot,night_ot,")
            e("  pay_type,standard_work_days,")
            e("  period_from,period_to,")
            e("  income_entries,allowance_entries,custom_formula,")
            e("  salary_grade_id,salary_grade_code,salary_grade_name) VALUES")
            e(",\n".join(prv[i:i+CHUNK]) + ";")
            e("")

        e(f"-- Done: {len(prv)} payroll rows for {cname}")
        e("")

    e("SET FOREIGN_KEY_CHECKS=1;")
    print("\n".join(lines))

if __name__ == "__main__":
    main()
