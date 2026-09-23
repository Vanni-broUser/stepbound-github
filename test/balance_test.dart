import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('generated balance matches the authoritative JSON asset', () {
    final decoded =
        jsonDecode(File('assets/balance/default.json').readAsStringSync())
            as Map<String, Object?>;

    expect(
      BalanceConfig.standard().toJson(),
      BalanceConfig.fromJson(decoded).toJson(),
    );
  });
}
