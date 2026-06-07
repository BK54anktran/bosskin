"""
Seed data generator for Bosskin HR system.
Generates one company at a time.
Usage: python generate_seed.py [company_index 1-10]

Schema notes (verified from DB):
- positions: (id, name, code, department_id, description, created_at, updated_at, deleted)
- salary_grades: (id, code, name, pay_type, base_rate, created_at, updated_at, department_id, deleted)
  NO position_id in salary_grades!
- employees: NO base_salary column; salary via salary_grade.base_rate
- shift_assignments: no snapshot_type column
- attendances: no check_in/out lat/lon in col order matters — use named columns
- leave_grants: (grant_days, grant_hours, used_days, used_hours) — NOT amount/used_amount
"""

import sys, io, random
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

COMPANIES = [
    {"idx":1,  "name":"TechVision Corp",        "code":"TECHVISION",  "domain":"techvision.vn",  "phone":"0281234001","email":"hr@techvision.vn", "address":"123 Nguyen Hue, Q1, HCM",     "industry":"tech"},
    {"idx":2,  "name":"GreenFood JSC",           "code":"GREENFOOD",   "domain":"greenfood.vn",   "phone":"0281234002","email":"hr@greenfood.vn",  "address":"456 Le Loi, Q1, HCM",         "industry":"food"},
    {"idx":3,  "name":"MegaBuild Construction",  "code":"MEGABUILD",   "domain":"megabuild.vn",   "phone":"0281234003","email":"hr@megabuild.vn",  "address":"789 Tran Hung Dao, Q5, HCM",  "industry":"construction"},
    {"idx":4,  "name":"HealthPlus Medical",      "code":"HEALTHPLUS",  "domain":"healthplus.vn",  "phone":"0281234004","email":"hr@healthplus.vn", "address":"321 CMT8, Q3, HCM",           "industry":"medical"},
    {"idx":5,  "name":"LogiSwift Transport",     "code":"LOGISWIFT",   "domain":"logiswift.vn",   "phone":"0281234005","email":"hr@logiswift.vn",  "address":"654 Nguyen Van Linh, Q7, HCM","industry":"logistics"},
    {"idx":6,  "name":"EduBright Academy",       "code":"EDUBRIGHT",   "domain":"edubright.vn",   "phone":"0281234006","email":"hr@edubright.vn",  "address":"111 Dien Bien Phu, Q10, HCM", "industry":"education"},
    {"idx":7,  "name":"FinanceFirst Bank",       "code":"FINANCEFIRST","domain":"financefirst.vn","phone":"0281234007","email":"hr@financefirst.vn","address":"222 Hai Ba Trung, Q1, HCM",  "industry":"finance"},
    {"idx":8,  "name":"RetailMax Group",         "code":"RETAILMAX",   "domain":"retailmax.vn",   "phone":"0281234008","email":"hr@retailmax.vn",  "address":"333 Ly Thuong Kiet, Q10, HCM","industry":"retail"},
    {"idx":9,  "name":"ManufacturePro VN",       "code":"MANUFPRO",    "domain":"manufpro.vn",    "phone":"0281234009","email":"hr@manufpro.vn",   "address":"444 KCN Tan Binh, HCM",       "industry":"manufacturing"},
    {"idx":10, "name":"TravelGo Tourism",        "code":"TRAVELGO",    "domain":"travelgo.vn",    "phone":"0281234010","email":"hr@travelgo.vn",   "address":"555 Bui Vien, Q1, HCM",       "industry":"tourism"},
]

