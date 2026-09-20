import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

import 'test_world.dart';

void main() {
  test('WorldState survives a complete JSON round trip', () {
    final world = corridorWorld(EntityKind.blind, seed: 123);
    const MoveAction(Direction.east).resolve(world);

    final encoded = jsonEncode(world.toJson());
    final restored = WorldState.fromJson(
      jsonDecode(encoded) as Map<String, Object?>,
    );

    expect(jsonEncode(restored.toJson()), encoded);
  });

  test('seeded random produces repeatable sequences', () {
    final first = SeededRandom(42);
    final second = SeededRandom(42);

    expect(
      List<int>.generate(20, (_) => first.nextInt(1000)),
      List<int>.generate(20, (_) => second.nextInt(1000)),
    );
  });
}
