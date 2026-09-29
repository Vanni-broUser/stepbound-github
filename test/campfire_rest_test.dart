import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/campfire_rest.dart';
import 'package:stepbound/game/cover_controller.dart';
import 'package:stepbound/game/game_cover.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/report/breadcrumbs.dart';

void main() {
  late Progress progress;
  late CoverController covers;
  late List<String> saved;
  late List<GridPoint> kneels;
  late Breadcrumbs trail;
  late Future<bool>? Function(String place) checkpoint;
  late CampfireRest rest;

  final fire = campfireNames.keys.firstWhere(
    (tile) => !trainFoodTiles.contains(tile),
  );
  final table = trainFoodTiles.first;

  setUp(() {
    progress = Progress.newGame();
    covers = CoverController(onShow: () {}, progress: progress);
    saved = <String>[];
    kneels = <GridPoint>[];
    trail = Breadcrumbs();
    checkpoint = (place) {
      saved.add(place);
      return Future<bool>.value(true);
    };
    rest = CampfireRest(
      progress: progress,
      covers: covers,
      checkpoint: (place) => checkpoint(place),
      onKneel: kneels.add,
      placeName: () => 'Dietro la caserma',
      trail: trail,
    );
  });

  tearDown(() => covers.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('Mario kneels, the fire is lit, and the save waits for the rest', () {
    rest.restAt(fire);
    expect(rest.resting, isTrue);
    expect(rest.atTable, isFalse);
    expect(kneels, <GridPoint>[fire]);
    expect(progress.litCampfires, <String>{campfireNames[fire]!});
    rest.update(CharacterComponent.restDuration / 2);
    expect(saved, isEmpty, reason: 'still kneeling');
  });

  test('once the rest is over the game is saved and a line says so', () async {
    rest
      ..restAt(fire)
      ..update(CharacterComponent.restDuration);
    await settle();
    expect(saved, <String>[campfireNames[fire]!]);
    expect(
      covers.cover.value,
      isA<PromptCover>().having(
        (c) => c.lines.single.text,
        'line',
        CampfireRest.savedLine,
      ),
    );
    expect(rest.resting, isTrue, reason: 'until the line is gone');
    rest.update(1);
    await settle();
    expect(saved, hasLength(1), reason: 'saved once');
    covers.dismissPrompt();
    expect(rest.resting, isFalse);
  });

  test(
    'at the table nobody kneels, no fire is lit, and the save is aboard',
    () async {
      rest
        ..restAt(table)
        ..update(CharacterComponent.restDuration);
      await settle();
      expect(rest.atTable, isTrue);
      expect(kneels, isEmpty);
      expect(progress.litCampfires, isEmpty);
      expect(saved, <String>[campfireNames[table]!]);
    },
  );

  test(
    'a save that is not written says so, and the fire can be used again',
    () async {
      checkpoint = (place) => Future<bool>.value(false);
      rest
        ..restAt(fire)
        ..update(CharacterComponent.restDuration);
      await settle();
      expect(
        covers.cover.value,
        isA<SaveFailedCover>().having(
          (c) => c.line,
          'line',
          CampfireRest.saveFailedLine,
        ),
      );
      expect(
        trail.entries.single.text,
        'salvataggio non riuscito: Dietro la caserma',
      );
      covers.dismissSaveFailed();
      expect(rest.resting, isFalse);
      checkpoint = (place) {
        saved.add(place);
        return Future<bool>.value(true);
      };
      rest
        ..restAt(fire)
        ..update(CharacterComponent.restDuration);
      await settle();
      expect(saved, <String>[campfireNames[fire]!]);
    },
  );

  test('at the table the failed save names the table', () async {
    checkpoint = (place) => throw StateError('disk full');
    rest
      ..restAt(table)
      ..update(CharacterComponent.restDuration);
    await settle();
    expect(
      (covers.cover.value! as SaveFailedCover).line,
      CampfireRest.mealSaveFailedLine,
    );
  });

  test('with nowhere to save to, the rest still ends well', () async {
    checkpoint = (place) => null;
    rest
      ..restAt(fire)
      ..update(CharacterComponent.restDuration);
    await settle();
    expect(covers.cover.value, isA<PromptCover>());
  });
}
