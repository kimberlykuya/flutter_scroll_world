# Media tools

## Recreate the 3D example

The “Kenya in Motion” media is a deterministic Blender 5.2 LTS world built
only from procedural primitives. It includes a KICC-inspired Nairobi skyline
and matatu, tea-covered Highlands and a Mount Kenya silhouette, and a Swahili
Coast with an arch, palms, river, ocean, and dhow. No downloaded models or
textures are used.

On Windows with Blender 5.2 LTS and FFmpeg 8 or newer:

```powershell
.\tools\render_3d_media.ps1 -Mode validate
.\tools\render_3d_media.ps1 -Mode preview
.\tools\render_3d_media.ps1 -Mode render
.\tools\render_3d_media.ps1 -Mode encode # reuse existing PNG frames
```

`generate_sample_media.ps1` remains as a backwards-compatible alias. The
renderer auto-discovers `C:\Tools\Blender-5.2\blender.exe`, PATH installations,
and standard Blender Foundation installs; pass `-BlenderPath` to override it.

On Bash-compatible environments, set `BLENDER_BIN` when Blender is not on PATH:

```bash
BLENDER_BIN=/opt/blender/blender ./tools/render_3d_media.sh all render
```

The generator creates one 284-frame world per orientation at 24 fps. It splits
shared frame ranges into three scene clips and two connector clips, writes
three focal-frame WebP posters, produces landscape/portrait contact sheets,
runs encoded seam validation at SSIM 0.95, refreshes the manifest, and rejects a video
set of 10 MB or more.

The demo uses CRF 26 H.264 with light unsharp filtering and an all-intra GOP of
1. A browser motion probe showed that GOP 8/4 still made paused scroll seeking
look like a slideshow; every frame is now independently decodable. Blob-backed
web playback keeps the clips seekable even on servers without byte ranges. The
lossless source boundary frames remain identical; the encoded seam threshold
allows normal compression differences.

Generated `.blend` files and lossless PNG sequences remain under ignored
`build/blender/`. Only the compact delivery media is committed.

## Encode production footage

```powershell
.\tools\encode_video.ps1 -InputFile master.mov -OutputFile scene.mp4 -Profile desktop
.\tools\encode_video.ps1 -InputFile portrait.mov -OutputFile scene-portrait.mp4 -Profile mobile
```

```bash
./tools/encode_video.sh master.mov scene.mp4 desktop
```

Both helpers emit muted H.264/yuv420p, fast-start MP4 files. The all-intra GOP
uses more bytes than inter-frame encoding, but removes dependent-frame decoding
from the paused scroll-scrub path.

## Connector rule

Generate a connector from the preceding rendered clip's actual last frame and the next rendered clip's actual first frame. Do not use the source stills as connector endpoints. Inspect composition at the seam even when numeric image comparison passes.

## Manifest

`generate_manifest.dart` runs `ffprobe` and records relative path, dimensions, duration, codec, byte size, and SHA-256 for every video and poster. The example itself remains declarative and does not load this file at runtime.

## Production web delivery

Serve MP4 files with the correct MIME type, CORS policy, long-lived versioned cache headers, and byte-range support. Keep large production media outside Git and GitHub Pages; use a CDN-backed object store close to the intended audience, including an African region or edge network when serving Kenyan users.