DEPT_TEMPLATES = {
    "tech":         [("Ban Giam Doc","BGD"),("Phong Ky Thuat","KT"),("Phong Phat Trien San Pham","PTSP"),("Phong Kinh Doanh","KD"),("Phong Marketing","MKT"),("Phong Nhan Su","NS"),("Phong Tai Chinh","TC"),("Phong CSKH","CSKH"),("Phong QA","QA"),("Phong Ha Tang","HT"),("Phong An Ninh Mang","ANM"),("Phong Du Lieu","DL"),("Phong UX Design","UX"),("Phong Phap Ly","PL"),("Phong Hanh Chinh","HC")],
    "food":         [("Ban Giam Doc","BGD"),("Phong San Xuat","SX"),("Phong Chat Luong","CL"),("Phong Kinh Doanh","KD"),("Phong Marketing","MKT"),("Phong Nhan Su","NS"),("Phong Tai Chinh","TC"),("Phong Cung Ung","CU"),("Phong R&D","RD"),("Phong Kho Van","KV"),("Phong CSKH","CSKH"),("Phong Hanh Chinh","HC"),("Phong Phap Ly","PL"),("Phong ATVSTP","AT"),("Phong Xuat Nhap Khau","XNK")],
    "construction": [("Ban Giam Doc","BGD"),("Phong Ky Thuat","KT"),("Phong Thi Cong","TC"),("Phong Kinh Doanh","KD"),("Phong Thiet Ke","TK"),("Phong Nhan Su","NS"),("Phong Tai Chinh","TCH"),("Phong Mua Sam","MS"),("Phong Du Toan","DT"),("Phong An Toan","ATLD"),("Phong Hanh Chinh","HC"),("Phong Phap Ly","PL"),("Phong Co Dien","CD"),("Phong Kiem Soat CL","KSCL"),("Ban Quan Ly DA","BQLDA")],
    "medical":      [("Ban Giam Doc","BGD"),("Khoa Noi","KN"),("Khoa Ngoai","KNG"),("Khoa San","KS"),("Khoa Nhi","KNH"),("Khoa Cap Cuu","KCC"),("Phong Duoc","PD"),("Phong Xet Nghiem","XN"),("Phong Chan Doan Hinh Anh","CDHA"),("Phong Nhan Su","NS"),("Phong Tai Chinh","TC"),("Phong Hanh Chinh","HC"),("Phong CSVC","CSVC"),("Phong Kiem Soat NK","KSNK"),("Phong CNTT","CNTT")],
    "logistics":    [("Ban Giam Doc","BGD"),("Phong Van Tai","VT"),("Phong Kho Van","KV"),("Phong Kinh Doanh","KD"),("Phong Hai Quan","HQ"),("Phong Nhan Su","NS"),("Phong Tai Chinh","TC"),("Phong CSKH","CSKH"),("Phong Dieu Phoi","DP"),("Phong Cong Nghe","CN"),("Phong An Toan","AT"),("Phong Hanh Chinh","HC"),("Phong Mua Sam","MS"),("Phong Phap Ly","PL"),("Trung Tam Phan Loai","TTPL")],
    "education":    [("Ban Giam Doc","BGD"),("Phong Giang Day CB","GDCB"),("Phong Giang Day NC","GDNC"),("Phong Tuyen Sinh","TS"),("Phong Hoc Vu","HV"),("Phong Nhan Su","NS"),("Phong Tai Chinh","TC"),("Phong CNTT","CNTT"),("Phong Marketing","MKT"),("Phong Hop Tac","HT"),("Phong Nghien Cuu","NC"),("Phong Hanh Chinh","HC"),("Phong CSVC","CSVC"),("Phong Kiem Dinh CL","KDCL"),("Phong Doi Ngoai","DN")],
    "finance":      [("Ban Giam Doc","BGD"),("Phong Tin Dung","TD"),("Phong Ke Toan","KT"),("Phong Kinh Doanh","KD"),("Phong TTQT","TTQT"),("Phong Nhan Su","NS"),("Phong QLRR","QLRR"),("Phong CNTT","CNTT"),("Phong Marketing","MKT"),("Phong Phap Ly","PL"),("Phong Kiem Toan","KiT"),("Phong Hanh Chinh","HC"),("Phong Ngan Quy","NQ"),("Phong Phat Trien SP","PTSP"),("Phong CSKH","CSKH")],
    "retail":       [("Ban Giam Doc","BGD"),("Phong Ban Hang","BH"),("Phong Kho Van","KV"),("Phong Marketing","MKT"),("Phong Mua Hang","MH"),("Phong Nhan Su","NS"),("Phong Tai Chinh","TC"),("Phong CNTT","CNTT"),("Phong CSKH","CSKH"),("Phong Kiem Soat CL","KSCL"),("Phong Hanh Chinh","HC"),("Phong Phap Ly","PL"),("Phong Trung Bay","TB"),("Phong TMDT","TMDT"),("Phong Phat Trien","PT")],
    "manufacturing":[("Ban Giam Doc","BGD"),("Phong San Xuat A","SXA"),("Phong San Xuat B","SXB"),("Phong Ky Thuat","KT"),("Phong Chat Luong","CL"),("Phong Nhan Su","NS"),("Phong Tai Chinh","TC"),("Phong Mua Sam","MS"),("Phong R&D","RD"),("Phong Kho Van","KV"),("Phong An Toan","AT"),("Phong Hanh Chinh","HC"),("Phong Co Dien","CD"),("Phong Kinh Doanh","KD"),("Phong Moi Truong","MT")],
    "tourism":      [("Ban Giam Doc","BGD"),("Phong Tour TN","TTN"),("Phong Tour QT","TQT"),("Phong Kinh Doanh","KD"),("Phong Marketing","MKT"),("Phong Nhan Su","NS"),("Phong Tai Chinh","TC"),("Phong CSKH","CSKH"),("Phong Dat Phong","DP"),("Phong Ve May Bay","VMB"),("Phong Hanh Chinh","HC"),("Phong Phap Ly","PL"),("Phong Cong Nghe","CN"),("Phong Doi Tac","DT"),("Phong Noi Dung","ND")],
}

