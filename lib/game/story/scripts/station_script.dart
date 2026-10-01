import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// The station, where Luigi said he would wait. Getting to him is the
/// whole of it: the doorway onto the platform leads to a dead end behind
/// the derailed train, and only the other one, through the underpass,
/// comes out on the far side. Once Luigi has been rescued, taking the
/// first step on that platform plays their meeting, and that is the end of
/// the level: Mario is aboard, at the map table in the locomotive, and
/// the game is saved there.
final class StationScript extends StoryScript {
  StationScript(super.director);

  static const String luigi = 'Luigi Rovaga';
  static const String platformScene = 'assets/story/scenes/station_luigi.jpg';
  static const String planScene = 'assets/story/scenes/station_plan.jpg';
  static const String northCapeScene =
      'assets/story/scenes/station_north_cape.jpg';
  static const String goldenPistolScene =
      'assets/story/scenes/station_golden_pistol.jpg';
  static String get lockedDoorLine => strings.stationLockedDoorLine;

  /// Luigi finds Mario came all this way with no gun: after the reunion,
  /// only then (see [SecretMission.unarmedToLuigi]). The memory keeps his
  /// words; the line on what the pistol does is said once, there.
  static CutsceneFrame get goldenPistolGift => CutsceneFrame(
    image: goldenPistolScene,
    speaker: luigi,
    text: strings.stationGoldenPistolGift,
  );
  static CutsceneFrame get goldenPistolLesson => CutsceneFrame(
    image: goldenPistolScene,
    text: strings.stationGoldenPistolLesson,
  );

  /// Luigi leaning out of the cab of the one train still in one piece.
  static List<CutsceneFrame> get reunionScene => <CutsceneFrame>[
    CutsceneFrame(
      image: platformScene,
      speaker: luigi,
      text: strings.stationReunionScene1,
    ),
    CutsceneFrame(
      image: planScene,
      speaker: 'Mario Rossi',
      text: strings.stationReunionScene2,
    ),
    CutsceneFrame(
      image: planScene,
      speaker: luigi,
      text: strings.stationReunionScene3,
    ),
    CutsceneFrame(
      image: planScene,
      speaker: 'Mario Rossi',
      text: strings.stationReunionScene4,
    ),
    CutsceneFrame(
      image: northCapeScene,
      speaker: luigi,
      text: strings.stationReunionScene5,
    ),
    CutsceneFrame(
      image: northCapeScene,
      speaker: luigi,
      text: strings.stationReunionScene6,
    ),
  ];

  bool _reunionPlayed = false;
  bool _steppedOnPlatform = false;

  /// Whether this attempt ended with the golden pistol handed over: the
  /// results screen crosses the secret mission out with the level's.
  bool _goldenPistolGiven = false;

  /// Whether the level just completed from [story] (a save's story state)
  /// handed the golden pistol over.
  static bool gaveGoldenPistol(Map<String, Object?> story) =>
      (story['station'] as Map<String, Object?>?)?['goldenPistol'] == true;

  @override
  String get key => 'station';

  /// The portal itself only gives Mario time to take in the platform. The
  /// meeting becomes eligible on his first proper step after arriving,
  /// and only if Luigi was rescued from the hypermarket first.
  @override
  void onEvent(WorldEvent event) {
    if (event case NoInteractionEvent(:final at)
        when at == stationTrainDoorTile &&
            !progress.hasExperienced(StoryMemory.luigiRescued)) {
      say(StoryPrompt(<StoryLine>[StoryLine(lockedDoorLine)]));
      return;
    }
    if (!progress.hasExperienced(StoryMemory.luigiRescued)) {
      return;
    }
    if (event case TravelMapUsedEvent(:final at)
        when trainMapTiles.contains(at) &&
            progress.hasExperienced(StoryMemory.luigiAtStation)) {
      host.openTravelMap();
      return;
    }
    if (event case MovedEvent(
      entityId: final id,
      :final to,
    ) when id == world.playerId && stationPlatform.contains(to)) {
      _steppedOnPlatform = true;
    }
  }

  @override
  void update({required bool turnAnimating}) {
    if (_reunionPlayed ||
        !_steppedOnPlatform ||
        !progress.hasExperienced(StoryMemory.luigiRescued) ||
        turnAnimating ||
        host.isPromptVisible) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (!stationPlatform.contains(position)) {
      return;
    }
    _reunionPlayed = true;
    // Here without ever having picked the pistol up: rounds or not, Luigi
    // hands over his golden one.
    final unarmed = !world.player.component<AmmoComponent>().hasGun;
    host.playCutscene(
      <CutsceneFrame>[
        ...reunionScene,
        if (unarmed) ...<CutsceneFrame>[goldenPistolGift, goldenPistolLesson],
      ],
      memories: <StoryMemory>{
        StoryMemory.luigiAtStation,
        if (unarmed) StoryMemory.goldenPistol,
      },
      stayBlack: true,
      music: Music.luigi,
      onFinished: () {
        if (unarmed) {
          _giveGoldenPistol();
        }
        _board();
      },
    );
  }

  /// The secret mission done: the pistol is Mario's from now on, golden,
  /// and so is what it takes to fire it.
  void _giveGoldenPistol() {
    _goldenPistolGiven = true;
    progress.secretMissions.add(SecretMission.unarmedToLuigi);
    world.player.component<AmmoComponent>().hasGun = true;
    host
      ..unlock(HudElement.ammo)
      ..unlock(HudElement.shoot);
  }

  /// Behind the black the scene ends on, Mario gets on the train and
  /// stands at the map table: that is where the save puts him, and where the
  /// game picks up again when the map sends him back home.
  /// Luigi has been reached: that mission is crossed out on the results
  /// screen, since the level ends here.
  void _board() {
    progress.missions.complete(Mission.reachLuigi);
    world.player.component<PositionComponent>()
      ..position = trainMapStandTile
      ..facing = trainArrivalFacing;
    host.completeLevel();
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'reunion': _reunionPlayed,
    'goldenPistol': _goldenPistolGiven,
  };

  @override
  void restore(Map<String, Object?> json) {
    _reunionPlayed = json['reunion'] as bool? ?? false;
    _goldenPistolGiven = json['goldenPistol'] as bool? ?? false;
  }
}
