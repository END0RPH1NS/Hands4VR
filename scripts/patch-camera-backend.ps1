$ErrorActionPreference = 'Stop'

$root = (Get-Location).Path
$cameraPath = Join-Path $root 'third_party/VRchatFACE-HAND-ARM-tracking/hub/src-tauri/src/tracking/camera.rs'
if (-not (Test-Path $cameraPath)) { throw "Camera source not found: $cameraPath" }

$src = Get-Content $cameraPath -Raw

# On Windows the Hub must use the same Media Foundation backend for enumeration,
# benchmarking and actual capture. Mixing MediaFoundation + Auto can produce a
# camera entry whose numeric index no longer refers to the same device.
$oldBackends = 'let backends_to_try = vec![ApiBackend::MediaFoundation, ApiBackend::Auto];'
$newBackends = 'let backends_to_try = vec![ApiBackend::MediaFoundation];'
if ($src.Contains($oldBackends)) {
    $src = $src.Replace($oldBackends, $newBackends)
} elseif (-not $src.Contains($newBackends)) {
    throw 'Could not locate Windows camera backend list.'
}

# The benchmark previously used Camera::new(), which selects ApiBackend::Auto.
# Force it to the same Windows Media Foundation backend used by real tracking.
$oldBenchmark = 'Camera::new(index.clone(), req)'
$newBenchmark = 'Camera::with_backend(index.clone(), req, ApiBackend::MediaFoundation)'
$src = $src.Replace($oldBenchmark, $newBenchmark)

Set-Content $cameraPath $src -Encoding UTF8

Write-Host 'Camera backend patch applied: Windows uses MediaFoundation consistently.'
