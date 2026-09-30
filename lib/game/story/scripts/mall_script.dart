import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// The hypermarket: a few steps in, a voice calls for help and Mario
/// answers; upstairs, walking up to the shutter where Luigi is stuck plays
/// his scene, then zombies pour in through the gate, between Mario and the
/// panel that lifts the shutter. Getting to the panel through them is what
/// saves Luigi: out of his shop, with his axe, he sees off whatever is
/// left of the horde himself.
final class MallScript extends StoryScript {
  MallScript(super.director);

  static String get mysteryVoice => strings.speakerMysteryVoice;
  static String get helpCall => strings.mallHelpCall;
  static String get someoneAlive => strings.mallSomeoneAlive;
  static String get shutterOpened => strings.mallShutterOpened;
  static const String luigi = 'Luigi Rovaga';
  static String get trustLine => strings.mallTrustLine;
  static String get meetAtStationLine => strings.mallMeetAtStationLine;

  /// Luigi behind the shutter, then the zombies at Mario's back.
  static List<CutsceneFrame> get luigiScene => <CutsceneFrame>[
    CutsceneFrame(
      image: 'assets/story/scenes/luigi_trapped.jpg',
      speaker: luigi,
      text: strings.mallLuigiScene1,
    ),
    CutsceneFrame(
      image: 'assets/story/scenes/luigi_warning.jpg',
      speaker: luigi,
      text: strings.mallLuigiScene2,
    ),
    CutsceneFrame(
      image: 'assets/story/scenes/mall_zombies.jpg',
      speaker: strings.speakerZombie,
      text: strings.mallLuigiScene3,
    ),
  ];

  /// Luigi finishing off the horde, then his reunion with Mario.
  static List<CutsceneFrame> get reunionScene => <CutsceneFrame>[
    CutsceneFrame(
      image: 'assets/story/scenes/luigi_rescue.jpg',
      speaker: luigi,
      text: strings.mallReunionScene1,
    ),
    CutsceneFrame(
      image: 'assets/story/scenes/mario_luigi_reunion.jpg',
      speaker: 'Mario Rossi',
      text: strings.mallReunionScene2,
    ),
    CutsceneFrame(
      image: 'assets/story/scenes/mario_luigi_reunion.jpg',
      speaker: luigi,
      text: strings.mallReunionScene3,
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
            StoryPrompt(<StoryLine>[
              StoryLine(helpCall, speaker: mysteryVoice),
              StoryLine.mario(someoneAlive),
            ], delay: StoryDirector.reactionDelay),
          );
        }
      case ControlUsedEvent():
        // The scene follows, so the flag waits for the box to be read:
        // otherwise the pictures would cover the news of the shutter.
        say(
          StoryPrompt(<StoryLine>[
            StoryLine(shutterOpened),
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
        host.playCutscene(
          luigiScene,
          memories: const <StoryMemory>{StoryMemory.luigiTrapped},
          onFinished: () {
            progress.missions.give(Mission.freeLuigi);
            if (_shutterOpen) {
              // Mario lifted the shutter before walking up to it: Luigi
              // is already free, and the corner says so before the
              // reunion.
              progress.missions.complete(Mission.freeLuigi);
            }
            director.foundSurvivor();
            _releaseHorde();
          },
        );
      }
      return;
    }
    if (_shutterOpen &&
        !_reunionPlayed &&
        !turnAnimating &&
        !host.isPromptVisible &&
        !host.missionsSettling) {
      _reunionPlayed = true;
      host.playCutscene(
        reunionScene,
        memories: const <StoryMemory>{StoryMemory.luigiRescued},
        music: Music.luigi,
        onFinished: _luigiTakesOver,
      );
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

  /// Luigi trusts Mario with his plan, then leaves to wait at the station:
  /// he is free, and the next thing to do is to join him there.
  void _startTrustDialogue() {
    say(
      StoryPrompt(
        <StoryLine>[
          StoryLine.luigi(trustLine),
          StoryLine.luigi(meetAtStationLine),
        ],
        onDismissed: () {
          progress.missions
            ..complete(Mission.freeLuigi)
            ..give(Mission.reachLuigi);
          _luigiGone = true;
          host.hometown.sendLuigiAway();
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
