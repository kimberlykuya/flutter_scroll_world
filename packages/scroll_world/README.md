# scroll_world

`scroll_world` turns vertical scroll position into synchronized video seeking, scene transitions, text overlays, and progress navigation on Android, iOS, and Flutter Web.

## Features

- Declarative scenes with responsive portrait, landscape, standard, and high-quality video variants
- Pure, unit-tested timeline math with forward and reverse scrubbing
- Latest-target-wins seek scheduling and a bounded nearby-controller pool
- Animation-frame smoothing, Blob-backed web media, and interruptible reverse replay
- Optional frame-matched connector clips or direct crossfades
- Poster-first loading, retry, and failure fallback
- System reduced-motion support that bypasses video initialization
- Keyboard scrolling, labelled scene navigation, safe areas, and screen-reader headings
- Custom playback drivers and overlay builders for advanced integrations and tests
- First-class scene actions for replay, scene navigation, and host application flows

## Install

```yaml
dependencies:
  scroll_world: ^0.1.0
```

The package requires Dart 3.10, Flutter 3.38.5, Android SDK 24, or iOS 13. Network media must use HTTPS. Add Android's `INTERNET` permission when using network sources.

## Usage

```dart
final journeyController = ScrollWorldController();

ScrollWorldView(
  controller: journeyController,
  scenes: const [
    ScrollWorldScene(
      id: 'nairobi',
      title: 'Nairobi wakes in motion',
      description: 'A city moving forward.',
      poster: AssetImage('assets/posters/nairobi.webp'),
      sources: ScrollWorldSources(
        mobilePortrait: ScrollWorldSource.asset(
          'assets/videos/nairobi-portrait.mp4',
        ),
        mobileLandscape: ScrollWorldSource.asset(
          'assets/videos/nairobi-landscape.mp4',
        ),
        webStandard: ScrollWorldSource.asset(
          'assets/videos/nairobi-web.mp4',
        ),
      ),
      scrollExtent: 1.4,
      transitionExtent: 0.8,
      linger: 0.45,
      actions: [
        ScrollWorldAction.replayReverse(
          id: 'replay',
          label: 'Replay the journey',
        ),
      ],
    ),
  ],
  configuration: const ScrollWorldConfiguration(
    preloadRadius: 1,
    smoothingFactor: 0.18,
  ),
)
```

Give `ScrollWorldView` bounded width and height—normally a `Scaffold.body`. It owns an internal vertical scrollable and should not be nested inside another vertical scroll view.

### Sources and connectors

`ScrollWorldSource.asset` and `ScrollWorldSource.network` are supported. The deterministic selector chooses portrait media first in portrait orientation, mobile landscape below the configured breakpoint, high web media on large high-density web displays, then standard and remaining fallbacks.

Set `connectorToNext` on a scene to scrub a dedicated transition clip. Its first frame should match the preceding scene's actual last frame and its last frame should match the next scene's actual first frame. Without a connector, the package crossfades directly.

### Custom overlays and drivers

Provide `overlayBuilder` when title and description are not enough. Scene actions are appended beneath either the default or custom narrative, and `actionBuilder` can replace their visual treatment. Built-in replay and scene-navigation intents work automatically; `onAction` handles custom application navigation and analytics.

`ScrollWorldController` can navigate by stable scene ID, jump without animation, cancel programmatic movement, or replay the current journey in reverse. Replay is interruptible by pointer, wheel, keyboard, and navigation input.

### Full-stage interactive scenes and gates

Use `sceneContentBuilder` for controls that must occupy and track the entire
camera stage. It receives a `ScrollWorldSceneFrame` with raw and linger-mapped
media progress, scene visibility, travel direction, overall progress, motion
state, and reduced-motion state. `interactionRegion` declares when that live
content accepts input.

Set `gateAt` to prevent forward travel beyond a scene progress point. Release
or restore it with `ScrollWorldController.openGate` and `resetGate`. The
controller also exposes `activeSceneProgress`, and its navigation methods accept
an exact `sceneProgress`. `initialSceneId` plus `initialSceneProgress` positions
deep links before the first visible frame, including under reduced motion.

These APIs are additive: existing overlays, actions, simple scenes, custom
drivers, and externally supplied scroll controllers behave unchanged.

Implement `ScrollVideoDriverFactory` to use another player or a fake. Custom drivers can optionally implement `ScrollVideoPrimingDriver` when their platform needs a user gesture before a sought frame can paint.

## Accessibility and lifecycle

When `MediaQuery.disableAnimations` is true and `respectReducedMotion` is enabled, no video driver is created. Posters or `reducedMotionImage` values retain the complete narrative, navigation jumps without animation, and text translation is removed.

Arrow keys, Page Up/Down, Home, and End control the timeline. Navigation dots expose position, scene title, selected state, and focus indicators. Videos are decorative and contain no essential text.

Inactive players pause. Paused, hidden, or detached applications release their controller pool and restore nearby media from scroll state on resume. Memory pressure trims the pool to visible media.

## Media and hosting

Use short MP4/H.264 clips encoded as `yuv420p`, without audio, with frequent keyframes and fast-start metadata. Portrait footage should be composed natively rather than center-cropped when possible. See the repository `tools` directory for scripts.

Web media uses Blob-backed object URLs by default, matching the original Scroll World engine and remaining seekable on simple local servers without byte-range support. The web driver waits for a compositor-submitted frame, uses the browser's low-latency keyframe path, and corrects imprecise resting positions. All-intra media provides the smoothest exact scrub for compact onboarding clips; a short GOP remains the better size/quality tradeoff for large production footage. Blob mode downloads each nearby clip completely, so remote sources still require CORS. For large production media, select `ScrollWorldWebMediaStrategy.direct` and use a CDN with correct `video/mp4` MIME types, cache headers, CORS, and HTTP byte-range responses.

## Troubleshooting

- **Poster never changes:** verify the source exists, is H.264-compatible, and initializes on the target browser or device. For remote Blob media, confirm CORS permits the fetch. Listen to `onError` for the underlying failure.
- **Seeking stutters:** shorten clips, add more frequent keyframes, lower mobile resolution, and profile in release mode.
- **A seam pops:** regenerate the connector from the rendered boundary frames rather than the original stills.
- **Web works locally but not after deployment:** confirm the base path, CORS, MIME type, caching, and byte-range response.
- **Memory grows:** keep `preloadRadius` at one and verify custom drivers fully release native resources.

## Release status

Version `0.1.0` is the MVP. A `1.0.0` release requires the physical Android/iOS and desktop/mobile browser certification matrix documented in the repository.
