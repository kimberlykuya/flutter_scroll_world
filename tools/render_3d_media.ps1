param(
  [ValidateSet('landscape','portrait','all')]
  [string]$Profile = 'all',
  [ValidateSet('validate','preview','render','encode')]
  [string]$Mode = 'render',
  [string]$PreviewFrames = '36,142,248',
  [string]$BlenderPath = '',
  [string]$OutputRoot = (Join-Path $PSScriptRoot '..\build\blender'),
  [string]$AssetRoot = (Join-Path $PSScriptRoot '..\example\assets')
)

$ErrorActionPreference = 'Stop'

function Resolve-Blender([string]$RequestedPath) {
  $candidates = @()
  if ($RequestedPath) { $candidates += $RequestedPath }
  $pathCommand = Get-Command blender.exe -ErrorAction SilentlyContinue
  if ($pathCommand) { $candidates += $pathCommand.Source }
  $candidates += @(
    'C:\Tools\Blender-5.2\blender.exe',
    'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe',
    'C:\Program Files\Blender Foundation\Blender\blender.exe'
  )
  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  throw 'Blender was not found. Pass -BlenderPath or install the portable build at C:\Tools\Blender-5.2.'
}

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Command failed with exit code $LASTEXITCODE"
  }
}

$blender = Resolve-Blender $BlenderPath
$generator = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'blender\generate_kenya_world.py')).Path
$output = [System.IO.Path]::GetFullPath($OutputRoot)
$assets = [System.IO.Path]::GetFullPath($AssetRoot)
$profiles = if ($Profile -eq 'all') { @('landscape','portrait') } else { @($Profile) }

if ($Mode -ne 'encode') {
  foreach ($currentProfile in $profiles) {
    Write-Output "Building $currentProfile world with Blender $blender"
    $blenderArguments = @(
      '--background',
      '--factory-startup',
      '--python-exit-code','1',
      '--python',$generator,
      '--',
      '--profile',$currentProfile,
      '--mode',$Mode,
      '--output',$output
    )
    if ($Mode -eq 'preview') { $blenderArguments += @('--frames',$PreviewFrames) }
    Invoke-Checked $blender $blenderArguments
  }
}

if ($Mode -in @('validate','preview')) {
  Write-Output "Blender $Mode completed in $output"
  exit 0
}

$videoDir = Join-Path $assets 'videos'
$posterDir = Join-Path $assets 'posters'
New-Item -ItemType Directory -Force -Path $videoDir,$posterDir | Out-Null

$segments = @(
  @{ Name='nairobi'; Start=1; Count=72 },
  @{ Name='nairobi-highlands'; Start=72; Count=36 },
  @{ Name='highlands'; Start=107; Count=72 },
  @{ Name='highlands-coast'; Start=178; Count=36 },
  @{ Name='coast'; Start=213; Count=72 }
)

foreach ($currentProfile in $profiles) {
  $frames = Join-Path $output "$currentProfile\frames\frame_%04d.png"
  $gop = 1
  foreach ($segment in $segments) {
    $destination = Join-Path $videoDir "$($segment.Name)-$currentProfile.mp4"
    Invoke-Checked 'ffmpeg' @(
      '-hide_banner','-loglevel','error','-y',
      '-framerate','24','-start_number',"$($segment.Start)",'-i',$frames,
      '-frames:v',"$($segment.Count)",'-an','-vf','unsharp=5:5:0.8:5:5:0.0',
      '-c:v','libx264','-preset','slow','-crf','26','-pix_fmt','yuv420p',
      '-g',"$gop",'-keyint_min',"$gop",
      '-sc_threshold','0',
      '-movflags','+faststart',$destination
    )
  }

  $selected = 'eq(n,0)+eq(n,35)+eq(n,71)+eq(n,106)+eq(n,141)+eq(n,177)+eq(n,212)+eq(n,247)+eq(n,283)'
  $tileScale = if ($currentProfile -eq 'portrait') { '180:320' } else { '320:180' }
  Invoke-Checked 'ffmpeg' @(
    '-hide_banner','-loglevel','error','-y','-framerate','24','-start_number','1','-i',$frames,
    '-vf',"select='$selected',scale=$tileScale,tile=3x3",'-frames:v','1',
    (Join-Path $output "$currentProfile\contact-sheet.webp")
  )
}

if ($profiles -contains 'landscape') {
  foreach ($poster in @(
    @{ Name='nairobi'; Frame=36 },
    @{ Name='highlands'; Frame=142 },
    @{ Name='coast'; Frame=248 }
  )) {
    $source = Join-Path $output ("landscape\frames\frame_{0:D4}.png" -f $poster.Frame)
    Invoke-Checked 'ffmpeg' @('-hide_banner','-loglevel','error','-y','-i',$source,'-c:v','libwebp','-quality','84',(Join-Path $posterDir "$($poster.Name).webp"))
  }
}

if ($profiles.Count -eq 2) {
  & (Join-Path $PSScriptRoot 'verify_seams.ps1') -AssetRoot $assets -MinimumSsim 0.95
  if ($LASTEXITCODE -ne 0) { throw 'Seam validation failed.' }
  Push-Location (Join-Path $PSScriptRoot '..')
  try {
    Invoke-Checked 'dart' @('run','tools\generate_manifest.dart')
  } finally {
    Pop-Location
  }
  $mediaBytes = (Get-ChildItem -LiteralPath $videoDir -Filter '*.mp4' | Measure-Object Length -Sum).Sum
  if ($mediaBytes -ge 10MB) { throw "Video budget exceeded: $mediaBytes bytes" }
  Write-Output ("Committed video total: {0:N2} MB" -f ($mediaBytes / 1MB))
}

Write-Output "3D media completed in $assets"
