# Kenya in Motion

A three-scene stylized 3D demonstration of `scroll_world` covering Nairobi,
the Highlands, and the Coast as one continuous miniature world.

```bash
flutter run -d chrome -t example/lib/main.dart
flutter build web --release -t example/lib/main.dart
flutter build apk --debug -t example/lib/main.dart
```

The committed, audio-free H.264 videos are rendered from an original procedural
Blender 5.2 LTS scene. Nairobi’s road climbs into tea-covered Highlands, then a
river widens into the Indian Ocean. Landscape and portrait versions are framed
independently and share exact boundary frames with their connectors.

Rebuild or inspect the scene without paid services or downloaded models:

```powershell
.\tools\render_3d_media.ps1 -Mode validate
.\tools\render_3d_media.ps1 -Mode preview
.\tools\render_3d_media.ps1 -Mode render
```

The generated `.blend` files and PNG sequences remain under ignored
`build/blender`; the compact MP4/WebP delivery assets are committed.

The app automatically uses portrait media on portrait viewports, keeps only
nearby media initialized, displays focal-frame posters until a seekable frame is
ready, and becomes poster-only when reduced motion is requested. Web clips load
through Blob URLs, so the scroll scrubber also works on basic local servers that
do not implement byte-range responses.

The final Coast page keeps a visible **Replay the journey** action. It animates
the real timeline backwards through both connectors to Nairobi and can be
interrupted immediately by scrolling, keyboard input, or scene navigation.
