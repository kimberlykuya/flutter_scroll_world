param(
  [string]$AssetRoot = (Join-Path $PSScriptRoot '..\examples\padlo_poc\assets'),
  [double]$MinimumSsim = 0.95
)

$ErrorActionPreference = 'Stop'
$videoDir = Join-Path $AssetRoot 'videos'
$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("padlo-seams-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null

function Extract([string]$Video, [string]$Output, [bool]$Last) {
  if ($Last) {
    $count = & ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 $Video
    & ffmpeg -hide_banner -loglevel error -y -i $Video -vf "select='eq(n,$([int]$count - 1))'" -vsync 0 -frames:v 1 $Output
  } else {
    & ffmpeg -hide_banner -loglevel error -y -i $Video -frames:v 1 $Output
  }
  if ($LASTEXITCODE -ne 0) { throw "Could not extract seam frame from $Video" }
}

function Compare-Seam([string]$Left, [string]$Right, [string]$Label) {
  $result = (& ffmpeg -hide_banner -i $Left -i $Right -lavfi ssim -f null - 2>&1) -join "`n"
  $match = [regex]::Match($result, 'All:([0-9.]+)')
  if (-not $match.Success) { throw "Could not calculate SSIM for $Label" }
  $score = [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
  if ($score -lt $MinimumSsim) { throw "$Label failed: SSIM $score" }
  Write-Output "$Label SSIM=$score"
}

try {
  $pairs = @(
    @('see-court','net-depth'),
    @('net-depth','recovery'),
    @('recovery','spacing'),
    @('spacing','transition')
  )
  foreach ($profile in @('landscape','portrait')) {
    foreach ($pair in $pairs) {
      $from = Join-Path $videoDir "$($pair[0])-$profile.mp4"
      $connector = Join-Path $videoDir "$($pair[0])-$($pair[1])-$profile.mp4"
      $to = Join-Path $videoDir "$($pair[1])-$profile.mp4"
      $a = Join-Path $temporary 'a.png'; $b = Join-Path $temporary 'b.png'
      Extract $from $a $true; Extract $connector $b $false
      Compare-Seam $a $b "$($pair[0])->connector ($profile)"
      Extract $connector $a $true; Extract $to $b $false
      Compare-Seam $a $b "connector->$($pair[1]) ($profile)"
    }
  }
} finally {
  if ($temporary.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $temporary -Recurse -Force
  }
}
