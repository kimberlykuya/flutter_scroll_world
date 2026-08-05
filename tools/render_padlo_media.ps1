param(
  [ValidateSet('landscape','portrait','all')]
  [string]$Profile = 'all',
  [ValidateSet('validate','preview','render','encode')]
  [string]$Mode = 'render',
  [string]$BlenderPath = 'C:\Users\USER\Tools\blender-5.2.0-windows-x64\blender.exe',
  [string]$OutputRoot = (Join-Path $PSScriptRoot '..\build\padlo_blender'),
  [string]$AssetRoot = (Join-Path $PSScriptRoot '..\examples\padlo_poc\assets')
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

if (-not (Test-Path -LiteralPath $BlenderPath)) {
  $command = Get-Command blender.exe -ErrorAction SilentlyContinue
  if (-not $command) { throw 'Blender 5.2 was not found. Pass -BlenderPath.' }
  $BlenderPath = $command.Source
}

$generator = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'blender\generate_padlo_world.py')).Path
$output = [System.IO.Path]::GetFullPath($OutputRoot)
$assets = [System.IO.Path]::GetFullPath($AssetRoot)
$profiles = if ($Profile -eq 'all') { @('landscape','portrait') } else { @($Profile) }

if ($Mode -ne 'encode') {
  foreach ($current in $profiles) {
    Invoke-Checked $BlenderPath @(
      '--background','--factory-startup','--python-exit-code','1',
      '--python',$generator,'--','--profile',$current,'--mode',$Mode,'--output',$output
    )
  }
}
if ($Mode -in @('validate','preview')) { exit 0 }

$videoDir = Join-Path $assets 'videos'
$posterDir = Join-Path $assets 'posters'
New-Item -ItemType Directory -Force -Path $videoDir,$posterDir | Out-Null
$segments = @(
  @{ Name='first-serve'; Start=1; Count=48; Focal=30 },
  @{ Name='positioning-lab'; Start=48; Count=48; Focal=77 },
  @{ Name='decision-gate'; Start=95; Count=48; Focal=124 },
  @{ Name='player-tunnel'; Start=142; Count=48; Focal=171 },
  @{ Name='player-setup'; Start=189; Count=48; Focal=218 },
  @{ Name='clubhouse'; Start=236; Count=48; Focal=265 },
  @{ Name='analysis-court'; Start=283; Count=48; Focal=312 },
  @{ Name='report-vault'; Start=330; Count=48; Focal=359 },
  @{ Name='replay-arena'; Start=377; Count=48; Focal=406 },
  @{ Name='profile-locker'; Start=424; Count=48; Focal=453 }
)

foreach ($current in $profiles) {
  $frames = Join-Path $output "$current\frames\frame_%04d.png"
  # yuv420p requires even dimensions; 404 is the nearest valid width to the
  # native 405 px portrait composition.
  $scale = if ($current -eq 'landscape') { 'scale=720:404,pad=720:406:0:1:black' } else { 'scale=404:720' }
  foreach ($segment in $segments) {
    Invoke-Checked 'ffmpeg' @(
      '-hide_banner','-loglevel','error','-y','-framerate','24',
      '-start_number',"$($segment.Start)",'-i',$frames,'-frames:v',"$($segment.Count)",
      '-an','-vf',"$scale,unsharp=5:5:0.35:5:5:0.0",'-c:v','libx264','-preset','slow',
      '-qp','33','-pix_fmt','yuv420p','-g','1','-keyint_min','1','-sc_threshold','0',
      '-movflags','+faststart',(Join-Path $videoDir "$($segment.Name)-$current.mp4")
    )
  }
}

if ($profiles -contains 'landscape') {
  foreach ($segment in $segments) {
    $source = Join-Path $output ("landscape\frames\frame_{0:D4}.png" -f $segment.Focal)
    Invoke-Checked 'ffmpeg' @(
      '-hide_banner','-loglevel','error','-y','-i',$source,
      '-c:v','libwebp','-quality','84',(Join-Path $posterDir "$($segment.Name).webp")
    )
  }
}

if ($Profile -eq 'all') {
  & (Join-Path $PSScriptRoot 'verify_padlo_seams.ps1') -AssetRoot $assets
  if ($LASTEXITCODE -ne 0) { throw 'Padlo seam validation failed.' }
  Push-Location (Join-Path $PSScriptRoot '..')
  try { Invoke-Checked 'dart' @('run','tools\generate_manifest.dart','examples\padlo_poc\assets') }
  finally { Pop-Location }
  $bytes = (Get-ChildItem -LiteralPath $videoDir -Filter '*.mp4' | Measure-Object Length -Sum).Sum
  if ($bytes -ge 10MB) { throw "Padlo media budget exceeded: $bytes bytes" }
  Write-Output ("Padlo videos: {0:N2} MB" -f ($bytes / 1MB))
}
