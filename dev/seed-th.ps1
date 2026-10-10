<#
  Tạo công ty mẫu "TH company" với dữ liệu tối thiểu cho mọi phần (chạy qua dev\seed-th.cmd).
  Gọi API backend (http://localhost:8080) nên dữ liệu đi qua đúng nghiệp vụ.
  Cần trong backend\.env: BOOTSTRAP_SYSADMIN_EMAIL / _PASSWORD (system admin) và
  SEED_USER_PASSWORD (mật khẩu chung cho mọi tài khoản TH company).
  System admin bắt buộc 2FA: lần đầu script tự cài và ghi SEED_SYSADMIN_TOTP_SECRET vào .env (xem runbook mục 11).
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
# Tài khoản do admin tạo phải đổi mật khẩu ở lần đầu (V7): tạo bằng mật khẩu tạm rồi đổi sang $PW.
$TMP = $PW + 'Tmp1'
function Activate($email) {
  $t = Login $email $TMP
  Call PATCH '/api/v1/profile/password' @{ currentPassword = $TMP; newPassword = $PW; confirmPassword = $PW } $t | Out-Null
}
# ── 2FA system admin (bước C) ──────────────────────────────────────────────
# System admin bắt buộc 2FA. Script đọc SEED_SYSADMIN_TOTP_SECRET trong backend\.env để tự sinh mã;
# lần đầu (chưa cài) script tự cài, ghi khoá vào .env và in mã QR (otpauth) + mã dự phòng để thêm vào app.
function Base32Decode([string]$s) {
  $alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
  $bits = 0; $val = 0; $out = New-Object System.Collections.Generic.List[byte]
  foreach ($c in $s.ToUpper().TrimEnd('=').ToCharArray()) {
    $i = $alpha.IndexOf($c); if ($i -lt 0) { continue }
    $val = ($val -shl 5) -bor $i; $bits += 5
    if ($bits -ge 8) { $bits -= 8; $out.Add([byte](($val -shr $bits) -band 0xFF)) }
  }
  return ,$out.ToArray()
}
function Totp([string]$secret) {
  $step = [long][Math]::Floor([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() / 30)
  $msg = [BitConverter]::GetBytes($step); if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($msg) }
  $h = (New-Object System.Security.Cryptography.HMACSHA1 (,(Base32Decode $secret))).ComputeHash($msg)
  $o = $h[19] -band 0x0F
  $bin = (([int]$h[$o] -band 0x7F) -shl 24) -bor ([int]$h[$o+1] -shl 16) -bor ([int]$h[$o+2] -shl 8) -bor [int]$h[$o+3]
  return ($bin % 1000000).ToString('000000')
}
function SysLogin {
  $r = Call POST '/admin/auth/login' @{ email = $cfg['BOOTSTRAP_SYSADMIN_EMAIL']; password = $cfg['BOOTSTRAP_SYSADMIN_PASSWORD'] } $null
  if (-not $r.twoFactor) { return $r.accessToken }
  $ch = $r.challengeToken
  if ($r.twoFactor -eq 'SETUP_REQUIRED') {
    $setup = Call POST '/admin/auth/2fa/setup' @{ challengeToken = $ch } $null
    $done = Call POST '/admin/auth/2fa/enable' @{ challengeToken = $ch; code = (Totp $setup.secret) } $null
    Add-Content -Path $envFile -Encoding UTF8 -Value "`r`nSEED_SYSADMIN_TOTP_SECRET=$($setup.secret)"
    $cfg['SEED_SYSADMIN_TOTP_SECRET'] = $setup.secret
    Write-Host ''
    Write-Host '!! Đã bật 2FA cho system admin. Thêm vào app xác thực bằng khoá hoặc liên kết dưới đây:' -ForegroundColor Yellow
    Write-Host "   Khoá: $($setup.secret)"
    Write-Host "   $($setup.otpauthUri)"
    Write-Host "   Mã dự phòng (mỗi mã dùng 1 lần, chép lại cất kỹ): $($done.recoveryCodes -join ' ')"
    Write-Host '   Khoá đã ghi vào backend\.env (SEED_SYSADMIN_TOTP_SECRET).'
    return $done.accessToken
  }
  $sec = $cfg['SEED_SYSADMIN_TOTP_SECRET']
  if (-not $sec) { throw 'System admin đã bật 2FA: thêm SEED_SYSADMIN_TOTP_SECRET=<khoá 2FA> vào backend\.env' }
  return (Call POST '/admin/auth/2fa/verify' @{ challengeToken = $ch; code = (Totp $sec) } $null).accessToken
}
function D($d) { $d.ToString('yyyy-MM-dd') }
function Items($r) { if ($r -is [array]) { return ,$r }; if ($null -ne $r.content) { return ,@($r.content) }; return ,@($r) }
function Step($t) { Write-Host ''; Write-Host "== $t" }

if (-not (Test-Port 8080)) { throw 'Backend chưa chạy (cổng 8080). Chạy dev\start.cmd trước.' }

# ── 1. Công ty ──────────────────────────────────────────────────────────────
Step 'Công ty'
$sys = SysLogin
$existing = Call GET '/admin/companies' $null $sys
$list = Items $existing
if ($list | Where-Object { $_.code -eq 'THCO' }) {
  throw 'TH company (mã THCO) đã tồn tại. Muốn tạo lại: dev\reset-db.cmd rồi chạy lại seed.'
}
$adminEmail = 'admin@thco.local'
$co = Call POST '/admin/companies' @{
  name = 'TH company'; code = 'THCO'; domain = 'thco.local'
  address = '12 Nguyễn Huệ, Quận 1, TP.HCM'; phone = '02873000001'; companyEmail = 'hr@thco.local'
  adminEmail = $adminEmail; adminPassword = $TMP; adminFullName = 'Quản trị TH'
} $sys
Write-Host "TH company id=$($co.id)"
Activate $adminEmail
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
  'DASHBOARD_VIEW','REPORT_VIEW','CALENDAR_VIEW')
