import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The company past the palazzo: walking up the west wing from the gate,
/// Mario comes to see Chiara through the glass, at a workstation in the
/// east wing. A few steps more with her in view and her phone call plays;
/// then there is someone to reach, the long way round by the floors above.
/// Once Mario is a couple of steps from her, they meet: he sends her to the
/// station,
/// where the other survivors are, and that mission is done. She stays at
/// her desk while he is still on her floor, and says she will see him
/// there; once he has gone to another place she has gone too, to the
/// train, where she keeps her corner of the second coach from then on.
/// Starting Molfetta over puts her back at her desk: this is Molfetta's
/// story.
final class CompanyScript extends StoryScript {
  CompanyScript(super.director);

  static const String chiara = 'Chiara Mente';
  static const String zombie = 'Zombi';
  static const String callScene = 'assets/story/scenes/chiara_call.jpg';
  static const String phoneScene =
      'assets/story/scenes/chiara_zombie_phone.jpg';
  static const String offerScene = 'assets/story/scenes/chiara_offer.jpg';
  static const String roarScene = 'assets/story/scenes/chiara_zombie_roar.jpg';
  static const String hangUpScene = 'assets/story/scenes/chiara_hang_up.jpg';
  static const String metScene = 'assets/story/scenes/chiara_met.jpg';
  static const String apocalypseScene =
      'assets/story/scenes/chiara_mario_apocalypse.jpg';
  static const String contractsScene =
      'assets/story/scenes/chiara_contracts.jpg';
  static const String mario = 'Mario Rossi';
  static const String chiaraPortrait =
      'assets/characters/npcs/portraits/chiara.png';

  /// Back in the game after the meeting, before Mario can move.
  static const String sendToStation =
      'Signora vai alla stazione, lì ci sono altri sopravvissuti';

  /// What she says to him while she is still at her desk.
  static const StoryLine seeYouThere = StoryLine(
    'Allora ci vediamo in stazione...',
    speaker: chiara,
    portrait: chiaraPortrait,
  );

  /// Mario beside her at last, round by the floors above.
  static const List<CutsceneFrame> meetingFrames = <CutsceneFrame>[
    CutsceneFrame(
      image: metScene,
      speaker: mario,
      text: 'Ei ma che ci fai qui?',
    ),
    CutsceneFrame(
      image: metScene,
      speaker: chiara,
      text: 'Ho degli straordinari da recuperare',
    ),
    CutsceneFrame(
      image: apocalypseScene,
      speaker: mario,
      text: "Signora c'è l'apocalisse zombi qui!",
    ),
    CutsceneFrame(
      image: contractsScene,
      speaker: chiara,
      text: 'Ecco perché non chiudevo più nessun contratto',
    ),
  ];

  static const List<CutsceneFrame> callFrames = <CutsceneFrame>[
    CutsceneFrame(
      image: callScene,
      speaker: chiara,
      text: 'Dai dai speriamo che almeno questo qui risponde',
    ),
    CutsceneFrame(image: phoneScene, speaker: zombie, text: 'Uuh ?'),
    CutsceneFrame(
      image: offerScene,
      speaker: chiara,
      text:
          'Salve, la chiamo per conto di NonPrende Mobile, vorrei offrirvi '
          'ad un prezzo veramente vantaggioso la nostra offerta Fibra Morale',
    ),
    CutsceneFrame(image: roarScene, speaker: zombie, text: 'Aaaarggh !'),
    CutsceneFrame(
      image: roarScene,
      speaker: chiara,
      text: 'Ma che modi sono questi?! Maleducato!',
    ),
    CutsceneFrame(
      image: hangUpScene,
      speaker: chiara,
      text: "Mamma mia... Al giorno d'oggi sono tutti senza cervello...",
    ),
  ];

  /// How many steps Mario takes with Chiara in view before her call
  /// plays: time enough to make her out.
  static const int stepsInView = 3;

  bool _seen = false;
  int _stepsInView = 0;
  bool _played = false;

  /// Where Mario stood when last looked at, to count his steps: not
  /// saved, a step is counted from where he is when the game resumes.
  GridPoint? _lastPosition;

  bool _met = false;
  bool _gone = false;

  /// How close Mario comes, in steps, before they meet: a couple of cells
  /// short of her desk, where she turns and sees him.
  static const int meetingReach = 3;

  bool get callPlayed => _played;
  bool get met => _met;

  /// Whether she has left her desk for the train.
  bool get aboard => _gone;

  @override
  String get key => 'company';

  @override
  void update({required bool turnAnimating}) {
    if (turnAnimating ||
        !host.inPlay ||
        !director.isIdle ||
        progress.level != LevelId.hometown) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (_met && !_gone && placeAt(position)?.id != PlaceId.companyGround) {
      _gone = true;
      return;
    }
    if (!_met &&
        placeAt(position)?.id == PlaceId.companyGround &&
        position.manhattanDistanceTo(chiaraTile) <= meetingReach) {
      _meet();
      return;
    }
    if (_played) {
      return;
    }
    if (!companyWestWing.contains(position)) {
      _lastPosition = null;
      return;
    }
    final inView = host.isTileVisible(chiaraTile);
    final moved = _lastPosition != null && _lastPosition != position;
    _lastPosition = position;
    if (!inView) {
      return;
    }
    if (!_seen) {
      _seen = true;
      return;
    }
    if (moved && ++_stepsInView >= stepsInView) {
      _played = true;
      host
        ..stopWalking()
        ..playCutscene(
          callFrames,
          memories: const <StoryMemory>{StoryMemory.chiaraCall},
          music: Music.weasel,
          onFinished: () => progress.missions.give(Mission.reachSurvivor),
        );
    }
  }

  /// Near her: the meeting, then Mario sends her to the station,
  /// and the mission to reach her is done.
  void _meet() {
    _met = true;
    host
      ..stopWalking()
      ..playCutscene(
        meetingFrames,
        memories: const <StoryMemory>{StoryMemory.chiaraMet},
        music: Music.weasel,
        onFinished: () => say(
          StoryPrompt(
            const <StoryLine>[StoryLine.mario(sendToStation)],
            holdsInput: true,
            onDismissed: () =>
                progress.missions.complete(Mission.reachSurvivor),
          ),
        ),
      );
  }

  @override
  void onEvent(WorldEvent event) {
    if (event case LookedOutEvent(
      :final at,
    ) when at == chiaraTile && _met && !_gone) {
      say(StoryPrompt(const <StoryLine>[seeYouThere]));
    }
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'seen': _seen,
    'steps': _stepsInView,
    'played': _played,
    'met': _met,
    'gone': _gone,
  };

  @override
  void restore(Map<String, Object?> json) {
    _seen = json['seen'] as bool? ?? false;
    _stepsInView = json['steps'] as int? ?? 0;
    _played = json['played'] as bool? ?? false;
    _met = json['met'] as bool? ?? false;
    _gone = json['gone'] as bool? ?? false;
  }
}
