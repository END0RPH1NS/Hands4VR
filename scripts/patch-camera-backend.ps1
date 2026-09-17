$ErrorActionPreference = 'Stop'

$root = (Get-Location).Path
$cameraPath = Join-Path $root 'third_party/VRchatFACE-HAND-ARM-tracking/hub/src-tauri/src/tracking/camera.rs'
if (-not (Test-Path $cameraPath)) { throw "Camera source not found: $cameraPath" }

$src = Get-Content $cameraPath -Raw

# Windows must use the same Media Foundation backend for enumeration,
# benchmarking, strict format opening and actual capture. Mixing MediaFoundation
# enumeration with Camera::new(Auto) can make the selected numeric index refer
# to a different device/backend and results in a detected camera with no stream.
$oldBackends = 'let backends_to_try = vec![ApiBackend::MediaFoundation, ApiBackend::Auto];'
$newBackends = 'let backends_to_try = vec![ApiBackend::MediaFoundation];'
if ($src.Contains($oldBackends)) {
    $src = $src.Replace($oldBackends, $newBackends)
} elseif (-not $src.Contains($newBackends)) {
    throw 'Could not locate Windows camera backend list.'
}

# Force the strict requested-format path to the same Windows backend.
$oldStrict = 'match Camera::new(index.clone(), req) {'
$newStrict = @'
let strict_camera = {
    #[cfg(target_os = "windows")]
    {
        Camera::with_backend(index.clone(), req, ApiBackend::MediaFoundation)
    }
    #[cfg(not(target_os = "windows"))]
    {
        Camera::new(index.clone(), req)
    }
};
match strict_camera {
'@.TrimEnd()
if ($src.Contains($oldStrict)) {
    $src = $src.Replace($oldStrict, $newStrict)
} elseif (-not $src.Contains('let strict_camera = {')) {
    throw 'Could not locate strict camera open path.'
}

# The benchmark must use the same backend as actual capture.
$oldBenchmark = 'Camera::new(index.clone(), req)'
$newBenchmark = 'Camera::with_backend(index.clone(), req, ApiBackend::MediaFoundation)'
$src = $src.Replace($oldBenchmark, $newBenchmark)

Set-Content $cameraPath $src -Encoding UTF8

Write-Host 'Camera backend patch applied: Windows enumeration, benchmark and strict capture use MediaFoundation consistently.'
