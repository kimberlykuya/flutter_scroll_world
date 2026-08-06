# Padlo Slovenia spatial proof of concept

This example is the first web-only real-time 3D Padlo pilot. It is one
persistent, scroll-controlled facility—not an onboarding film followed by
conventional product pages. The pilot intentionally ships the first three
locations before the remaining world is migrated:

1. First Serve
2. Positioning Lab
3. Decision Gate
4. Player Tunnel (next migration)
5. Player Setup terminal (next migration)
6. Clubhouse Hub (next migration)
7. Analysis Court (next migration)
8. Report Vault (next migration)
9. Replay Arena (next migration)
10. Profile Locker (next migration)

The existing hash URLs remain valid. During this pilot, `/onboarding` and
`/padlo/` open at First Serve; `/register` and `/app/*` redirect back to that
world while retaining their intended destination for the later migration. The
router does not rebuild the scene in response to active-chapter updates, so
manual scrolling cannot be reset to chapter one by a route feedback loop.

The court zones are named GLB meshes with `SemanticsComponent` hit targets;
screen-space Flutter buttons mirror them for keyboard, touch, and precision
access. Reduced motion snaps to three authored camera compositions while
retaining all choices and feedback.

All data are fictional Slovenian proof-of-concept data stored locally with
`shared_preferences`. There is no password, authentication, upload, AI
service, analytics, backend, or data transmission.

```powershell
Set-Location C:\Users\USER\Documents\flutter_scroll_world\examples\padlo_poc
fvm install
fvm flutter config --enable-native-assets --enable-dart-data-assets
fvm flutter pub get
fvm flutter run -d chrome
fvm flutter test test
fvm flutter build web --release --no-wasm-dry-run --base-href /flutter_scroll_world/padlo/
```

On Windows, the repository-root shortcut is `.\tools\run_padlo.ps1`. It
always launches from this subproject so Flutter includes the GLB, brand assets,
fonts, and `flutter_scene` shader bundle.

Use `.\tools\export_padlo_web.ps1` from the repository root to create a
validated GitHub Pages bundle in `build/padlo_web_export`. It builds with the
pinned SDK and `/flutter_scroll_world/padlo/` base URL, then checks the GLB,
logo, shader bundle, payload budget, and video-free runtime before exporting.

## Media

`tools/blender/generate_padlo_world.py` builds a single deterministic nighttime
facility from Blender primitives and can export the source GLB directly:

```powershell
blender --background --factory-startup `
  --python tools/blender/generate_padlo_world.py -- `
  --profile landscape --mode export --output build/padlo_scene
```

The committed `assets/scene/padlo-pilot.glb` contains named court zones,
players, lighting, and a persistent ball. `PadloSceneRuntime` imports it once,
pauses its animation clips, and seeks them from normalized scroll progress.
The source scene is 1.9 MB, well below the pilot's 12 MiB payload budget.

```powershell
.\tools\render_padlo_media.ps1 -Mode validate
.\tools\render_padlo_media.ps1 -Mode preview
.\tools\render_padlo_media.ps1 -Mode render
```

The old MP4 render helpers remain available for the Kenya/example pipeline, but
Padlo's runtime no longer references them. Only the source GLB and local brand
assets are declared in `pubspec.yaml`; no video decoder or remote media request
is made by the pilot.

## Brand and licensing

- Padlo product direction and logo reference: <https://padloapp.com/>
- Epilogue typeface: Google Fonts, licensed under the included OFL file
- All players, matches, results, and tactical analysis are fictional

The logo is included for this client proof of concept. Confirm client brand
permission before redistributing the example outside the project.
