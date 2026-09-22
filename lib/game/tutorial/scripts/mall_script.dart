import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The hypermarket: a few steps in, a voice calls for help and Mario
/// answers; upstairs, walking up to the shutter where Luigi is stuck plays
/// his scene, then zombies pour in through the gate, between Mario and the
/// panel that lifts the shutter.
final class MallScript extends TutorialScript {
  MallScript(super.director);

  static const String mysteryVoice = 'Voce misteriosa';
  static const String helpCall = "Aiuto! C'è qualcuno?! Aiutooo";
  static const String someoneAlive = "Ei ma qui c'è qualcuno ancora vivo!";
  static const String shutterOpened =
      'Hai disattivato il sistema antifurto: la saracinesca si è alzata';
  static const String luigi = 'Luigi Rovaga';

  /// Luigi behind the shutter, then the zombies at Mario's back.
  static const List<CutsceneFrame> luigiScene = <CutsceneFrame>[
    CutsceneFrame(
      image: 'assets/story/scene_luigi_trapped.jpg',
      speaker: luigi,
      text:
          'Mi chiamo Luigi. Sono rimasto bloccato qui per colpa del sistema '
          'antifurto',
    ),
    CutsceneFrame(
      image: 'assets/story/scene_luigi_warning.jpg',
      speaker: luigi,
      text: 'Attenzione! Dietro di te',
    ),
    CutsceneFrame(
      image: 'assets/story/scene_mall_zombies.jpg',
      speaker: 'Zombi',
      text: 'Aaaahhrg!',
    ),
  ];

  /// Steps into the hypermarket before the voice is heard.
  static const int stepsBeforeVoice = 3;

  /// How far Luigi's shouting carries: the zombies come in after it.
  static const int hordeCallRadius = 30;

  int _stepsInside = 0;
  bool _voiceHeard = false;
  bool _luigiScenePlayed = false;
  bool _hordeOut = false;

  @override
  String get key => 'mall';

  @override
  void onEvent(WorldEvent event) {
    switch (event) {
      case MovedEvent(entityId: final id, :final to)
          when id == world.playerId &&
              place(PlaceId.mallGround).bounds.contains(to):
        _stepsInside++;
        if (_stepsInside >= stepsBeforeVoice && !_voiceHeard) {
          _voiceHeard = true;
          say(
            TutorialPrompt(const <TutorialLine>[
              TutorialLine(helpCall, speaker: mysteryVoice),
              TutorialLine.mario(someoneAlive),
            ], delay: TutorialDirector.reactionDelay),
          );
        }
      case ControlUsedEvent():
        say(TutorialPrompt(const <TutorialLine>[TutorialLine(shutterOpened)]));
      case _:
        break;
    }
  }

  /// Walking up to the shutter plays Luigi's scene once the step is over;
  /// the zombies come in when it ends.
  @override
  void update({required bool turnAnimating}) {
    if (_luigiScenePlayed || turnAnimating || host.isPromptVisible) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (!luigiSceneTrigger.contains(position)) {
      return;
    }
    _luigiScenePlayed = true;
    progress.remember(StoryMemory.luigiTrapped);
    host.playCutscene(luigiScene, onFinished: _releaseHorde);
  }

  /// Zombies at the gate, drawn by Luigi's shouting towards Mario.
  void _releaseHorde() {
    if (_hordeOut) {
      return;
    }
    _hordeOut = true;
    final occupied = world.occupiedPoints();
    var index = 0;
    for (final spawn in mallHordeSpawns) {
      if (!occupied.contains(spawn)) {
        host.spawnZombie(createMallZombie('mall-zombie-${index++}', spawn));
      }
    }
    world.emitNoise(
      origin: world.player.component<PositionComponent>().position,
      radius: hordeCallRadius,
      sourceEntityId: world.playerId,
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'stepsInside': _stepsInside,
    'voice': _voiceHeard,
    'luigiScene': _luigiScenePlayed,
    'horde': _hordeOut,
  };

  @override
  void restore(Map<String, Object?> json) {
    _stepsInside = json['stepsInside'] as int? ?? 0;
    _voiceHeard = json['voice'] as bool? ?? false;
    _luigiScenePlayed = json['luigiScene'] as bool? ?? false;
    _hordeOut = json['horde'] as bool? ?? false;
  }
}
