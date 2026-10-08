<#
  Tạo công ty mẫu "TH company" với dữ liệu tối thiểu cho mọi phần (chạy qua dev\seed-th.cmd).
  Gọi API backend (http://localhost:8080) nên dữ liệu đi qua đúng nghiệp vụ.
  Cần trong backend\.env: BOOTSTRAP_SYSADMIN_EMAIL / _PASSWORD (system admin) và
  SEED_USER_PASSWORD (mật khẩu chung cho mọi tài khoản TH company).
  Muốn làm lại từ đầu: dev\reset-db.cmd rồi chạy lại script này.
#>
param([string]$Api = 'http://localhost:8080')
. "$PSScriptRoot\_common.ps1"
Start-Transcript -Path (Join-Path $LogDir 'seed-th.log') -Force | Out-Null
try {

# ── .env ────────────────────────────────────────────────────────────────────
$envFile = Join-Path $Root 'backend\.env'
$cfg = @{}
Get-Content $envFile -Encoding UTF8 | ForEach-Object {
  if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$') { $cfg[$Matches[1]] = $Matches[2] }
}
foreach ($k in 'BOOTSTRAP_SYSADMIN_EMAIL','BOOTSTRAP_SYSADMIN_PASSWORD','SEED_USER_PASSWORD') {
  if (-not $cfg[$k]) { throw "Thiếu $k trong backend\.env" }
}
$PW = $cfg['SEED_USER_PASSWORD']

# ── HTTP ────────────────────────────────────────────────────────────────────
$script:Token = $null
function Call($method, $path, $body = $null, $token = $script:Token) {
  $h = @{}
  if ($token) { $h['Authorization'] = "Bearer $token" }
  $p = @{ Method = $method; Uri = "$Api$path"; Headers = $h; UseBasicParsing = $true }
  if ($null -ne $body) {
    $p['Body'] = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 10 -Compress))
    $p['ContentType'] = 'application/json; charset=utf-8'
  }
  try {
    $r = Invoke-WebRequest @p
    if (-not $r.Content) { return $null }
    $text = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
    return $text | ConvertFrom-Json
  } catch {
    $msg = $_.ErrorDetails.Message; if (-not $msg) { $msg = $_.Exception.Message }
    throw "$method $path → $msg"
  }
}
function Login($email, $password, $path = '/api/v1/auth/login') {
  (Call POST $path @{ email = $email; password = $password } $null).accessToken
}
function D($d) { $d.ToString('yyyy-MM-dd') }
function Items($r) { if ($r -is [array]) { return ,$r }; if ($null -ne $r.content) { return ,@($r.content) }; return ,@($r) }
function Step($t) { Write-Host ''; Write-Host "== $t" }

if (-not (Test-Port 8080)) { throw 'Backend chưa chạy (cổng 8080). Chạy dev\start.cmd trước.' }

# ── 1. Công ty ──────────────────────────────────────────────────────────────
Step 'Công ty'
$sys = Login $cfg['BOOTSTRAP_SYSADMIN_EMAIL'] $cfg['BOOTSTRAP_SYSADMIN_PASSWORD'] '/admin/auth/login'
$existing = Call GET '/admin/companies' $null $sys
$list = Items $existing
if ($list | Where-Object { $_.code -eq 'THCO' }) {
  throw 'TH company (mã THCO) đã tồn tại. Muốn tạo lại: dev\reset-db.cmd rồi chạy lại seed.'
}
$adminEmail = 'admin@thco.local'
$co = Call POST '/admin/companies' @{
  name = 'TH company'; code = 'THCO'; domain = 'thco.local'
  address = '12 Nguyễn Huệ, Quận 1, TP.HCM'; phone = '02873000001'; companyEmail = 'hr@thco.local'
  adminEmail = $adminEmail; adminPassword = $PW; adminFullName = 'Quản trị TH'
} $sys
Write-Host "TH company id=$($co.id)"
$script:Token = Login $adminEmail $PW

