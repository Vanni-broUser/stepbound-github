// Freezes the saves of a public build: every test scenario, as this build
// writes it, into test/saves/published/. From then on
// test/published_save_test.dart checks that each later build still loads
// them. Run it once per public build, after setting publishedSaveFormat
// (see docs/save_policy.md):
//
//   flutter test tools/freeze_published_saves.dart
//
// It runs under `flutter test` because the save code needs Flutter; it is
// not in test/, so CI skips it.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/test_scenarios.dart';
import 'package:stepbound/save/published_save.dart';
import 'package:stepbound/save/save_game.dart';

void main() {
  test('freeze the saves of the public build', () {
    if (publishedSaveFormat != SaveGame.format) {
      fail(
        'publishedSaveFormat is $publishedSaveFormat, the build writes '
        'format ${SaveGame.format}: set it to the format going public first',
      );
    }
    final frozen = Directory('test/saves/published');
    if (frozen.existsSync()) {
      frozen.deleteSync(recursive: true);
    }
    frozen.createSync(recursive: true);
    for (final (index, scenario) in testScenarios.indexed) {
      final name = scenario.name
          .toLowerCase()
          .replaceAll(RegExp('[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final path =
          '${frozen.path}/${index.toString().padLeft(2, '0')}_$name.json';
      File(path).writeAsStringSync(jsonEncode(scenario.save(1).toJson()));
      print(path);
    }
  });
}
