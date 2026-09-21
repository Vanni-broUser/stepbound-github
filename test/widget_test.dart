import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/stepbound_game.dart';

/// Two taps per scene (image, then text) across the three intro scenes.
const int _introTapCount = 6;

Future<void> _pumpAppThroughIntro(WidgetTester tester) async {
  await tester.pumpWidget(const StepboundApp(flavor: AppFlavor.dev));
  await tester.pump();
  final intro = find.byKey(const ValueKey<String>('story-intro'));
  for (var i = 0; i < _introTapCount; i++) {
    await tester.tap(intro);
    await tester.pump();
  }
}

Future<StepboundGame> _pumpReadyGame(WidgetTester tester) async {
  await _pumpAppThroughIntro(tester);
  final gameState = tester.state<GameWidgetState<StepboundGame>>(
    find.byType(GameWidget<StepboundGame>),
  );
  await gameState.loaderFuture;
  final game = gameState.currentGame;
  await game.ready();
  return game;
}

void main() {
  testWidgets('F2 mounts the Flame game surface', (tester) async {
    await _pumpAppThroughIntro(tester);
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
      'touch-ammo',
    ]) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
    }
    expect(find.text('\u00d76'), findsOneWidget);
  });

  testWidgets('intro scenes reveal text on tap, then advance to the next', (
    tester,
  ) async {
    await tester.pumpWidget(const StepboundApp(flavor: AppFlavor.dev));
    await tester.pump();
    final intro = find.byKey(const ValueKey<String>('story-intro'));
    expect(intro, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('story-text')), findsNothing);
    expect(find.byKey(const ValueKey<String>('story-image-0')), findsOneWidget);

    await tester.tap(intro);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('story-text')), findsOneWidget);
    expect(
      find.text(
        'Attenzione, interrompiamo le comunicazioni per una edizione '
        'straordinaria del telegiornale',
      ),
      findsOneWidget,
    );

    await tester.tap(intro);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('story-image-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('story-text')), findsNothing);

    for (var i = 0; i < 4; i++) {
      await tester.tap(intro);
      await tester.pump();
    }
    expect(find.byKey(const ValueKey<String>('story-intro')), findsNothing);
    expect(find.byType(GameWidget<StepboundGame>), findsOneWidget);
  });

  testWidgets('camera starts clamped around the player', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);
      expect(game.camera.viewfinder.position.x, 192);
      expect(game.camera.viewfinder.position.y, 160);
    });
  });

  testWidgets('shoot button cannot aim when the magazine is empty', (tester) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);

      void setLoadedRounds(int value) =>
          game.simulation.player.component<AmmoComponent>().loaded = value;

      setLoadedRounds(0);
      game.pressShoot();
      expect(game.aiming.value, isFalse);

      setLoadedRounds(1);
      game.pressShoot();
      expect(game.aiming.value, isTrue);
    });
  });

  testWidgets('a fatal bite shows the game over overlay and restart works', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await _pumpReadyGame(tester);

      final player = game.simulation.player;
      expect(
        player.component<HealthComponent>().maximum,
        1,
        reason: 'a single zombie bite must be fatal',
      );
      player.component<HealthComponent>().current = 1;
      final playerPosition = player.component<PositionComponent>().position;
      final zombie = game.simulation.entities.values.firstWhere(
        (entity) => entity.kind != EntityKind.player,
      );
      zombie.component<PositionComponent>()
        ..position = playerPosition.step(Direction.east)
        ..facing = Direction.west;
      zombie.component<ActorComponent>().energy =
          zombie.component<ActorComponent>().tickCost - 1;

      game.pressWait();
      await tester.pump(const Duration(milliseconds: 300));
      expect(player.component<HealthComponent>().current, 0);

      await tester.pump(const Duration(seconds: 1));
      expect(game.gameOver.value, isTrue);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('game-over-overlay')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('restart-button')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('game-over-overlay')),
        findsNothing,
      );
    });
  });
}
