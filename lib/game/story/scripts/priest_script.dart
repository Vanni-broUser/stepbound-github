import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// The Duomo on the harbour: coming up to the churchyard alley, on the
/// seafront road in front of it or in the alley itself, gets Mario hailed
/// by Don Angelo, who wants the two zombies at his gate gone before he
/// will talk. Once they are dead, or far enough away for Mario to stand
/// there unbothered, the priest names his price: a censer's worth of
/// incense. Bringing it back to a clear gate earns Mario his welcome
/// inside; coming back while zombies crowd the entrance makes Don Angelo
/// repeat his warning. Every one of his scenes plays in the same place,
/// [priestSceneTrigger]: the next one follows where Mario stands.
final class PriestScript extends StoryScript {
  PriestScript(super.director);

  static const String priest = 'Don Angelo Dannato';
  static const String priestPortrait =
      'assets/characters/npcs/portraits/priest.png';
  static const String gateScene = 'assets/story/scenes/priest_gate.jpg';
  static const String seafrontScene = 'assets/story/scenes/mario_seafront.jpg';
  static const String dealSceneImage = 'assets/story/scenes/priest_deal.jpg';
  static const String welcomeSceneImage =
      'assets/story/scenes/priest_welcome.jpg';
  static const String communitySceneImage =
      'assets/story/scenes/priest_community.jpg';
  static const String barKeySceneImage =
      'assets/story/scenes/priest_bar_key.jpg';

  static String get clearThemOut => strings.priestClearThemOut;
  static String get incenseLine => strings.priestIncenseLine;
  static String get whereLine => strings.priestWhereLine;
  static String get everyTwoStreetsLine => strings.priestEveryTwoStreetsLine;
  static String get welcomeLine => strings.priestWelcomeLine;
  static String get notCommunityYetLine => strings.priestNotCommunityYetLine;
  static String get moreWorkLine => strings.priestMoreWorkLine;
  static String get useYourSkillsLine => strings.priestUseYourSkillsLine;
  static String get barKeyLine => strings.priestBarKeyLine;

  /// Don Angelo calls out from behind his gate, Mario answers.
  static List<CutsceneFrame> get meetingScene => <CutsceneFrame>[
    CutsceneFrame(
      image: gateScene,
      speaker: priest,
      text: strings.priestMeetingScene1,
    ),
    CutsceneFrame(
      image: seafrontScene,
      speaker: 'Mario Rossi',
      text: strings.priestMeetingScene2,
    ),
    CutsceneFrame(
      image: gateScene,
      speaker: priest,
      text: strings.priestMeetingScene3,
    ),
  ];

  /// Mario at the gate with the zombies gone, and the priest's price.
  static List<CutsceneFrame> get dealScene => <CutsceneFrame>[
    CutsceneFrame(
      image: dealSceneImage,
      speaker: 'Mario Rossi',
      text: strings.priestDealScene1,
    ),
    CutsceneFrame(
      image: dealSceneImage,
      speaker: priest,
      text: strings.priestDealScene2,
    ),
    CutsceneFrame(
      image: dealSceneImage,
      speaker: 'Mario Rossi',
      text: strings.priestDealScene3,
    ),
    CutsceneFrame(
      image: dealSceneImage,
      speaker: priest,
      text: strings.priestDealScene4,
    ),
  ];

  /// Don Angelo receives Mario once he returns with the incense.
  static List<CutsceneFrame> get welcomeScene => <CutsceneFrame>[
    CutsceneFrame(image: welcomeSceneImage, speaker: priest, text: welcomeLine),
    CutsceneFrame(
      image: communitySceneImage,
      speaker: priest,
      text: notCommunityYetLine,
    ),
    CutsceneFrame(
      image: communitySceneImage,
      speaker: 'Mario Rossi',
      text: moreWorkLine,
    ),
    CutsceneFrame(
      image: communitySceneImage,
      speaker: priest,
      text: useYourSkillsLine,
    ),
    CutsceneFrame(image: barKeySceneImage, speaker: priest, text: barKeyLine),
  ];

  /// How far a zombie still on its feet has to be, in tiles, for Mario to
  /// stand at the gate without it coming after him: past both a
  /// wanderer's sight and its hearing.
  static const int safeDistance = 10;

  bool _metPlayed = false;
  bool _clearAsked = false;
  bool _dealPlayed = false;
  bool _errandGiven = false;
  bool _welcomePlayed = false;
  bool _blockedAtGate = false;

  /// True once Don Angelo has asked for the incense: the errand is open.
  bool get errandGiven => _errandGiven;
  bool get welcomePlayed => _welcomePlayed;

  @override
  String get key => 'priest';