# ── 2. Phòng ban + chức danh ────────────────────────────────────────────────
Step 'Phòng ban, chức danh'
$dept = @{}
foreach ($d in @(
  @('BGD','Ban giám đốc'), @('HCNS','Hành chính - Nhân sự'), @('KT','Kế toán'), @('SX','Xưởng sản xuất'))) {
  $dept[$d[0]] = (Call POST '/api/v1/departments' @{ code = $d[0]; name = $d[1] }).id
}
$pos = @{}
foreach ($p in @(
  @('GD','Giám đốc','BGD'), @('TPNS','Trưởng phòng nhân sự','HCNS'), @('KTT','Kế toán trưởng','KT'),
  @('KTV','Kế toán viên','KT'), @('QD','Quản đốc','SX'), @('CN','Công nhân','SX'))) {
  $pos[$p[0]] = (Call POST '/api/v1/positions' @{ code = $p[0]; name = $p[1]; departmentId = $dept[$p[2]] }).id
}

# ── 3. Vai trò ──────────────────────────────────────────────────────────────
Step 'Vai trò'
$roles = Call GET '/api/v1/roles'
$roleList = Items $roles
$roleNV = ($roleList | Where-Object { $_.isDefault -or $_.default } | Select-Object -First 1).id
if (-not $roleNV) { $roleNV = ($roleList | Where-Object { $_.name -eq 'Nhân viên' } | Select-Object -First 1).id }
function NewRole($name, $perms) {
  (Call POST '/api/v1/roles' @{ name = $name; description = 'Dữ liệu mẫu TH'; permissions = $perms; roleViewAllCompany = $true }).id
}
$roleQL = NewRole 'Quản lý' @('ATTENDANCE_VIEW','ATTENDANCE_MANAGE','ATTENDANCE_APPROVE','ATTENDANCE_REQUEST_APPROVE',
  'ATTENDANCE_PERIOD_LOCK','SHIFT_VIEW','SHIFT_MANAGE','EMPLOYEE_VIEW','DEPARTMENT_VIEW','LEAVE_VIEW','LEAVE_REQUEST_APPROVE',
  'DASHBOARD_VIEW','REPORT_VIEW')
$roleNS = NewRole 'Nhân sự' @('EMPLOYEE_VIEW','EMPLOYEE_CREATE','EMPLOYEE_UPDATE','DEPARTMENT_VIEW','DEPARTMENT_MANAGE',
  'POSITION_MANAGE','ATTENDANCE_VIEW','SHIFT_VIEW','SHIFT_MANAGE','LEAVE_VIEW','LEAVE_TYPE_VIEW','LEAVE_TYPE_MANAGE',
  'LEAVE_GRANT_MANUAL','LEAVE_ACCRUAL_VIEW','LEAVE_ACCRUAL_MANAGE','LEAVE_REQUEST_CREATE_FOR_OTHERS',
  'EXCEL_EXPORT','EXCEL_IMPORT','DASHBOARD_VIEW','REPORT_VIEW')
$roleKT = NewRole 'Kế toán' @('PAYROLL_VIEW','PAYROLL_CREATE','PAYROLL_APPROVE','PAYROLL_PAY','EMPLOYEE_VIEW',
  'ATTENDANCE_VIEW','DASHBOARD_VIEW','EXCEL_EXPORT')

# ── 4. Ca làm ───────────────────────────────────────────────────────────────
Step 'Ca làm'
$shift = @{}
foreach ($s in @(
  @('HC','Hành chính','08:00','17:00','12:00','13:00'),
  @('CA1','Ca 1 (sáng)','06:00','14:00',$null,$null),
  @('CA2','Ca 2 (chiều)','14:00','22:00',$null,$null),
  @('DEM','Ca đêm','22:00','06:00',$null,$null),
  @('SANG','Ca gãy - sáng','07:00','11:00',$null,$null),
  @('CHIEU','Ca gãy - chiều','13:00','17:00',$null,$null))) {
  $shift[$s[0]] = (Call POST '/api/v1/shifts' @{ code = $s[0]; name = $s[1]; startTime = $s[2]; endTime = $s[3]; breakStart = $s[4]; breakEnd = $s[5] }).id
}

