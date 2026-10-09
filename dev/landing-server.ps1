<#
  Máy chủ tĩnh nhỏ cho trang giới thiệu (landing\) — chạy qua dev\start.ps1 landing.
  Dùng HttpListener có sẵn của Windows, hỗ trợ Range để tua video.
#>
param([int]$Port = 8099, [string]$Root = (Join-Path (Split-Path -Parent $PSScriptRoot) 'landing'))
$ErrorActionPreference = 'Stop'
$types = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css'; '.js'='text/javascript'; '.json'='application/json'
  '.png'='image/png'; '.jpg'='image/jpeg'; '.webp'='image/webp'; '.svg'='image/svg+xml'; '.ico'='image/x-icon'
  '.mp4'='video/mp4'; '.vtt'='text/vtt'; '.md'='text/plain; charset=utf-8' }
$rootFull = [IO.Path]::GetFullPath($Root)
$http = New-Object Net.HttpListener
$http.Prefixes.Add("http://localhost:$Port/")
$http.Start()
Write-Host "landing: phục vụ $rootFull tại http://localhost:$Port/"
while ($http.IsListening) {
  $ctx = $http.GetContext(); $req = $ctx.Request; $res = $ctx.Response
  try {
    $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
    if ($rel -eq '' -or $rel.EndsWith('/')) { $rel += 'index.html' }
    $path = [IO.Path]::GetFullPath((Join-Path $rootFull $rel))
    if (-not $path.StartsWith($rootFull) -or -not (Test-Path $path -PathType Leaf)) {
      $res.StatusCode = 404; $b = [Text.Encoding]::UTF8.GetBytes('404'); $res.OutputStream.Write($b, 0, $b.Length)
    } else {
      $ext = [IO.Path]::GetExtension($path).ToLower()
      $res.ContentType = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
      $res.AddHeader('Accept-Ranges', 'bytes'); $res.AddHeader('Cache-Control', 'no-cache')
      $fs = [IO.File]::OpenRead($path)
      try {
        $len = $fs.Length; $start = 0; $end = $len - 1
        $range = $req.Headers['Range']
        if ($range -match '^bytes=(\d*)-(\d*)$') {
          if ($Matches[1]) { $start = [long]$Matches[1] }
          if ($Matches[2]) { $end = [Math]::Min([long]$Matches[2], $len - 1) }
          elseif (-not $Matches[1]) { $start = $len - [long]$Matches[2] }
          $res.StatusCode = 206; $res.AddHeader('Content-Range', "bytes $start-$end/$len")
        }
        $res.ContentLength64 = $end - $start + 1
        if ($req.HttpMethod -ne 'HEAD') {
          $fs.Seek($start, 'Begin') | Out-Null
          $buf = New-Object byte[] 262144; $left = $end - $start + 1
          while ($left -gt 0) {
            $n = $fs.Read($buf, 0, [Math]::Min($buf.Length, $left)); if ($n -le 0) { break }
            $res.OutputStream.Write($buf, 0, $n); $left -= $n
          }
        }
      } finally { $fs.Close() }
    }
  } catch { }   # trình duyệt huỷ tải giữa chừng (tua video) — bỏ qua
  finally { try { $res.Close() } catch { } }
}
