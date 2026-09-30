import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// Rome, at the bottom of Via Cavour: Tonino and Marcello stand across the
/// way onto Piazza di Santa Maria Maggiore. Walking down the last stretch
/// of the street plays their meeting with Mario, and they want something
/// of value to let him by. From then on every step towards them gets one
/// of their warnings, in turn, and Mario walked back up the street; the
/// controls come back once he is.
///
/// Coming at them with the gold ingot from the bank's vault plays its
/// handing over instead, and the ticket for the Colosseum they give him
/// for it: the mission is done, and they let him by. They stay where they
/// are, a line each for him if he talks to them, until he has left the
/// square: back on it, they have gone.
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
  static const String ingotScene = 'assets/story/scenes/rome_maranza_ingot.jpg';
  static const String ticketScene =
      'assets/story/scenes/rome_maranza_ticket.jpg';

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

  /// The gold ingot handed over, and what they give Mario for it.
  static const List<CutsceneFrame> paidScene = <CutsceneFrame>[
    CutsceneFrame(
      image: ingotScene,
      speaker: tonino,
      text:
          'Grande frà, questo era proprio che intendevo con qualcosa di '
          'prezioso!',
    ),
    CutsceneFrame(
      image: ticketScene,
      speaker: marcello,
      text:
          'Ci stai simpatico frà, tieni questo è un biglietto per il '
          'Colosseo',
    ),
    CutsceneFrame(
      image: ticketScene,
      speaker: 'Mario Rossi',
      text: 'Il Colosseo? Ci fanno ancora le gite turistiche?',
    ),
    CutsceneFrame(
      image: ticketScene,
      speaker: marcello,
      text: 'Gite turistiche!? Hehehe niente del genere frà, lo scoprirai...',
    ),
  ];

  /// What each of them says to Mario talking to them once they have the
  /// ingot.
  static const StoryLine toninoAfter = StoryLine(
    'Ora dobbiamo trovare qualcosa da fare con questo lingotto adesso',
    speaker: tonino,
    portrait: toninoPortrait,
  );
  static const StoryLine marcelloAfter = StoryLine(
    'Ci vediamo al Colosseo frà',
    speaker: marcello,
    portrait: marcelloPortrait,
  );

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

  /// The ingot handed over: they let Mario by.
  bool _paid = false;

  /// Gone from the square, once Mario has left it after paying them.
  bool _gone = false;

  bool get metPlayed => _metPlayed;
  bool get paid => _paid;
  bool get gone => _gone;

  @override
  String get key => 'maranza';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent || !_paid || _gone) {
      return;
    }
    if (event.at == toninoTile) {
      say(StoryPrompt(const <StoryLine>[toninoAfter]));
    } else if (event.at == marcelloTile) {
      say(StoryPrompt(const <StoryLine>[marcelloAfter]));
    }
  }

  @override
  void update({required bool turnAnimating}) {
    final position = world.player.component<PositionComponent>().position;
    if (_paid && !_gone && placeAt(position)?.id != PlaceId.piazzaCinquecento) {
      _gone = true;
    }
    if (_warning ||
        turnAnimating ||
        host.isPromptVisible ||
        progress.level != LevelId.rome) {
      return;
    }
    if (!_metPlayed) {
      if (maranzaSceneTrigger.contains(position)) {
        _metPlayed = true;
        host
          ..stopWalking()
          ..playCutscene(
            meetingScene,
            memories: const <StoryMemory>{StoryMemory.maranzaMet},
            music: Music.maranza,
            onFinished: () => progress.missions.give(Mission.findValuable),
          );
      }
      return;
    }
    if (_paid || !maranzaTurf.contains(position)) {
      return;
    }
    if (host.isUnlocked(HudElement.goldIngot)) {
      _handOver();
    } else {
      _warn();
    }
  }

  /// The ingot for the ticket: the mission done, the ingot's badge gone
  /// and the ticket's up, and the next mission, to find out what goes on
  /// at the Colosseum.
  void _handOver() {
    _paid = true;
    host
      ..stopWalking()
      ..playCutscene(
        paidScene,
        memories: const <StoryMemory>{StoryMemory.maranzaPaid},
        music: Music.maranza,
        onFinished: () {
          host
            ..removeHud(HudElement.goldIngot)
            ..unlock(HudElement.colosseumTicket);
          progress.missions
            ..complete(Mission.findValuable)
            ..give(Mission.discoverColosseum);
        },
      );
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
    if (_paid) 'paid': true,
    if (_gone) 'gone': true,
  };

  @override
  void restore(Map<String, Object?> json) {
    _metPlayed = json['met'] as bool? ?? false;
    _warningsGiven = json['warnings'] as int? ?? 0;
    _paid = json['paid'] as bool? ?? false;
    _gone = json['gone'] as bool? ?? false;
  }
}