$roleNS = NewRole 'Nhân sự' @('EMPLOYEE_VIEW','EMPLOYEE_CREATE','EMPLOYEE_UPDATE','DEPARTMENT_VIEW','DEPARTMENT_MANAGE',
  'POSITION_MANAGE','ATTENDANCE_VIEW','SHIFT_VIEW','SHIFT_MANAGE','LEAVE_VIEW','LEAVE_TYPE_VIEW','LEAVE_TYPE_MANAGE',
  'LEAVE_GRANT_MANUAL','LEAVE_ACCRUAL_VIEW','LEAVE_ACCRUAL_MANAGE','LEAVE_REQUEST_CREATE_FOR_OTHERS',
  'EXCEL_EXPORT','EXCEL_IMPORT','DASHBOARD_VIEW','REPORT_VIEW','CALENDAR_VIEW','CALENDAR_MANAGE',
  'CONTRACT_VIEW','CONTRACT_EDIT','EMPLOYEE_SENSITIVE_VIEW')
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
# ca linh hoạt: làm đủ 8 tiếng bất kỳ lúc nào trong 07:00–19:00
$shift['LH'] = (Call POST '/api/v1/shifts' @{ code = 'LH'; name = 'Linh hoạt 8 tiếng'; startTime = '07:00'; endTime = '19:00'
  shiftType = 'FLEXIBLE'; requiredMinutes = 480 }).id

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
    fullName = $p[1]; email = $p[2]; password = $TMP; gender = $p[3]; joinDate = '2025-01-02'
    departmentId = $dept[$p[4]]; positionId = $pos[$p[5]]; phone = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)
  }
  # PUT cập nhật cả chức vụ/bậc lương: không gửi positionId thì chức vụ bị xoá
  Call PUT "/api/v1/employees/$($e.id)" @{ positionId = $pos[$p[5]]; salaryGradeId = $p[6]; contractSalary = $p[7] } | Out-Null
  $emp[$p[0]] = @{ id = $e.id; email = $p[2]; name = $p[1]; grade = $p[6]; userId = $null }
  Activate $p[2]
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

# ── 6b. Quản lý trực tiếp + quá trình công tác (Bước K) ─────────────────────
Step 'Quản lý trực tiếp'
$reports = @{ gd = @('ns','ktt','qd'); ktt = @('ktv'); qd = @('cn1','cn2','cn3') }
$person = @{}; foreach ($p in $people) { $person[$p[0]] = $p }
foreach ($m in $reports.Keys) {
  foreach ($k in $reports[$m]) {
    # PUT không gửi positionId / salaryGradeId thì hai trường đó bị xoá → gửi lại cùng quản lý
    Call PUT "/api/v1/employees/$($emp[$k].id)" @{ managerId = $emp[$m].id; positionId = $pos[$person[$k][5]]
      salaryGradeId = $person[$k][6] } | Out-Null
  }
}
# mốc tương lai: Nam lên quản đốc từ 01/12/2026 (tự áp dụng khi tới ngày)
Call POST "/api/v1/employees/$($emp['cn3'].id)/job-histories" @{ effectiveFrom = '2026-12-01'; changeType = 'PROMOTION'
  departmentId = $dept['SX']; positionId = $pos['QD']; salaryGradeId = $gradeSX; managerId = $emp['gd'].id
  note = 'Lên quản đốc ca đêm' } | Out-Null
