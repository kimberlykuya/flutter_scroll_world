import 'dart:io';

/// Detaches the stable package and Kenya example from the Padlo master-SDK
/// workspace in an ephemeral CI checkout.
///
/// Run this only in CI. It intentionally rewrites pubspecs so Flutter stable
/// can resolve the two stable projects without seeing the flutter_scene app.
void main() {
  final rootPubspec = File('pubspec.yaml');
  final packagePubspec = File('packages/scroll_world/pubspec.yaml');
  final examplePubspec = File('example/pubspec.yaml');

  for (final file in <File>[rootPubspec, packagePubspec, examplePubspec]) {
    if (!file.existsSync()) {
      stderr.writeln('Missing expected pubspec: ${file.path}');
      exitCode = 1;
      return;
    }
  }

  _removeWorkspaceBlock(rootPubspec);
  _removeWorkspaceResolution(packagePubspec);
  _removeWorkspaceResolution(examplePubspec);
  stdout.writeln('Prepared standalone stable package and Kenya example.');
}

void _removeWorkspaceBlock(File file) {
  final lines = file.readAsLinesSync();
  final output = <String>[];
  var skippingMembers = false;

  for (final line in lines) {
    if (line.trim() == 'workspace:') {
      skippingMembers = true;
      continue;
    }
    if (skippingMembers && line.startsWith('  - ')) {
      continue;
    }
    skippingMembers = false;
    output.add(line);
  }

  file.writeAsStringSync('${output.join('\n')}\n');
}

void _removeWorkspaceResolution(File file) {
  final lines = file.readAsLinesSync().where(
    (line) => line.trim() != 'resolution: workspace',
  );
  file.writeAsStringSync('${lines.join('\n')}\n');
}
