import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('the world does not progress across 10000 cycles without input', () {
    final world = createDemoWorld();
    const renderer = AsciiRenderer();
    final before = jsonEncode(world.toJson());

    for (var iteration = 0; iteration < 10000; iteration++) {
      renderer.render(world);
    }

    expect(world.tick, 0);
    expect(jsonEncode(world.toJson()), before);
  });
}
