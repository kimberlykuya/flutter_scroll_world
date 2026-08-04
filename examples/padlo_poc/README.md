# Padlo Slovenia proof of concept

This second Flutter example demonstrates how `scroll_world` can lead into a
complete interactive product experience rather than ending as a video landing
page. It uses fictional Slovenian players and city-only locations.

## Journey

1. Five-scene scroll-controlled positioning tour
2. Local mock registration
3. Responsive home dashboard
4. Deterministic match-analysis simulation
5. Reports archive and tactical match report

All profile and generated-report state is stored with `shared_preferences` on
the current device. There is no authentication, upload, AI service, analytics,
or backend. Every product screen carries a proof-of-concept indicator.

```powershell
flutter run -d chrome
flutter test
flutter build web --release --base-href /flutter_scroll_world/padlo/
```

The web build uses Flutter's default hash routing, which allows nested product
routes to work from GitHub Pages without a server-side rewrite rule.

## Media

The onboarding world is generated entirely from Blender primitives by
`tools/blender/generate_padlo_world.py`. It contains an abstract blue padel
court, four fictional players, Alpine and Ljubljana-inspired background forms,
and animated tactical overlays. Nothing reproduces a real club or athlete.

```powershell
.\tools\render_padlo_media.ps1 -Mode validate
.\tools\render_padlo_media.ps1 -Mode preview
.\tools\render_padlo_media.ps1 -Mode render
```

The committed H.264 clips are all-intra, 24 fps, `yuv420p`, fast-start, and
audio-free. Scene and connector clips share their boundary frames, and the
seam validator requires SSIM of at least `0.95`.

## Brand and licensing

- Padlo product direction and logo reference: <https://padloapp.com/>
- Epilogue typeface: Google Fonts, licensed under the included OFL file
- All match data, players, results, and tactical analysis are fictional

The logo is included for this client proof of concept. Confirm client brand
permission before redistributing the example outside the project.