Write-Host '  GD quản lý NS, KTT, QĐ; KTT quản lý KTV; QĐ quản lý 3 công nhân; công ty duyệt theo quyền (mặc định)'

# ── 6c. Hợp đồng lao động (Bước L) ─────────────────────────────────────────
Step 'Hợp đồng lao động'
$lunch = @{ code = 'AN_TRUA'; name = 'Ăn trưa'; amount = 730000; insurable = $false; taxable = $false }
$resp  = @{ code = 'TRACH_NHIEM'; name = 'Trách nhiệm'; amount = 2000000; insurable = $true; taxable = $true }
$contracts = @(
  # key, số HĐ, loại, bắt đầu, kết thúc, phụ cấp trách nhiệm
  @('gd',  'TH-HD-001', 'INDEFINITE', '2025-01-02', $null,        $true),
  @('ns',  'TH-HD-002', 'INDEFINITE', '2025-01-02', $null,        $true),
  @('ktt', 'TH-HD-003', 'INDEFINITE', '2025-01-02', $null,        $true),
  @('ktv', 'TH-HD-004', 'FIXED_TERM', '2025-01-02', '2026-10-31', $false),
  @('qd',  'TH-HD-005', 'INDEFINITE', '2025-01-02', $null,        $true),
  @('cn1', 'TH-HD-006', 'FIXED_TERM', '2025-01-02', '2026-12-31', $false),
  @('cn2', 'TH-HD-007', 'FIXED_TERM', '2025-01-02', '2027-01-01', $false),
  @('cn3', 'TH-HD-008', 'FIXED_TERM', '2025-01-02', '2027-12-31', $false)
)
$hd = @{}
foreach ($c in $contracts) {
  $allow = @($lunch); if ($c[5]) { $allow += $resp }
  $hd[$c[0]] = (Call POST '/api/v1/contracts' @{ employeeId = $emp[$c[0]].id; contractNo = $c[1]; contractType = $c[2]
    status = 'ACTIVE'; signDate = $c[3]; startDate = $c[3]; endDate = $c[4]; baseSalary = $person[$c[0]][7]
    positionTitle = $null; allowances = $allow }).id
}
# Tài tăng lương giữa kỳ 9 (16/09) → bảng lương nháp tháng 9 tính bình quân theo công chuẩn
Call POST "/api/v1/contracts/$($hd['cn1'])/appendices" @{ appendixNo = 'PL-01'; effectiveFrom = '2026-09-16'
  baseSalary = 9600000; note = 'Tăng lương sau đánh giá' } | Out-Null
# Nam lên quản đốc 01/12/2026: phụ lục đổi lương + chức danh + thêm phụ cấp trách nhiệm
Call POST "/api/v1/contracts/$($hd['cn3'])/appendices" @{ appendixNo = 'PL-01'; effectiveFrom = '2026-12-01'
  baseSalary = 15000000; positionTitle = 'Quản đốc ca đêm'; overridesAllowances = $true; allowances = @($lunch, $resp) } | Out-Null
# Hợp đồng mới chờ ký cho Mai (nối tiếp HĐ hết hạn 31/10) — để nháp, HR kích hoạt khi ký
Call POST '/api/v1/contracts' @{ employeeId = $emp['ktv'].id; contractNo = 'TH-HD-009'; contractType = 'FIXED_TERM'
  status = 'DRAFT'; startDate = '2026-11-01'; endDate = '2028-10-31'; baseSalary = 14000000; allowances = @($lunch) } | Out-Null
Write-Host '  8 hợp đồng hiệu lực (Mai hết hạn 31/10 → cần gia hạn, HĐ mới đang nháp), phụ lục tăng lương Tài 16/09, Nam 01/12'

