import 'dart:js_interop';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../models/scroll_world_configuration.dart';
import '../models/scroll_world_source.dart';
import 'prepared_video_source_types.dart';

Future<PreparedVideoSource?> prepareVideoSource(
  ScrollWorldSource source,
  ScrollWorldWebMediaStrategy strategy,
) async {
  if (strategy == ScrollWorldWebMediaStrategy.direct) return null;

  late final Uint8List bytes;
  var contentType = 'video/mp4';
  switch (source.type) {
    case ScrollWorldSourceType.asset:
      final key = source.package == null
          ? source.assetName
          : 'packages/${source.package}/${source.assetName}';
      final data = await rootBundle.load(key);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      break;
    case ScrollWorldSourceType.network:
      final response = await http.get(source.uri, headers: source.headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Unable to load ${source.uri}: HTTP ${response.statusCode}.',
        );
      }
      bytes = response.bodyBytes;
      contentType =
          response.headers['content-type']?.split(';').first ?? contentType;
      break;
  }

  final parts = <JSAny>[bytes.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: contentType));
  final objectUrl = web.URL.createObjectURL(blob);
  return PreparedVideoSource(Uri.parse(objectUrl), () {
    web.URL.revokeObjectURL(objectUrl);
  });
}
