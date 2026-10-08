# Dùng chung cho start/stop/status. Chạy trên Windows PowerShell 5+ (máy dev).
$ErrorActionPreference = 'Stop'
$Root    = Split-Path -Parent $PSScriptRoot
$DevDir  = $PSScriptRoot
$LogDir  = Join-Path $DevDir 'logs'
$RunDir  = Join-Path $DevDir 'run'
New-Item -ItemType Directory -Force -Path $LogDir, $RunDir | Out-Null

$Services = @{
  backend  = @{ Port = 8080; Dir = (Join-Path $Root 'backend') }
  frontend = @{ Port = 3000; Dir = (Join-Path $Root 'frontend') }
}
$MySqlPort = 3306

function Get-PidFile($name) { Join-Path $RunDir "$name.pid" }

function Get-ServicePid($name) {
  $f = Get-PidFile $name
  if (-not (Test-Path $f)) { return $null }
  $id = [int](Get-Content $f -Raw).Trim()
  if (Get-Process -Id $id -ErrorAction SilentlyContinue) { return $id }
  Remove-Item $f -Force
  return $null
}

function Test-Port($port) {
  [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
}

function Get-PortOwner($port) {
  $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return $c.OwningProcess }
  return $null
}

function Wait-Port($port, $seconds, $procId) {
  # Trả về $true khi cổng mở; $false khi hết giờ hoặc tiến trình đã thoát (khởi động lỗi)
  $deadline = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-Port $port) { return $true }
    if ($procId -and -not (Get-Process -Id $procId -ErrorAction SilentlyContinue)) { return $false }
    Start-Sleep -Seconds 2
  }
  return $false
}

function Show-LogTail($name) {
  foreach ($f in "$name.err.log", "$name.log") {
    $path = Join-Path $LogDir $f
    if ((Test-Path $path) -and (Get-Item $path).Length -gt 0) {
      Write-Host "--- $f (20 dòng cuối) ---"; Get-Content $path -Tail 20
    }
  }
}

function Stop-Tree($id) {
  # taskkill /T dừng cả cây tiến trình (cmd → java / flutter → dart)
  & taskkill.exe /PID $id /T /F 2>&1 | Out-Null
}

function Start-Detached($command, $workDir, $log, $err) {
  # Chạy trong cửa sổ console ẩn RIÊNG (ShellExecute) để đóng cửa sổ gọi script
  # không kéo theo server; log ghi bằng chuyển hướng của cmd.
  Start-Process cmd.exe -ArgumentList '/c', "$command > `"$log`" 2> `"$err`"" `
    -WorkingDirectory $workDir -WindowStyle Hidden -PassThru
}
