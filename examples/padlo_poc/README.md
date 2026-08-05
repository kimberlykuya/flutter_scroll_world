# Padlo Slovenia spatial proof of concept

This example is one persistent, scroll-controlled Padlo facility—not an
onboarding film followed by conventional product pages. The ball guides the
camera through ten connected locations:

1. First Serve
2. Positioning Lab
3. Decision Gate
4. Player Tunnel
5. Player Setup terminal
6. Clubhouse Hub
7. Analysis Court
8. Report Vault
9. Replay Arena
10. Profile Locker

The existing hash URLs remain valid, but they now identify camera anchors in
the same world. The router shell stays mounted while browser navigation moves
the real Scroll World position. Protected `/app/*` links resolve to the Player
Setup gate until the local profile is valid.

Tactical choices, court portals, registration fields, scores, and report data
are live Flutter controls aligned over reserved surfaces in the Blender film.
All controls remain usable with keyboard and touch. Reduced motion uses the
same controls over dedicated still frames and moves instantly between anchors.

All data are fictional Slovenian proof-of-concept data stored locally with
`shared_preferences`. There is no password, authentication, upload, AI
service, analytics, backend, or data transmission.

```powershell
flutter run -d chrome
flutter test test
flutter build web --release --base-href /flutter_scroll_world/padlo/
```

## Media

`tools/blender/generate_padlo_world.py` builds a single deterministic nighttime
facility from Blender primitives: an electric-blue Ljubljana court, tactical
signals, glass tunnel, setup terminal, portal room, scanner court, trophy wall,
miniature replay court, Alpine silhouette, and locker room. The same glowing
ball persists through the forward-only 471-frame camera path.

```powershell
.\tools\render_padlo_media.ps1 -Mode validate
.\tools\render_padlo_media.ps1 -Mode preview
.\tools\render_padlo_media.ps1 -Mode render
```

Ten overlapping 48-frame legs are encoded at 24 fps as all-intra H.264,
720×406 and 404×720, `yuv420p`, fast-start, and audio-free. H.264 4:2:0 requires
even dimensions, so these are the nearest compatible sizes to the 720×405 and
405×720 compositions. Adjacent legs share
one source frame; `verify_padlo_seams.ps1` requires encoded SSIM `>=0.98`.
Combined committed runtime media must remain below 10 MiB.

## Brand and licensing

- Padlo product direction and logo reference: <https://padloapp.com/>
- Epilogue typeface: Google Fonts, licensed under the included OFL file
- All players, matches, results, and tactical analysis are fictional

The logo is included for this client proof of concept. Confirm client brand
permission before redistributing the example outside the project.
