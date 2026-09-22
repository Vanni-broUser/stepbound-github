import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The hypermarket: a few steps in, a voice calls for help and Mario
/// answers; upstairs, walking up to the shutter where Luigi is stuck plays
/// his scene, then zombies pour in through the gate, between Mario and the
/// panel that lifts the shutter. Getting to the panel through them is what
/// saves Luigi: out of his shop, with his axe, he sees off whatever is
/// left of the horde himself.
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

  /// The ids of the zombies that come in through the gate.
  static const String hordePrefix = 'mall-zombie-';

  int _stepsInside = 0;
  bool _voiceHeard = false;
  bool _luigiScenePlayed = false;
  bool _hordeOut = false;
  bool _shutterOpen = false;
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
        // The scene follows, so the flag waits for the box to be read:
        // otherwise the pictures would cover the news of the shutter.
        say(
          TutorialPrompt(const <TutorialLine>[
            TutorialLine(shutterOpened),
          ], onDismissed: () => _shutterOpen = true),
        );
      case _:
        break;
    }
  }

  /// Walking up to the shutter plays Luigi's scene once the step is over;
  /// the zombies come in when it ends. Lifting the shutter frees him:
  /// their reunion plays, he cuts down what is left of the horde, and he
  /// agrees to meet again at the station.
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
    if (_shutterOpen &&
        !_reunionPlayed &&
        !turnAnimating &&
        !host.isPromptVisible) {
      _reunionPlayed = true;
      progress.remember(StoryMemory.luigiRescued);
      host.playCutscene(reunionScene, onFinished: _luigiTakesOver);
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
        host.spawnZombie(createMallZombie('$hordePrefix${index++}', spawn));
      }
    }
    world.emitNoise(
      origin: world.player.component<PositionComponent>().position,
      radius: hordeCallRadius,
      sourceEntityId: world.playerId,
    );
  }

  /// What the reunion's first picture shows: free at last, Luigi puts down
  /// whatever Mario left of the horde. Then he talks.
  void _luigiTakesOver() {
    host.killZombies(<String>[
      for (final entity in world.entities.values)
        if (entity.id.startsWith(hordePrefix) && entity.isAlive) entity.id,
    ]);
    _startTrustDialogue();
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
    'shutter': _shutterOpen,
    'reunion': _reunionPlayed,
    'luigiGone': _luigiGone,
  };

  @override
  void restore(Map<String, Object?> json) {
    _stepsInside = json['stepsInside'] as int? ?? 0;
    _voiceHeard = json['voice'] as bool? ?? false;
    _luigiScenePlayed = json['luigiScene'] as bool? ?? false;
    _hordeOut = json['horde'] as bool? ?? false;
    _shutterOpen = json['shutter'] as bool? ?? false;
    _reunionPlayed = json['reunion'] as bool? ?? false;
    _luigiGone = json['luigiGone'] as bool? ?? false;
  }
}