# 10 shift templates
SHIFT_TEMPLATES = [
    # name, code_prefix, type, start, end, break_start, break_end, work_min, color
    ("Ca Sang",        "CAS",  "WORK",     "08:00","17:00","12:00","13:00",480,"#1976D2"),
    ("Ca Chieu",       "CAC",  "WORK",     "13:00","22:00","17:30","18:00",480,"#388E3C"),
    ("Ca Toi",         "CAT",  "WORK",     "22:00","06:00",None,   None,   480,"#7B1FA2"),
    ("Ca Hanh Chinh",  "CAHC", "WORK",     "08:30","17:30","12:00","13:00",480,"#0288D1"),
    ("Ca Linh Hoat",   "CALH", "WORK",     "09:00","18:00","12:30","13:30",480,"#F57C00"),
    ("Nua Ca Sang",    "NCS",  "HALF_AM",  "08:00","12:00",None,   None,   240,"#0097A7"),
    ("Nua Ca Chieu",   "NCC",  "HALF_PM",  "13:00","17:00",None,   None,   240,"#00796B"),
    ("Ca Nghi",        "CAN",  "DAY_OFF",  None,   None,   None,   None,   0,  "#9E9E9E"),
    ("Ngay Le",        "NGLE", "HOLIDAY",  None,   None,   None,   None,   0,  "#E53935"),
    ("Ca Tang Ca",     "CATG", "WORK",     "07:00","19:00","12:00","13:00",660,"#AD1457"),
]

LAST_NAMES = ["Nguyen","Tran","Le","Pham","Hoang","Huynh","Phan","Vu","Dang","Bui","Do","Ho","Ngo","Duong","Ly"]
MID_M = ["Van","Thanh","Minh","Quoc","Huu","Duc","Xuan","Trong","Anh","Khac"]
MID_F = ["Thi","Ngoc","Thuy","Kim","Lan","Thu","My","Thanh","Hong","Phuong"]
FIRST_M = ["An","Binh","Cuong","Dung","Phong","Giang","Hung","Khoa","Long","Minh","Nam","Phi","Quan","Son","Tai","Uy","Vinh","Xuan","Hao","Kien"]
FIRST_F = ["An","Bich","Chi","Dieu","Phuong","Giang","Huong","Khanh","Lan","Mai","Ngan","Oanh","Quynh","Sang","Trang","Uyen","Van","Xuan","Yen","Linh"]
BANKS = ["Vietcombank","Techcombank","BIDV","Agribank","MB Bank","VPBank","ACB","Sacombank"]

def rname(rng, g):
    ln = rng.choice(LAST_NAMES)
    mn = rng.choice(MID_M if g=="MALE" else MID_F)
    fn = rng.choice(FIRST_M if g=="MALE" else FIRST_F)
    return f"{ln} {mn} {fn}"

