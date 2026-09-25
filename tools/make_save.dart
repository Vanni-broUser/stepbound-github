// Writes one of the test scenarios as the browser stores a save, ready to be
// put in the localStorage of a page running the game:
//
//   flutter test tools/make_save.dart --dart-define=SCENARIO=3 \
//     --dart-define=SLOT=2 --dart-define=OUT=/path/save.json
//
// SCENARIO is the index or part of the name (without it, the list is
// printed); SLOT defaults to the last one. OUT gets
// {"key": ..., "value": ...}: localStorage.setItem(key, value), then reload
// the page and the save is in CARICA PARTITA. It runs under `flutter test`
// because the save code needs Flutter; it is not in test/, so CI skips it.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/test_scenarios.dart';
import 'package:stepbound/save/save_game.dart';

void main() {
  test('make a save', () {
    const wanted = String.fromEnvironment('SCENARIO');
    const slot = int.fromEnvironment(
      'SLOT',
      defaultValue: SaveRepository.slotCount,
    );
    const out = String.fromEnvironment('OUT');
    if (wanted.isEmpty) {
      for (final (index, scenario) in testScenarios.indexed) {
        print('$index: ${scenario.name}');
      }
      return;
    }
    final index = int.tryParse(wanted);
    final scenario = index != null
        ? testScenarios[index]
        : testScenarios.firstWhere(
            (scenario) =>
                scenario.name.toLowerCase().contains(wanted.toLowerCase()),
          );
    final save = scenario.save(slot);
    // The web shared_preferences store every value JSON-encoded, and the
    // repository's value is itself the save's JSON.
    final entry = <String, String>{
      'key': StoredSaveRepository.slotKey(slot),
      'value': jsonEncode(jsonEncode(save.toJson())),
    };
    File(out).writeAsStringSync(jsonEncode(entry));
    print('${scenario.name} -> slot $slot -> $out');
  });
}
