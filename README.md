# scroll-world


This repository now provides two complementary ways to build a scroll world:

- **Flutter package (`scroll_world` 0.1.0):** reusable scroll-linked video scenes for Android, iOS, and web, with Blob-backed seeking, smoothed scrubbing, interactive scene actions, reverse replay, responsive sources, bounded controller pooling, and reduced motion.
- **Padlo real-time 3D pilot:** a web-only `flutter_scene` experiment that uses one Blender GLB and a scroll-driven animation timeline—no Padlo video is loaded or decoded.
- **Agent skill:** the existing framework-agnostic creative pipeline and vanilla-JavaScript scrub engine remain under `skills/scroll-world` unchanged.

## Flutter package quick start

The repository is a Dart workspace containing the package in
`packages/scroll_world`, the “Kenya in Motion” app in `example`, and the Padlo
Slovenia product proof of concept in `examples/padlo_poc`.

```bash
flutter pub get
flutter test packages/scroll_world
flutter run -d chrome -t example/lib/main.dart
```

Use the pinned FVM revision for Padlo:

```powershell
.\tools\run_padlo.ps1
```

The helper resolves the pinned SDK and changes into `examples/padlo_poc`
before launching. Running the Padlo target from the workspace root compiles the
entrypoint against the wrong web asset manifest and causes GLB/shader 404s.

## Padlo real-time 3D pilot

The Padlo example is a web-only three-chapter spatial prototype:

1. **First Serve** — the camera descends into a Ljubljana court.
2. **Positioning Lab** — the player chooses the blue pressure zone to release a
   deterministic progress gate.
3. **Decision Gate** — the player reads the next ball, chooses a tactical path,
   and can replay the journey back to the opening composition.

The camera, players, glowing ball, court zones, lighting, and coaching markers
are animated in a single `flutter_scene` GLB. A vertical scroll spacer is the
only timeline authority; a ticker smooths the rendered camera position and
`AnimationClip.seek()` samples the authored Blender animation. Padlo MP4 files
are not included in the application manifest or runtime bundle. Keyboard and
screen-space controls mirror the in-world zones, and unsupported WebGL2/Impeller
surfaces receive an accessible fallback.

The pilot uses an FVM-managed Flutter master revision because `flutter_scene
0.20.0` is pre-1.0 and requires the newer engine. The checked-in `.fvmrc`
selects the immutable revision; it is recorded in
[`tools/flutter_scene_toolchain.md`](tools/flutter_scene_toolchain.md).

```powershell
fvm install
fvm flutter config --enable-native-assets --enable-dart-data-assets
fvm flutter pub get
Set-Location examples/padlo_poc
fvm flutter run -d chrome
fvm flutter build web --release --no-wasm-dry-run `
  --base-href /flutter_scroll_world/padlo/
