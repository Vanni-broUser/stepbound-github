import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/game_session.dart';
import 'package:stepbound/game/missions.dart';
import 'package:stepbound/game/zombie_lore.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/l10n/language_setting.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/pause_menu.dart';

void main() {
  tearDown(() => Language.current.value = Language.italian);

  group('Language', () {
    test('each has its own code, found again by it', () {
      final codes = <String>{for (final l in Language.values) l.code};
      expect(codes, hasLength(Language.values.length));
      for (final language in Language.values) {
        expect(Language.byCode(language.code), language);
        expect(Language.byCode(language.code.toUpperCase()), language);
      }
      expect(Language.byCode('xx'), isNull);
      expect(Language.byCode(null), isNull);
    });

    test('the switch goes through them all and back to the first', () {
      var language = Language.values.first;
      final seen = <Language>[];
      for (var i = 0; i < Language.values.length; i++) {
        seen.add(language);
        language = language.next;
      }
      expect(seen, Language.values);
      expect(language, Language.values.first);
    });

    test('the game speaks the language picked', () {
      expect(Mission.findSurvivors.text, 'Trova altri sopravvissuti');
      Language.current.value = Language.english;
      expect(Mission.findSurvivors.text, 'Find other survivors');
      expect(ResumePoint.campfire.resumeLabel, 'RESUME FROM THE CAMPFIRE');
      expect(zombieLore[EntityKind.wanderer]!.name, 'Wanderer');
    });

    test('every language names every zombie and teaches it', () {
      for (final language in Language.values) {
        for (final kind in zombieLore.keys) {
          final words = language.strings;
          expect(words.zombieName(kind), isNotEmpty, reason: '$language');
          expect(words.zombieLesson(kind), isNotEmpty, reason: '$language');
          expect(
            words.zombieDescription(kind),
            isNotEmpty,
            reason: '$language',
          );
        }
        expect(
          language.strings.zombieName(EntityKind.blind),
          isNotEmpty,
          reason: 'the card still to come',
        );
      }
    });

    test('every language but Italian says every place name the game can '
        'show, proper names included', () {
      final names = <String>{
        for (final place in gamePlaces) ?place.name,
        ...campfireNames.values,
        trainPlaceName,
        GameSession.levelStartPlace,
        // The level's own name, where a place has none.
        'Città natale',
        'Roma',
      };
      expect(Language.italian.strings.placeNames, isEmpty);
      for (final language in Language.values) {
        if (language == Language.italian) {
          continue;
        }
        final missing = names.difference(
          language.strings.placeNames.keys.toSet(),
        );
        expect(missing, isEmpty, reason: '${language.code} lacks them');
      }
    });

    test('a place Italian names itself stays as it is', () {
      expect(strings.place('Sagrato del Duomo'), 'Sagrato del Duomo');
      Language.current.value = Language.english;
      expect(strings.place('Sagrato del Duomo'), 'Duomo churchyard');
      expect(strings.place('Nowhere'), 'Nowhere');
    });
  });

  group('LanguageSetting', () {
    late InMemorySharedPreferencesAsync store;
    late LanguageSetting setting;

    setUp(() {
      store = InMemorySharedPreferencesAsync.empty();
      SharedPreferencesAsyncPlatform.instance = store;
      setting = LanguageSetting();
    });

    tearDown(() => setting.dispose());

    test(
      'without a choice, the phone language when the game speaks it',
      () async {
        await setting.load(const Locale('en', 'GB'));
        expect(Language.current.value, Language.english);
      },
    );

    test('a phone language the game does not speak gets the original, '
        'Italian', () async {
      await setting.load(const Locale('ja'));
      expect(Language.current.value, Language.italian);
      expect(Language.fallback, Language.italian);
    });

    test('the language picked is kept, and wins over the phone', () async {
      await setting.load(const Locale('it'));
      Language.current.value = Language.english;
      await pumpEventQueue();
      setting.dispose();

      Language.current.value = Language.italian;
      setting = LanguageSetting();
      await setting.load(const Locale('it'));
      expect(Language.current.value, Language.english);
    });
  });

  testWidgets('the switch between the audio and the credits changes every '
      'word of the menu', (tester) async {
    await tester.pumpWidget(
      StepboundApp(saves: MemorySaveRepository(), audio: SilentAudio()),
    );
    await tester.pump();
    final audio = tester.getCenter(
      find.byKey(const ValueKey<String>('menu-audio')),
    );
    final language = find.byKey(const ValueKey<String>('menu-language'));
    final credits = tester.getCenter(
      find.byKey(const ValueKey<String>('menu-credits')),
    );
    expect(tester.getCenter(language).dx, greaterThan(audio.dx));
    expect(tester.getCenter(language).dx, lessThan(credits.dx));
    expect(find.text('IT'), findsOneWidget);
    expect(find.text('NUOVA PARTITA'), findsOneWidget);
    expect(find.text(MainMenu.disclaimer), findsOneWidget);

    await tester.tap(language);
    await tester.pump();
    expect(Language.current.value, Language.english);
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('NEW GAME'), findsOneWidget);
    expect(find.text('CREDITS'), findsOneWidget);
    expect(find.text(Language.english.strings.menuDisclaimer), findsOneWidget);

    await tester.tap(language);
    await tester.pump();
    expect(Language.current.value, Language.italian);
    expect(find.text('NUOVA PARTITA'), findsOneWidget);
  });
}
