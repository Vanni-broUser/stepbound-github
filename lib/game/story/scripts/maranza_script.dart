import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// Rome, at the bottom of Via Cavour: Tonino and Marcello stand across the
/// way onto Piazza di Santa Maria Maggiore. Walking down the last stretch
/// of the street plays their meeting with Mario, and they want something
/// of value to let him by. From then on every step towards them gets one
/// of their warnings, in turn, and Mario walked back up the street; the
/// controls come back once he is.
final class MaranzaScript extends StoryScript {
  MaranzaScript(super.director);

  static const String tonino = 'Tonino Cacio e Pepe';
  static const String marcello = 'Marcello er Criminale';
  static const String toninoPortrait =
      'assets/characters/npcs/portraits/maranza_roma.png';
  static const String marcelloPortrait =
      'assets/characters/npcs/portraits/maranza_lazio.png';
  static const String meetScene = 'assets/story/scenes/rome_maranza_meet.jpg';
  static const String marioScene = 'assets/story/scenes/rome_maranza_mario.jpg';
  static const String laughScene = 'assets/story/scenes/rome_maranza_laugh.jpg';

  static const List<CutsceneFrame> meetingScene = <CutsceneFrame>[
    CutsceneFrame(
      image: meetScene,
      speaker: tonino,
      text: 'Aò frà, tu non sei morto vero?',
    ),
    CutsceneFrame(
      image: meetScene,
      speaker: marcello,
      text: 'Che vuoi passà da qua? Questa è zona nostra',
    ),
    CutsceneFrame(
      image: marioScene,
      speaker: 'Mario Rossi',
      text: 'Cosa volete?',
    ),
    CutsceneFrame(
      image: marioScene,
      speaker: tonino,
      text: 'Daje frà, lo sai... Qualcosa di prezioso, di valore!',
    ),
    CutsceneFrame(
      image: marioScene,
      speaker: 'Mario Rossi',
      text: "Ma cosa ve ne fate? Siamo nel pieno dell'apocalisse zombi!",
    ),
    CutsceneFrame(
      image: laughScene,
      speaker: marcello,
      text:
          'Frà, fino a quando ci saranno almeno due persone sulla Terra, '
          'servirà sempre avere roba di valore',
    ),
  ];

  /// What they say to Mario coming at them again, one after the other.
  static const List<StoryLine> warnings = <StoryLine>[
    StoryLine(
      'Fratè, meglio che torni con qualcosa di valore per noi',
      speaker: tonino,
      portrait: toninoPortrait,
    ),
    StoryLine(
      'Se torni senza qualcosa per noi ti becchi una sberla',
      speaker: marcello,
      portrait: marcelloPortrait,
    ),
  ];

  bool _metPlayed = false;
  int _warningsGiven = 0;

  /// True from the moment a warning is queued until Mario has been walked
  /// back: a single step towards them gets a single one.
  bool _warning = false;

  bool get metPlayed => _metPlayed;

  @override
  String get key => 'maranza';

  @override
  void update({required bool turnAnimating}) {
    if (_warning ||
        turnAnimating ||
        host.isPromptVisible ||
        progress.level != LevelId.rome) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (!_metPlayed) {
      if (maranzaSceneTrigger.contains(position)) {
        _metPlayed = true;
        host
          ..stopWalking()
          ..playCutscene(
            meetingScene,
            memories: const <StoryMemory>{StoryMemory.maranzaMet},
            onFinished: () => progress.missions.give(Mission.findValuable),
          );
      }
      return;
    }
    if (maranzaTurf.contains(position)) {
      _warn();
    }
  }

  /// One of their two lines, then Mario is walked a step back up the
  /// street, the way he came.
  void _warn() {
    _warning = true;
    host.stopWalking();
    final line = warnings[_warningsGiven % warnings.length];
    _warningsGiven++;
    say(
      StoryPrompt(
        <StoryLine>[line],
        holdsInput: true,
        onDismissed: () {
          _warning = false;
          host.walkPlayer(Direction.north);
        },
      ),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'met': _metPlayed,
    'warnings': _warningsGiven,
  };

  @override
  void restore(Map<String, Object?> json) {
    _metPlayed = json['met'] as bool? ?? false;
    _warningsGiven = json['warnings'] as int? ?? 0;
  }
}
