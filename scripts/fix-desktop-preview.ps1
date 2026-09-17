$ErrorActionPreference = 'Stop'

$hub = Join-Path (Get-Location).Path 'third_party/VRchatFACE-HAND-ARM-tracking/hub'
$mainJsPath = Join-Path $hub 'src/main.js'
if (-not (Test-Path $mainJsPath)) { throw "Hub main.js not found: $mainJsPath" }

$mainJs = Get-Content $mainJsPath -Raw
$old = 'http://localhost:9001/stream'
$new = 'http://127.0.0.1:9001/stream'
if ($mainJs.Contains($old)) {
    $mainJs = $mainJs.Replace($old, $new)
    Set-Content $mainJsPath $mainJs -Encoding UTF8
    Write-Host 'Fixed desktop preview URL: localhost -> 127.0.0.1'
} elseif ($mainJs.Contains($new)) {
    Write-Host 'Desktop preview URL already fixed.'
} else {
    throw 'Could not find the desktop MJPEG preview URL in main.js.'
}
