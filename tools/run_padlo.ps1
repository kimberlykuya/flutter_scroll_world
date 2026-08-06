param(
  [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$padloProject = Join-Path $repositoryRoot 'examples\padlo_poc'
$fvmConfigPath = Join-Path $repositoryRoot '.fvmrc'
$fvmConfig = Get-Content -LiteralPath $fvmConfigPath -Raw | ConvertFrom-Json
$padloSdkVersion = $fvmConfig.flutter
$flutterExecutable = Join-Path $env:USERPROFILE "fvm\versions\$padloSdkVersion\bin\flutter.bat"

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
