#!/usr/bin/env bash
set -euo pipefail

profile="${1:-all}"
mode="${2:-render}"
blender_bin="${BLENDER_BIN:-blender}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$repo_root/build/padlo_blender"
assets="$repo_root/examples/padlo_poc/assets"
generator="$repo_root/tools/blender/generate_padlo_world.py"

case "$profile" in
  landscape|portrait) profiles=("$profile") ;;
  all) profiles=(landscape portrait) ;;
  *) echo 'Profile must be landscape, portrait, or all.' >&2; exit 64 ;;
esac
case "$mode" in
  validate|preview|render|encode) ;;
  *) echo 'Mode must be validate, preview, render, or encode.' >&2; exit 64 ;;
esac

if [[ "$mode" != "encode" ]]; then
  for current in "${profiles[@]}"; do
    "$blender_bin" --background --factory-startup --python-exit-code 1 \
      --python "$generator" -- --profile "$current" --mode "$mode" --output "$output"
  done
fi
[[ "$mode" == 'validate' || "$mode" == 'preview' ]] && exit 0

mkdir -p "$assets/videos" "$assets/posters"
names=(first-serve positioning-lab decision-gate player-tunnel player-setup clubhouse analysis-court report-vault replay-arena profile-locker)
starts=(1 48 95 142 189 236 283 330 377 424)
focals=(30 77 124 171 218 265 312 359 406 453)
for current in "${profiles[@]}"; do
  frames="$output/$current/frames/frame_%04d.png"
  if [[ "$current" == 'landscape' ]]; then scale='scale=720:404,pad=720:406:0:1:black'; else scale='scale=404:720'; fi
  for index in "${!names[@]}"; do
    ffmpeg -hide_banner -loglevel error -y -framerate 24 -start_number "${starts[$index]}" \
      -i "$frames" -frames:v 48 -an -vf "$scale,unsharp=5:5:0.35:5:5:0.0" \
      -c:v libx264 -preset slow -qp 33 -pix_fmt yuv420p -g 1 -keyint_min 1 \
      -sc_threshold 0 -movflags +faststart "$assets/videos/${names[$index]}-$current.mp4"
  done
done

if [[ " ${profiles[*]} " == *' landscape '* ]]; then
  for index in "${!names[@]}"; do
    name="${names[$index]}"; frame="${focals[$index]}"; printf -v padded '%04d' "$frame"
    ffmpeg -hide_banner -loglevel error -y -i "$output/landscape/frames/frame_$padded.png" \
      -c:v libwebp -quality 84 "$assets/posters/$name.webp"
  done
fi

if [[ "$profile" == 'all' ]]; then
  pwsh -File "$repo_root/tools/verify_padlo_seams.ps1" -AssetRoot "$assets"
  (cd "$repo_root" && dart run tools/generate_manifest.dart examples/padlo_poc/assets)
  bytes=$(find "$assets/videos" -name '*.mp4' -print0 | xargs -0 wc -c | tail -1 | awk '{print $1}')
  (( bytes < 10485760 )) || { echo "Padlo media budget exceeded: $bytes bytes" >&2; exit 1; }
fi
