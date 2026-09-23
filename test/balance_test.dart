import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  final decoded =
      jsonDecode(File('assets/balance/default.json').readAsStringSync())
          as Map<String, Object?>;

  test('generated balance matches the authoritative JSON asset', () {
    expect(
      BalanceConfig.standard().toJson(),
      BalanceConfig.fromJson(decoded).toJson(),
    );
  });

  test('every actor kind has stats', () {
    // A kind added to the enum alone would only fail when it is spawned.
    expect(
      BalanceConfig.standard().actors.keys.toSet(),
      EntityKind.values.toSet(),
    );
  });
}