# ── 5. Bậc lương + công thức ────────────────────────────────────────────────
Step 'Bậc lương, công thức lương'
$gradeVP = (Call POST '/api/v1/salary-grades' @{ code = 'VP'; name = 'Khối văn phòng'; payType = 'DAILY'; baseRate = 500000 }).id
$gradeSX = (Call POST '/api/v1/salary-grades' @{ code = 'SX'; name = 'Khối sản xuất'; payType = 'DAILY'; baseRate = 350000 }).id
$formula = @{}
foreach ($g in @(@($gradeVP,'Lương tháng VP'), @($gradeSX,'Lương tháng SX'))) {
  $formula[$g[0]] = (Call POST '/api/v1/salary-formulas' @{
    salaryGradeId = $g[0]; name = $g[1]; effectiveDate = '2026-01-01'
    expressionGross = 'ROUND(CONTRACT_SALARY / STANDARD_WORK_DAYS * (PRESENT_DAYS + PAID_LEAVE_DAYS))'
    expressionNet   = 'GROSS - TOTAL_INSURANCE - PIT'
  }).id
}

# ── 6. Nhân viên (mỗi người có tài khoản, mật khẩu = SEED_USER_PASSWORD) ─────
Step 'Nhân viên'
$people = @(
  # key, họ tên, email, giới tính, phòng, chức danh, bậc, lương HĐ, vai trò thêm
  @('gd',   'Trần Minh Hoàng', 'hoang.tm@thco.local', 'MALE',   'BGD',  'GD',   $gradeVP, 40000000, $roleQL),
  @('ns',   'Lê Thu Hà',       'ha.lt@thco.local',    'FEMALE', 'HCNS', 'TPNS', $gradeVP, 22000000, $roleNS),
  @('ktt',  'Phạm Văn Kiên',   'kien.pv@thco.local',  'MALE',   'KT',   'KTT',  $gradeVP, 25000000, $roleKT),
  @('ktv',  'Nguyễn Thị Mai',  'mai.nt@thco.local',   'FEMALE', 'KT',   'KTV',  $gradeVP, 13000000, $null),
  @('qd',   'Đỗ Quang Dũng',   'dung.dq@thco.local',  'MALE',   'SX',   'QD',   $gradeSX, 18000000, $roleQL),
  @('cn1',  'Vũ Văn Tài',      'tai.vv@thco.local',   'MALE',   'SX',   'CN',   $gradeSX, 9000000,  $null),
  @('cn2',  'Bùi Thị Lan',     'lan.bt@thco.local',   'FEMALE', 'SX',   'CN',   $gradeSX, 9000000,  $null),
  @('cn3',  'Hoàng Văn Nam',   'nam.hv@thco.local',   'MALE',   'SX',   'CN',   $gradeSX, 9500000,  $null)
)
$emp = @{}
foreach ($p in $people) {
  $e = Call POST '/api/v1/employees' @{
    fullName = $p[1]; email = $p[2]; password = $PW; gender = $p[3]; joinDate = '2025-01-02'
    departmentId = $dept[$p[4]]; positionId = $pos[$p[5]]; phone = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)
  }
  Call PUT "/api/v1/employees/$($e.id)" @{ salaryGradeId = $p[6]; contractSalary = $p[7] } | Out-Null
  $emp[$p[0]] = @{ id = $e.id; email = $p[2]; name = $p[1]; grade = $p[6]; userId = $null }
}
# gán vai trò: ai cũng có "Nhân viên" (tự chấm công, xin nghỉ) + vai trò theo chức năng
$users = Call GET '/api/v1/users'
$userList = Items $users
foreach ($p in $people) {
  $u = $userList | Where-Object { $_.email -eq $p[2] } | Select-Object -First 1
  $emp[$p[0]].userId = $u.id
  $ids = @($roleNV); if ($p[8]) { $ids += $p[8] }
  Call PUT "/api/v1/users/$($u.id)/roles" @{ roleIds = $ids } | Out-Null
}