  /// Coming up to the gate plays the priest's first scene, and he asks for
  /// the zombies to be dealt with. Standing there with them gone plays the
  /// second, and he names his price. Once Mario has the incense, a clear
  /// gate plays the welcome; at a blocked gate Don Angelo repeats his
  /// original warning once per visit.
  @override
  void update({required bool turnAnimating}) {
    if (turnAnimating || host.isPromptVisible) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (!_metPlayed) {
      if (priestSceneTrigger.contains(position)) {
        _metPlayed = true;
        host.playCutscene(
          meetingScene,
          memories: const <StoryMemory>{StoryMemory.priestMet},
          music: Music.sacred,
          onFinished: _askToClearTheGate,
        );
      }
      return;
    }
    // A scene straight after a mission done waits for the corner to have
    // crossed it out: the gate cleared, the incense already in hand.
    if (host.missionsSettling) {
      return;
    }
    if (_clearAsked && !_dealPlayed && _gateIsClear(position)) {
      _dealPlayed = true;
      host.playCutscene(
        dealScene,
        memories: const <StoryMemory>{StoryMemory.priestErrand},
        music: Music.sacred,
        onFinished: _askForIncense,
      );
      return;
    }
    if (!_errandGiven ||
        _welcomePlayed ||
        !host.isUnlocked(HudElement.incense)) {
      return;
    }
    if (!priestSceneTrigger.contains(position)) {
      _blockedAtGate = false;
      return;
    }
    if (_gateIsClear(position)) {
      _welcomePlayed = true;
      host.playCutscene(
        welcomeScene,
        memories: const <StoryMemory>{StoryMemory.priestWelcomed},
        music: Music.sacred,
        onBlack: _finishWelcome,
        // The gate too, if the zombies had crowded it again: both are done
        // together.
        onFinished: () => progress.missions
          ..complete(Mission.clearGate)
          ..complete(Mission.findIncense)
          ..give(Mission.findRing),
      );
      return;
    }
    if (!_blockedAtGate) {
      _blockedAtGate = true;
      _askToClearTheGate();
    }
  }

  /// True when Mario stands where Don Angelo can talk to him and neither
  /// of the priest's zombies is dead set on him: they are dead, or far
  /// enough away to have lost him.
  bool _gateIsClear(GridPoint position) {
    if (!priestSceneTrigger.contains(position)) {
      return false;
    }
    for (final zombie in world.entities.values) {
      if (zombie.kind == EntityKind.player || !zombie.isAlive) {
        continue;
      }
      final isPriestZombie = zombie.id.startsWith(priestZombiePrefix);
      if (isPriestZombie && zombie.component<HearingComponent>().hunting) {
        return false;
      }
      final where = zombie.component<PositionComponent>().position;
      if (where.manhattanDistanceTo(position) < safeDistance) {
        return false;
      }
    }
    return true;
  }

  /// Back in the open world, the priest asks for the gate to be cleared;
  /// the controls come back once Mario has heard him out. Asked again, once
  /// Mario is back with the incense, the gate is a mission once more.
  void _askToClearTheGate() {
    say(
      StoryPrompt(
        <StoryLine>[StoryLine.priest(clearThemOut)],
        onDismissed: () {
          _clearAsked = true;
          progress.missions.give(Mission.clearGate);
          director.foundSurvivor();
        },
      ),
    );
  }

  /// Back in the open world again, the errand itself. Asked with the
  /// incense already in Mario's pocket, it is found as soon as it is
  /// handed out: the welcome follows once the corner has crossed it out.
  void _askForIncense() {
    say(
      StoryPrompt(
        <StoryLine>[
          StoryLine.priest(incenseLine),
          StoryLine.mario(whereLine),
          StoryLine.priest(everyTwoStreetsLine),
        ],
        onDismissed: () {
          _errandGiven = true;
          progress.missions
            ..complete(Mission.clearGate)
            ..give(Mission.findIncense);
          if (host.isUnlocked(HudElement.incense)) {
            progress.missions.complete(Mission.findIncense);
          }
        },
      ),
    );
  }

  /// The incense has been handed over. Before the game shows again the
  /// churchyard is open, Don Angelo waits at the altar and Mario carries
  /// the bar key.
  void _finishWelcome() {
    host
      ..removeHud(HudElement.incense)
      ..unlock(HudElement.barKey)
      ..hometown.openDuomo();
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'met': _metPlayed,
    'clearAsked': _clearAsked,
    'deal': _dealPlayed,
    'errand': _errandGiven,
    'welcome': _welcomePlayed,
  };

  @override
  void restore(Map<String, Object?> json) {
    _metPlayed = json['met'] as bool? ?? false;
    _clearAsked = json['clearAsked'] as bool? ?? false;
    _dealPlayed = json['deal'] as bool? ?? false;
    _errandGiven = json['errand'] as bool? ?? false;
    _welcomePlayed = json['welcome'] as bool? ?? false;
  }
}
