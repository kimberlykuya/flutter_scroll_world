param(
  [Parameter(Mandatory = $true)][string]$InputFile,
  [Parameter(Mandatory = $true)][string]$OutputFile,
  [ValidateSet('desktop','mobile')][string]$Profile = 'desktop'
)

$ErrorActionPreference = 'Stop'
$scale = if ($Profile -eq 'mobile') { 'scale=720:-2' } else { 'scale=1280:-2' }
$gop = '1'
$crf = '26'
& ffmpeg -hide_banner -y -i $InputFile -vf $scale -an -c:v libx264 -pix_fmt yuv420p -preset slow -crf $crf -g $gop -keyint_min $gop -sc_threshold 0 -movflags +faststart $OutputFile
if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed with exit code $LASTEXITCODE" }
