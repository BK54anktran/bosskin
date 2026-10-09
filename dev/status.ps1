<#
  Trạng thái môi trường dev + 15 dòng log cuối.
    .\dev\status.ps1            .\dev\status.ps1 -Lines 50
#>
param([int]$Lines = 15)
. "$PSScriptRoot\_common.ps1"

Write-Host ("MySQL     cổng {0}: {1}" -f $MySqlPort, $(if (Test-Port $MySqlPort) {'đang nghe'} else {'KHÔNG chạy'}))
foreach ($name in 'backend','frontend','landing') {
  $port = $Services[$name].Port
  $id = Get-ServicePid $name
  $state = if ($id -and (Test-Port $port)) { 'SẴN SÀNG' } elseif ($id) { 'đang khởi động' } elseif (Test-Port $port) { "cổng bị tiến trình $(Get-PortOwner $port) chiếm" } else { 'dừng' }
  Write-Host ("{0,-9} cổng {1}: {2}{3}" -f $name, $port, $state, $(if ($id) {" (PID $id)"} else {''}))
  foreach ($f in "$name.log", "$name.err.log") {
    $path = Join-Path $LogDir $f
    if ((Test-Path $path) -and (Get-Item $path).Length -gt 0) {
      Write-Host "  --- $f ---"; Get-Content $path -Tail $Lines | ForEach-Object { "  $_" }
    }
  }
}
