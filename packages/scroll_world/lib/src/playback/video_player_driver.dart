import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../models/scroll_world_source.dart';
import '../models/scroll_world_configuration.dart';
import 'prepared_video_source.dart';
import 'prepared_video_source_types.dart';
import 'scroll_video_driver.dart';

final class VideoPlayerDriverFactory implements ScrollVideoDriverFactory {
  const VideoPlayerDriverFactory({
    this.webMediaStrategy = ScrollWorldWebMediaStrategy.blob,
  });

  final ScrollWorldWebMediaStrategy webMediaStrategy;

  @override
  ScrollVideoDriver create(ScrollWorldSource source) =>
      VideoPlayerScrollDriver(source, webMediaStrategy: webMediaStrategy);
}

/// Official video_player-backed driver for Android, iOS, and web.
final class VideoPlayerScrollDriver
    implements ScrollVideoDriver, ScrollVideoPrimingDriver {
  VideoPlayerScrollDriver(
    this._source, {
    this.webMediaStrategy = ScrollWorldWebMediaStrategy.blob,
  });

  final ScrollWorldSource _source;
  final ScrollWorldWebMediaStrategy webMediaStrategy;
  VideoPlayerController? _controller;
  PreparedVideoSource? _preparedSource;
  bool _disposed = false;

  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  @override
  bool get isReady => !_disposed && (_controller?.value.isInitialized ?? false);

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    _preparedSource = await prepareVideoSource(_source, webMediaStrategy);
    if (_disposed) {
      _preparedSource?.release();
      _preparedSource = null;
      return;
    }
    final prepared = _preparedSource;
    _controller = prepared != null
        ? VideoPlayerController.networkUrl(prepared.uri)
        : switch (_source.type) {
            ScrollWorldSourceType.asset => VideoPlayerController.asset(
              _source.assetName,
              package: _source.package,
            ),
            ScrollWorldSourceType.network => VideoPlayerController.networkUrl(
              _source.uri,
              httpHeaders: _source.headers,
            ),
          };
    await _controller!.initialize();
    await _controller!.setVolume(0);
    await _controller!.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (!isReady) return;
    await _controller!.seekTo(position);
    await _controller!.pause();
  }

  @override
  Future<void> pause() async {
    if (isReady) await _controller!.pause();
  }

  @override
  Future<void> prime() async {
    if (!isReady) return;
    await _controller!.play();
    await _controller!.pause();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller?.dispose();
    _controller = null;
    _preparedSource?.release();
    _preparedSource = null;
  }

  @override
  Widget buildView({BoxFit fit = BoxFit.cover}) {
    if (!isReady) return const SizedBox.shrink();
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    final size = controller.value.size;
    final width = size.width <= 0 ? 16.0 : size.width;
    final height = size.height <= 0 ? 9.0 : size.height;
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
