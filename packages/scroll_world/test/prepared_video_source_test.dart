import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_world/src/playback/prepared_video_source_types.dart';

void main() {
  test('prepared Blob URL cleanup runs exactly once', () {
    var releaseCalls = 0;
    final source = PreparedVideoSource(
      Uri.parse('blob:https://example.test/media'),
      () => releaseCalls += 1,
    );

    source.release();
    source.release();

    expect(releaseCalls, 1);
  });
}
