import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The Duomo on the harbour: walking up the alley to the churchyard gate
/// gets Mario hailed by Don Angelo, who wants the two zombies at his gate
/// gone before he will talk. Once they are dead, or far enough away for
/// Mario to stand at the gate unbothered, the priest names his price: a
/// censer's worth of incense. Bringing it back to a clear gate earns Mario
/// his welcome inside; coming back while zombies crowd the entrance makes
/// Don Angelo repeat his warning.
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

  static const String clearThemOut =
      'Sbarazzati di questi zombi così potremmo parlare meglio';
  static const String incenseLine =
      "Portami dell'incenso, mi serve per le mie cerimonie";
  static const String whereLine = "Dove lo trovo dell'incenso?!";
  static const String everyTwoStreetsLine =
      'Suvvia giovanotto, siamo in Italia! Nei centri storici trovi una '
      'chiesa ogni due strade';
  static const String welcomeLine =
      'Ottimo giovanotto, ben fatto! Benvenuto nella nostra chiesa';
  static const String notCommunityYetLine =
      'Ora puoi entrare qui ma non sei ancora davvero parte della nostra '
      'comunità';
  static const String moreWorkLine =
      'Ah... Immagino che vi aspettate che faccia altro per voi';
  static const String useYourSkillsLine =
      'Giovanotto sembri così bravo a muoverti nella città desolata, '
      'sarebbe un peccato non sfruttare queste tue capacità';
  static const String barKeyLine =
      'Usa questa chiave per aprire una porta nel bar Arcobaleno sul porto, '
      'lì troverai il mio anello episcopale';

  /// Don Angelo calls out from behind his gate, Mario answers.
  static const List<CutsceneFrame> meetingScene = <CutsceneFrame>[
    CutsceneFrame(
      image: gateScene,
      speaker: priest,
      text:
          'Ohh che piacere vedere qualcuno ancora in vita passeggiare per il '
          'nostro porto',
    ),
    CutsceneFrame(
      image: seafrontScene,
      speaker: 'Mario Rossi',
      text: 'Siete vivi?! Qui alla chiesa vi siete salvati?',
    ),
    CutsceneFrame(
      image: gateScene,
      speaker: priest,
      text:
          'Giovanotto la chiesa è sempre il primo posto in cui cercare la '
          'salvezza',
    ),
  ];

  /// Mario at the gate with the zombies gone, and the priest's price.
  static const List<CutsceneFrame> dealScene = <CutsceneFrame>[
    CutsceneFrame(
      image: dealSceneImage,
      speaker: 'Mario Rossi',
      text: 'Ci siamo padre, apra il cancello',
    ),
    CutsceneFrame(
      image: dealSceneImage,
      speaker: priest,
      text: 'Prima dovrai fare qualcosa per noi',
    ),
    CutsceneFrame(
      image: dealSceneImage,
      speaker: 'Mario Rossi',
      text: 'Cosa?! Ma è pericoloso qui fuori padre...',
    ),
    CutsceneFrame(
      image: dealSceneImage,
      speaker: priest,
      text:
          'Giovanotto pensi che se facessi entrare chiunque nella mia chiesa '
          'ora sarei ancora sopravvissuto?',
    ),
  ];

  /// Don Angelo receives Mario once he returns with the incense.
  static const List<CutsceneFrame> welcomeScene = <CutsceneFrame>[
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

  /// Walking up to the gate plays the priest's first scene, and he asks for
  /// the zombies to be dealt with. Standing at the gate with them gone
  /// plays the second, and he names his price. Once Mario has the incense,
  /// returning to a clear gate plays the welcome; at a blocked gate Don
  /// Angelo repeats his original warning once per visit.
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
    if (!priestGateFront.contains(position)) {
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
      );
      return;
    }
    if (!_blockedAtGate) {
      _blockedAtGate = true;
      _askToClearTheGate();
    }
  }

  /// True when Mario stands in the alley in front of the gate and neither
  /// of the priest's zombies is dead set on him: they are dead, or far
  /// enough away to have lost him.
  bool _gateIsClear(GridPoint position) {
    if (!priestGateFront.contains(position)) {
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
  /// the controls come back once Mario has heard him out.
  void _askToClearTheGate() {
    say(
      StoryPrompt(const <StoryLine>[
        StoryLine.priest(clearThemOut),
      ], onDismissed: () => _clearAsked = true),
    );
  }

  /// Back in the open world again, the errand itself.
  void _askForIncense() {
    say(
      StoryPrompt(const <StoryLine>[
        StoryLine.priest(incenseLine),
        StoryLine.mario(whereLine),
        StoryLine.priest(everyTwoStreetsLine),
      ], onDismissed: () => _errandGiven = true),
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