```

For a validated, upload-ready Padlo bundle on Windows, run this from the
repository root:

```powershell
.\tools\export_padlo_web.ps1
```

The bundle is written to `build/padlo_web_export`. The script fails if the
Pages base path is wrong, the GLB/logo/`flutter_scene` shader bundle is absent,
the GLB exceeds 12 MiB, or video files leak into the Padlo build. Pushes to
`main` deploy the Kenya example at `/flutter_scroll_world/` and this pilot at
`/flutter_scroll_world/padlo/` through `.github/workflows/deploy_web.yml`.

See [`examples/padlo_poc/README.md`](examples/padlo_poc/README.md) for the
scene export, GLB budget, accessibility behavior, and acceptance checks.

```dart
ScrollWorldView(
  scenes: [
    ScrollWorldScene(
      id: 'forest',
      title: 'Enter the forest',
      description: 'Explore the landscape.',
      poster: const AssetImage('assets/posters/forest.webp'),
      sources: const ScrollWorldSources(
        mobilePortrait: ScrollWorldSource.asset(
          'assets/videos/forest-portrait.mp4',
        ),
        webStandard: ScrollWorldSource.asset(
          'assets/videos/forest-web.mp4',
        ),
      ),
    ),
  ],
)
```

See [`packages/scroll_world/README.md`](packages/scroll_world/README.md) for the API, media requirements, accessibility behavior, and troubleshooting. See [`tools/README.md`](tools/README.md) for encoding and manifest generation.

---


https://github.com/user-attachments/assets/b08e641e-985b-4bd4-83ff-6750272d0c37


An agent skill — for Claude Code, Codex, and any `SKILL.md`-compatible agent — that
builds an immersive, **scroll-scrubbed "fly through the world" landing page** for any industry or brand — the kind where, as you scroll, a camera flies
from *outside* each scene *into* its interior, then flows on to the next scene with **no
cuts**. One continuous connected flight through a little generated world (think the Emons
logistics site, applied to whatever you want).

## Install

### Claude Code — as a plugin (recommended)

```
/plugin marketplace add oso95/scroll-world
/plugin install scroll-world@scroll-world
```

Then just ask for a scroll-through world landing page, or invoke `/scroll-world`.

### Codex & other agents — via the skills CLI

Using [Vercel's skills CLI](https://github.com/vercel-labs/skills), which installs into
Codex, Claude Code, Cursor, and 20+ other agents:

```bash
npx skills add oso95/scroll-world            # pick your agent(s) when prompted
npx skills add oso95/scroll-world -a codex   # or target Codex directly
```

In Codex, invoke it with `$scroll-world` (or `/skills` to browse), or just ask for a
scroll-through world landing page.

### Manually (drop-in skill)

Copy the skill folder into your agent's skills directory:

```bash
git clone https://github.com/oso95/scroll-world
cp -R scroll-world/skills/scroll-world ~/.claude/skills/   # Claude Code
cp -R scroll-world/skills/scroll-world ~/.codex/skills/    # Codex
```

## Requirements

- The [Monid CLI](https://monid.ai) with an API key and balance — the **default
  video-chain backend** (Seedance 2.0, billed per clip in USD; see below).
- The [Higgsfield CLI](https://higgsfield.ai), authenticated (`higgsfield auth login`),
  with credits — renders the scene stills, the `kling3_0` fallback, and the whole
  chain when Monid is absent.
- `ffmpeg` / `ffprobe` for frame extraction and encoding.
- Python 3 with Pillow (for the mobile portrait canvases; also the optional
  transparent-scene knockout).
- The [Codex CLI](https://github.com/openai/codex) (optional) — if present, the scene
  stills can be generated through Codex's built-in `image_gen` (the same GPT Image
  model), billed to a ChatGPT subscription instead of Higgsfield credits.
- About the Monid default: verified 2026-07-25 — first/last-frame conditioning
  frame-locks, so it renders the full seamless chain; frames travel via Monid's
  free workspace file system. Pay-per-use with no subscription or monthly expiry
  (a 6-scene 1080p chain ≈ $27). The skill re-checks the endpoint schema each
  build and keeps qualification probes in the pipeline for when the catalog
  changes; Higgsfield credits remain the fallback biller.

## What it does

It generates the art with AI: cohesive isometric diorama scenes (GPT Image 2 — via
Higgsfield, or the Codex CLI on a ChatGPT subscription) and the camera flights
themselves (Seedance image-to-video via **Monid by default**, pay-per-clip; Seedance
or Kling on Higgsfield credits as fallback — only models that can frame-lock a
seam), scrubbed
by scroll position — the same technique behind Apple's scroll-through product pages. The
camera genuinely moves; scroll only drives time. It's **framework-agnostic**: you get the
Higgsfield pipeline, the prompt templates, and a portable vanilla-JS scrub engine that
drops into plain HTML, Next.js, Vue, or a Python-served page — nothing assumes a stack.

When invoked, the skill:

1. **Interviews you** — the subject/industry + pitch, a brand kit (import from a URL, hand
   it over, or have it proposed), art direction, the ordered scenes the camera visits,
   whether you want the **mobile version** (a second chain rendered natively in 9:16
   portrait — composed for phones, not a crop of the landscape film), and the **budget** —
   render tiers and stills source shown with estimated credit costs, approved before
   anything generates.
2. **Generates the assets** — one still per scene, one "dive-in" camera
   clip per scene, and the **connector** clips that join consecutive scenes, generated
   from the actual rendered frames of their neighbours so every seam is frame-identical.
   Mobile opt-in renders a parallel portrait chain the same way, frame-locked against its
   own 9:16 renders.
3. **Wires it up** — a config-driven scroll engine that plays the whole chain as one
   flight, serving the portrait clips and posters automatically on phones.

## What's in the skill

```
skills/scroll-world/
├── SKILL.md                    the procedure + the seam rule + gotchas
└── references/
    ├── prompts.md              intake checklist + every Higgsfield prompt template
    ├── pipeline.md             copy-paste batch scripts (generate → frames → connectors → encode)
    ├── scrub-engine.js         portable, config-driven scrub engine (blob-seek, lazy load, seam crossfade)
    ├── index-template.html     a minimal standalone page that mounts the engine
    └── knockout.py             background knockout for floating scenes
```

## Notes

- Asset generation costs money (~N image gens on Higgsfield credits + ~2N-1 video
  gens billed per clip on Monid by default; the mobile chain doubles the video gens)
  and takes a while — the skill runs generations in the background and polls. Monid
  pricing is per-token and printed per run; Higgsfield pricing isn't exposed by its
  CLI, so the skill calibrates against your live balance. Either way the estimated
  total is stated before spending.
- The generated `.mp4`/`.webp` assets are produced per project; they're not shipped here.

## Star History

<a href="https://www.star-history.com/?type=date&repos=oso95%2Fscroll-world">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=oso95/scroll-world&type=date&theme=dark&legend=top-left&sealed_token=rsHNX9eWfbhlu820oC1dzsc66Y8UZI4dawuHvAUlbn36F0gwOWXRDi-Qq4QFopkoEJE7bzgXPUkAmSnmMcglxAo_rM7TvGDKFehk5MzprmeT2euDRbHnTQZIxEWwjjpGQ3nodpdblW6WjTssURtDxXO2MCVL_WgJ_WnCIoVbV8qhsB_Z-Eeo8KCyVerC" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=oso95/scroll-world&type=date&legend=top-left&sealed_token=rsHNX9eWfbhlu820oC1dzsc66Y8UZI4dawuHvAUlbn36F0gwOWXRDi-Qq4QFopkoEJE7bzgXPUkAmSnmMcglxAo_rM7TvGDKFehk5MzprmeT2euDRbHnTQZIxEWwjjpGQ3nodpdblW6WjTssURtDxXO2MCVL_WgJ_WnCIoVbV8qhsB_Z-Eeo8KCyVerC" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=oso95/scroll-world&type=date&legend=top-left&sealed_token=rsHNX9eWfbhlu820oC1dzsc66Y8UZI4dawuHvAUlbn36F0gwOWXRDi-Qq4QFopkoEJE7bzgXPUkAmSnmMcglxAo_rM7TvGDKFehk5MzprmeT2euDRbHnTQZIxEWwjjpGQ3nodpdblW6WjTssURtDxXO2MCVL_WgJ_WnCIoVbV8qhsB_Z-Eeo8KCyVerC" />
 </picture>
</a>

## License

MIT — see [LICENSE](LICENSE).
