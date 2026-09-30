import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/input/action_zone.dart';
import 'package:stepbound/game/input/move_zone.dart';
import 'package:stepbound/game/input/pinch_zone.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/blood_splat.dart';
import 'app_harness.dart';

void main() {
  tapThroughDialogueAtOnce();

  testWidgets('camera starts clamped around the player', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      // The player starts near the south-west corner of the tutorial street:
      // the view stops at the map's left edge instead of centring on him,
      // and never reaches past its bottom.
      final view = game.camera.visibleWorldRect;
      expect(view.left, closeTo(0, 0.01));
      expect(
        view.bottom,
        lessThanOrEqualTo(streetLevelRows.length * 16 + 0.01),
      );
    });
  });

  testWidgets('two fingers landing together zoom the view instead of '
      'walking, and two thumbs, one after the other, still play', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      final mario = game.simulation.player.component<PositionComponent>();
      final start = mario.position;
      void play(double seconds) {
        for (var t = 0.0; t < seconds; t += 1 / 30) {
          game.update(1 / 30);
        }
      }

      final whole = game.camera.visibleWorldRect.width;
      final left = tester.getCenter(
        find.byKey(const ValueKey<String>('touch-move')),
      );
      final a = await tester.startGesture(left - const Offset(12, 0));
      final b = await tester.startGesture(left + const Offset(12, 0));
      expect(game.pinching.value, isTrue);
      await a.moveBy(const Offset(-30, 0));
      await b.moveBy(const Offset(30, 0));
      play(1);
      expect(game.zoom, greaterThan(1));
      expect(
        game.camera.visibleWorldRect.width,
        closeTo(whole / game.zoom, 0.01),
      );
      expect(mario.position, start, reason: 'a pinch is not a step');
      await a.up();
      await b.up();
      expect(game.pinching.value, isFalse);
      expect(game.zoom, greaterThan(1), reason: 'the view stays close');

      // Walking with the left thumb, then touching the right a while
      // later: that is playing, not zooming.
      final zoomed = game.zoom;
      final thumb = await tester.createGesture();
      await thumb.down(left, timeStamp: const Duration(seconds: 10));
      final right = await tester.createGesture();
      await right.down(
        tester.getCenter(find.byKey(const ValueKey<String>('touch-act'))),
        timeStamp:
            const Duration(seconds: 10) +
            PinchZone.together +
            const Duration(milliseconds: 100),
      );
      expect(game.pinching.value, isFalse);
      await thumb.moveBy(const Offset(0, -40));
      await right.moveBy(const Offset(0, 4));
      play(1);
      expect(game.zoom, zoomed);
      expect(mario.position, isNot(start), reason: 'the thumb walked');
      await thumb.up();
      await right.up();
    });
  });

  testWidgets('a drag on the left walks that way for as long as it is held, '
      'turns without lifting and stops on release', (tester) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      final mario = game.simulation.player.component<PositionComponent>();
      void play(double seconds) {
        for (var t = 0.0; t < seconds; t += 1 / 30) {
          game.update(1 / 30);
        }
      }

      final zone = tester.getCenter(
        find.byKey(const ValueKey<String>('touch-move')),
      );
      final start = mario.position;
      final thumb = await tester.startGesture(zone);
      await thumb.moveBy(const Offset(0, -8));
      play(1);
      expect(mario.position, start, reason: 'inside the dead zone');

      await thumb.moveBy(const Offset(0, -30));
      play(1.5);
      expect(mario.facing, Direction.north);
      expect(
        start.y - mario.position.y,
        greaterThan(1),
        reason: 'still walking while the thumb stays down',
      );

      // Round to the east without lifting the thumb.
      final turned = mario.position;
      await thumb.moveBy(const Offset(40, 30));
      play(0.4);
      expect(mario.facing, Direction.east);
      expect(mario.position.x - turned.x, greaterThan(1));

      // Lifted well short of the wall at the end of the street.
      await thumb.up();
      play(0.3);
      final stopped = mario.position;
      play(1.5);
      expect(mario.position, stopped, reason: 'lifting the thumb stops him');
    });
  });

  testWidgets('holding the right raises a stick that turns Mario, lifting '
      'fires that way and lifting in the middle ring lowers the pistol', (
    tester,
  ) {
    return tester.runAsync(() async {
      final game = await pumpReadyGame(tester);
      final mario = game.simulation.player;
      final facing = mario.component<PositionComponent>();
      final zone = tester.getCenter(
        find.byKey(const ValueKey<String>('touch-act')),
      );
      Future<void> holdLongEnough() => Future<void>.delayed(
        ActionZone.holdToAim + const Duration(milliseconds: 150),
      );
      Iterable<ShotEvent> shots() =>
          game.presentation.lastEvents.whereType<ShotEvent>();
      // Lets the turn just taken play out, so the next one starts at once.
      void settle() {
        for (var i = 0; i < 30; i++) {
          game.update(1 / 30);
        }
      }

      mario.component<AmmoComponent>().hasGun = true;
      var finger = await tester.startGesture(zone);
      await holdLongEnough();
      await finger.up();
      expect(
        game.input.aiming.value,
        isFalse,
        reason: 'no shooting unlocked yet',
      );

      game.unlock(HudElement.shoot);
      await tester.pump();

      // Nothing loaded: holding only clicks the pistol.
      mario.component<AmmoComponent>().loaded = 0;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      await finger.up();
      expect(game.input.aiming.value, isFalse);
      expect(
        game.presentation.lastEvents.whereType<DryFiredEvent>(),
        hasLength(1),
      );

      settle();

      mario.component<AmmoComponent>().loaded = 3;
      // A swipe before the pistol is up does nothing.
      finger = await tester.startGesture(zone);
      await finger.moveBy(const Offset(40, 0));
      await holdLongEnough();
      await finger.up();
      expect(game.input.aiming.value, isFalse);

      // Hold: the pistol comes up with a splash of blood. Dragging turns
      // Mario without firing, all the way round, and lifting fires.
      await tester.pump();
      // Splats age by the wall clock here, so older ones may dry off in
      // between: count only the new ones on top.
      final before = splats(tester).lastOrNull;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      expect(game.input.aiming.value, isTrue);
      await tester.pump();
      final hold = splats(tester).last;
      expect(hold, isNot(same(before)), reason: 'the hold');
      await finger.moveBy(const Offset(0, -40));
      expect(facing.facing, Direction.north);
      await finger.moveBy(const Offset(40, 40));
      expect(facing.facing, Direction.east);
      expect(shots(), isEmpty, reason: 'nothing fired while held');
      expect(game.input.aiming.value, isTrue);
      await finger.up();
      await tester.pump();
      expect(splats(tester).last, isNot(same(hold)), reason: 'the shot');
      expect(shots().single.direction, Direction.east);
      expect(game.input.aiming.value, isFalse);
      settle();

      // Dragged out and back into the middle ring: lifting fires nothing.
      var loaded = mario.component<AmmoComponent>().loaded;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      await finger.moveBy(const Offset(-40, 5));
      expect(facing.facing, Direction.west);
      await finger.moveBy(const Offset(36, -3));
      await finger.up();
      expect(game.input.aiming.value, isFalse);
      expect(mario.component<AmmoComponent>().loaded, loaded);

      // Held and lifted where it landed: the pistol goes down unfired.
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      expect(game.input.aiming.value, isTrue);
      await finger.up();
      expect(game.input.aiming.value, isFalse, reason: 'lifting lowers it');
      expect(mario.component<AmmoComponent>().loaded, loaded);

      // Right thumb aiming, left thumb dragging: he neither walks nor
      // fires, the left thumb has no say while the pistol is up.
      final standing = facing.position;
      finger = await tester.startGesture(zone);
      await holdLongEnough();
      final left = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey<String>('touch-move'))),
      );
      await left.moveBy(const Offset(0, 40));
      settle();
      expect(mario.component<AmmoComponent>().loaded, loaded);
      expect(facing.position, standing);
      expect(game.input.aiming.value, isTrue);
      await finger.up();
      await left.up();
      settle();

      // The keyboard arrows still fire straight away.
      loaded = mario.component<AmmoComponent>().loaded;
      game.input.pressShoot();
      expect(game.input.aiming.value, isTrue);
      game.input.pressDirection(Direction.east);
      expect(shots().single.direction, Direction.east);
      expect(game.input.aiming.value, isFalse);
      expect(mario.component<AmmoComponent>().loaded, loaded - 1);

      // A few seconds on, the blood has dried off the glass.
      await tester.pump();
      expect(splats(tester), isNotEmpty);
      await Future<void>.delayed(
        Duration(
          milliseconds: (BloodSplatPainter.lifetime * 1000).round() + 100,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(splats(tester), isEmpty);
    });
  });

  testWidgets('on a keyboard, tapping space interacts, holding it aims and '
      'the arrows then shoot', (tester) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await pumpReadyGame(tester, saves: saves);
      final mario = game.simulation.player;
      void key(LogicalKeyboardKey key, {required bool down}) {
        final physical = key == LogicalKeyboardKey.space
            ? PhysicalKeyboardKey.space
            : PhysicalKeyboardKey.arrowUp;
        game.onKeyEvent(
          down
              ? KeyDownEvent(
                  physicalKey: physical,
                  logicalKey: key,
                  timeStamp: Duration.zero,
                )
              : KeyUpEvent(
                  physicalKey: physical,
                  logicalKey: key,
                  timeStamp: Duration.zero,
                ),
          const <LogicalKeyboardKey>{},
        );
      }

      void play(double seconds) {
        for (var t = 0.0; t < seconds; t += 1 / 30) {
          game.update(1 / 30);
        }
      }

      const space = LogicalKeyboardKey.space;
      mario.component<AmmoComponent>()
        ..hasGun = true
        ..loaded = 2;
      game.unlock(HudElement.shoot);

      // Held: the pistol comes up once the hold is long enough.
      key(space, down: true);
      play(0.2);
      expect(
        game.input.aiming.value,
        isFalse,
        reason: 'not held long enough yet',
      );
      play(0.2);
      expect(game.input.aiming.value, isTrue);
      key(space, down: false);
      expect(game.input.aiming.value, isTrue, reason: 'letting go keeps it up');

      // An arrow fires that way.
      key(LogicalKeyboardKey.arrowUp, down: true);
      expect(
        game.presentation.lastEvents.whereType<ShotEvent>().single.direction,
        Direction.north,
      );
      key(LogicalKeyboardKey.arrowUp, down: false);
      expect(game.input.aiming.value, isFalse);
      play(1);

      // Aiming, a quick tap lowers the pistol.
      key(space, down: true);
      play(0.4);
      key(space, down: false);
      expect(game.input.aiming.value, isTrue);
      key(space, down: true);
      play(0.1);
      key(space, down: false);
      expect(game.input.aiming.value, isFalse);
      expect(mario.component<AmmoComponent>().loaded, 1);

      // Not aiming, a quick tap interacts: here, resting at the fire.
      game.story.restore(const <String, Object?>{
        'north': <String, Object?>{'campLesson': true},
        'backpacks': <String, Object?>{'lesson': true},
        'street': <String, Object?>{'zombieLesson': true},
      });
      final camp = game.simulation.campfires.firstWhere(
        place(PlaceId.northDistrict).bounds.contains,
      );
      mario.component<PositionComponent>()
        ..position = camp.step(Direction.west)
        ..facing = Direction.east;
      game.unlock(HudElement.interact);
      key(space, down: true);
      play(0.1);
      key(space, down: false);
      expect(game.input.aiming.value, isFalse);
      play(3);
      await Future<void>.delayed(Duration.zero);
      expect((await saves.load(1))?.atCampfire, isTrue);
    });
  });

  testWidgets('a tap on the right interacts once interacting is unlocked', (
    tester,
  ) {
    return tester.runAsync(() async {
      final saves = MemorySaveRepository();
      final game = await pumpReadyGame(tester, saves: saves);
      game.story.restore(const <String, Object?>{
        'north': <String, Object?>{'campLesson': true},
        'backpacks': <String, Object?>{'lesson': true},
        'street': <String, Object?>{'zombieLesson': true},
      });
      final camp = game.simulation.campfires.firstWhere(
        place(PlaceId.northDistrict).bounds.contains,
      );
      game.simulation.player.component<PositionComponent>()
        ..position = camp.step(Direction.west)
        ..facing = Direction.east;
      var splatted = false;
      Future<void> tapAndWait() async {
        final before = splats(tester).lastOrNull;
        await tester.tap(find.byKey(const ValueKey<String>('touch-act')));
        await tester.pump();
        splatted = !identical(splats(tester).lastOrNull, before);
        for (var i = 0; i < 60; i++) {
          game.update(1 / 20);
        }
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
      }

      await tapAndWait();
      expect(await saves.load(1), isNull, reason: 'not unlocked yet');
      expect(splatted, isFalse, reason: 'a tap that does nothing');

      game.unlock(HudElement.interact);
      await tester.pump();
      await tapAndWait();
      expect((await saves.load(1))?.atCampfire, isTrue);
      expect(splatted, isTrue, reason: 'the tap left blood');
    });
  });

  test('a drag points along the axis it leans on, and keeps its direction '
      'along a diagonal', () {
    expect(directionOf(const Offset(30, 10)), Direction.east);
    expect(directionOf(const Offset(-30, 10)), Direction.west);
    expect(directionOf(const Offset(5, -30)), Direction.north);
    expect(directionOf(const Offset(5, 30)), Direction.south);
    const diagonal = Offset(20, 22);
    expect(directionOf(diagonal, current: Direction.east), Direction.east);
    expect(directionOf(diagonal, current: Direction.south), Direction.south);
    expect(
      directionOf(const Offset(10, 30), current: Direction.east),
      Direction.south,
    );
  });

  testWidgets('the left half of the screen walks, the right half acts', (
    tester,
  ) async {
    final saves = MemorySaveRepository();
    await saves.save(
      SaveGame(
        slot: 1,
        savedAt: DateTime(2026),
        place: 'Dietro la caserma',
        world: saveGameWorld(createGameWorld()),
        story: const <String, Object?>{},
        progress: Progress.newGame().toJson(),
        hud: const <String>['interact', 'ammo', 'shoot'],
      ),
    );
    await tester.pumpWidget(StepboundApp(saves: saves));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
    await tester.pump();
    tester
            .state<GameWidgetState<StepboundGame>>(
              find.byType(GameWidget<StepboundGame>),
            )
            .currentGame
            .freeToMove
            .value =
        true;
    await tester.pump();

    Rect rectOf(String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key)));

    // Like every gamepad since the NES: the thumb that moves is the left one.
    final screen =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final move = rectOf('touch-move');
    final act = rectOf('touch-act');
    expect(move.left, 0);
    expect(move.right, moreOrLessEquals(screen / 2));
    expect(act.left, moreOrLessEquals(screen / 2));
    expect(act.right, moreOrLessEquals(screen));
    // The missions in the top-left corner, what Mario carries in the
    // bottom-right one, the menu in the top-right one.
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(rectOf('mission-board').left, lessThan(screen * 0.1));
    expect(rectOf('mission-board').top, lessThan(height / 4));
    expect(rectOf('touch-ammo').right, greaterThan(screen * 0.9));
    expect(rectOf('touch-ammo').center.dy, greaterThan(height * 0.75));
    expect(rectOf('touch-menu').right, greaterThan(screen * 0.9));
    expect(rectOf('touch-menu').center.dy, lessThan(height / 4));
  });

  group('on a phone longer than 16:9, with the camera on the left', () {
    /// A 20:9 phone in landscape: the 16:9 picture the menus keep would
    /// leave a band on each side.
    const screen = Size(915, 412);
    const cutout = 32.0;
    final picture =
        IntegerResolutionViewport.virtualWidth *
        IntegerResolutionViewport.scaleFor(screen.width, screen.height);
    final band = (screen.width - picture) / 2;

    Future<StepboundGame> loadOnThePhone(WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = screen
        ..padding = const FakeViewPadding(left: cutout);
      addTearDown(tester.view.reset);
      final saves = MemorySaveRepository();
      await saves.save(
        SaveGame(
          slot: 1,
          savedAt: DateTime(2026),
          place: 'Dietro la caserma',
          world: saveGameWorld(createGameWorld()),
          story: const <String, Object?>{},
          progress: Progress.newGame().toJson(),
          hud: const <String>['interact', 'ammo', 'shoot'],
        ),
      );
      await tester.pumpWidget(StepboundApp(saves: saves));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
      await tester.pump();
      final game = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;
      game.freeToMove.value = true;
      await tester.pump();
      return game;
    }

    Rect rectOf(WidgetTester tester, String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key)));

    testWidgets('the controls sit in the bands, as far from either edge', (
      tester,
    ) async {
      await loadOnThePhone(tester);
      expect(
        rectOf(tester, 'stepbound-game'),
        Offset.zero & screen,
        reason: 'the world fills the screen',
      );

      // The camera cutout is on the left; the right edge keeps the same
      // gap, so the HUD looks the same from either side. The missions
      // start on the left, the menu ends the top and what Mario carries the
      // bottom on the right, and all keep that mirrored gap.
      final missions = rectOf(tester, 'mission-board').left;
      expect(missions, moreOrLessEquals(cutout), reason: 'same gap both sides');
      expect(missions, lessThan(band), reason: 'out by the edge of the screen');
      for (final key in <String>['touch-menu', 'touch-ammo']) {
        final right = screen.width - rectOf(tester, key).right;
        expect(right, moreOrLessEquals(cutout), reason: 'same gap both sides');
        expect(right, lessThan(band), reason: 'out by the edge of the screen');
      }
      // The gesture halves cover the whole screen, bands included.
      expect(rectOf(tester, 'touch-move').left, 0);
      expect(rectOf(tester, 'touch-act').right, moreOrLessEquals(screen.width));
    });

    testWidgets('a text box spans the screen, as far from either edge', (
      tester,
    ) async {
      final game = await loadOnThePhone(tester);
      game.showPrompt(const <StoryLine>[StoryLine('Una battuta')]);
      await tester.pump();

      final box = rectOf(tester, 'story-text');
      expect(box.left, lessThan(band), reason: 'out into the band');
      expect(box.left, greaterThanOrEqualTo(cutout), reason: 'clear of it');
      expect(
        screen.width - box.right,
        moreOrLessEquals(box.left),
        reason: 'same gap both sides',
      );
    });
  });
}
