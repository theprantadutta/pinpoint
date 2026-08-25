import 'dart:io';

/// Reads a file relative to the package root.
///
/// `flutter test` runs with the package root as the working directory, so a
/// plain relative path is stable.
String readProjectFile(String relativePath) {
  final file = File(relativePath);
  if (!file.existsSync()) {
    throw StateError(
      'Expected $relativePath to exist (cwd: ${Directory.current.path}). '
      'If the file moved, update the guard tests that read it.',
    );
  }
  return file.readAsStringSync();
}

/// Every `.dart` file under [directory], as path -> source.
Iterable<MapEntry<String, String>> dartFilesUnder(String directory) sync* {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    throw StateError('Expected $directory to exist '
        '(cwd: ${Directory.current.path}).');
  }
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield MapEntry(
        entity.path.replaceAll(r'\', '/'),
        entity.readAsStringSync(),
      );
    }
  }
}
