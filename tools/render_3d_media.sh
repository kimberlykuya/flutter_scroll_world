#!/usr/bin/env bash
set -euo pipefail

profile="${1:-all}"
mode="${2:-render}"
blender_bin="${BLENDER_BIN:-blender}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator="$repo_root/tools/blender/generate_kenya_world.py"
output="$repo_root/build/blender"
assets="$repo_root/example/assets"

case "$profile" in
  landscape|portrait) profiles=("$profile") ;;
  all) profiles=(landscape portrait) ;;
  *) echo "Profile must be landscape, portrait, or all." >&2; exit 64 ;;
esac

case "$mode" in
  validate|preview|render|encode) ;;
  *) echo "Mode must be validate, preview, render, or encode." >&2; exit 64 ;;
esac

if [[ "$mode" != "encode" ]]; then
  for current_profile in "${profiles[@]}"; do
    "$blender_bin" --background --factory-startup --python-exit-code 1 \
      --python "$generator" -- --profile "$current_profile" --mode "$mode" --output "$output"
  done
fi

if [[ "$mode" == "validate" || "$mode" == "preview" ]]; then
  echo "Blender $mode completed in $output"
  exit 0
fi

mkdir -p "$assets/videos" "$assets/posters"
segment_names=(nairobi nairobi-highlands highlands highlands-coast coast)
segment_starts=(1 72 107 178 213)
segment_counts=(72 36 72 36 72)

for current_profile in "${profiles[@]}"; do
  frames="$output/$current_profile/frames/frame_%04d.png"
  scale=320:180
  gop=1
  [[ "$current_profile" == "portrait" ]] && scale=180:320
  for index in "${!segment_names[@]}"; do
    ffmpeg -hide_banner -loglevel error -y -framerate 24 \
      -start_number "${segment_starts[$index]}" -i "$frames" \
      -frames:v "${segment_counts[$index]}" -an -vf "unsharp=5:5:0.8:5:5:0.0" \
      -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p \
      -g "$gop" -keyint_min "$gop" -sc_threshold 0 \
      -movflags +faststart "$assets/videos/${segment_names[$index]}-$current_profile.mp4"
  done
  ffmpeg -hide_banner -loglevel error -y -framerate 24 -start_number 1 -i "$frames" \
    -vf "select='eq(n,0)+eq(n,35)+eq(n,71)+eq(n,106)+eq(n,141)+eq(n,177)+eq(n,212)+eq(n,247)+eq(n,283)',scale=$scale,tile=3x3" \
    -frames:v 1 "$output/$current_profile/contact-sheet.webp"
done

if [[ " ${profiles[*]} " == *" landscape "* ]]; then
  for spec in nairobi:36 highlands:142 coast:248; do
    name="${spec%%:*}"
    frame="${spec##*:}"
    printf -v padded '%04d' "$frame"
    ffmpeg -hide_banner -loglevel error -y \
      -i "$output/landscape/frames/frame_$padded.png" \
      -c:v libwebp -quality 84 "$assets/posters/$name.webp"
  done
fi

if [[ "$profile" == "all" ]]; then
  seam_dir=$(mktemp -d)
  trap 'rm -rf "$seam_dir"' EXIT
  compare_frames() {
    local left="$1" right="$2" label="$3" result score
    result=$(ffmpeg -hide_banner -i "$left" -i "$right" -lavfi ssim -f null - 2>&1)
    score=$(sed -n 's/.*All:\([0-9.]*\).*/\1/p' <<<"$result" | tail -1)
    [[ -n "$score" ]] || { echo "Could not calculate SSIM for $label" >&2; exit 1; }
    awk -v score="$score" -v label="$label" 'BEGIN { if (score < 0.95) { printf "%s failed seam validation: SSIM %s\n", label, score > "/dev/stderr"; exit 1 } }'
    echo "$label SSIM=$score"
  }
  for current_profile in landscape portrait; do
    for pair in nairobi:highlands highlands:coast; do
      from="${pair%%:*}"
      to="${pair##*:}"
      from_last="$seam_dir/from-last.png"
      connector_first="$seam_dir/connector-first.png"
      connector_last="$seam_dir/connector-last.png"
      to_first="$seam_dir/to-first.png"
      from_count=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 "$assets/videos/$from-$current_profile.mp4")
      connector_count=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 "$assets/videos/$from-$to-$current_profile.mp4")
      ffmpeg -hide_banner -loglevel error -y -i "$assets/videos/$from-$current_profile.mp4" -vf "select='eq(n,$((from_count - 1)))'" -vsync 0 -frames:v 1 "$from_last"
      ffmpeg -hide_banner -loglevel error -y -i "$assets/videos/$from-$to-$current_profile.mp4" -frames:v 1 "$connector_first"
      ffmpeg -hide_banner -loglevel error -y -i "$assets/videos/$from-$to-$current_profile.mp4" -vf "select='eq(n,$((connector_count - 1)))'" -vsync 0 -frames:v 1 "$connector_last"
      ffmpeg -hide_banner -loglevel error -y -i "$assets/videos/$to-$current_profile.mp4" -frames:v 1 "$to_first"
      compare_frames "$from_last" "$connector_first" "$from->connector ($current_profile)"
      compare_frames "$connector_last" "$to_first" "connector->$to ($current_profile)"
    done
  done
  (cd "$repo_root" && dart run tools/generate_manifest.dart)
  media_bytes=$(find "$assets/videos" -name '*.mp4' -print0 | xargs -0 wc -c | tail -1 | awk '{print $1}')
  if (( media_bytes >= 10485760 )); then
    echo "Video budget exceeded: $media_bytes bytes" >&2
    exit 1
  fi
fi

echo "3D media completed in $assets"
