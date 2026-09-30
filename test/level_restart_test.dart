import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/game_session.dart';
import 'package:stepbound/game/level_restart.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/test_scenarios.dart';
import 'package:stepbound/save/save_game.dart';

/// Starting a level over starts over only the city it is played in.
void main() {
  late MemorySaveRepository saves;
  late GameSession session;

  setUp(() {
    saves = MemorySaveRepository();
    session = GameSession(
      saves: saves,
      audio: SilentAudio(),
      onLevelCompleted: (_, {required saved}) {},
      onTravelMapRequested: (_) {},
    );
  });

  GameSnapshot game(void Function(ScenarioBuilder story) build) {
    final save = TestScenario('prova', build).save(1);
    return (
      world: save.world,
      story: save.story,
      progress: save.progress,
      hud: save.hud,
      place: save.place,
    );
  }

  /// Molfetta played, then Rome: a backpack and the grappling hook found,
  /// Tonino and Marcello met, a zombie type met there and the wanderers,
  /// known from Molfetta, seen there too.
  void molfettaThenRome(ScenarioBuilder story) {
    story
      ..collect(ammoBackpackId)
      ..remember(StoryMemory.luigiAtStation)
      ..unlock(HudElement.molotov);
    story.progress
      ..meet(EntityKind.wanderer)
      ..unlockOutfit(PlayerOutfit.cultist)
      ..steps[LevelId.hometown] = 100;
    story
      ..travelTo(LevelId.rome)
      ..collect(terminiRubbishBackpackId)
      ..collect(grapplingHookPickupId)
      ..unlock(HudElement.grapplingHook)
      ..remember(StoryMemory.maranzaMet)
      ..script('rome', <String, Object?>{'welcomed': true})
      ..script('maranza', <String, Object?>{'met': true})
      ..script('journey', <String, Object?>{'taught': true})
      ..missions(done: const <Mission>[Mission.findSupplies]);
    story.progress
      ..meet(EntityKind.sprinter)
      ..meet(EntityKind.wanderer)
      ..steps[LevelId.rome] = 40;
    story.world.player.component<AmmoComponent>()
      ..loaded = 9
      ..hasGun = true
      ..grapplingHook = true;
    story.progress.activeOutfit = PlayerOutfit.cultist;
  }

  AmmoComponent ammoOf(StepboundGame game) =>
      game.simulation.player.component<AmmoComponent>();

  group('Molfetta started over after Rome', () {
    late StepboundGame molfetta;
    late SaveGame start;

    setUp(() async {
      final back = game((story) {
        molfettaThenRome(story);
        story.travelTo(LevelId.hometown);
      });
      session.slot = 1;
      expect(await session.saveLevelStart(current: back), isTrue);
      start = (await saves.load(1))!;
      molfetta = session.newGame();
    });

    /// The game as it is now, the story as the start of the level left it.
    GameSnapshot now(StepboundGame game, {String place = 'Porto'}) => (
      world: saveGameWorld(game.simulation),
      story: start.story,
      progress: game.progress.toJson(),
      hud: <String>[for (final badge in game.hud.value) badge.name],
      place: place,
    );

    test('starts with nothing, and none of Rome to be seen', () {
      final progress = molfetta.progress;
      expect(progress.level, LevelId.hometown);
      expect(progress.visited(LevelId.rome), isFalse);
      expect(progress.memories, isNot(contains(StoryMemory.maranzaMet)));
      expect(progress.memories, isNot(contains(StoryMemory.luigiAtStation)));
      expect(progress.missions.isDone(Mission.findSupplies), isFalse);
      expect(progress.knownZombies, isEmpty);
      expect(progress.unlockedOutfits, <PlayerOutfit>{PlayerOutfit.base});
      expect(progress.steps, isEmpty);
      final ammo = ammoOf(molfetta);
      expect(ammo.grapplingHook, isFalse);
      expect(ammo.hasGun, isFalse);
      expect(ammo.loaded, 0);
      expect(molfetta.hud.value, isEmpty);
      expect(molfetta.simulation.pickups[ammoBackpackId]!.collected, isFalse);
      expect(start.story.containsKey('station'), isFalse);
    });

    test('leaves Rome itself as it was', () {
      final pickups = molfetta.simulation.pickups;
      expect(pickups[terminiRubbishBackpackId]!.collected, isTrue);
      expect(pickups[grapplingHookPickupId]!.collected, isTrue);
      expect(start.story['maranza'], containsPair('met', true));
      expect(start.story['journey'], containsPair('taught', true));
    });

    test('gives Rome back once Luigi is reached, and Rome is as it was, the '
        'golden pistol won meanwhile with it', () async {
      molfetta.progress.secretMissions.add(SecretMission.unarmedToLuigi);
      final badges = <HudElement>{};
      handBackHeldAway(molfetta.progress, molfetta.simulation, badges.add);
      final progress = molfetta.progress;
      expect(progress.heldAway, isNull);
      expect(progress.visited(LevelId.rome), isTrue);
      expect(progress.memories, contains(StoryMemory.maranzaMet));
      expect(progress.missions.isDone(Mission.findSupplies), isTrue);
      expect(progress.knownZombies, contains(EntityKind.sprinter));
      expect(progress.knowsIn(EntityKind.wanderer, LevelId.rome), isTrue);
      expect(
        progress.knowsIn(EntityKind.wanderer, LevelId.hometown),
        isFalse,
        reason: 'Molfetta, started over, has not met one yet',
      );
      expect(progress.steps[LevelId.rome], 40);
      expect(ammoOf(molfetta).grapplingHook, isTrue);
      expect(badges, <HudElement>{HudElement.grapplingHook});

      final rome = session.startLevel(
        LevelId.rome,
        now(molfetta, place: trainPlaceName),
      );
      expect(ammoOf(rome).loaded, 9, reason: 'the rounds left in Rome');
      expect(ammoOf(rome).grapplingHook, isTrue);
      // The robe is Molfetta's: not found again there, it is not his in
      // Rome either.
      expect(rome.progress.unlockedOutfits, <PlayerOutfit>{PlayerOutfit.base});
      expect(rome.progress.activeOutfit, PlayerOutfit.base);
      expect(rome.progress.hasGoldenPistol, isTrue);
      expect(
        rome.simulation.pickups[terminiRubbishBackpackId]!.collected,
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await saves.load(1))!.story['maranza'],
        containsPair('met', true),
      );
    });

    test("keeps what Mario carries for Rome's errands, out of sight, and "
        "drops Molfetta's", () async {
      final back = game((story) {
        molfettaThenRome(story);
        story
          ..collect(bankIngotBackpackId)
          ..unlock(HudElement.goldIngot)
          ..travelTo(LevelId.hometown)
          ..unlock(HudElement.barKey);
      });
      await session.saveLevelStart(current: back);
      final again = session.newGame();
      expect(
        again.hud.value,
        unorderedEquals(<HudElement>[HudElement.goldIngot]),
      );
      expect(
        again.simulation.pickups[bankIngotBackpackId]!.collected,
        isTrue,
        reason: 'Rome is as it was: the vault is empty',
      );
    });

    test('keeps it all held away through a second restart', () async {
      await session.saveLevelStart(current: now(molfetta));
      final again = session.newGame();
      expect(again.progress.memories, isEmpty);
      handBackHeldAway(again.progress, again.simulation, (_) {});
      expect(again.progress.memories, contains(StoryMemory.maranzaMet));
      expect(ammoOf(again).grapplingHook, isTrue);
    });
  });

  group('Rome started over', () {
    late GameSnapshot inRome;

    setUp(() {
      inRome = game((story) {
        molfettaThenRome(story);
        story.restAt(piazzaCampfireTile);
      });
    });

    test('goes back to the arrival, as the first time', () {
      final restarted = restartCity(inRome);
      final progress = restarted.progress;
      final world = restoreGameWorld(restarted.world);
      expect(progress.level, LevelId.rome);
      expect(
        world.player.component<PositionComponent>().position,
        trainMapStandTile,
      );
      final ammo = world.player.component<AmmoComponent>();
      expect(ammo.loaded, arrivalRounds);
      expect(ammo.grapplingHook, isFalse);
      expect(restarted.hud, isNot(contains(HudElement.grapplingHook.name)));
      expect(world.pickups[terminiRubbishBackpackId]!.collected, isFalse);
      expect(world.pickups[grapplingHookPickupId]!.collected, isFalse);
      expect(restarted.story.containsKey('maranza'), isFalse);
      expect(restarted.story.containsKey('rome'), isFalse);
      expect(restarted.story['journey'], containsPair('taught', true));
      expect(progress.memories, isNot(contains(StoryMemory.maranzaMet)));
      expect(progress.memories, contains(StoryMemory.presidentFled));
      expect(progress.missions.isOpen(Mission.findSupplies), isFalse);
      expect(progress.missions.isDone(Mission.findSupplies), isFalse);
      expect(progress.knownZombies, isNot(contains(EntityKind.sprinter)));
      expect(progress.knowsIn(EntityKind.wanderer, LevelId.rome), isFalse);
      expect(progress.steps[LevelId.rome], isNull);
      expect(progress.litCampfires, isEmpty);
    });

    test("takes Rome's errand things away with its backpacks and story, "
        "not Molfetta's", () {
      final restarted = restartCity(
        game((story) {
          molfettaThenRome(story);
          story
            ..unlock(HudElement.barKey)
            ..unlock(HudElement.goldIngot)
            ..unlock(HudElement.colosseumTicket)
            ..restAt(piazzaCampfireTile);
        }),
      );
      expect(restarted.hud, isNot(contains(HudElement.goldIngot.name)));
      expect(restarted.hud, isNot(contains(HudElement.colosseumTicket.name)));
      expect(restarted.hud, contains(HudElement.barKey.name));
      final world = restoreGameWorld(restarted.world);
      expect(world.pickups[bankIngotBackpackId]!.collected, isFalse);
    });

    test('leaves Molfetta as it was', () async {
      final restarted = restartCity(inRome);
      final progress = restarted.progress;
      final world = restoreGameWorld(restarted.world);
      expect(world.pickups[ammoBackpackId]!.collected, isTrue);
      expect(progress.memories, contains(StoryMemory.luigiAtStation));
      expect(progress.knowsIn(EntityKind.wanderer, LevelId.hometown), isTrue);
      expect(progress.unlockedOutfits, contains(PlayerOutfit.cultist));
      expect(progress.steps[LevelId.hometown], 100);
      expect(restarted.hud, contains(HudElement.molotov.name));
      // Molfetta's pistol and robe stay his, and the robe on him.
      expect(world.player.component<AmmoComponent>().hasGun, isTrue);
      expect(progress.activeOutfit, PlayerOutfit.cultist);

      session.slot = 1;
      final rome = await session.restartCityLevel(inRome);
      final saved = (await saves.load(1))!;
      expect(saved.place, GameSession.levelStartPlace);
      final home = session.startLevel(LevelId.hometown, (
        world: saveGameWorld(rome.simulation),
        story: saved.story,
        progress: rome.progress.toJson(),
        hud: saved.hud,
        place: trainPlaceName,
      ));
      expect(home.simulation.pickups[ammoBackpackId]!.collected, isTrue);
      expect(home.progress.memories, contains(StoryMemory.luigiAtStation));
      // The grappling hook is Rome's: straight back home, Mario has not got
      // it, and its badge is gone, until he has picked it up in Rome again.
      expect(ammoOf(home).grapplingHook, isFalse);
      expect(home.hud.value, isNot(contains(HudElement.grapplingHook)));
    });
  });
}
