import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/ui/zombie_book.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  group('station', () {
    /// The far platform, in front of the train Luigi is waiting in.
    GridPoint onTheFarPlatform() => GridPoint(
      (stationPlatform.left + stationPlatform.right) ~/ 2,
      stationPlatform.bottom,
    );

    void takeAPlatformStep() {
      final to = onTheFarPlatform();
      world.player.component<PositionComponent>().position = to;
      director.onEvents(<WorldEvent>[
        MovedEvent(
          entityId: world.playerId,
          from: to.step(Direction.west),
          to: to,
        ),
      ]);
      settle();
    }

    test('before Luigi is rescued, the passenger door says it is locked', () {
      director.onEvents(<WorldEvent>[NoInteractionEvent(stationTrainDoorTile)]);
      settle();
      expect(host.shown.single.single.text, StationScript.lockedDoorLine);
      expect(StationScript.lockedDoorLine, 'La porta è chiusa');
    });

    test('after Luigi is rescued, his meeting waits for the first step', () {
      progress.remember(StoryMemory.luigiRescued);
      world.player.component<AmmoComponent>().hasGun = true;
      world.player.component<PositionComponent>().position = onTheFarPlatform();
      settle();
      expect(
        host.cutscenes,
        isEmpty,
        reason: 'arriving through the stairs leaves time to see the map',
      );

      takeAPlatformStep();
      expect(host.shown, isEmpty, reason: 'the picture comes first');
      final scene = host.cutscenes.single;
      expect(scene, StationScript.reunionScene);
      expect(host.cutsceneMusic.single, Music.luigi);
      expect(scene, hasLength(6));
      final frame = scene.first;
      expect(frame.speaker, StationScript.luigi);
      expect(frame.text, "Eccoti ragazzo, ce l'hai fatta finalmente!");
      expect(frame.image, StationScript.platformScene);
      expect(scene[1].image, StationScript.planScene);
      expect(scene[4].text, 'La nostra meta é Capo Nord ragazzo. In Norvegia');
      expect(scene[4].image, StationScript.northCapeScene);
      expect(
        host.cutsceneStaysBlack,
        isTrue,
        reason: 'the level ends behind it, not back on the platform',
      );
      expect(progress.memories, contains(StoryMemory.luigiAtStation));
      expect(host.levelsCompleted, 0, reason: 'not before the scene is over');

      expect(progress.missions.isDone(Mission.reachLuigi), isFalse);
      host.onCutsceneFinished?.call();
      expect(host.levelsCompleted, 1);
      expect(
        progress.missions.isDone(Mission.reachLuigi),
        isTrue,
        reason: 'done before the level is saved, for its results',
      );
      final mario = world.player.component<PositionComponent>();
      expect(
        mario.position,
        trainMapStandTile,
        reason: 'the save, and the way back home, find him at the map',
      );
      expect(mario.facing, trainArrivalFacing, reason: 'away from the map');
      expect(
        trainMapTiles,
        isNot(contains(mario.position.step(mario.facing))),
        reason: 'a stray tap does not open the map again',
      );
      director.onEvents(<WorldEvent>[
        TravelMapUsedEvent(at: trainMapTiles.last),
      ]);
      expect(host.travelMapsOpened, 1);
      expect(host.levelsCompleted, 1);
      settle();
      expect(
        host.cutscenes,
        hasLength(1),
        reason: 'walking the platform again does not play it twice',
      );
    });

    test('reaching Luigi without ever picking the pistol up, rounds or '
        'not, he hands over the golden one: the secret mission is done', () {
      progress.remember(StoryMemory.luigiRescued);
      world.player.component<AmmoComponent>()
        ..hasGun = false
        ..loaded = 3;
      takeAPlatformStep();

      final scene = host.cutscenes.single;
      expect(scene, <CutsceneFrame>[
        ...StationScript.reunionScene,
        StationScript.goldenPistolGift,
        StationScript.goldenPistolLesson,
      ]);
      expect(StationScript.goldenPistolGift.speaker, 'Luigi Rovaga');
      expect(
        StationScript.goldenPistolGift.text,
        "Ei ma non hai nessun'arma con te? Tieni prendi questa",
      );
      expect(StationScript.goldenPistolLesson.speaker, isNull);
      expect(
        StationScript.goldenPistolLesson.text,
        "La pistola d'oro infligge danni doppi",
      );
      expect(progress.hasExperienced(StoryMemory.goldenPistol), isTrue);
      expect(progress.hasGoldenPistol, isFalse, reason: 'not before the end');

      host.onCutsceneFinished?.call();
      expect(progress.hasGoldenPistol, isTrue);
      expect(world.player.component<AmmoComponent>().hasGun, isTrue);
      expect(
        host.unlocked,
        containsAll(<HudElement>[HudElement.ammo, HudElement.shoot]),
      );
      expect(host.levelsCompleted, 1);
      expect(
        StationScript.gaveGoldenPistol(director.toJson()),
        isTrue,
        reason: 'the results screen crosses the secret out',
      );
      // Its memory keeps Luigi's words, not the line on the pistol.
      expect(
        memoryScenes[StoryMemory.goldenPistol]!.map((scene) => scene.text),
        <String>[StationScript.goldenPistolGift.text],
      );
    });

    test('aboard, Luigi talks, the books hold the zombie types and the '
        'cot the memories, as often as asked', () {
      for (var i = 0; i < 2; i++) {
        director.onEvents(<WorldEvent>[LookedOutEvent(at: trainLuigiTile)]);
        settle();
        final line = host.shown.last.single;
        expect(line.speaker, 'Luigi Rovaga');
        expect(line.portrait, 'assets/characters/npcs/portraits/luigi.png');
        expect(line.text, "Sarà un viaggio per l'Europa molto impegnativo");
        host.dismiss();
      }
      expect(host.shown, hasLength(2));

      for (final (index, book) in trainBookTiles.indexed) {
        director.onEvents(<WorldEvent>[LookedOutEvent(at: book)]);
        settle();
        expect(host.shown.last.single.text, 'Appunti sugli zombi conosciuti');
        expect(host.zombieBooksOpened, index, reason: 'not before the line');
        host.dismiss();
        expect(host.zombieBooksOpened, index + 1);
      }
      expect(trainBookTiles, hasLength(3), reason: 'the whole desk');
      // The wardrobe, then the outfits to choose from.
      director.onEvents(<WorldEvent>[
        LookedOutEvent(at: trainWardrobeTiles.first),
      ]);
      settle();
      expect(
        host.shown.last.single.text,
        'Scegli quale abbigliamento indossare',
      );
      expect(host.wardrobesOpened, 0, reason: 'not before the line');
      host.dismiss();
      expect(host.wardrobesOpened, 1);
      // The cot opens the figures of the adventure, the memories among
      // them.
      director.onEvents(<WorldEvent>[LookedOutEvent(at: trainCotTiles.first)]);
      settle();
      expect(host.shown.last.single.text, TrainScript.cotLine);
      expect(host.adventureStatsOpened, 0, reason: 'not before the line');
      host.dismiss();
      expect(host.adventureStatsOpened, 1);
    });

    test('the ammunition crate loads Mario up to five rounds, as often as '
        'he has fewer, and says there is nothing to take when he has five '
        'or more', () {
      final ammo = world.player.component<AmmoComponent>()..loaded = 2;
      director.onEvents(<WorldEvent>[LookedOutEvent(at: trainAmmoTiles.first)]);
      settle();
      expect(ammo.loaded, trainAmmoRefill);
      expect(host.shown.last.single.text, TrainScript.ammoRefilled);
      expect(
        TrainScript.ammoRefilled,
        'Munizioni ricaricate. Torna qui in qualsiasi momento se hai meno '
        'di 5 proiettili per ricaricare',
      );
      expect(host.unlocked, contains(HudElement.ammo));
      host.dismiss();

      director.onEvents(<WorldEvent>[LookedOutEvent(at: trainAmmoTiles.last)]);
      settle();
      expect(ammo.loaded, trainAmmoRefill);
      expect(host.shown.last.single.text, TrainScript.ammoFull);
      expect(
        TrainScript.ammoFull,
        'Hai già abbastanza munizioni. Torna qui quando avrai meno di 5 '
        'proiettili per ricaricare',
      );
      host.dismiss();

      ammo.loaded = 7;
      director.onEvents(<WorldEvent>[LookedOutEvent(at: trainAmmoTiles.first)]);
      settle();
      expect(ammo.loaded, 7, reason: 'more than five are never taken away');
      expect(host.shown.last.single.text, TrainScript.ammoFull);
      host.dismiss();

      ammo.loaded = 0;
      director.onEvents(<WorldEvent>[LookedOutEvent(at: trainAmmoTiles.first)]);
      settle();
      expect(ammo.loaded, trainAmmoRefill, reason: 'as often as needed');
      expect(host.shown.last.single.text, TrainScript.ammoRefilled);
    });

    test('the meeting cannot happen before Luigi has been rescued', () {
      takeAPlatformStep();
      expect(host.cutscenes, isEmpty);
      expect(progress.memories, isNot(contains(StoryMemory.luigiAtStation)));
      director.onEvents(<WorldEvent>[
        TravelMapUsedEvent(at: trainMapPanelTile),
      ]);
      expect(host.travelMapsOpened, 0);
      expect(host.levelsCompleted, 0);
    });

    test('nothing plays anywhere short of that platform', () {
      progress.remember(StoryMemory.luigiRescued);
      world.player.component<PositionComponent>().position = place(
        PlaceId.station,
      ).doorRow('E').first;
      settle();
      expect(host.cutscenes, isEmpty);
      expect(progress.memories, isNot(contains(StoryMemory.luigiAtStation)));
    });

    test('a save taken after it does not play it again on the way back', () {
      progress.remember(StoryMemory.luigiRescued);
      takeAPlatformStep();
      expect(host.cutscenes, hasLength(1));

      final resumed = StoryDirector(
        world: world,
        host: host,
        progress: progress,
      )..restore(director.toJson());
      for (var i = 0; i < 20; i++) {
        resumed.update(0.1, turnAnimating: false);
      }
      expect(host.cutscenes, hasLength(1));
    });
  });
}
