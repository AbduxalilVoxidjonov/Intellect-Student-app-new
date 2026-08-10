<#
  Play Console uchun chiqarish (release) build'i.

  Nima qiladi:
    1. pubspec.yaml dan versiyani o'qiydi (masalan 1.0.0+1).
    2. android/key.properties borligini tekshiradi — yo'q bo'lsa TO'XTAYDI
       (debug kaliti bilan imzolangan AAB'ni Play qabul qilmaydi, lekin buni
       faqat yuklash paytida aytadi — vaqtni behuda sarflamaslik uchun oldin
       tekshiramiz).
    3. flutter analyze + flutter test ni ishga tushiradi (--skip-checks bilan o'tkazib
       yuborish mumkin).
    4. AAB (Play uchun) va arm64 APK (telefonda sinash uchun) yig'adi.
    5. Ikkalasini release/ papkasiga VERSIYA NOMI bilan nusxalaydi:
         release/intellect-student-1.0.0-build1.aab
         release/intellect-student-1.0.0-build1.apk
       Shu sabab eski build'lar ustiga yozilmaydi va Play'ga qaysi fayl
       yuklanganini keyin ham aniqlash mumkin.

  Ishlatish:
    powershell -ExecutionPolicy Bypass -File tool\release.ps1
    powershell -ExecutionPolicy Bypass -File tool\release.ps1 -SkipChecks
    powershell -ExecutionPolicy Bypass -File tool\release.ps1 -NoApk
#>
param(
    [switch]$SkipChecks,
    [switch]$NoApk
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# --- 1. Versiya -------------------------------------------------------------
$versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' |
    Select-Object -First 1
if (-not $versionLine) { throw "pubspec.yaml da 'version:' qatori topilmadi." }
$version = $versionLine.Matches[0].Groups[1].Value.Trim()
# -match ATAYIN musbat shaklda: $Matches faqat shunda ishonchli to'ladi.
if ($version -match '^(?<name>[0-9]+\.[0-9]+\.[0-9]+)\+(?<code>[0-9]+)$') {
    $versionName = $Matches['name']
    $versionCode = $Matches['code']
} else {
    throw "Versiya formati noto'g'ri: '$version'. Kutilgan ko'rinish: 1.0.0+1"
}
Write-Host "Versiya: $versionName (versionCode $versionCode)" -ForegroundColor Cyan

# --- 2. Imzo kaliti ---------------------------------------------------------
if (-not (Test-Path 'android\key.properties')) {
    throw @"
android\key.properties topilmadi — release DEBUG kaliti bilan imzolanardi va
Play Console uni RAD ETADI. Kalitni yarating (PLAY-STORE.md, 5-bo'lim) yoki
zaxiradan tiklang.
"@
}
$storeFile = (Select-String -Path 'android\key.properties' -Pattern '^storeFile=(.+)$').Matches[0].Groups[1].Value.Trim()
if (-not (Test-Path (Join-Path 'android\app' $storeFile))) {
    throw "Keystore fayli topilmadi: android\app\$storeFile"
}

# --- 3. Tekshiruvlar --------------------------------------------------------
if (-not $SkipChecks) {
    Write-Host "flutter analyze..." -ForegroundColor Cyan
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze xato qaytardi — build to'xtatildi." }

    Write-Host "flutter test..." -ForegroundColor Cyan
    flutter test
    if ($LASTEXITCODE -ne 0) { throw "Testlar o'tmadi — build to'xtatildi." }
}

# --- 4. Build ---------------------------------------------------------------
New-Item -ItemType Directory -Force -Path 'release' | Out-Null
$stem = "intellect-student-$versionName-build$versionCode"

Write-Host "flutter build appbundle --release..." -ForegroundColor Cyan
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) { throw "AAB yig'ilmadi." }
Copy-Item 'build\app\outputs\bundle\release\app-release.aab' "release\$stem.aab" -Force

if (-not $NoApk) {
    Write-Host "flutter build apk --release (arm64)..." -ForegroundColor Cyan
    flutter build apk --release --target-platform android-arm64
    if ($LASTEXITCODE -ne 0) { throw "APK yig'ilmadi." }
    Copy-Item 'build\app\outputs\flutter-apk\app-release.apk' "release\$stem.apk" -Force
}

# --- 5. Xulosa --------------------------------------------------------------
Write-Host ""
Write-Host "Tayyor:" -ForegroundColor Green
Get-ChildItem "release\$stem.*" | ForEach-Object {
    "{0,-46} {1,8:N1} MB" -f $_.Name, ($_.Length / 1MB)
}
Write-Host ""
Write-Host "Play Console -> Production -> Create new release -> .aab faylni yuklang." -ForegroundColor Yellow
Write-Host "Keyingi build uchun pubspec.yaml dagi +$versionCode ni oshirishni unutmang." -ForegroundColor Yellow
