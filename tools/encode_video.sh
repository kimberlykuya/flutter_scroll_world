#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 INPUT OUTPUT [desktop|mobile]" >&2
  exit 64
fi

input=$1
output=$2
profile=${3:-desktop}
if [ "$profile" = "mobile" ]; then
  scale='scale=720:-2'; gop=4; crf=23
else
  scale='scale=1280:-2'; gop=8; crf=20
fi

ffmpeg -hide_banner -y -i "$input" -vf "$scale" -an -c:v libx264 \
  -pix_fmt yuv420p -preset slow -crf "$crf" -g "$gop" -keyint_min "$gop" \
  -sc_threshold 0 -movflags +faststart "$output"
