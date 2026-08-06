import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> arguments) async {
  final root = Directory(
    arguments.isEmpty ? 'example/assets' : arguments.first,
  );
  if (!root.existsSync()) {
    stderr.writeln('Asset directory does not exist: ${root.path}');
    exitCode = 66;
    return;
  }
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.mp4') ||
                file.path.endsWith('.webp') ||
                file.path.endsWith('.glb'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final assets = <Map<String, Object?>>[];
  for (final file in files) {
    final relative = file.path
        .replaceAll('\\', '/')
        .replaceFirst('${root.path.replaceAll('\\', '/')}/', '');
    final item = <String, Object?>{
      'path': relative,
      'bytes': file.lengthSync(),
      'sha256': sha256.convert(await file.readAsBytes()).toString(),
    };
    if (file.path.endsWith('.glb')) {
      item['format'] = 'glb';
    }
    if (file.path.endsWith('.mp4')) {
      final result = await Process.run('ffprobe', <String>[
        '-v',
        'error',
        '-show_entries',
        'stream=codec_type,codec_name,width,height,duration,avg_frame_rate',
        '-of',
        'json',
        file.path,
      ]);
      if (result.exitCode != 0) {
        throw ProcessException('ffprobe', <String>[
          file.path,
        ], '${result.stderr}');
      }
      final probe = jsonDecode(result.stdout as String) as Map<String, Object?>;
      final streams = probe['streams']! as List<Object?>;
      final typedStreams = streams.cast<Map<String, Object?>>();
      final videoStreams = typedStreams
          .where((stream) => stream['codec_type'] == 'video')
          .toList();
      final audioStreams = typedStreams
          .where((stream) => stream['codec_type'] == 'audio')
          .toList();
      if (videoStreams.length != 1) {
        throw StateError('${file.path} must contain exactly one video stream.');
      }
      final video = videoStreams.single;
      if (video['codec_name'] != 'h264') {
        throw StateError('${file.path} must use H.264 video.');
      }
      if (video['avg_frame_rate'] != '24/1') {
        throw StateError('${file.path} must use 24 fps.');
      }
      if (audioStreams.isNotEmpty) {
        throw StateError('${file.path} must not contain audio.');
      }
      item['video'] = video;
      item['audio_streams'] = audioStreams.length;
    }
    assets.add(item);
  }

  final output = File(
    '${root.path}${Platform.pathSeparator}media_manifest.json',
  );
  const encoder = JsonEncoder.withIndent('  ');
  output.writeAsStringSync(
    '${encoder.convert(<String, Object>{'assets': assets})}\n',
  );
  stdout.writeln('Wrote ${output.path} with ${assets.length} assets.');
}
