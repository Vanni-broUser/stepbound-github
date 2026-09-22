import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The Duomo on the harbour: walking up the alley to the churchyard gate
/// gets Mario hailed by Don Angelo, who wants the two zombies at his gate
/// gone before he will talk. Once they are dead, or far enough away for
/// Mario to stand at the gate unbothered, the priest names his price: a
/// censer's worth of incense, and only then the gate.
final class PriestScript extends TutorialScript {
  PriestScript(super.director);

  static const String priest = 'Don Angelo Dannato';
  static const String priestPortrait = 'assets/story/portrait_priest.png';
  static const String gateScene = 'assets/story/scene_priest_gate.jpg';
  static const String seafrontScene = 'assets/story/scene_mario_seafront.jpg';
  static const String dealSceneImage = 'assets/story/scene_priest_deal.jpg';

  static const String clearThemOut =
      'Sbarazzati di questi zombi così potremmo parlare meglio';
  static const String incenseLine =
      "Portami dell'incenso, mi serve per le mie cerimonie";
  static const String whereLine = "Dove lo trovo dell'incenso?!";
  static const String everyTwoStreetsLine =
      'Suvvia giovanotto, siamo in Italia! Nei centri storici trovi una '
      'chiesa ogni due strade';

  /// Don Angelo calls out from behind his gate, Mario answers.
  static const List<CutsceneFrame> meetingScene = <CutsceneFrame>[
    CutsceneFrame(
      image: gateScene,
      speaker: priest,
      text:
          'Ohh che piacere vedere qualcuno ancora in vita passeggiare per il '
          'nostro lungomare',
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

  /// How far a zombie still on its feet has to be, in tiles, for Mario to
  /// stand at the gate without it coming after him: past both a
  /// wanderer's sight and its hearing.
  static const int safeDistance = 10;

  bool _metPlayed = false;
  bool _clearAsked = false;
  bool _dealPlayed = false;
  bool _errandGiven = false;

  /// True once Don Angelo has asked for the incense: the errand is open.
  bool get errandGiven => _errandGiven;

  @override
  String get key => 'priest';

  /// Walking up to the gate plays the priest's first scene, and he asks for
  /// the zombies to be dealt with. Standing at the gate with them gone
  /// plays the second, and he names his price.
  @override
  void update({required bool turnAnimating}) {
    if (turnAnimating || host.isPromptVisible) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (!_metPlayed) {
      if (priestSceneTrigger.contains(position)) {
        _metPlayed = true;
        progress.remember(StoryMemory.priestMet);
        host.playCutscene(meetingScene, onFinished: _askToClearTheGate);
      }
      return;
    }
    if (_clearAsked && !_dealPlayed && _gateIsClear(position)) {
      _dealPlayed = true;
      progress.remember(StoryMemory.priestErrand);
      host.playCutscene(dealScene, onFinished: _askForIncense);
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
      if (!zombie.id.startsWith(priestZombiePrefix) || !zombie.isAlive) {
        continue;
      }
      if (zombie.component<HearingComponent>().hunting) {
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
      TutorialPrompt(const <TutorialLine>[
        TutorialLine.priest(clearThemOut),
      ], onDismissed: () => _clearAsked = true),
    );
  }

  /// Back in the open world again, the errand itself.
  void _askForIncense() {
    say(
      TutorialPrompt(const <TutorialLine>[
        TutorialLine.priest(incenseLine),
        TutorialLine.mario(whereLine),
        TutorialLine.priest(everyTwoStreetsLine),
      ], onDismissed: () => _errandGiven = true),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'met': _metPlayed,
    'clearAsked': _clearAsked,
    'deal': _dealPlayed,
    'errand': _errandGiven,
  };

  @override
  void restore(Map<String, Object?> json) {
    _metPlayed = json['met'] as bool? ?? false;
    _clearAsked = json['clearAsked'] as bool? ?? false;
    _dealPlayed = json['deal'] as bool? ?? false;
    _errandGiven = json['errand'] as bool? ?? false;
  }
}
