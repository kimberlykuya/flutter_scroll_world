param(
  [ValidateSet('landscape','portrait','all')]
  [string]$Profile = 'all',
  [ValidateSet('validate','preview','render','encode')]
  [string]$Mode = 'render',
  [string]$BlenderPath = '',
  [string]$OutputRoot = (Join-Path $PSScriptRoot '..\build\blender'),
  [string]$AssetRoot = (Join-Path $PSScriptRoot '..\example\assets')
)

# Backwards-compatible entry point. The sample is now the deterministic
# Blender world rather than the original FFmpeg gradient placeholder.
& (Join-Path $PSScriptRoot 'render_3d_media.ps1') `
  -Profile $Profile `
  -Mode $Mode `
  -BlenderPath $BlenderPath `
  -OutputRoot $OutputRoot `
  -AssetRoot $AssetRoot

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
