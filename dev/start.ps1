<#
  Khởi động môi trường dev (chạy nền, ghi log vào dev\logs).
    .\dev\start.ps1               # cả backend và frontend
    .\dev\start.ps1 backend       # chỉ backend  (http://localhost:8080)
    .\dev\start.ps1 frontend      # chỉ frontend (http://localhost:3000)
  Backend: mvn spring-boot:run trong backend\ (đọc backend\.env). Cần MySQL ở localhost:3306.
  Frontend: flutter run -d web-server (bản debug, có ô đổi server), API_HOST=http://localhost:8080.
#>
param([ValidateSet('all','backend','frontend')][string]$Target = 'all')
. "$PSScriptRoot\_common.ps1"

function Start-Backend {
  if (Get-ServicePid 'backend') { Write-Host 'backend: đang chạy rồi'; return }
  $owner = Get-PortOwner 8080
  if ($owner) { throw "Cổng 8080 đang bị tiến trình $owner chiếm (không do script này chạy). Dừng nó hoặc chạy .\dev\stop.ps1 -Force" }
  if (-not (Test-Port $MySqlPort)) { Write-Warning "MySQL chưa nghe ở cổng $MySqlPort — backend sẽ lỗi kết nối DB." }
  $mvn = if (Get-Command mvn -ErrorAction SilentlyContinue) { 'mvn' } else { '.\mvnw.cmd' }
  $log = Join-Path $LogDir 'backend.log'; $err = Join-Path $LogDir 'backend.err.log'
  $p = Start-Process cmd.exe -ArgumentList '/c', "$mvn -q spring-boot:run" `
        -WorkingDirectory $Services.backend.Dir -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError $err
  Set-Content (Get-PidFile 'backend') $p.Id
  Write-Host "backend: đang khởi động (PID $($p.Id)), log: dev\logs\backend.log"
  if (Wait-Port 8080 240) { Write-Host 'backend: SẴN SÀNG  http://localhost:8080' }
  else { Write-Warning 'backend: quá 4 phút chưa mở cổng 8080 — xem dev\logs\backend*.log' }
}

function Start-Frontend {
  if (Get-ServicePid 'frontend') { Write-Host 'frontend: đang chạy rồi'; return }
  $owner = Get-PortOwner 3000
  if ($owner) { throw "Cổng 3000 đang bị tiến trình $owner chiếm. Dừng nó hoặc chạy .\dev\stop.ps1 -Force" }
  $log = Join-Path $LogDir 'frontend.log'; $err = Join-Path $LogDir 'frontend.err.log'
  $flutterArgs = 'run -d web-server --web-port=3000 --web-hostname=localhost --dart-define=API_HOST=http://localhost:8080'
  if (Get-Command flutter -ErrorAction SilentlyContinue) {
    $mode = 'windows'
    $p = Start-Process cmd.exe -ArgumentList '/c', "flutter $flutterArgs" `
          -WorkingDirectory $Services.frontend.Dir -WindowStyle Hidden -PassThru `
          -RedirectStandardOutput $log -RedirectStandardError $err
  } elseif (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    # Flutter cài trong WSL2: chạy qua wsl, cổng 3000 tự chuyển về localhost của Windows
    $mode = 'wsl'
    $wslDir = (& wsl.exe wslpath -a ($Services.frontend.Dir -replace '\\','/')).Trim()
    $p = Start-Process wsl.exe -ArgumentList '-e', 'bash', '-lc', "`"cd '$wslDir' && flutter $flutterArgs`"" `
          -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError $err
  } else { throw 'Không tìm thấy flutter (Windows PATH hay WSL)' }
  Set-Content (Get-PidFile 'frontend') $p.Id
  Set-Content (Join-Path $RunDir 'frontend.mode') $mode
  Write-Host "frontend: đang biên dịch (PID $($p.Id)), log: dev\logs\frontend.log"
  if (Wait-Port 3000 300) { Write-Host 'frontend: SẴN SÀNG  http://localhost:3000' }
  else { Write-Warning 'frontend: quá 5 phút chưa mở cổng 3000 — xem dev\logs\frontend*.log' }
}

if ($Target -in 'all','backend')  { Start-Backend }
if ($Target -in 'all','frontend') { Start-Frontend }
