import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// Conversations inside the Duomo. All of them are triggered by facing the
/// person and using the interaction button, and therefore carry a portrait.
final class DuomoScript extends StoryScript {
  DuomoScript(super.director);

  static String get cultist => strings.speakerCultist;
  static const String cultistPortrait =
      'assets/characters/npcs/portraits/cultist.png';
  static const String initiationImage = 'assets/story/scenes/priest_family.jpg';
  static String get stairBlockedLine => strings.duomoStairBlockedLine;
  static String get welcomeLine => strings.duomoWelcomeLine;
  static String get ringReminderLine => strings.duomoRingReminderLine;
  static String get familyWelcomeLine => strings.duomoFamilyWelcomeLine;
  static String get robeLine => strings.duomoRobeLine;
  static String get initiationReminderLine =>
      strings.duomoInitiationReminderLine;
  static String get lockedDoorLine => strings.duomoLockedDoorLine;
  static String get robeFoundLine => strings.duomoRobeFoundLine;

  static List<CutsceneFrame> get initiationScene => <CutsceneFrame>[
    CutsceneFrame(
      image: initiationImage,
      speaker: PriestScript.priest,
      text: familyWelcomeLine,
    ),
    CutsceneFrame(
      image: initiationImage,
      speaker: PriestScript.priest,
      text: robeLine,
    ),
  ];

  static const String massImage = 'assets/story/scenes/priest_mass.jpg';
  static const String crucifiedImage =
      'assets/story/scenes/crucified_zombie.jpg';
  static String get massWelcomeLine => strings.duomoMassWelcomeLine;
  static String get massSermonLine => strings.duomoMassSermonLine;

  /// Played when Mario comes back down into the Duomo wearing the robe.
  static List<CutsceneFrame> get massScene => <CutsceneFrame>[
    CutsceneFrame(
      image: massImage,
      speaker: PriestScript.priest,
      text: massWelcomeLine,
    ),
    CutsceneFrame(
      image: crucifiedImage,
      speaker: PriestScript.priest,
      text: massSermonLine,
    ),
  ];

  static const String sermonImage = 'assets/story/scenes/priest_worship.jpg';
  static const String feastImage = 'assets/story/scenes/cultists_feast.jpg';
  static const String mutationImage =
      'assets/story/scenes/cultists_mutation.jpg';
  static const String seizedImage = 'assets/story/scenes/priest_seized.jpg';

  static String get worshipLine => strings.duomoWorshipLine;
  static String get areYouMadLine => strings.duomoAreYouMadLine;
  static String get superZombieLine => strings.duomoSuperZombieLine;
  static String get letMeGoLine => strings.duomoLetMeGoLine;

  /// How the mass ends: the sermon turns into worship, the community eats
  /// of the crucified zombie, Mario works out what that makes of them, and
  /// what they have become takes Don Angelo.
  static List<CutsceneFrame> get massacreScene => <CutsceneFrame>[
    CutsceneFrame(
      image: sermonImage,
      speaker: PriestScript.priest,
      text: worshipLine,
    ),
    CutsceneFrame(
      image: feastImage,
      speaker: 'Mario Rossi',
      text: areYouMadLine,
    ),
    CutsceneFrame(
      image: mutationImage,
      speaker: 'Mario Rossi',
      text: superZombieLine,
    ),
    CutsceneFrame(
      image: seizedImage,
      speaker: PriestScript.priest,
      text: letMeGoLine,
    ),
  ];

  /// The mass and what it turns into, played as one scene: fading back to
  /// the game between the sermon and the feast would cut the moment in two.
  static List<CutsceneFrame> get massSequence => <CutsceneFrame>[
    ...massScene,
    ...massacreScene,
  ];

  static String get keyUsedLine => strings.duomoKeyUsedLine;

  static String get outfitChangedLine => strings.duomoOutfitChangedLine;

  /// Said with the robe coming off, and in the same breath where the
  /// clothes are changed: the wardrobe on the train, if Mario has been
  /// aboard already, or somewhere still to come.
  static String get outfitObtainedLine => strings.duomoOutfitObtainedLine;
  static String get wardrobeOnTrainLine => strings.duomoWardrobeOnTrainLine;
  static String get wardrobeLaterLine => strings.duomoWardrobeLaterLine;

  /// Leaves the portal's fade time to lift off the harbour first.
  static const double outfitLessonDelay = 0.8;

  bool _ringDelivered = false;
  bool _massacrePlayed = false;
  bool _leftAfterMassacre = false;

  bool get ringDelivered => _ringDelivered;

  /// True once the mass has ended: Don Angelo is dead, his community are
  /// the four cultists in the nave and the key lies beside his body.
  bool get massacrePlayed => _massacrePlayed;

  @override
  String get key => 'duomo';

