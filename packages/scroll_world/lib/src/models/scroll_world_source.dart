import 'package:flutter/foundation.dart';

enum ScrollWorldSourceType { asset, network }

/// An asset or HTTPS network video.
@immutable
final class ScrollWorldSource {
  const ScrollWorldSource.asset(this.location, {this.package})
    : type = ScrollWorldSourceType.asset,
      headers = const <String, String>{};

  ScrollWorldSource.network(Uri uri, {this.headers = const {}})
    : type = ScrollWorldSourceType.network,
      location = uri,
      package = null {
    if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'must be an absolute HTTPS URI');
    }
  }

  final ScrollWorldSourceType type;
  final Object location;
  final String? package;
  final Map<String, String> headers;

  String get assetName => location as String;
  Uri get uri => location as Uri;

  @override
  bool operator ==(Object other) =>
      other is ScrollWorldSource &&
      other.type == type &&
      other.location == location &&
      other.package == package &&
      mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(
    type,
    location,
    package,
    Object.hashAllUnordered(
      headers.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );

  @override
  String toString() => 'ScrollWorldSource($type, $location)';
}

/// Responsive video variants for a scene or connector.
@immutable
final class ScrollWorldSources {
  const ScrollWorldSources({
    this.mobilePortrait,
    this.mobileLandscape,
    this.webStandard,
    this.webHigh,
  });

  final ScrollWorldSource? mobilePortrait;
  final ScrollWorldSource? mobileLandscape;
  final ScrollWorldSource? webStandard;
  final ScrollWorldSource? webHigh;

  bool get isEmpty =>
      mobilePortrait == null &&
      mobileLandscape == null &&
      webStandard == null &&
      webHigh == null;

  Iterable<ScrollWorldSource> get available sync* {
    if (mobilePortrait case final source?) yield source;
    if (mobileLandscape case final source?) yield source;
    if (webStandard case final source?) yield source;
    if (webHigh case final source?) yield source;
  }
}
