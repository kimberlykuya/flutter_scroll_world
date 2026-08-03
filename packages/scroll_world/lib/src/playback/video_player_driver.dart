import '../models/scroll_world_configuration.dart';
import '../models/scroll_world_source.dart';
import 'scroll_video_driver.dart';
import 'video_player_driver_native.dart'
    if (dart.library.js_interop) 'video_player_driver_web.dart'
    as platform;

final class VideoPlayerDriverFactory implements ScrollVideoDriverFactory {
  const VideoPlayerDriverFactory({
    this.webMediaStrategy = ScrollWorldWebMediaStrategy.blob,
  });

  final ScrollWorldWebMediaStrategy webMediaStrategy;

  @override
  ScrollVideoDriver create(ScrollWorldSource source) =>
      platform.createVideoPlayerScrollDriver(
        source,
        webMediaStrategy: webMediaStrategy,
      );
}
