import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../models/scroll_world_configuration.dart';
import '../models/scroll_world_source.dart';
import 'prepared_video_source.dart';
import 'prepared_video_source_types.dart';
import 'scroll_video_driver.dart';

ScrollVideoDriver createVideoPlayerScrollDriver(
  ScrollWorldSource source, {
  required ScrollWorldWebMediaStrategy webMediaStrategy,
}) => VideoPlayerScrollDriver(source, webMediaStrategy: webMediaStrategy);

final class VideoPlayerScrollDriver
    implements ScrollVideoDriver, ScrollVideoPrimingDriver {
  VideoPlayerScrollDriver(this._source, {required this.webMediaStrategy});

  static int _nextViewId = 0;

  final ScrollWorldSource _source;
  final ScrollWorldWebMediaStrategy webMediaStrategy;
  final String _viewType = 'scroll-world-video-${_nextViewId++}';
  web.HTMLVideoElement? _element;
  PreparedVideoSource? _preparedSource;
  Duration _duration = Duration.zero;
  Completer<void>? _activeSeek;
  int _seekGeneration = 0;
  bool _ready = false;
  bool _disposed = false;

  @override
  Duration get duration => _duration;

  @override
  bool get isReady => _ready && !_disposed;

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    _preparedSource = await prepareVideoSource(_source, webMediaStrategy);
    if (_disposed) {
      _preparedSource?.release();
      _preparedSource = null;
      return;
    }

    final element = web.HTMLVideoElement()
      ..autoplay = false
      ..controls = false
      ..muted = true
      ..playsInline = true;
    element.style
      ..width = '100%'
      ..height = '100%'
      ..display = 'block'
      ..objectPosition = 'center center'
      ..pointerEvents = 'none';
    _element = element;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId, {Object? params}) => element,
    );

    final sourceUri = _preparedSource?.uri ?? _directUri(_source);
    final metadataReady = _waitForEvent(
      element,
      'loadedmetadata',
      timeout: const Duration(seconds: 8),
      isAlreadyComplete: () => element.readyState >= 1,
    );
    element.src = sourceUri.toString();
    element.load();
    await metadataReady;
    if (_disposed) return;
    if (!element.duration.isFinite || element.duration <= 0) {
      throw StateError('Video metadata did not provide a usable duration.');
    }
    _duration = Duration(
      microseconds: (element.duration * Duration.microsecondsPerSecond).round(),
    );
    _ready = true;
    await pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    final element = _element;
    if (!isReady || element == null) return;
    final targetSeconds =
        position.inMicroseconds / Duration.microsecondsPerSecond;
    if (!element.seeking &&
        (element.currentTime - targetSeconds).abs() < 0.001) {
      return;
    }

    final generation = ++_seekGeneration;
    // Register the video-frame callback before changing currentTime. Registering
    // it after `seeked` misses the compositor submission on Chromium and makes
    // every scrub wait for the fallback timer, which looks like a slideshow.
    final settled = _waitForSeekAndPaint(element, generation);
    try {
      // Demo media is all-intra, so fastSeek remains frame-accurate while using
      // Chromium's low-latency keyframe path. Other media falls back to exact
      // currentTime seeking when the API is unavailable.
      element.fastSeek(targetSeconds);
    } on Object {
      element.currentTime = targetSeconds;
    }
    await settled;
    if (_disposed || generation != _seekGeneration) return;
    if ((element.currentTime - targetSeconds).abs() > 0.05) {
      // fastSeek may snap GOP-encoded production footage to a nearby keyframe.
      // Correct from that decoded neighbourhood so the final resting position
      // remains frame-accurate without slowing the all-intra demo path.
      final exactSettled = _waitForSeekAndPaint(element, generation);
      element.currentTime = targetSeconds;
      await exactSettled;
    }
  }

  @override
  Future<void> pause() async {
    _element?.pause();
  }

  @override
  Future<void> prime() async {
    final element = _element;
    if (!isReady || element == null) return;
    try {
      await element.play().toDart;
    } on Object {
      return;
    } finally {
      element.pause();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    _seekGeneration += 1;
    if (_activeSeek case final active? when !active.isCompleted) {
      active.complete();
    }
    final element = _element;
    _element = null;
    if (element != null) {
      element.pause();
      element.removeAttribute('src');
      element.load();
    }
    _preparedSource?.release();
    _preparedSource = null;
  }

  @override
  Widget buildView({BoxFit fit = BoxFit.cover}) {
    final element = _element;
    if (!isReady || element == null) return const SizedBox.shrink();
    element.style.objectFit = switch (fit) {
      BoxFit.fill => 'fill',
      BoxFit.contain => 'contain',
      BoxFit.cover => 'cover',
      BoxFit.fitWidth => 'contain',
      BoxFit.fitHeight => 'contain',
      BoxFit.none => 'none',
      BoxFit.scaleDown => 'scale-down',
    };
    return HtmlElementView(
      viewType: _viewType,
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    );
  }

  Uri _directUri(ScrollWorldSource source) => switch (source.type) {
    ScrollWorldSourceType.network => source.uri,
    ScrollWorldSourceType.asset => Uri.parse(
      'assets/${source.package == null ? source.assetName : 'packages/${source.package}/${source.assetName}'}',
    ),
  };

  Future<void> _waitForEvent(
    web.EventTarget target,
    String eventName, {
    required Duration timeout,
    required bool Function() isAlreadyComplete,
  }) {
    if (isAlreadyComplete()) return Future<void>.value();
    final completer = Completer<void>();
    _activeSeek = completer;
    Timer? timer;
    late JSFunction listener;
    void complete() {
      target.removeEventListener(eventName, listener);
      timer?.cancel();
      if (!completer.isCompleted) completer.complete();
      if (identical(_activeSeek, completer)) _activeSeek = null;
    }

    listener = ((web.Event event) => complete()).toJS;
    target.addEventListener(eventName, listener);
    timer = Timer(timeout, complete);
    return completer.future;
  }

  Future<void> _waitForSeekAndPaint(
    web.HTMLVideoElement element,
    int generation,
  ) {
    final completer = Completer<void>();
    _activeSeek = completer;
    var seeked = false;
    var painted = false;
    Timer? timer;
    late JSFunction seekedListener;
    void complete({bool force = false}) {
      if (!force && (!seeked || !painted)) return;
      element.removeEventListener('seeked', seekedListener);
      timer?.cancel();
      if (!completer.isCompleted) completer.complete();
      if (identical(_activeSeek, completer)) _activeSeek = null;
    }

    seekedListener = ((web.Event event) {
      seeked = true;
      complete();
    }).toJS;
    element.addEventListener('seeked', seekedListener);
    try {
      element.requestVideoFrameCallback(
        ((JSAny timestamp, JSAny metadata) {
          if (_disposed || generation != _seekGeneration) {
            complete(force: true);
            return;
          }
          painted = true;
          complete();
        }).toJS,
      );
    } on Object {
      painted = true;
    }
    timer = Timer(
      const Duration(milliseconds: 750),
      () => complete(force: true),
    );
    return completer.future;
  }
}
