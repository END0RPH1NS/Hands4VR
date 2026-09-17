$ErrorActionPreference = 'Stop'

$root = (Get-Location).Path
$hub = Join-Path $root 'third_party/VRchatFACE-HAND-ARM-tracking/hub'
$sourceOutput = Join-Path $root 'third_party/HandOfLesser/output'
$resource = Join-Path $hub 'src-tauri/handoflesser'

if (-not (Test-Path $hub)) { throw "VRChat Bridge Hub source not found: $hub" }
if (-not (Test-Path $sourceOutput)) { throw "HandOfLesser output not found: $sourceOutput" }

New-Item -ItemType Directory -Force -Path $resource | Out-Null
Copy-Item -Recurse -Force (Join-Path $sourceOutput '*') $resource

$confPath = Join-Path $hub 'src-tauri/tauri.conf.json'
$conf = Get-Content $confPath -Raw | ConvertFrom-Json
$conf.productName = 'Hands4VR'
$conf.identifier = 'com.hands4vr.app'
$conf.bundle.resources = @('./handoflesser/')
$conf.bundle.targets = @('nsis','msi')
$conf | ConvertTo-Json -Depth 20 | Set-Content $confPath -Encoding UTF8

$libPath = Join-Path $hub 'src-tauri/src/lib.rs'
$lib = Get-Content $libPath -Raw

if ($lib -notmatch 'fn start_handoflesser') {
    $lib = $lib.Replace(
        'use tauri::{State, Manager, Emitter};',
        "use tauri::{State, Manager, Emitter};`nuse tauri::path::BaseDirectory;`nuse std::process::Command;"
    )

    $marker = '/// Get list of available cameras'
    $insert = @'
#[tauri::command]
fn start_handoflesser(app: tauri::AppHandle) -> Result<bool, String> {
    let driver_dir = app.path().resolve("handoflesser/drivers/00handoflesser", BaseDirectory::Resource)
        .map_err(|e| e.to_string())?;
    let exe = driver_dir.join("resources/bin/win64/HandOfLesser.exe");
    if !exe.exists() {
        return Err(format!("Bundled HandOfLesser.exe not found: {}", exe.display()));
    }

    let candidates = [
        std::path::PathBuf::from(r"C:\Program Files (x86)\Steam\steamapps\common\SteamVR\bin\win64\vrpathreg.exe"),
        std::path::PathBuf::from(r"C:\Program Files\Steam\steamapps\common\SteamVR\bin\win64\vrpathreg.exe"),
    ];
    if let Some(vrpathreg) = candidates.iter().find(|p| p.exists()) {
        let _ = Command::new(vrpathreg).arg("removedriverswithname").arg("00handoflesser").status();
        let _ = Command::new(vrpathreg).arg("adddriver").arg(&driver_dir).status();
    }

    let _ = Command::new(&exe)
        .current_dir(&driver_dir)
        .arg("-activatemultipledrivers")
        .status();

    Command::new(&exe)
        .current_dir(&driver_dir)
        .spawn()
        .map_err(|e| format!("Failed to start HandOfLesser: {}", e))?;
    Ok(true)
}

'@
    $lib = $lib.Replace($marker, $insert + $marker)
}

if ($lib -notmatch 'start_handoflesser,') {
    $lib = $lib.Replace('            get_cameras,', '            start_handoflesser,`n            get_cameras,')
}

if ($lib -notmatch 'let _ = start_handoflesser') {
    $setupMarker = '            Ok(())'
    $setupIndex = $lib.LastIndexOf($setupMarker)
    if ($setupIndex -lt 0) { throw 'Could not locate Tauri setup return marker.' }
    $startup = "            let _ = start_handoflesser(app.handle().clone());`n"
    $lib = $lib.Insert($setupIndex, $startup)
}

Set-Content $libPath $lib -Encoding UTF8

@'
Hands4VR unified build
Core UI/AI/OSC engine: VRChat Bridge Hub
Native SteamVR/OpenXR hand driver: HandOfLesser
Additional source components: VRC-Skeletal-Hands, HandCameraDriver, AetherVR
'@ | Set-Content (Join-Path $root 'BUILD_COMPONENTS.txt') -Encoding UTF8

Write-Host 'Unified Hands4VR source preparation completed.'
