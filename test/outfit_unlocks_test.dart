import 'dart:async';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/save/outfit_unlocks.dart';
import 'package:stepbound/save/save_game.dart';

void main() {
  group('skin unlock links', () {
    for (final outfit in halloweenOutfits) {
      test('${outfit.name} has a round-tripping campaign link', () {
        final link = outfitUnlockLink(outfit);
        expect(link.scheme, 'stepbound');
        expect(link.host, 'unlock');
        expect(outfitFromUnlockLink(link), outfit);
      });
    }

    test('campaign codes are unique opaque 128-bit tokens', () {
      final codes = <String>{
        for (final outfit in halloweenOutfits)
          outfitUnlockLink(outfit).pathSegments.single,
      };

      expect(codes, hasLength(halloweenOutfits.length));
      for (final code in codes) {
        expect(code, matches(RegExp(r'^[0-9a-f]{32}$')));
      }
    });

    test('unrelated and malformed links are ignored', () {
      for (final link in <String>[
        'https://example.com/unlock/ghost',
        'stepbound://other/ghost',
        'stepbound://unlock/base',
        'stepbound://unlock/ghost',
        'stepbound://unlock/vampire',
        'stepbound://unlock/jack-o-lantern',
        'stepbound://unlock/zombie',
        'stepbound://unlock/7fcc3bdba2794318b697b64046adf9f0',
        'stepbound://unlock/ghost/extra',
        'stepbound://unlock/ghost?again=true',
      ]) {
        expect(outfitFromUnlockLink(Uri.parse(link)), isNull, reason: link);
      }
    });
  });

  test('Android and iOS register the Stepbound unlock scheme', () async {
    final android = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();
    expect(android, contains('android:scheme="stepbound"'));
    expect(android, contains('android:host="unlock"'));
    expect(
      android,
      contains('android:name="android.intent.category.BROWSABLE"'),
    );
    expect(android, contains('android:name="flutter_deeplinking_enabled"'));
    expect(android, contains('android:value="false"'));

    final ios = await File('ios/Runner/Info.plist').readAsString();
    expect(ios, contains('<string>stepbound</string>'));
    expect(ios, contains('<key>FlutterDeepLinkingEnabled</key>'));
    expect(ios, contains('<false/>'));
  });

  test('device storage keeps linked skins independent of save slots', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final repository = PreferencesOutfitUnlockRepository(
      preferences: SharedPreferencesAsync(),
    );

    await repository.unlock(PlayerOutfit.ghost);
    await repository.unlock(PlayerOutfit.zombie);
    await repository.unlock(PlayerOutfit.ghost);

    expect(await repository.load(), <PlayerOutfit>{
      PlayerOutfit.ghost,
      PlayerOutfit.zombie,
    });
  });

  testWidgets('a cold-start link is persisted and announced in the menu', (
    tester,
  ) async {
    final unlocks = MemoryOutfitUnlockRepository();
    await tester.pumpWidget(
      StepboundApp(
        saves: MemorySaveRepository(),
        outfitUnlocks: unlocks,
        skinLinks: Stream<Uri>.value(
          outfitUnlockLink(PlayerOutfit.jackOLantern),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Hai ottenuto la skin Jack-o’-lantern'), findsOneWidget);
    expect(
      find.text(
        'Quando avrai sbloccato nella trama la possibilità di cambiare '
        'abbigliamento troverai anche questa nuova opzione',
      ),
      findsOneWidget,
    );
    expect(unlocks.unlocked, contains(PlayerOutfit.jackOLantern));
  });

  testWidgets('a warm link returns to the main menu and shows its name', (
    tester,
  ) async {
    final links = StreamController<Uri>();
    addTearDown(links.close);
    await tester.pumpWidget(
      StepboundApp(
        saves: MemorySaveRepository(),
        outfitUnlocks: MemoryOutfitUnlockRepository(),
        skinLinks: links.stream,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('menu-new-game')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('menu-slot-1')), findsOneWidget);

    links.add(outfitUnlockLink(PlayerOutfit.vampire));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('main-menu')), findsOneWidget);
    expect(find.text('Hai ottenuto la skin Vampiro'), findsOneWidget);
  });

  testWidgets('linked skins are merged into an existing save', (tester) async {
    final saves = MemorySaveRepository();
    await saves.save(
      SaveGame(
        slot: 1,
        savedAt: DateTime(2026),
        place: 'Dietro la caserma',
        world: saveGameWorld(createGameWorld()),
        story: const <String, Object?>{},
        progress: Progress.newGame().toJson(),
        hud: const <String>[],
      ),
    );
    await tester.pumpWidget(
      StepboundApp(
        saves: saves,
        outfitUnlocks: MemoryOutfitUnlockRepository(const <PlayerOutfit>[
          PlayerOutfit.zombie,
        ]),
      ),
    );
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
    expect(game.progress.unlockedOutfits, contains(PlayerOutfit.zombie));
    expect(
      game.progress.unlockedOutfits,
      isNot(contains(PlayerOutfit.cultist)),
      reason: 'the link does not skip the Duomo story unlock',
    );
  });
}
