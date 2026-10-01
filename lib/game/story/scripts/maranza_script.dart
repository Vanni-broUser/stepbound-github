import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// Rome, at the bottom of Via Cavour: Tonino and Marcello stand across the
/// way onto Piazza di Santa Maria Maggiore. Everything with them plays in
/// the same place, [onMaranzaTurf]. Walking into it plays their meeting
/// with Mario, and they want something of value to let him by. From then
/// on every step in it gets one of their warnings, in turn, and Mario
/// walked back up the street; the controls come back once he is.
///
/// With the gold ingot from the bank's vault their handing over plays
/// instead, where Mario stands, and the ticket for the Colosseum they give
/// him for it: they let him by. Had he the ingot already when they asked
/// for it, the mission is crossed out as it is handed out, and the handing
/// over follows once the corner has shown it. They stay where they
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

  static List<CutsceneFrame> get meetingScene => <CutsceneFrame>[
    CutsceneFrame(
      image: meetScene,
      speaker: tonino,
      text: strings.maranzaMeetingScene1,
    ),
    CutsceneFrame(
      image: meetScene,
      speaker: marcello,
      text: strings.maranzaMeetingScene2,
    ),
    CutsceneFrame(
      image: marioScene,
      speaker: 'Mario Rossi',
      text: strings.maranzaMeetingScene3,
    ),
    CutsceneFrame(
      image: marioScene,
      speaker: tonino,
      text: strings.maranzaMeetingScene4,
    ),
    CutsceneFrame(
      image: marioScene,
      speaker: 'Mario Rossi',
      text: strings.maranzaMeetingScene5,
    ),
    CutsceneFrame(
      image: laughScene,
      speaker: marcello,
      text: strings.maranzaMeetingScene6,
    ),
  ];

  /// The gold ingot handed over, and what they give Mario for it.
  static List<CutsceneFrame> get paidScene => <CutsceneFrame>[
    CutsceneFrame(
      image: ingotScene,
      speaker: tonino,
      text: strings.maranzaPaidScene1,
    ),
    CutsceneFrame(
      image: ticketScene,
      speaker: marcello,
      text: strings.maranzaPaidScene2,
    ),
    CutsceneFrame(
      image: ticketScene,
      speaker: 'Mario Rossi',
      text: strings.maranzaPaidScene3,
    ),
    CutsceneFrame(
      image: ticketScene,
      speaker: marcello,
      text: strings.maranzaPaidScene4,
    ),
  ];

  /// What each of them says to Mario talking to them once they have the
  /// ingot.
  static StoryLine get toninoAfter => StoryLine(
    strings.maranzaToninoAfter,
    speaker: tonino,
    portrait: toninoPortrait,
  );
  static StoryLine get marcelloAfter => StoryLine(
    strings.maranzaMarcelloAfter,
    speaker: marcello,
    portrait: marcelloPortrait,
  );

  /// What they say to Mario coming at them again, one after the other.
  static List<StoryLine> get warnings => <StoryLine>[
    StoryLine(
      strings.maranzaWarnings1,
      speaker: tonino,
      portrait: toninoPortrait,
    ),
    StoryLine(
      strings.maranzaWarnings2,
      speaker: marcello,
      portrait: marcelloPortrait,
    ),
  ];

  bool _metPlayed = false;
  int _warningsGiven = 0;

  /// True from the moment a warning is queued until Mario has been walked
  /// back: a single step towards them gets a single one.
  bool _warning = false;

  /// Their last word said, the meeting or a warning: the tile Mario is
  /// left on once it is over gets no other, only a step off it does.
  bool _leftAlone = false;
  GridPoint? _leftOn;

  /// The meeting is playing: nothing else until they have had their say.
  bool _meeting = false;

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
      say(StoryPrompt(<StoryLine>[toninoAfter]));
    } else if (event.at == marcelloTile) {
      say(StoryPrompt(<StoryLine>[marcelloAfter]));
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
    final onTurf = onMaranzaTurf(position);
    if (_leftAlone) {
      // Mario has been walked back, or the meeting is over: where he
      // stands now is where they left him.
      _leftAlone = false;
      _leftOn = onTurf ? position : null;
    }
    if (!onTurf) {
      _leftOn = null;
    }
    if (!_metPlayed) {
      if (onTurf) {
        _metPlayed = true;
        _meeting = true;
        // Where the meeting finds him is where it leaves him.
        _leftOn = position;
        host
          ..stopWalking()
          ..playCutscene(
            meetingScene,
            memories: const <StoryMemory>{StoryMemory.maranzaMet},
            music: Music.maranza,
            onFinished: _askForSomethingValuable,
          );
      }
      return;
    }
    // A scene straight after a mission done waits for the corner to have
    // crossed it out: the ingot already in hand.
    if (_paid || _meeting || !onTurf || host.missionsSettling) {
      return;
    }
    if (host.isUnlocked(HudElement.goldIngot)) {
      _handOver();
    } else if (position != _leftOn) {
      _warn();
    }
  }

  /// The meeting is over: the mission is to find them something of value,
  /// found already if Mario has the ingot on him.
  void _askForSomethingValuable() {
    _meeting = false;
    _leftAlone = true;
    progress.missions.give(Mission.findValuable);
    if (host.isUnlocked(HudElement.goldIngot)) {
      progress.missions.complete(Mission.findValuable);
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
          _leftAlone = true;
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
