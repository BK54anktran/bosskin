<#
  Bộ chạy lệnh dev cho Claude (chạy 1 lần, để mở): dev\runner.cmd
  Claude không chạy được lệnh Windows trực tiếp (shell của Claude là máy ảo Linux, không thấy
  Java/Flutter/MySQL của Windows), nên Claude ghi một file yêu cầu vào dev\run\requests\<id>.req
  chứa TÊN LỆNH; runner này chỉ chạy các lệnh trong danh sách cho phép bên dưới, ghi kết quả vào
  dev\logs\runner.log và dev\run\results\<id>.txt.
  KHÔNG có lệnh xoá dữ liệu (reset-db) trong danh sách — việc đó chỉ chủ dự án tự chạy.
#>
. "$PSScriptRoot\_common.ps1"
$ErrorActionPreference = 'Continue'
$Req = Join-Path $RunDir 'requests'; $Res = Join-Path $RunDir 'results'
New-Item -ItemType Directory -Force -Path $Req, $Res | Out-Null
$Allowed = @{
  'start'          = @('start.ps1')
  'start-backend'  = @('start.ps1', 'backend')
  'start-frontend' = @('start.ps1', 'frontend')
  'stop'           = @('stop.ps1')
  'stop-backend'   = @('stop.ps1', 'backend')
  'stop-frontend'  = @('stop.ps1', 'frontend')
  'start-landing'  = @('start.ps1', 'landing')
  'stop-landing'   = @('stop.ps1', 'landing')
  'restart-backend'  = @('restart', 'backend')
  'restart-frontend' = @('restart', 'frontend')
  'status'         = @('status.ps1')
  'seed-th'        = @('seed-th.ps1')
}
$log = Join-Path $LogDir 'runner.log'
"$(Get-Date -Format s) runner started (PID $PID)" | Add-Content $log
Write-Host "Runner đang chờ lệnh từ Claude... (đóng cửa sổ này để tắt)"
while ($true) {
  Set-Content (Join-Path $RunDir 'runner.alive') (Get-Date -Format s)
  foreach ($f in Get-ChildItem $Req -Filter *.req -ErrorAction SilentlyContinue | Sort-Object LastWriteTime) {
    $name = (Get-Content $f.FullName -Raw).Trim().ToLower()
    Remove-Item $f.FullName -Force
    $out = Join-Path $Res ($f.BaseName + '.txt')
    if (-not $Allowed.ContainsKey($name)) {
      "REFUSED: '$name' không có trong danh sách cho phép" | Set-Content $out
      "$(Get-Date -Format s) refused '$name'" | Add-Content $log
      continue
    }
    "$(Get-Date -Format s) run '$name'" | Add-Content $log
    Write-Host "$(Get-Date -Format T)  $name"
    $a = $Allowed[$name]
    $text = if ($a[0] -eq 'restart') {
      (& "$PSScriptRoot\stop.ps1" $a[1] *>&1 | Out-String) + (& "$PSScriptRoot\start.ps1" $a[1] *>&1 | Out-String)
    } else {
      $rest = @($a | Select-Object -Skip 1)
      & (Join-Path $PSScriptRoot $a[0]) @rest *>&1 | Out-String
    }
    ($text + "`nDONE $(Get-Date -Format s)") | Set-Content $out -Encoding UTF8
  }
  Start-Sleep -Seconds 2
}
