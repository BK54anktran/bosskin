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

function Wait-Port($port, $seconds) {
  $deadline = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-Port $port) { return $true }
    Start-Sleep -Seconds 2
  }
  return $false
}

function Stop-Tree($id) {
  # taskkill /T dừng cả cây tiến trình (cmd → java / flutter → dart)
  & taskkill.exe /PID $id /T /F 2>&1 | Out-Null
}
