import 'package:flutter/widgets.dart';

import '../models/scroll_world_source.dart';

/// Platform-neutral playback surface used by Scroll World.
abstract interface class ScrollVideoDriver {
  Future<void> initialize();
  Future<void> seekTo(Duration position);
  Future<void> pause();
  Future<void> dispose();

  Duration get duration;
  bool get isReady;

  Widget buildView({BoxFit fit = BoxFit.cover});
}

/// Creates one playback driver for one selected source.
abstract interface class ScrollVideoDriverFactory {
  ScrollVideoDriver create(ScrollWorldSource source);
}

/// Optional capability for platforms that need a user gesture before seeking.
abstract interface class ScrollVideoPrimingDriver {
  Future<void> prime();
}
