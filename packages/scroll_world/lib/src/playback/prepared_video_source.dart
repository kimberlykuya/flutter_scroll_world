import '../models/scroll_world_configuration.dart';
import '../models/scroll_world_source.dart';
import 'prepared_video_source_types.dart';
import 'prepared_video_source_stub.dart'
    if (dart.library.js_interop) 'prepared_video_source_web.dart'
    as platform;

Future<PreparedVideoSource?> prepareVideoSource(
  ScrollWorldSource source,
  ScrollWorldWebMediaStrategy strategy,
) => platform.prepareVideoSource(source, strategy);