# ── 7. Phân ca: tháng 9 + tháng 10/2026 ─────────────────────────────────────
Step 'Phân ca'
$office = 'gd','ns','ktt','ktv'
$sa = @{}   # "$key|yyyy-MM-dd" → id phân ca
function Assign($key, $code, $date) {
  $r = Call POST '/api/v1/shifts/assignments' @{ employeeId = $emp[$key].id; shiftId = $shift[$code]; workDate = (D $date) }
  $script:sa["$key|$(D $date)"] = $r.id
}
$from = [datetime]'2026-09-01'; $to = [datetime]'2026-10-31'
for ($d = $from; $d -le $to; $d = $d.AddDays(1)) {
  if ($d.DayOfWeek -eq 'Sunday' -or $d.DayOfWeek -eq 'Saturday') { continue }
  $sat = $false
  $week = [int][Math]::Floor(($d - $from).TotalDays / 7)
  if (-not $sat) { foreach ($k in $office + 'qd') { Assign $k 'HC' $d } }
  # công nhân: xoay ca 1 / ca 2 theo tuần
  Assign 'cn1' $(if ($week % 2 -eq 0) {'CA1'} else {'CA2'}) $d
  Assign 'cn2' $(if ($week % 2 -eq 0) {'CA2'} else {'CA1'}) $d
  # cn3: ca đêm thứ 2–6; tuần 19–23/10 làm ca gãy (2 ca/ngày)
  if (-not $sat) {
    if ($d -ge [datetime]'2026-10-19' -and $d -le [datetime]'2026-10-23') { Assign 'cn3' 'SANG' $d; Assign 'cn3' 'CHIEU' $d }
    else { Assign 'cn3' 'DEM' $d }
  }
}

# ── 8. Loại phép, cấp phép, quy tắc cộng phép ───────────────────────────────
Step 'Nghỉ phép'
$ltPN = (Call POST '/api/v1/leaves/types' @{ code = 'PN'; name = 'Phép năm'; unit = 'DAY'; deductPerDay = 1; paid = $true; requiresBalance = $true; active = $true }).id
$ltOM = (Call POST '/api/v1/leaves/types' @{ code = 'OM'; name = 'Nghỉ ốm (BHXH)'; unit = 'DAY'; deductPerDay = 1; paid = $false; requiresBalance = $false; active = $true }).id
$ltKL = (Call POST '/api/v1/leaves/types' @{ code = 'KL'; name = 'Nghỉ không lương'; unit = 'DAY'; deductPerDay = 1; paid = $false; requiresBalance = $false; active = $true }).id
$ltGio = (Call POST '/api/v1/leaves/types' @{ code = 'PG'; name = 'Phép theo giờ'; unit = 'HOUR'; deductPerDay = 1; paid = $true; requiresBalance = $true; active = $true }).id
foreach ($k in $emp.Keys) {
  Call POST '/api/v1/leaves/grants/manual' @{ employeeId = $emp[$k].id; leaveTypeId = $ltPN; grantDays = 12
    validFrom = '2026-01-01'; validTo = '2026-12-31'; note = 'Phép năm 2026' } | Out-Null
}
Call POST '/api/v1/leaves/accrual-rules' @{ name = 'Cộng 1 ngày phép mỗi tháng'; frequency = 'MONTHLY'; dayOfMonth = 1
  grantDays = 1; validFrom = '2026-11-01'; expireAfterDays = 365; active = $true } | Out-Null

# ── 9. Chấm công đã duyệt: 01/09 – 07/10 (giờ thực tế nhập bằng override) ───
Step 'Chấm công tháng 9 và đầu tháng 10'
$times = @{ HC = @('07:55','17:05'); CA1 = @('05:55','14:03'); CA2 = @('13:52','22:04'); DEM = @('21:55','06:02') }
$lastWorked = [datetime]'2026-10-07'
# đơn nghỉ phép có lương đã duyệt (Mai nghỉ 15/09) — tạo TRƯỚC khi duyệt công ngày đó
$ktvToken = Login $emp['ktv'].email $PW
$lv = Call POST '/api/v1/leaves/requests' @{ leaveTypeId = $ltPN; mode = 'DAY_RANGE'; fromDate = '2026-09-15'; toDate = '2026-09-15'; reason = 'Việc gia đình' } $ktvToken
$gdToken = Login $emp['gd'].email $PW
Call PUT "/api/v1/leaves/requests/$($lv.id)/approve" @{} $gdToken | Out-Null