  @override
  void onEvent(WorldEvent event) {
    if (event case TeleportedEvent(
      :final entityId,
      :final from,
      :final to,
    ) when entityId == world.playerId) {
      _leaveAfterMassacre(from, to);
      return;
    }
    // The robe lies in a backpack, like everything Mario picks up.
    if (event case PickedUpEvent(cultistRobe: true)) {
      say(
        StoryPrompt(
          <StoryLine>[StoryLine(robeFoundLine)],
          delay: StoryDirector.pickupDelay,
          onDismissed: host.hometown.collectCultistRobe,
        ),
      );
      return;
    }
    if (event case NoInteractionEvent(
      :final at,
    ) when at == duomoUpperLockedDoorTile) {
      _tryTheUpperDoor(at);
      return;
    }
    if (event case NoInteractionEvent(:final at)) {
      // Nobody is left in the nave to answer once the mass has ended.
      final line = _massacrePlayed
          ? null
          : switch (at) {
              _ when !_ringDelivered && at == duomoStairCultistTile =>
                StoryLine.cultist(stairBlockedLine),
              _ when _ringDelivered && at == duomoStairCultistMovedTile =>
                StoryLine.cultist(welcomeLine),
              _ when at == duomoWelcomingCultistTile => StoryLine.cultist(
                welcomeLine,
              ),
              _ when at == duomoPriestTile => StoryLine.priest(
                _ringDelivered ? initiationReminderLine : ringReminderLine,
              ),
              _ => null,
            };
      if (line != null) {
        say(StoryPrompt(<StoryLine>[line]));
      }
    }
  }

  /// The locked door in the corner of the upper floor: the key found beside
  /// Don Angelo's body opens it for good and is used up doing so, as the
  /// bar's own key is. Without it, all Mario learns is that it is locked.
  void _tryTheUpperDoor(GridPoint at) {
    if (world.map.tileAt(at).isWalkable) {
      return;
    }
    if (host.isUnlocked(HudElement.duomoKey)) {
      world.map.setTile(at, const Tile(TileKind.floor));
      host.removeHud(HudElement.duomoKey);
      say(StoryPrompt(<StoryLine>[StoryLine(keyUsedLine)]));
      return;
    }
    say(StoryPrompt(<StoryLine>[StoryLine(lockedDoorLine)]));
  }

  @override
  void update({required bool turnAnimating}) {
    if (turnAnimating || host.isPromptVisible) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (_ringDelivered) {
      _startMassIfDressed(position);
      return;
    }
    final ring = world.pickups[episcopalRingPickupId];
    if (ring == null ||
        !ring.collected ||
        placeAt(position)?.id != PlaceId.duomo) {
      return;
    }
    _ringDelivered = true;
    host.playCutscene(
      initiationScene,
      memories: const <StoryMemory>{StoryMemory.priestFamily},
      music: Music.sacred,
      onBlack: _finishInitiation,
      onFinished: () => progress.missions
        ..complete(Mission.findRing)
        ..give(Mission.initiation),
    );
  }

  /// The mass waits for Mario in the Duomo in the occultist robe: coming
  /// down in his own clothes changes nothing, until he is back in there
  /// wearing it. It runs straight into the massacre, and once that has been
  /// played the nave stays as it left it.
  void _startMassIfDressed(GridPoint position) {
    if (_massacrePlayed ||
        progress.activeOutfit != PlayerOutfit.cultist ||
        placeAt(position)?.id != PlaceId.duomo) {
      return;
    }
    _massacrePlayed = true;
    host.playCutscene(
      massSequence,
      memories: const <StoryMemory>{
        StoryMemory.priestMass,
        StoryMemory.priestMassacre,
      },
      music: Music.sacred,
      onBlack: host.hometown.startDuomoMassacre,
      onFinished: () => progress.missions.complete(Mission.initiation),
    );
  }

  /// The first time Mario comes out of the Duomo onto the harbour after
  /// the massacre, the robe comes off: he is back in his own clothes, the
  /// robe is his, and he is told where the clothes are changed -- on the
  /// train, once he has been aboard. Out in his own clothes already, he has
  /// found the wardrobe by himself, and nothing is said.
  void _leaveAfterMassacre(GridPoint from, GridPoint to) {
    if (!_massacrePlayed ||
        _leftAfterMassacre ||
        placeAt(from)?.id != PlaceId.duomo ||
        placeAt(to)?.id != PlaceId.harbour) {
      return;
    }
    _leftAfterMassacre = true;
    if (progress.activeOutfit != PlayerOutfit.cultist) {
      return;
    }
    host.wearOutfit(PlayerOutfit.base);
    final where = progress.hasExperienced(StoryMemory.luigiAtStation)
        ? wardrobeOnTrainLine
        : wardrobeLaterLine;
    say(
      StoryPrompt(<StoryLine>[
        StoryLine(outfitChangedLine),
        StoryLine('$outfitObtainedLine $where'),
      ], delay: outfitLessonDelay),
    );
  }

  void _finishInitiation() {
    host
      ..removeHud(HudElement.episcopalRing)
      ..hometown.openDuomoUpper();
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'ringDelivered': _ringDelivered,
    'massacre': _massacrePlayed,
    'leftAfterMassacre': _leftAfterMassacre,
  };

  @override
  void restore(Map<String, Object?> json) {
    _ringDelivered = json['ringDelivered'] as bool? ?? false;
    _massacrePlayed = json['massacre'] as bool? ?? false;
    _leftAfterMassacre = json['leftAfterMassacre'] as bool? ?? false;
  }
}
