import 'dart:io';

import 'package:blast_qr/app_preferences.dart';
import 'package:blast_qr/file_name_utils.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('blastqr/files');

const _legacyName = 'docs';

// Linux and Windows keep it in the user's own Documents folder, which may
// already have a folder called "Received".
final _name = Platform.isLinux || Platform.isWindows ? _legacyName : 'Received';

/// On iOS, Documents shows in the Files app, so received files stay in
/// Application Support unless the user turns on [AppPreferences.showInFilesApp].
Future<Directory> _directory({required bool visible, String? name}) async {
  final base = !Platform.isIOS || visible
      ? await getApplicationDocumentsDirectory()
      : await getApplicationSupportDirectory();
  return Directory('${base.path}/${name ?? _name}');
}

Future<Directory> receivedFilesDirectory() async {
  final directory = await _directory(visible: AppPreferences.showInFilesApp);
  await directory.create(recursive: true);
  return directory;
}

/// Moves received files to where the setting points and keeps them out of
/// iCloud backups.
Future<void> syncReceivedFiles() async {
  final directory = await _moveReceivedFiles();
  if (Platform.isIOS) {
    await _channel.invokeMethod('excludeFromBackup', directory.path);
  }
}

/// Moves received files into the directory the setting points at, including
/// any left in the old `docs` folder.
Future<Directory> _moveReceivedFiles() async {
  final to = await receivedFilesDirectory();
  final sources = [
    if (_name != _legacyName) ...[
      await _directory(visible: true, name: _legacyName),
      if (Platform.isIOS) await _directory(visible: false, name: _legacyName),
    ],
    if (Platform.isIOS)
      await _directory(visible: !AppPreferences.showInFilesApp),
  ];
  for (final from in sources) {
    if (!await from.exists()) continue;
    await for (final entity in from.list()) {
      if (entity is! File) continue;
      final name = await resolveUniqueFileName(
        to,
        entity.uri.pathSegments.last,
      );
      await entity.rename('${to.path}/$name');
    }
    try {
      await from.delete();
    } on FileSystemException catch (_) {}
  }
  return to;
}
