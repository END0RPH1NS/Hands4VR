$ErrorActionPreference = 'Stop'

$hub = Join-Path (Get-Location).Path 'third_party/VRchatFACE-HAND-ARM-tracking/hub'
$mainJsPath = Join-Path $hub 'src/main.js'
if (-not (Test-Path $mainJsPath)) { throw "Hub main.js not found: $mainJsPath" }

$mainJs = Get-Content $mainJsPath -Raw
$old = 'http://localhost:9001/stream'
$new = 'http://127.0.0.1:9001/stream'
if ($mainJs.Contains($old)) {
    $mainJs = $mainJs.Replace($old, $new)
}

# The WebView can request /stream before the first camera frame exists. The
# broadcast-only endpoint then waits forever on an empty channel. Use the
# snapshot as a deterministic readiness probe and only attach MJPEG after a
# real JPEG is available. This also gives us a visible connection state.
$oldStart = @'
async function startVideoStream() {
  elements.videoPlaceholder.classList.add('hidden');
  if (elements.videoFrame) {
    elements.videoFrame.src = "http://127.0.0.1:9001/stream";
    elements.videoFrame.classList.add('active');
  }
  if (elements.landmarkCanvas) elements.landmarkCanvas.classList.add('active');
  elements.videoOverlay.classList.add('active');

  updateMirrorMode(); // Ensure mirror state is applied

  if (renderInterval) clearInterval(renderInterval);
  renderInterval = setInterval(renderLoop, 50); // ~20 FPS for visualization
}
'@.TrimEnd()
$newStart = @'
async function startVideoStream() {
  elements.videoPlaceholder.classList.add('hidden');
  if (elements.landmarkCanvas) elements.landmarkCanvas.classList.add('active');
  elements.videoOverlay.classList.add('active');

  updateMirrorMode();

  // Wait for an actual JPEG. /stream is a broadcast channel and a browser
  // connected before the first frame can otherwise sit in "No Stream" forever.
  if (elements.videoFrame) {
    elements.videoFrame.classList.add('active');
    elements.videoFrame.src = '';
  }

  const streamUrl = 'http://127.0.0.1:9001/stream';
  const snapshotUrl = 'http://127.0.0.1:9001/snapshot';
  let ready = false;
  for (let i = 0; i < 80 && isTracking; i++) {
    try {
      const response = await fetch(snapshotUrl, { cache: 'no-store' });
      if (response.ok && response.headers.get('content-type')?.includes('image/jpeg')) {
        ready = true;
        break;
      }
    } catch (_) {}
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  if (ready && elements.videoFrame) {
    elements.videoFrame.src = streamUrl;
  } else if (elements.videoFrame) {
    elements.videoFrame.classList.remove('active');
    elements.videoPlaceholder.classList.remove('hidden');
    console.error('Camera preview did not produce a JPEG on /snapshot within 8 seconds.');
  }

  if (renderInterval) clearInterval(renderInterval);
  renderInterval = setInterval(renderLoop, 50);
}
'@.TrimEnd()
if ($mainJs.Contains($oldStart)) {
    $mainJs = $mainJs.Replace($oldStart, $newStart)
} elseif (-not $mainJs.Contains('const snapshotUrl =')) {
    throw 'Could not locate startVideoStream() in main.js.'
}

Set-Content $mainJsPath $mainJs -Encoding UTF8
Write-Host 'Desktop preview patch applied: waits for a real JPEG snapshot before opening MJPEG stream.'
