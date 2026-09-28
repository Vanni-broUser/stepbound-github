import 'dart:async';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/game_session.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/save/skin_links.dart';

final DateTime _now = DateTime(2026, 10, 20, 18);

Uri _link(PlayerOutfit outfit, {Duration left = skinLinkValidity}) =>
    skinGiftLink(outfit, expiresAt: _now.add(left), nonce: 42);

SaveGame _save(int slot, {Progress? progress}) => SaveGame(
  slot: slot,
  savedAt: DateTime(2026),
  place: 'Dietro la caserma',
  world: saveGameWorld(createGameWorld()),
  story: const <String, Object?>{},
  progress: (progress ?? Progress.newGame()).toJson(),
  hud: const <String>[],
);

void main() {
  group('gift links', () {
    for (final outfit in halloweenOutfits) {
      test('${outfit.name} reads back with its expiry', () {
        final link = readSkinLink(_link(outfit));
        expect(link?.outfit, outfit);
        expect(link?.expiresAt, _now.add(skinLinkValidity));
        expect(link?.expiredAt(_now), isFalse);
        expect(link?.expiredAt(_now.add(skinLinkValidity)), isTrue);
      });
    }

    test('two links for the same skin differ, and both work', () {
      final first = skinGiftLink(
        PlayerOutfit.ghost,
        expiresAt: _now,
        nonce: randomSkinLinkNonce(),
      );
      final second = skinGiftLink(
        PlayerOutfit.ghost,
        expiresAt: _now,
        nonce: randomSkinLinkNonce(),
      );
      expect(first, isNot(second));
      expect(readSkinLink(first)?.outfit, PlayerOutfit.ghost);
      expect(readSkinLink(second)?.outfit, PlayerOutfit.ghost);
    });

    test('an edited link, or one not made here, is ignored', () {
      final token = _link(PlayerOutfit.zombie).pathSegments.single;
      final edited = token.replaceRange(3, 4, token[3] == 'A' ? 'B' : 'A');
      for (final link in <String>[
        'stepbound://unlock/$edited',
        'https://example.com/unlock/$token',
        'stepbound://other/$token',
        'stepbound://unlock/$token/extra',
        'stepbound://unlock/$token?again=true',
        'stepbound://unlock/ghost',
        // The old codes, which never expired.
        'stepbound://unlock/7fcc3bdba2794318b697b64046adf9f8',
      ]) {
        expect(readSkinLink(Uri.parse(link)), isNull, reason: link);
      }
    });

    test('only the Halloween skins can be given', () {
      expect(
        () => skinGiftLink(PlayerOutfit.cultist, expiresAt: _now, nonce: 1),
        throwsArgumentError,
      );
    });
  });

  test('Android and iOS register the Stepbound unlock scheme', () async {
    final android = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();
    expect(android, contains('android:scheme="stepbound"'));
    expect(android, contains('android:host="unlock"'));
    final ios = await File('ios/Runner/Info.plist').readAsString();
    expect(ios, contains('<string>stepbound</string>'));
  });

  group('gifts in a slot', () {
    late MemorySaveRepository saves;
    late GameSession session;

    setUp(() {
      saves = MemorySaveRepository();
      session = GameSession(
        saves: saves,
        audio: SilentAudio(),
        onLevelCompleted: (_) {},
        onTravelMapRequested: (_) {},
      );
    });

    test('an empty slot keeps them for the game started in it', () async {
      await saves.saveGifts(2, <PlayerOutfit>{PlayerOutfit.vampire});

      await session.startNew(2);

      expect(await saves.loadGifts(2), <PlayerOutfit>{PlayerOutfit.vampire});
      expect(
        session.newGame().progress.unlockedOutfits,
        orderedEquals(<PlayerOutfit>[PlayerOutfit.vampire, PlayerOutfit.base]),
        reason: 'Mario had it before the game began: before his own clothes',
      );
    });

    test('a game started over a saved one drops them', () async {
      await saves.save(_save(3));
      await saves.saveGifts(3, <PlayerOutfit>{PlayerOutfit.ghost});

      await session.startNew(3);

      expect(await saves.loadGifts(3), isEmpty);
      expect(
        session.newGame().progress.unlockedOutfits,
        isNot(contains(PlayerOutfit.ghost)),
      );
    });

    test('a saved game loaded from its slot wears them', () async {
      await saves.save(_save(1));
      await saves.saveGifts(1, <PlayerOutfit>{PlayerOutfit.zombie});

      final game = await session.load(_save(1));

      expect(
        game.progress.unlockedOutfits,
        orderedEquals(<PlayerOutfit>[PlayerOutfit.base, PlayerOutfit.zombie]),
        reason: 'a gift does not skip the Duomo, and comes after the base',
      );
    });

    test('a gift that came to a saved game goes after what it had, the '
        'robe included, and stays where it went', () async {
      final robe = Progress.newGame()..unlockOutfit(PlayerOutfit.cultist);
      await saves.save(_save(1, progress: robe));
      await saves.saveGifts(1, <PlayerOutfit>{PlayerOutfit.ghost});

      final game = await session.load(_save(1, progress: robe));
      final order = <PlayerOutfit>[
        PlayerOutfit.base,
        PlayerOutfit.cultist,
        PlayerOutfit.ghost,
      ];
      expect(game.progress.unlockedOutfits, orderedEquals(order));

      // Saved and loaded again, the ghost is still where it went, and the
      // gift already there adds nothing.
      final again = await session.load(
        _save(1, progress: Progress.fromJson(game.progress.toJson())),
      );
      expect(again.progress.unlockedOutfits, orderedEquals(order));
    });
  });

  group('opening a link', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
    }

    testWidgets('gives the skin to all four slots and says so', (tester) async {
      final saves = MemorySaveRepository();
      await saves.save(_save(1));
      await tester.pumpWidget(
        StepboundApp(
          saves: saves,
          clock: () => _now,
          skinLinks: Stream<Uri>.value(_link(PlayerOutfit.jackOLantern)),
        ),
      );
      await settle(tester);

      for (var slot = 1; slot <= SaveRepository.slotCount; slot++) {
        expect(await saves.loadGifts(slot), <PlayerOutfit>{
          PlayerOutfit.jackOLantern,
        });
      }
      expect(
        find.byKey(const ValueKey<String>('skin-gift-notice')),
        findsOneWidget,
      );
      expect(find.text('Skin Jack-o’-lantern'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('skin-link-close')));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
      await settle(tester);
      expect(
        find.byKey(const ValueKey<String>('menu-slot-1-gift')),
        findsOneWidget,
      );
    });

    testWidgets('a second skin adds to the first, one label per slot', (
      tester,
    ) async {
      final saves = MemorySaveRepository();
      await saves.saveGifts(4, <PlayerOutfit>{PlayerOutfit.ghost});
      await saves.save(_save(4));
      await tester.pumpWidget(
        StepboundApp(
          saves: saves,
          clock: () => _now,
          skinLinks: Stream<Uri>.value(_link(PlayerOutfit.vampire)),
        ),
      );
      await settle(tester);

      expect(await saves.loadGifts(4), <PlayerOutfit>{
        PlayerOutfit.ghost,
        PlayerOutfit.vampire,
      });
      await tester.tap(find.byKey(const ValueKey<String>('skin-link-close')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('menu-new-game')));
      await settle(tester);
      expect(find.text('REGALO'), findsNWidgets(SaveRepository.slotCount));
    });

    testWidgets('an expired link gives nothing and says so', (tester) async {
      final saves = MemorySaveRepository();
      await tester.pumpWidget(
        StepboundApp(
          saves: saves,
          clock: () => _now,
          skinLinks: Stream<Uri>.value(
            _link(PlayerOutfit.ghost, left: -const Duration(minutes: 1)),
          ),
        ),
      );
      await settle(tester);

      expect(
        find.byKey(const ValueKey<String>('skin-link-invalid')),
        findsOneWidget,
      );
      for (var slot = 1; slot <= SaveRepository.slotCount; slot++) {
        expect(await saves.loadGifts(slot), isEmpty);
      }
    });

    testWidgets('an edited link says it is not valid, others are ignored', (
      tester,
    ) async {
      final links = StreamController<Uri>();
      addTearDown(links.close);
      await tester.pumpWidget(
        StepboundApp(
          saves: MemorySaveRepository(),
          clock: () => _now,
          skinLinks: links.stream,
        ),
      );
      await settle(tester);

      links.add(Uri.parse('https://example.com/unlock/abc'));
      await settle(tester);
      expect(
        find.byKey(const ValueKey<String>('skin-link-invalid')),
        findsNothing,
      );

      links.add(Uri.parse('stepbound://unlock/not-a-gift'));
      await settle(tester);
      expect(
        find.byKey(const ValueKey<String>('skin-link-invalid')),
        findsOneWidget,
      );
    });

    testWidgets('while playing, the game gets it and the menu comes back', (
      tester,
    ) async {
      final saves = MemorySaveRepository();
      await saves.save(_save(1));
      final links = StreamController<Uri>();
      addTearDown(links.close);
      await tester.pumpWidget(
        StepboundApp(saves: saves, clock: () => _now, skinLinks: links.stream),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('menu-load')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
      await settle(tester);
      final game = tester
          .state<GameWidgetState<StepboundGame>>(
            find.byType(GameWidget<StepboundGame>),
          )
          .currentGame;

      links.add(_link(PlayerOutfit.zombie));
      await settle(tester);

      expect(game.progress.unlockedOutfits, contains(PlayerOutfit.zombie));
      expect(find.byKey(const ValueKey<String>('main-menu')), findsOneWidget);
      expect(find.text('Skin Zombi'), findsOneWidget);
    });
  });
}
