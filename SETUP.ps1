# KrishiMitra one-click setup and build.
# Run from this folder:  powershell -ExecutionPolicy Bypass -File .\SETUP.ps1

$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)

Write-Host ""
Write-Host "=== KrishiMitra setup ===" -ForegroundColor Green

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter was not found. Open a terminal where the 'flutter' command works, then run this again." -ForegroundColor Red
  exit 1
}

# 1. Gemini key
$secretsPath = Join-Path $PSScriptRoot "lib\secrets.dart"
$secretsText = Get-Content $secretsPath -Raw
if ($secretsText -match 'PASTE_YOUR') {
  $key = Read-Host "Paste your Gemini API key (or press Enter to add it later in lib\secrets.dart)"
  $key = $key.Trim().Replace("'", "").Replace('"', "")
  if ($key.Length -gt 0) {
    [System.IO.File]::WriteAllText($secretsPath, "const String geminiKey = '$key';`r`n", $utf8)
    Write-Host "Gemini key saved." -ForegroundColor Green
  }
}

# 2. Android project files (generated fresh by your own Flutter version)
if (-not (Test-Path "android")) {
  Write-Host "Creating Android project files..." -ForegroundColor Cyan
  $tmp = Join-Path $env:TEMP ("km_scaffold_" + [guid]::NewGuid().ToString("N"))
  flutter create --no-pub --project-name krishimitra --org com.example --platforms android $tmp
  if (-not (Test-Path (Join-Path $tmp "android"))) {
    Write-Host "Could not create the Android files. Check that Flutter works: run 'flutter doctor'." -ForegroundColor Red
    exit 1
  }
  Copy-Item (Join-Path $tmp "android") (Join-Path $PSScriptRoot "android") -Recurse -Force
  Remove-Item $tmp -Recurse -Force
}

# 3. Manifest: app name and internet permission
$manifest = Join-Path $PSScriptRoot "android\app\src\main\AndroidManifest.xml"
$x = [System.IO.File]::ReadAllText($manifest)
$x = $x -replace 'android:label="[^"]*"', 'android:label="KrishiMitra"'
if ($x -notmatch 'android.permission.INTERNET') {
  $x = $x.Replace('<application', "<uses-permission android:name=`"android.permission.INTERNET`"/>`r`n    <application")
}
[System.IO.File]::WriteAllText($manifest, $x, $utf8)

# 4. Gradle settings that avoid the Kotlin cache and JVM target errors
$gp = Join-Path $PSScriptRoot "android\gradle.properties"
$gpText = [System.IO.File]::ReadAllText($gp)
if ($gpText -notmatch 'kotlin.incremental') {
  $gpText = $gpText.TrimEnd() + "`r`nkotlin.incremental=false`r`nkotlin.jvm.target.validation.mode=IGNORE`r`n"
  [System.IO.File]::WriteAllText($gp, $gpText, $utf8)
}

# 5. Packages and app icon
Write-Host "Getting packages..." -ForegroundColor Cyan
flutter pub get
Write-Host "Creating app icon..." -ForegroundColor Cyan
dart run flutter_launcher_icons

# 6. Build
Write-Host ""
Write-Host "Building the app. The first build takes 3 to 10 minutes..." -ForegroundColor Cyan
$started = Get-Date
flutter build apk --release

# 7. Find the APK (even if Flutter could not find it itself)
$apk = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "app-release.apk" -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -gt $started.AddMinutes(-1) } |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($apk) {
  $desk = [Environment]::GetFolderPath('Desktop')
  $dest = Join-Path $desk "KrishiMitra_final.apk"
  Copy-Item $apk.FullName $dest -Force
  Write-Host ""
  Write-Host "DONE. Your app is on the Desktop: KrishiMitra_final.apk" -ForegroundColor Green
  Write-Host "Copy it to the phone and install it. Uninstall the old KrishiMitra first." -ForegroundColor Green
  explorer $desk
} else {
  Write-Host ""
  Write-Host "The build did not finish. Scroll up and copy the lines that start with 'Error' or 'What went wrong', and send them to me." -ForegroundColor Red
}
