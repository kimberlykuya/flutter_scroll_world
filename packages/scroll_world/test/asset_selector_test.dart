import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_world/scroll_world.dart';
import 'package:scroll_world/src/utilities/asset_selector.dart';

const portrait = ScrollWorldSource.asset('portrait.mp4');
const landscape = ScrollWorldSource.asset('landscape.mp4');
const standard = ScrollWorldSource.asset('standard.mp4');
const high = ScrollWorldSource.asset('high.mp4');
const sources = ScrollWorldSources(
  mobilePortrait: portrait,
  mobileLandscape: landscape,
  webStandard: standard,
  webHigh: high,
);

void main() {
  test('network sources require absolute HTTPS URLs', () {
    expect(
      () =>
          ScrollWorldSource.network(Uri.parse('http://example.com/video.mp4')),
      throwsArgumentError,
    );
    expect(
      ScrollWorldSource.network(Uri.parse('https://example.com/video.mp4')).uri,
      Uri.parse('https://example.com/video.mp4'),
    );
  });

  test('selects portrait first', () {
    expect(
      selectScrollWorldSource(
        sources,
        const ScrollWorldEnvironment(
          isWeb: true,
          isPortrait: true,
          viewportWidth: 1200,
          devicePixelRatio: 2,
        ),
        mobileBreakpoint: 900,
        webHighPhysicalWidth: 1920,
      ),
      portrait,
    );
  });

  test('selects mobile landscape for narrow landscape viewports', () {
    expect(
      selectScrollWorldSource(
        sources,
        const ScrollWorldEnvironment(
          isWeb: false,
          isPortrait: false,
          viewportWidth: 800,
          devicePixelRatio: 2,
        ),
        mobileBreakpoint: 900,
        webHighPhysicalWidth: 1920,
      ),
      landscape,
    );
  });

  test('selects high web media by physical width', () {
    expect(
      selectScrollWorldSource(
        sources,
        const ScrollWorldEnvironment(
          isWeb: true,
          isPortrait: false,
          viewportWidth: 1200,
          devicePixelRatio: 2,
        ),
        mobileBreakpoint: 900,
        webHighPhysicalWidth: 1920,
      ),
      high,
    );
  });
}