$approver = Login $emp['qd'].email $PW   # quản đốc duyệt công (không tự duyệt công của mình)
foreach ($k in $emp.Keys) {
  $tok = if ($k -eq 'qd') { $gdToken } else { $approver }
  $days = $script:sa.Keys | Where-Object { $_ -like "$k|*" } | ForEach-Object { $_.Split('|')[1] } |
          Where-Object { [datetime]$_ -le $lastWorked } | Sort-Object -Unique
  foreach ($day in $days) {
    $saId = $script:sa["$k|$day"]
    Call POST '/api/v1/attendances/approve' @{ employeeId = $emp[$k].id; date = $day; shiftAssignmentId = $saId } $tok | Out-Null
  }
  foreach ($m in @(@(2026,9),@(2026,10))) {
    $page = Call GET "/api/v1/attendances?year=$($m[0])&month=$($m[1])&employeeId=$($emp[$k].id)&size=200" $null $tok
    foreach ($a in (Items $page)) {
      $day = ([datetime]$a.date).ToString('yyyy-MM-dd')
      if ($k -eq 'ktv' -and $day -eq '2026-09-15') { continue }                 # ngày nghỉ phép
      if ($k -eq 'cn2' -and $day -eq '2026-09-22') { continue }                 # vắng không phép
      $t = $times['HC']
      if ($k -like 'cn*') {
        $wk = [int][Math]::Floor((([datetime]$day) - $from).TotalDays / 7)
        $t = if ($k -eq 'cn3') { $times['DEM'] } elseif (($k -eq 'cn1') -eq ($wk % 2 -eq 0)) { $times['CA1'] } else { $times['CA2'] }
      }
      $in = $t[0]; $out = $t[1]
      if ($k -eq 'cn1' -and $day -eq '2026-09-10') { $in = '06:25' }           # đi muộn
      Call PATCH "/api/v1/attendances/$($a.id)/override" @{ overrideCheckIn = $in; overrideCheckOut = $out; overrideNote = 'Dữ liệu mẫu' } $tok | Out-Null
      Call POST '/api/v1/attendances/approve' @{ attendanceId = $a.id } $tok | Out-Null
    }
  }
  Write-Host "  $($emp[$k].name): $($days.Count) ngày"
}

# ── 10. Đơn đang chờ duyệt (để thử màn duyệt) ───────────────────────────────
Step 'Đơn chờ duyệt'
$cn1Token = Login $emp['cn1'].email $PW
Call POST '/api/v1/attendance-requests' @{ requestDate = '2026-10-08'; requestType = 'CHECK_IN'; requestedCheckIn = $times['CA2'][0]
  shiftAssignmentId = $script:sa['cn1|2026-10-08']; note = 'Quên chấm công vào' } $cn1Token | Out-Null
$cn2Token = Login $emp['cn2'].email $PW
Call POST '/api/v1/leaves/requests' @{ leaveTypeId = $ltPN; mode = 'DAY_RANGE'; fromDate = '2026-10-15'; toDate = '2026-10-16'; reason = 'Về quê' } $cn2Token | Out-Null

# ── 11. Bảng lương nháp tháng 9 ─────────────────────────────────────────────
Step 'Bảng lương tháng 9/2026 (nháp)'
$ktToken = Login $emp['ktt'].email $PW
foreach ($k in $emp.Keys) {
  $r = Call POST '/api/v1/payrolls/generate' @{ employeeId = $emp[$k].id; year = 2026; month = 9; formulaId = $formula[$emp[$k].grade] } $ktToken
  Write-Host ("  {0,-18} công {1,4}  gross {2,12:N0}  net {3,12:N0}" -f $emp[$k].name, $r.presentDays, $r.grossSalary, $r.netSalary)
}

Step 'XONG'
Write-Host "Đăng nhập http://localhost:3000/login — mật khẩu mọi tài khoản = SEED_USER_PASSWORD trong backend\.env"
Write-Host "  $adminEmail (quản trị công ty)"
foreach ($p in $people) { Write-Host ("  {0,-22} {1}" -f $p[2], $p[1]) }
} catch {
  Write-Host ''; Write-Host "LỖI: $_" -ForegroundColor Red
  exit 1
} finally { Stop-Transcript | Out-Null }
