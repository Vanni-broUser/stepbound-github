import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/game/stepbound_game.dart';

void main() {
  testWidgets('F2 mounts the Flame game surface', (tester) async {
    await tester.pumpWidget(const StepboundApp(flavor: AppFlavor.dev));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('stepbound-game-surface')),
      findsOneWidget,
    );
    expect(find.byType(GameWidget<StepboundGame>), findsOneWidget);
    for (final key in <String>[
      'touch-up',
      'touch-right',
      'touch-down',
      'touch-left',
      'touch-shoot',
      'touch-interact',
    ]) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
    }
  });

  testWidgets('camera starts clamped around the player', (tester) {
    return tester.runAsync(() async {
      await tester.pumpWidget(const StepboundApp(flavor: AppFlavor.dev));
      await tester.pump();
      final gameState = tester.state<GameWidgetState<StepboundGame>>(
        find.byType(GameWidget<StepboundGame>),
      );
      await gameState.loaderFuture;
      final game = gameState.currentGame;
      await game.ready();
      expect(game.camera.viewfinder.position.x, 192);
      expect(game.camera.viewfinder.position.y, 160);
    });
  });
}
