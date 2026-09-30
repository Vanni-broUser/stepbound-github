import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The company past the palazzo: walking up the west wing from the gate,
/// Mario comes to see Chiara through the glass, at a workstation in the
/// east wing. A few steps more with her in view and her phone call plays;
/// then there is someone to reach, the long way round by the floor above.
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

  bool get callPlayed => _played;

  @override
  String get key => 'company';

  @override
  void update({required bool turnAnimating}) {
    if (_played ||
        turnAnimating ||
        !host.inPlay ||
        !director.isIdle ||
        progress.level != LevelId.hometown) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
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
          onFinished: () => progress.missions.give(Mission.reachSurvivor),
        );
    }
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'seen': _seen,
    'steps': _stepsInView,
    'played': _played,
  };

  @override
  void restore(Map<String, Object?> json) {
    _seen = json['seen'] as bool? ?? false;
    _stepsInView = json['steps'] as int? ?? 0;
    _played = json['played'] as bool? ?? false;
  }
}
