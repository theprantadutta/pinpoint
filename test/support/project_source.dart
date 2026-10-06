import 'dart:io';

/// Reads a file relative to the package root, with LF line endings.
///
/// `flutter test` runs with the package root as the working directory, so a
/// plain relative path is stable. Line endings are normalised because a
/// Windows checkout turns files to CRLF, and guards matching across lines
/// would then fail there and pass elsewhere.
String readProjectFile(String relativePath) {
  final file = File(relativePath);
  if (!file.existsSync()) {
    throw StateError(
      'Expected $relativePath to exist (cwd: ${Directory.current.path}). '
      'If the file moved, update the guard tests that read it.',
    );
  }
  return file.readAsStringSync().replaceAll('\r\n', '\n');
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
        entity.readAsStringSync().replaceAll('\r\n', '\n'),
      );
    }
  }
}
