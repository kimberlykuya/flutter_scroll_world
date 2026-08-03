param(
  [string]$AssetRoot = (Join-Path $PSScriptRoot '..\example\assets'),
  [double]$MinimumSsim = 0.97
)

$ErrorActionPreference = 'Stop'
$videoDir = Join-Path $AssetRoot 'videos'
$frameDir = Join-Path ([System.IO.Path]::GetTempPath()) ("scroll-world-seams-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $frameDir | Out-Null

function Extract-Frame([string]$Video, [string]$Output, [bool]$Last) {
  $args = @('-hide_banner','-loglevel','error','-y')
  if ($Last) {
    $frameCount = & ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 $Video
    if ($LASTEXITCODE -ne 0 -or -not $frameCount) { throw "Could not count frames in $Video" }
    $lastIndex = [int]$frameCount - 1
    $args += @('-i',$Video,'-vf',"select='eq(n,$lastIndex)'",'-vsync','0')
  } else {
    $args += @('-i',$Video)
  }
  $args += @('-frames:v','1',$Output)
  & ffmpeg @args
  if ($LASTEXITCODE -ne 0) { throw "Could not extract a seam frame from $Video" }
}

function Compare-Frames([string]$Left, [string]$Right, [string]$Label) {
  $result = (& ffmpeg -hide_banner -i $Left -i $Right -lavfi ssim -f null - 2>&1) -join "`n"
  $match = [regex]::Match($result, 'All:([0-9.]+)')
  if (-not $match.Success) { throw "Could not calculate SSIM for $Label" }
  $score = [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
  if ($score -lt $MinimumSsim) { throw "$Label failed seam validation: SSIM $score" }
  Write-Output "$Label SSIM=$score"
}

try {
  foreach ($profile in @('landscape','portrait')) {
    foreach ($pair in @(@('nairobi','highlands'), @('highlands','coast'))) {
      $from = Join-Path $videoDir "$($pair[0])-$profile.mp4"
      $connector = Join-Path $videoDir "$($pair[0])-$($pair[1])-$profile.mp4"
      $to = Join-Path $videoDir "$($pair[1])-$profile.mp4"
      $fromLast = Join-Path $frameDir 'from-last.png'
      $connectorFirst = Join-Path $frameDir 'connector-first.png'
      $connectorLast = Join-Path $frameDir 'connector-last.png'
      $toFirst = Join-Path $frameDir 'to-first.png'
      Extract-Frame $from $fromLast $true
      Extract-Frame $connector $connectorFirst $false
      Extract-Frame $connector $connectorLast $true
      Extract-Frame $to $toFirst $false
      Compare-Frames $fromLast $connectorFirst "$($pair[0])->connector ($profile)"
      Compare-Frames $connectorLast $toFirst "connector->$($pair[1]) ($profile)"
    }
  }
} finally {
  if ($frameDir.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $frameDir -Recurse -Force
  }
}
