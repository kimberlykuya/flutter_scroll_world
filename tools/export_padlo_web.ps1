[CmdletBinding()]
param(
  [string]$RepositoryName = 'flutter_scroll_world',
  [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$padloProject = Join-Path $repositoryRoot 'examples\padlo_poc'
$buildRoot = Join-Path $repositoryRoot 'build'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $buildRoot 'padlo_web_export'
}

$fvmConfig = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot '.fvmrc') | ConvertFrom-Json
$sdkRevision = [string]$fvmConfig.flutter
$flutterExecutable = Join-Path $env:USERPROFILE "fvm\versions\$sdkRevision\bin\flutter.bat"
if (-not (Test-Path -LiteralPath $flutterExecutable)) {
  throw "Pinned Flutter SDK $sdkRevision is missing. Run 'fvm install' from the repository root first."
}

$baseHref = "/$RepositoryName/padlo/"
Push-Location $padloProject
try {
  & $flutterExecutable config --enable-native-assets --enable-dart-data-assets
  if ($LASTEXITCODE -ne 0) { throw 'Could not enable Flutter native/data assets.' }
  & $flutterExecutable pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
  & $flutterExecutable build web --release --no-wasm-dry-run --base-href $baseHref
  if ($LASTEXITCODE -ne 0) { throw 'Padlo release web build failed.' }
} finally {
  Pop-Location
}

$webBuild = Join-Path $padloProject 'build\web'
$indexPath = Join-Path $webBuild 'index.html'
$glbPath = Join-Path $webBuild 'assets\assets\scene\padlo-pilot.glb'
$shaderPath = Join-Path $webBuild 'assets\packages\flutter_scene\build\shaderbundles\base.shaderbundle'
$logoPath = Join-Path $webBuild 'assets\assets\brand\padlo-logo.png'

foreach ($required in @($indexPath, $glbPath, $shaderPath, $logoPath)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Required Padlo web export file is missing: $required"
  }
  if ((Get-Item -LiteralPath $required).Length -le 0) {
    throw "Required Padlo web export file is empty: $required"
  }
}

$index = Get-Content -Raw -LiteralPath $indexPath
if ($index -notmatch [regex]::Escape("<base href=`"$baseHref`">") ) {
  throw "The generated index.html does not contain the Pages base href $baseHref."
}
if ((Get-Item -LiteralPath $glbPath).Length -gt 12MB) {
  throw 'The Padlo GLB exceeds the 12 MiB pilot budget.'
}
$videos = Get-ChildItem -LiteralPath $webBuild -Recurse -File -Include *.mp4,*.webm,*.mov
if ($videos) {
  throw "Padlo export unexpectedly contains video files: $($videos.FullName -join ', ')"
}

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot).TrimEnd('\') + '\'
$resolvedOutput = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')
if (-not ($resolvedOutput + '\').StartsWith($resolvedBuildRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw "OutputDirectory must remain inside $buildRoot."
}
if (Test-Path -LiteralPath $resolvedOutput) {
  Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}
New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
Copy-Item -Path (Join-Path $webBuild '*') -Destination $resolvedOutput -Recurse -Force
New-Item -ItemType File -Path (Join-Path $resolvedOutput '.nojekyll') -Force | Out-Null

$glb = Get-Item -LiteralPath $glbPath
$shader = Get-Item -LiteralPath $shaderPath
Write-Host ''
Write-Host 'Padlo GitHub Pages export is ready.' -ForegroundColor Green
Write-Host "Output:  $resolvedOutput"
Write-Host "Base URL: $baseHref"
Write-Host "GLB:     $([math]::Round($glb.Length / 1MB, 2)) MiB"
Write-Host "Shaders: $([math]::Round($shader.Length / 1MB, 2)) MiB"
Write-Host "Deploy:  https://<owner>.github.io/$RepositoryName/padlo/"
