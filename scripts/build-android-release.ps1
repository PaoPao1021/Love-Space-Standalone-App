param(
  [Parameter(Mandatory = $true)][string]$ApiBaseUrl,
  [Parameter(Mandatory = $true)][string]$GetuiAppId,
  [string]$DownloadUrl = "",
  [string]$Version = "1.0.0",
  [int]$BuildNumber = 1
)

$ErrorActionPreference = "Stop"
$workspace = Split-Path -Parent $PSScriptRoot
$appDirectory = Join-Path $workspace "app"
$keyProperties = Join-Path $appDirectory "android\key.properties"
if (-not (Test-Path -LiteralPath $keyProperties)) {
  throw "Missing app/android/key.properties. Keep the keystore outside the repository and copy key.properties.example."
}

Push-Location $appDirectory
try {
  flutter build apk --release `
    --build-name=$Version `
    --build-number=$BuildNumber `
    --dart-define=API_BASE_URL=$ApiBaseUrl `
    -PGETUI_APPID=$GetuiAppId
} finally {
  Pop-Location
}

$sourceApk = Join-Path $appDirectory "build\app\outputs\flutter-apk\app-release.apk"
$releaseDirectory = Join-Path $appDirectory "web\releases"
$targetName = "lovespace-$Version.apk"
$targetApk = Join-Path $releaseDirectory $targetName
New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null
Copy-Item -LiteralPath $sourceApk -Destination $targetApk -Force
$sha256 = (Get-FileHash -LiteralPath $targetApk -Algorithm SHA256).Hash.ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($DownloadUrl)) {
  $DownloadUrl = "$($ApiBaseUrl.TrimEnd('/'))/releases/$targetName"
}
$manifest = [ordered]@{
  version = $Version
  buildNumber = $BuildNumber
  downloadUrl = $DownloadUrl
  sha256 = $sha256
  notes = "LoveSpace 双端核心闭环版本"
}
$manifestJson = $manifest | ConvertTo-Json
$manifestJson | Set-Content -LiteralPath (Join-Path $releaseDirectory "android.json") -Encoding utf8

# When Web was built first, keep its deployable output in sync as well.
$builtWebDirectory = Join-Path $appDirectory "build\web"
if (Test-Path -LiteralPath $builtWebDirectory) {
  $builtReleaseDirectory = Join-Path $builtWebDirectory "releases"
  New-Item -ItemType Directory -Path $builtReleaseDirectory -Force | Out-Null
  Copy-Item -LiteralPath $targetApk -Destination (Join-Path $builtReleaseDirectory $targetName) -Force
  $manifestJson | Set-Content -LiteralPath (Join-Path $builtReleaseDirectory "android.json") -Encoding utf8
}
Write-Output "APK: $targetApk"
Write-Output "SHA-256: $sha256"
