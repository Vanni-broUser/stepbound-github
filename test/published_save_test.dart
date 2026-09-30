import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/save/published_save.dart';
import 'package:stepbound/save/save_game.dart';

/// Players keep the saves of the last public build: whatever the format
/// has become since, this build must still load every one of them. They
/// are frozen by `tools/freeze_published_saves.dart`; see
/// `docs/save_policy.md`.
void main() {
  final directory = Directory('test/saves/published');
  final frozen = directory.existsSync()
      ? (directory.listSync().whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  test('the saves frozen are those of the public build', () {
    if (publishedSaveFormat == null) {
      expect(frozen, isEmpty, reason: 'no build is public yet');
      return;
    }
    expect(
      frozen,
      isNotEmpty,
      reason: 'freeze them: flutter test tools/freeze_published_saves.dart',
    );
    expect(publishedSaveFormat, lessThanOrEqualTo(SaveGame.format));
  });

  for (final file in frozen) {
    test('${file.uri.pathSegments.last} still loads', () {
      final read = SaveGame.decode(
        file.readAsStringSync(),
        check: checkRestorable,
      );
      expect(
        read,
        isA<LoadedSave>(),
        reason: switch (read) {
          DamagedSave(:final reason) => reason,
          _ => 'read as empty: it is not of the published format',
        },
      );
    });
  }
}
