<#
  Dừng môi trường dev.
    .\dev\stop.ps1                 # dừng tất cả
    .\dev\stop.ps1 backend         # chỉ backend
    .\dev\stop.ps1 -Force          # dừng luôn tiến trình lạ đang chiếm cổng 8080/3000
#>
param([ValidateSet('all','backend','frontend','landing')][string]$Target = 'all', [switch]$Force)
. "$PSScriptRoot\_common.ps1"

foreach ($name in 'backend','frontend','landing') {
  if ($Target -ne 'all' -and $Target -ne $name) { continue }
  $id = Get-ServicePid $name
  $modeFile = Join-Path $RunDir "$name.mode"
  if ((Test-Path $modeFile) -and ((Get-Content $modeFile -Raw).Trim() -eq 'wsl')) {
    # dừng flutter/dart bên trong WSL (taskkill chỉ dừng được wsl.exe)
    & wsl.exe -e pkill -f 'flutter_tools.*web-server' 2>&1 | Out-Null
    & wsl.exe -e pkill -f 'web-port=3000' 2>&1 | Out-Null
    Remove-Item $modeFile -Force
  }
  if ($id) { Stop-Tree $id; Remove-Item (Get-PidFile $name) -Force -ErrorAction SilentlyContinue; Write-Host "${name}: đã dừng (PID $id)" }
  else { Write-Host "${name}: không chạy" }
  if ($Force) {
    $owner = Get-PortOwner $Services[$name].Port
    if ($owner) { Stop-Tree $owner; Write-Host "${name}: đã dừng tiến trình $owner chiếm cổng $($Services[$name].Port)" }
  }
}
