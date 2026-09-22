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
  static const String trustLine =
      'Ragazzo ho deciso di fidarmi di te! Ti parlerò del mio grande piano '
      'per non schiattare';
  static const String meetAtStationLine =
      'Raggiungimi alla stazione, ne parliamo lì!';

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

  /// Luigi finishing off the horde, then his reunion with Mario.
  static const List<CutsceneFrame> reunionScene = <CutsceneFrame>[
    CutsceneFrame(
      image: 'assets/story/scene_luigi_rescue.jpg',
      speaker: luigi,
      text: "Ce l'hai fatta, ragazzo! Adesso me la vedo io con questi qui",
    ),
    CutsceneFrame(
      image: 'assets/story/scene_mario_luigi_reunion.jpg',
      speaker: 'Mario Rossi',
      text: "Sono felice di vedere che c'è qualcun altro vivo e vegeto",
    ),
    CutsceneFrame(
      image: 'assets/story/scene_mario_luigi_reunion.jpg',
      speaker: luigi,
      text:
          'A chi lo dici! Finalmente qualcuno che non prova a mangiarmi il '
          'cervello',
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
  bool _hordeCleared = false;
  bool _reunionPlayed = false;
  bool _luigiGone = false;

  /// True once Luigi has left the shop: the game skips drawing him.
  bool get luigiGone => _luigiGone;

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
      case DiedEvent(entityId: final id)
          when _hordeOut && !_hordeCleared && id.startsWith('mall-zombie-'):
        _checkHordeCleared();
      case _:
        break;
    }
  }

  /// Walking up to the shutter plays Luigi's scene once the step is over;
  /// the zombies come in when it ends. Once the horde is cleared, Luigi's
  /// reunion with Mario plays and he agrees to meet again at the station.
  @override
  void update({required bool turnAnimating}) {
    if (!_luigiScenePlayed) {
      final position = world.player.component<PositionComponent>().position;
      if (luigiSceneTrigger.contains(position) &&
          !turnAnimating &&
          !host.isPromptVisible) {
        _luigiScenePlayed = true;
        progress.remember(StoryMemory.luigiTrapped);
        host.playCutscene(luigiScene, onFinished: _releaseHorde);
      }
      return;
    }
    if (_hordeCleared &&
        !_reunionPlayed &&
        !turnAnimating &&
        !host.isPromptVisible) {
      _reunionPlayed = true;
      progress.remember(StoryMemory.luigiRescued);
      host.playCutscene(reunionScene, onFinished: _startTrustDialogue);
    }
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

  /// True once every zombie of the horde is dead.
  void _checkHordeCleared() {
    final cleared = world.entities.values
        .where((entity) => entity.id.startsWith('mall-zombie-'))
        .every((entity) => !entity.isAlive);
    if (cleared) {
      _hordeCleared = true;
    }
  }

  /// Luigi trusts Mario with his plan, then leaves to wait at the station.
  void _startTrustDialogue() {
    say(
      TutorialPrompt(
        const <TutorialLine>[
          TutorialLine.luigi(trustLine),
          TutorialLine.luigi(meetAtStationLine),
        ],
        onDismissed: () {
          _luigiGone = true;
          host.sendLuigiAway();
        },
      ),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'stepsInside': _stepsInside,
    'voice': _voiceHeard,
    'luigiScene': _luigiScenePlayed,
    'horde': _hordeOut,
    'hordeCleared': _hordeCleared,
    'reunion': _reunionPlayed,
    'luigiGone': _luigiGone,
  };

  @override
  void restore(Map<String, Object?> json) {
    _stepsInside = json['stepsInside'] as int? ?? 0;
    _voiceHeard = json['voice'] as bool? ?? false;
    _luigiScenePlayed = json['luigiScene'] as bool? ?? false;
    _hordeOut = json['horde'] as bool? ?? false;
    _hordeCleared = json['hordeCleared'] as bool? ?? false;
    _reunionPlayed = json['reunion'] as bool? ?? false;
    _luigiGone = json['luigiGone'] as bool? ?? false;
  }
}
