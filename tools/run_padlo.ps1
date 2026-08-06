param(
  [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$padloProject = Join-Path $repositoryRoot 'examples\padlo_poc'
$fvmConfigPath = Join-Path $repositoryRoot '.fvmrc'
$fvmConfig = Get-Content -LiteralPath $fvmConfigPath -Raw | ConvertFrom-Json
$padloSdkVersion = $fvmConfig.flutter
$versionsRoot = Join-Path $env:USERPROFILE 'fvm\versions'
$flutterExecutable = Join-Path $versionsRoot "$padloSdkVersion\bin\flutter.bat"

if (-not (Test-Path -LiteralPath $flutterExecutable)) {
  $compatibleSdks = @(
    Get-ChildItem -LiteralPath $versionsRoot -Directory -Filter "$padloSdkVersion*" -ErrorAction SilentlyContinue |
      Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\flutter.bat') }
  )
  if ($compatibleSdks.Count -eq 1) {
    $flutterExecutable = Join-Path $compatibleSdks[0].FullName 'bin\flutter.bat'
  }
}

if (-not (Test-Path -LiteralPath $flutterExecutable)) {
  throw "Pinned Flutter SDK not found at $flutterExecutable. Run 'fvm install' from $repositoryRoot first."
}

Push-Location $padloProject
try {
  & $flutterExecutable config --enable-native-assets --enable-dart-data-assets
  if (-not $SkipPubGet) {
    & $flutterExecutable pub get
  }
  & $flutterExecutable run -d chrome
} finally {
  Pop-Location
}
