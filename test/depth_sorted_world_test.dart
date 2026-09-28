import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/game/render/depth_sorted_world.dart';

final class _Standing extends PositionComponent with StandsOnFloor {
  _Standing(this.name, this.drawn, double feetY)
    : super(position: Vector2(0, feetY), priority: 20);

  final String name;
  final List<String> drawn;

  @override
  void render(ui.Canvas canvas) => drawn.add(name);
}

final class _Layer extends Component {
  _Layer(this.name, this.drawn, int priority) : super(priority: priority);

  final String name;
  final List<String> drawn;

  @override
  void render(ui.Canvas canvas) => drawn.add(name);
}

void main() {
  testWidgets('whoever stands further south is drawn over the one behind, '
      'whatever order they came in, and the layers keep their places', (
    tester,
  ) async {
    final drawn = <String>[];
    final world = DepthSortedWorld();
    final game = FlameGame(world: world);
    await tester.runAsync(() async {
      await tester.pumpWidget(GameWidget(game: game));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await world.addAll(<Component>[
        _Layer('floor', drawn, 0),
        _Layer('front', drawn, 22),
        // The cultist first, as the story adds its people before Mario.
        _Standing('cultist', drawn, 13 * 16),
        _Standing('mario', drawn, 12 * 16),
        _Standing('zombie', drawn, 14 * 16),
      ]);
      for (var i = 0; i < 3; i++) {
        game.update(0);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      drawn.clear();
      game.render(ui.Canvas(ui.PictureRecorder()));
    });
    expect(drawn, <String>['floor', 'mario', 'cultist', 'zombie', 'front']);
  });
}