def generate(company_idx, off):
    cfg = COMPANIES[company_idx - 1]
    ind = cfg["industry"]
    depts_def = DEPT_TEMPLATES[ind]
    rng = random.Random(company_idx * 9999)
    lines = []
    e = lines.append

    CID    = off["company"] + company_idx
    DB     = off["dept"]
    PB     = off["position"]
    SGB    = off["salary_grade"]
    EB     = off["employee"]
    UB     = off["user"]
    RB     = off["role"]
    SHB    = off["shift"]
    SAB    = off["shift_assign"]
    ATB    = off["attendance"]
    LTB    = off["leave_type"]
    LGB    = off["leave_grant"]
    LRB    = off["leave_request"]
    PRB    = off["payroll"]

    e(f"-- ═══════════════════════════════════════════════")
    e(f"-- COMPANY {company_idx}: {cfg['name']} (id={CID})")
    e(f"-- ═══════════════════════════════════════════════")
    e("SET FOREIGN_KEY_CHECKS=0;")
    e("")

    # ── 1. Company ─────────────────────────────────────────────────────────
    e("-- 1. Company")
    e(f"INSERT INTO companies (id,name,code,domain,phone,email,address,active,standard_work_days,created_at,updated_at) VALUES "
      f"({CID},{q(cfg['name'])},{q(cfg['code'])},{q(cfg['domain'])},{q(cfg['phone'])},{q(cfg['email'])},{q(cfg['address'])},1,22,NOW(),NOW());")
    e("")

    # ── 2. Departments ─────────────────────────────────────────────────────
    e("-- 2. Departments (15)")
    dept_ids = []
    dv = []
    for i,(dn,dc) in enumerate(depts_def):
        did = DB + i + 1
        dept_ids.append(did)
        dv.append(f"({did},{CID},{q(dn)},{q(dc+str(CID))},NULL,NULL,0,0,NOW(),NOW())")
    e("INSERT INTO departments (id,company_id,name,code,description,manager_id,level,deleted,created_at,updated_at) VALUES")
    e(",\n".join(dv)+";")
    e("")

    # ── 3. Positions (3 per dept) ─────────────────────────────────────────
    e("-- 3. Positions (45 total, 3/dept)")
    POS_NAMES = ["Truong phong","Pho phong","Chuyen vien"]
    pos_by_dept = {}  # dept_id -> [pos_id, ...]
    pv = []
    pc = 0
    for di,did in enumerate(dept_ids):
        pos_by_dept[did] = []
        for pi,pn in enumerate(POS_NAMES):
            pid = PB + pc + 1
            pc += 1
            pcode = f"P{CID}D{di+1}P{pi+1}"
            pos_by_dept[did].append(pid)
            pv.append(f"({pid},{q(pn)},{q(pcode)},{did},NULL,NOW(),NOW(),0)")
    e("INSERT INTO positions (id,name,code,department_id,description,created_at,updated_at,deleted) VALUES")
    e(",\n".join(pv)+";")
    e("")

    # ── 4. Salary Grades (1 per dept, tied to dept not position) ──────────
    # salary_grades has department_id (not position_id)
    e("-- 4. Salary Grades (3 per dept: senior/mid/junior)")
    sg_by_dept_rank = {}  # (dept_id, rank) -> sg_id
    sgv = []
    sgc = 0
    SALARIES = [25_000_000, 15_000_000, 9_000_000]
    for di,did in enumerate(dept_ids):
        sg_by_dept_rank[did] = {}
        for rank in range(3):
            sgid = SGB + sgc + 1
            sgc += 1
            sg_by_dept_rank[did][rank] = sgid
            sgcode = f"SG{sgid}"
            sgname = f"Bac luong {['Senior','Mid','Junior'][rank]}"
            sgv.append(f"({sgid},{q(sgcode)},{q(sgname)},'DAILY',{SALARIES[rank]},NOW(),NOW(),{did},0)")
    e("INSERT INTO salary_grades (id,code,name,pay_type,base_rate,created_at,updated_at,department_id,deleted) VALUES")
    e(",\n".join(sgv)+";")
    e("")

    # ── 5. Roles ───────────────────────────────────────────────────────────
    e("-- 5. Roles")
    role_defs = [("Admin Cong Ty",True,True),("HR Manager",False,True),("Truong Phong",False,False),("Nhan Vien",True,False)]
    role_ids = []
    rv = []
    for ri,(rn,isdef,vall) in enumerate(role_defs):
        rid = RB + ri + 1
        role_ids.append(rid)
        rv.append(f"({rid},{CID},{q(rn)},NULL,{1 if isdef else 0},{1 if vall else 0},NULL,0,NOW(),NOW())")
    e("INSERT INTO roles (id,company_id,name,description,is_default,role_view_all_company,role_view_department_id,deleted,created_at,updated_at) VALUES")
    e(",\n".join(rv)+";")
    e("")

    all_perms = list(range(1,34))
    hr_perms  = [1,2,3,4,5,6,7,8,9,10,20,21,22,23,24,25,26,27,28,29,30,31,32,33]
    mgr_perms = [1,5,7,8,20,22,23,24,31]
    emp_perms = [18,22,24,31]
    rp = []
    for plist,rid in [(all_perms,role_ids[0]),(hr_perms,role_ids[1]),(mgr_perms,role_ids[2]),(emp_perms,role_ids[3])]:
        for pid_ in plist:
            rp.append(f"({rid},{pid_})")
    e("INSERT IGNORE INTO role_permissions (role_id,permission_id) VALUES")
    e(",\n".join(rp)+";")
    e("")

    # ── 6. Work Shifts ─────────────────────────────────────────────────────
    e("-- 6. Work Shifts (10)")
    shift_ids = []
    shv = []
    shift_rows = []
    for si,(sn,sc,stype,ss,se,sbs,sbe,swm,scol) in enumerate(SHIFT_TEMPLATES):
        shid = SHB + si + 1
        shift_ids.append(shid)
        shift_rows.append({"id":shid,"name":sn,"code":sc+str(CID),"type":stype,"start":ss,"end":se,"work_minutes":swm})
        ts = f"'{ss}'" if ss else "NULL"
        te = f"'{se}'" if se else "NULL"
        tbs= f"'{sbs}'" if sbs else "NULL"
        tbe= f"'{sbe}'" if sbe else "NULL"
        # group_name used to distinguish shift categories (no 'type' column)
        group = "WORK" if stype=="WORK" else ("HALF" if "HALF" in stype else stype)
        shv.append(f"({shid},{CID},{q(sn)},{q(sc+str(CID))},{ts},{te},{tbs},{tbe},{swm},{q(scol)},1,NOW(),NOW(),{q(group)})")
    e("INSERT INTO work_shifts (id,company_id,name,code,start_time,end_time,break_start,break_end,work_minutes,color,active,created_at,updated_at,group_name) VALUES")
    e(",\n".join(shv)+";")
    e("")

    dsv = []
    for did in dept_ids:
        for shid in shift_ids:
            dsv.append(f"({did},{shid})")
    e("INSERT IGNORE INTO department_shifts (department_id,shift_id) VALUES")
    e(",\n".join(dsv)+";")
    e("")

    # ── 7. Employees (100) ─────────────────────────────────────────────────
    e("-- 7. Employees (100)")
    NUM_EMP = 100
    genders = ["MALE"]*60+["FEMALE"]*40
    rng.shuffle(genders)
    emp_rows = []
    ev = []
    for ei in range(NUM_EMP):
        eid  = EB + ei + 1
        g    = genders[ei]
        name = rname(rng,g)
        did  = dept_ids[ei % len(dept_ids)]
        # rank: first 15 are senior/mid, rest junior
        rank = 0 if ei < 5 else (1 if ei < 20 else 2)
        sg_id = sg_by_dept_rank[did][rank]
        pos_id = pos_by_dept[did][min(rank, len(pos_by_dept[did])-1)]
        base_salary = SALARIES[rank]
        ecode = f"NV{CID:02d}{ei+1:03d}"
        email = f"emp{CID}{ei+1}@{cfg['domain']}"
        phone = f"09{rng.randint(10000000,99999999)}"
        dob   = date(1979,1,1)+timedelta(days=rng.randint(0,(date(2000,1,1)-date(1979,1,1)).days))
        join  = date(2020,1,1)+timedelta(days=rng.randint(0,(date(2025,6,1)-date(2020,1,1)).days))
        bank  = rng.choice(BANKS)
        bacc  = str(rng.randint(10**11,10**12-1))
        emp_rows.append({"id":eid,"dept_id":did,"pos_id":pos_id,"sg_id":sg_id,
                          "base_salary":base_salary,"join_date":join,"gender":g,"name":name,"email":email})
        ev.append(
            f"({eid},{CID},{q(ecode)},{q(name)},{q(email)},{q(phone)},"
            f"NULL,NULL,{q(g)},{qd(dob)},{qd(join)},NULL,'ACTIVE',"
            f"{did},{pos_id},NULL,NULL,{q(bacc)},{q(bank)},0,NOW(),NOW(),{sg_id},NULL)"
        )
    e("INSERT INTO employees (id,company_id,employee_code,full_name,email,phone,")
    e("  personal_email,avatar,gender,date_of_birth,join_date,leave_date,status,")
    e("  department_id,position_id,address,identity_card,bank_account,bank_name,deleted,created_at,updated_at,salary_grade_id,contract_salary) VALUES")
    e(",\n".join(ev)+";")
    e("")

    # ── 8. Users ───────────────────────────────────────────────────────────
    e("-- 8. Users")
    PWD = "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVDe6R5kha"
    uv = []
    admin_uid = UB+1
    hr_uid    = UB+2
    uv.append(f"({admin_uid},{CID},{q('admin'+str(CID)+'@'+cfg['domain'])},{q(PWD)},NULL,1,0,NOW(),NOW())")
    uv.append(f"({hr_uid},{CID},{q('hr'+str(CID)+'@'+cfg['domain'])},{q(PWD)},NULL,1,0,NOW(),NOW())")
    for ei,emp in enumerate(emp_rows):
        uid = UB+3+ei
        uv.append(f"({uid},{CID},{q(emp['email'])},{q(PWD)},{emp['id']},1,0,NOW(),NOW())")
    e("INSERT INTO users (id,company_id,email,password,employee_id,enabled,deleted,created_at,updated_at) VALUES")
    e(",\n".join(uv)+";")
    e("")

    urv = []
    urv.append(f"({admin_uid},{role_ids[0]})")
    urv.append(f"({hr_uid},{role_ids[1]})")
    for ei in range(NUM_EMP):
        uid = UB+3+ei
        rid = role_ids[2] if ei < 20 else role_ids[3]
        urv.append(f"({uid},{rid})")
    e("INSERT IGNORE INTO user_roles (user_id,role_id) VALUES")
    e(",\n".join(urv)+";")
    e("")

    # ── 9. Leave Types ─────────────────────────────────────────────────────
    e("-- 9. Leave Types")
    lt_defs = [
        ("ANNUAL"+str(CID), "Nghi phep nam",  "DAY", True),
        ("SICK"+str(CID),   "Nghi benh",       "DAY", False),
        ("COMP"+str(CID),   "Nghi bu",         "DAY", True),
        ("UNPAID"+str(CID), "Nghi khong luong","DAY", False),
        ("MAT"+str(CID),    "Nghi thai san",   "DAY", True),
    ]
    lt_ids = []
    ltv = []
    for li,(lc,ln,lu,lp) in enumerate(lt_defs):
        ltid = LTB+li+1
        lt_ids.append(ltid)
        ltv.append(f"({ltid},{CID},{q(lc)},{q(ln)},{q(lu)},{1 if lp else 0},1,NULL,NOW(),NOW())")
    e("INSERT INTO leave_types (id,company_id,code,name,unit,is_paid,active,description,created_at,updated_at) VALUES")
    e(",\n".join(ltv)+";")
    e("")

    # ── 10. Leave Grants ───────────────────────────────────────────────────
    e("-- 10. Leave Grants (annual + sick per employee per year)")
    lgv = []
    lgc = 0
    ann_lt = lt_ids[0]
    sick_lt = lt_ids[1]
    for yr in [2025, 2026]:
        for emp in emp_rows:
            g_date = date(yr,1,1)
            # annual
            lgid = LGB+lgc+1; lgc+=1
            lgv.append(f"({lgid},{CID},{emp['id']},{ann_lt},'MANUAL',{qd(g_date)},{qd(date(yr,1,1))},{qd(date(yr,12,31))},NULL,NULL,NOW(),NOW(),12.00,NULL,0.00,0.00)")
            # sick
            lgid = LGB+lgc+1; lgc+=1
            lgv.append(f"({lgid},{CID},{emp['id']},{sick_lt},'MANUAL',{qd(g_date)},{qd(date(yr,1,1))},{qd(date(yr,12,31))},NULL,NULL,NOW(),NOW(),NULL,40.00,0.00,0.00)")
    CHUNK = 500
    for i in range(0,len(lgv),CHUNK):
        e("INSERT INTO leave_grants (id,company_id,employee_id,leave_type_id,source,granted_at,valid_from,valid_to,note,accrual_rule_id,created_at,updated_at,grant_days,grant_hours,used_days,used_hours) VALUES")
        e(",\n".join(lgv[i:i+CHUNK])+";")
    e("")

    # ── 11. Shift Assignments + Attendances ────────────────────────────────
    e("-- 11. Shift Assignments & Attendances (Jan 2025 → Jun 2026)")
    work_sh  = [s for s in shift_rows if s["type"]=="WORK"]
    off_sh   = next(s for s in shift_rows if s["type"]=="DAY_OFF")
    half_sh  = [s for s in shift_rows if s["type"] in ("HALF_AM","HALF_PM")]

    sav = []  # shift assignment VALUES
    atv = []  # attendance VALUES
    lrv = []  # leave request VALUES
    sac = 0; atc = 0; lrc = 0

    START = date(2025,1,1)
    END   = date(2026,6,5)

    cur = START.replace(day=1)
    while cur <= END:
        mo_end = (cur.replace(day=28)+timedelta(days=4)).replace(day=1)-timedelta(days=1)
        mo_end = min(mo_end, END)
        for emp in emp_rows:
            if emp["join_date"] > mo_end:
                continue
            eff_start = max(cur, emp["join_date"])
            d = eff_start
            while d <= mo_end:
                sa_id = SAB+sac+1; sac+=1
                at_id = ATB+atc+1; atc+=1
                weekend = d.weekday() >= 5
                rv = rng.random()

                if weekend:
                    sh = off_sh
                    status = None
                    ci = co = None
                    at_approved = False
                else:
                    if rv < 0.73:
                        sh = rng.choice(work_sh[:4])
                        status = "PRESENT"
                        h,m = map(int,sh["start"].split(":"))
                        eh,em_ = map(int,sh["end"].split(":"))
                        ci = datetime(d.year,d.month,d.day,h,m)+timedelta(minutes=rng.randint(-5,10))
                        co = datetime(d.year,d.month,d.day,eh,em_)+timedelta(minutes=rng.randint(-5,15))
                        if sh["type"]=="WORK" and eh < h:  # overnight
                            co += timedelta(days=1)
                        at_approved = d < date(2026,5,1)
                    elif rv < 0.79:
                        sh = off_sh; status="ABSENT"; ci=co=None; at_approved=False
                    elif rv < 0.85:
                        sh = rng.choice(work_sh[:2]); status="LATE"
                        h,m = map(int,sh["start"].split(":"))
                        eh,em_ = map(int,sh["end"].split(":"))
                        ci = datetime(d.year,d.month,d.day,h,m)+timedelta(minutes=rng.randint(20,60))
                        co = datetime(d.year,d.month,d.day,eh,em_)
                        at_approved = d < date(2026,5,1)
                    elif rv < 0.90:
                        sh = rng.choice(half_sh) if half_sh else work_sh[0]
                        status="HALF_DAY"
                        if sh["start"]:
                            h,m = map(int,sh["start"].split(":"))
                            ci = datetime(d.year,d.month,d.day,h,m)
                            co = ci+timedelta(hours=4)
                        else:
                            ci=co=None
                        at_approved = d < date(2026,5,1)
                    elif rv < 0.95:
                        sh = work_sh[0]; status="LEAVE"; ci=co=None
                        at_approved = d < date(2026,5,1)
                        lr_id = LRB+lrc+1; lrc+=1
                        lt_pick = rng.choice(lt_ids[:2])
                        lr_status = "APPROVED" if at_approved else "PENDING"
                        lrv.append(
                            f"({lr_id},{emp['id']},'Nghi phep',{q(lr_status)},NOW(),NOW(),"
                            f"{CID},{lt_pick},'DAY_RANGE',{qd(d)},{qd(d)},NULL,NULL,1.00,"
                            f"NULL,NULL,NULL,1,NULL)"
                        )
                    else:
                        sh = off_sh; status=None; ci=co=None; at_approved=False

                sa_approved = 1 if d < date(2026,5,1) else 0
                ts = f"'{sh['start']}'" if sh.get("start") else "NULL"
                te = f"'{sh['end']}'"   if sh.get("end")   else "NULL"

                sav.append(
                    f"({sa_id},{emp['id']},{sh['id']},{qd(d)},NULL,"
                    f"NULL,NULL,NULL,NULL,"
                    f"NULL,NOW(),"
                    f"0,{sa_approved},"
                    f"{q(sh['name'])},{q(sh['code'])},"
                    f"{ts},{te},NULL,NULL,"
                    f"{sh['work_minutes']},NULL)"
                )

                if status is not None:
                    flags = "ON_TIME" if status=="PRESENT" else ("LATE_IN" if status=="LATE" else None)
                    snap_h = None
                    if ci and co:
                        snap_h = round((co-ci).total_seconds()/3600,2)
                    app_at = qdt(datetime(d.year,d.month,d.day,17,0)) if at_approved else "NULL"
                    atv.append(
                        f"({at_id},{emp['id']},{sa_id},{qd(d)},"
                        f"{qdt(ci)},{qdt(co)},"
                        f"{q(status)},NULL,NOW(),NOW(),"
                        f"{'1' if at_approved else '0'},{app_at},NULL,"
                        f"{'NULL' if snap_h is None else snap_h},NULL,NULL,NULL,NULL,"
                        f"NULL,NULL,NULL,NULL,"
                        f"{q(flags)},"
                        f"NULL,NULL,NULL,NULL,NULL,NULL,"
                        f"0,NULL,NULL)"
                    )
                d += timedelta(days=1)
        cur = (cur.replace(day=28)+timedelta(days=4)).replace(day=1)

    for i in range(0,len(sav),CHUNK):
        e("INSERT INTO shift_assignments (id,employee_id,shift_id,work_date,note,")
        e("  custom_start_time,custom_end_time,custom_break_start,custom_break_end,")
        e("  created_by,created_at,deleted,approved,")
        e("  snapshot_name,snapshot_code,")
        e("  snapshot_start_time,snapshot_end_time,")
        e("  snapshot_break_start,snapshot_break_end,")
        e("  snapshot_work_minutes,snapshot_color) VALUES")
        e(",\n".join(sav[i:i+CHUNK])+";")
        e("")

    for i in range(0,len(atv),CHUNK):
        e("INSERT INTO attendances (id,employee_id,shift_assignment_id,date,")
        e("  check_in,check_out,status,note,created_at,updated_at,")
        e("  approved,approved_at,approved_by_id,")
        e("  snap_actual_hours,snap_day_hours,snap_day_ot,snap_night_hours,snap_night_ot,")
        e("  check_in_latitude,check_in_longitude,check_out_latitude,check_out_longitude,")
        e("  work_flags,")
        e("  override_check_in,override_check_out,override_break_minutes,override_ot_day_minutes,override_ot_night_minutes,override_note,")
        e("  deleted,deleted_at,deleted_by_id) VALUES")
        e(",\n".join(atv[i:i+CHUNK])+";")
        e("")

    for i in range(0,len(lrv),CHUNK):
        e("INSERT INTO leave_requests (id,employee_id,reason,status,created_at,updated_at,")
        e("  company_id,leave_type_id,mode,from_date,to_date,from_time,to_time,requested_amount,")
        e("  admin_note,processed_by,processed_at,applied,parent_id) VALUES")
        e(",\n".join(lrv[i:i+CHUNK])+";")
        e("")

    # ── 12. Payrolls ───────────────────────────────────────────────────────
    e("-- 12. Payrolls (Jan 2025 -> Jun 2026)")
    prv = []
    prc = 0
    payroll_months = []
    cur2 = date(2025,1,1)
    while cur2 <= date(2026,6,1):
        payroll_months.append((cur2.year,cur2.month))
        cur2=(cur2.replace(day=28)+timedelta(days=4)).replace(day=1)

    for (yr,mo) in payroll_months:
        pf = date(yr,mo,1)
        pt = (pf.replace(day=28)+timedelta(days=4)).replace(day=1)-timedelta(days=1)
        for emp in emp_rows:
            if emp["join_date"] > pt: continue
            prid = PRB+prc+1; prc+=1
            base = emp["base_salary"]
            work_days = rng.randint(18,22)
            day_h = round(work_days*8.0,2)
            day_ot = round(rng.uniform(0,8),2)
            allow = rng.choice([0,500_000,1_000_000])
            bonus = 0 if mo!=12 else rng.choice([0,1_000_000,3_000_000])
            ot_pay = round(base/22/8*day_ot*1.5,0)
            gross = round(base*work_days/22+allow+bonus+ot_pay,0)
            si = round(gross*0.08,0)
            hi = round(gross*0.015,0)
            ui = round(gross*0.01,0)
            txbl = max(0,gross-si-hi-ui-11_000_000)
            if txbl<=5e6:       pit=txbl*0.05
            elif txbl<=10e6:    pit=250000+(txbl-5e6)*0.10
            elif txbl<=18e6:    pit=750000+(txbl-10e6)*0.15
            elif txbl<=32e6:    pit=1950000+(txbl-18e6)*0.20
            elif txbl<=52e6:    pit=4750000+(txbl-32e6)*0.25
            elif txbl<=80e6:    pit=9750000+(txbl-52e6)*0.30
            else:               pit=18150000+(txbl-80e6)*0.35
            pit=round(pit,0)
            net=round(gross-si-hi-ui-pit,0)
            if yr==2026 and mo==6:
                st="DRAFT"; app_at="NULL"; paid_at="NULL"
            elif yr==2026 and mo==5:
                st="APPROVED"; app_at=qdt(datetime(2026,6,5,9,0)); paid_at="NULL"
            elif yr==2026 and mo==4:
                st="PAID"; app_at=qdt(datetime(2026,5,5,9,0)); paid_at=qdt(datetime(2026,5,10,14,0))
            elif yr==2026 and mo==3:
                st="APPROVED"; app_at=qdt(datetime(2026,4,5,9,0)); paid_at="NULL"
            else:
                nxt_mo=mo+1 if mo<12 else 1; nxt_yr=yr if mo<12 else yr+1
                st="PAID"; app_at=qdt(datetime(nxt_yr,nxt_mo,5,9,0)); paid_at=qdt(datetime(nxt_yr,nxt_mo,10,14,0))
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

    for i in range(0,len(prv),CHUNK):
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
        e(",\n".join(prv[i:i+CHUNK])+";")
        e("")

    e("SET FOREIGN_KEY_CHECKS=1;")
    e(f"-- Done: {len(sav)} shift_assignments, {len(atv)} attendances, {len(prv)} payrolls, {len(lrv)} leave_requests")
    e("")

    return lines

# ── entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    idx = int(sys.argv[1]) if len(sys.argv) > 1 else 1

    # Query actual MAX IDs from DB to avoid conflicts
    import subprocess, json

    def get_max_ids():
        sql = """
SELECT
  (SELECT COALESCE(MAX(id),2) FROM companies) as company,
  (SELECT COALESCE(MAX(id),19) FROM departments) as dept,
  (SELECT COALESCE(MAX(id),15) FROM positions) as position,
  (SELECT COALESCE(MAX(id),5) FROM salary_grades) as salary_grade,
  (SELECT COALESCE(MAX(id),11) FROM employees) as employee,
  (SELECT COALESCE(MAX(id),12) FROM users) as user,
  (SELECT COALESCE(MAX(id),7) FROM roles) as role,
  (SELECT COALESCE(MAX(id),23) FROM work_shifts) as shift,
  (SELECT COALESCE(MAX(id),444) FROM shift_assignments) as shift_assign,
  (SELECT COALESCE(MAX(id),102) FROM attendances) as attendance,
  (SELECT COALESCE(MAX(id),3) FROM leave_types) as leave_type,
  (SELECT COALESCE(MAX(id),57) FROM leave_grants) as leave_grant,
  (SELECT COALESCE(MAX(id),113) FROM leave_requests) as leave_request,
  (SELECT COALESCE(MAX(id),77) FROM payrolls) as payroll;
"""
        result = subprocess.run(
            ["mysql", "-ubosskin", "-pngocanhbk54", "bosskin", "-e", sql, "--skip-column-names"],
            capture_output=True, text=True
        )
        vals = result.stdout.strip().split('\t')
        keys = ["company","dept","position","salary_grade","employee","user","role","shift",
                "shift_assign","attendance","leave_type","leave_grant","leave_request","payroll"]
        return {k: int(v) for k, v in zip(keys, vals)}

    off = get_max_ids()
    lines = generate(idx, off)
    print("\n".join(lines))