# ── Bước M: MST, sổ BHXH, người phụ thuộc ────────────────────────────────────
Step 'Thuế, bảo hiểm, người phụ thuộc'
$i = 0
foreach ($k in 'gd','ns','ktt','ktv','qd','cn1','cn2','cn3') {
  $i++
  $e = Call GET "/api/v1/employees/$($emp[$k].id)"
  # PUT không gửi chức vụ / bậc lương sẽ xoá → gửi lại giá trị hiện có
  Call PUT "/api/v1/employees/$($e.id)" @{ positionId = $e.positionId; salaryGradeId = $e.salaryGradeId
    taxCode = ('81000000{0:D2}' -f $i); socialInsuranceNo = ('79250000{0:D2}' -f $i)
    healthInsurancePlace = 'BV Đa khoa Thủ Đức'; insuranceJoinDate = '2025-01-02' } | Out-Null
}
function Dep($key, $name, $rel, $dob, $from, $to, $status) {
  Call POST '/api/v1/dependents' @{ employeeId = $emp[$key].id; fullName = $name; relationship = $rel; dateOfBirth = $dob
    deductionFrom = $from; deductionTo = $to; registrationStatus = $status } | Out-Null
}
Dep 'gd'  'Lê Minh An'   'CHILD'  '2015-04-12' '2025-01-01' $null        'REGISTERED'
Dep 'gd'  'Lê Minh Châu' 'CHILD'  '2019-09-03' '2025-01-01' $null        'REGISTERED'
Dep 'qd'  'Nguyễn Thị Hoa' 'PARENT' '1955-02-20' '2025-01-01' '2026-08-01' 'REGISTERED'
Dep 'cn1' 'Phạm Gia Bảo' 'CHILD'  '2026-02-14' '2026-03-01' $null        'PENDING'
Write-Host '  MST + sổ BHXH cho 8 NV; 4 người phụ thuộc (2 con GĐ, mẹ QĐ hết giảm trừ từ 09/2026, con Tài chờ MST)'

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

# ── 9a. Lịch làm việc (bước J): xưởng làm sáng thứ 7; ngày lễ dùng mẫu hệ thống (có 24/11) ─
Step 'Lịch làm việc'
Call POST '/api/v1/work-calendars' @{ name = 'Xưởng: T7 làm sáng'; weekPattern = 'FFFFFHO'; departmentIds = @($dept['SX']) } | Out-Null
$hol = Call GET '/api/v1/holidays?year=2026'
Write-Host "  $(@($hol.items).Count) ngày lễ 2026 (mẫu hệ thống)"

# ── 9b. Xoay ca tháng 11: 2 ca 1 – 2 ca 2 – 2 ca đêm – 2 nghỉ cho 2 công nhân (lệch 2 ngày) ─
Step 'Xoay ca tháng 11'
$rot = Call POST '/api/v1/shift-rotations' @{ name = 'Xoay 2-2-2-2 (xưởng)'
  days = @(@($shift['CA1']), @($shift['CA1']), @($shift['CA2']), @($shift['CA2']), @($shift['DEM']), @($shift['DEM']), @(), @()) }
$gen = Call POST "/api/v1/shift-rotations/$($rot.id)/generate" @{ employeeIds = @($emp['cn1'].id, $emp['cn2'].id)
  from = '2026-11-01'; to = '2026-11-30'; startOffset = 0; staggerPerEmployee = 2; skipHolidays = $true }
Write-Host "  xếp $($gen.assignedDays) ngày, $(@($gen.conflicts).Count) ngày lỗi"
# Mai làm ca linh hoạt cả tuần 02–06/11 (thay ca hành chính)
for ($d = [datetime]'2026-11-02'; $d -le [datetime]'2026-11-06'; $d = $d.AddDays(1)) { Assign 'ktv' 'LH' $d }

# ── 10. Đơn đang chờ duyệt (để thử màn duyệt) ───────────────────────────────
Step 'Đơn chờ duyệt'
$cn1Token = Login $emp['cn1'].email $PW
Call POST '/api/v1/attendance-requests' @{ requestDate = '2026-10-08'; requestType = 'CHECK_IN'; requestedCheckIn = $times['CA2'][0]
  shiftAssignmentId = $script:sa['cn1|2026-10-08']; note = 'Quên chấm công vào' } $cn1Token | Out-Null
$cn2Token = Login $emp['cn2'].email $PW
Call POST '/api/v1/leaves/requests' @{ leaveTypeId = $ltPN; mode = 'DAY_RANGE'; fromDate = '2026-10-15'; toDate = '2026-10-16'; reason = 'Về quê' } $cn2Token | Out-Null
# đổi ca 02/11: Tài (ca 1) đổi với Lan (ca 2)
$myShifts = Call GET '/api/v1/shift-swaps/my-shifts' $null $cn1Token
$mine = @($myShifts) | Where-Object { $_.date -eq '2026-11-02' } | Select-Object -First 1
$cols = Call GET "/api/v1/shift-swaps/colleagues?assignmentId=$($mine.assignmentId)" $null $cn1Token
$lan = @($cols) | Where-Object { $_.employeeId -eq $emp['cn2'].id } | Select-Object -First 1
Call POST '/api/v1/shift-swaps' @{ requesterAssignmentId = $mine.assignmentId; targetEmployeeId = $emp['cn2'].id
  targetAssignmentId = @($lan.shifts)[0].assignmentId; reason = 'Đưa con đi khám buổi sáng' } $cn1Token | Out-Null

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
