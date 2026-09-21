import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/input/touch_controls.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'package:stepbound/ui/title_splash.dart';

/// The main menu first; a new game then plays the story scenes, the title
/// card and the protagonist's line before the controls appear, while a
/// loaded game goes straight to playing.
enum _Phase { menu, story, title, outbreak, dialogue, playing }

final class StepboundApp extends StatefulWidget {
  const StepboundApp({this.saves, this.audio, super.key});

  /// Where the four save slots live; the device storage when null.
  final SaveRepository? saves;

  /// The sound of the game; silent when null.
  final GameAudio? audio;

  @override
  State<StepboundApp> createState() => _StepboundAppState();
}

final class _StepboundAppState extends State<StepboundApp> {
  static const int baseSeed = 20260920;
  late final SaveRepository _saves =
      widget.saves ?? PreferencesSaveRepository();
  late final GameAudio _audio = widget.audio ?? SilentAudio();

  /// Pauses the sound while the app is in the background.
  late final AppLifecycleListener _lifecycle;
  StepboundGame? _game;
  _Phase _phase = _Phase.menu;
  int _restartCount = 0;

  /// The slot this game saves into at campfires.
  int _slot = 1;

  /// Whether the current slot holds a campfire save to resume after dying.
  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: _audio.pause,
      onShow: _audio.resume,
    );
    _audio.playMusic(Music.menu);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _newGame(int slot) async {
    await _saves.clear(slot);
    _audio.playMusic(Music.story);
    setState(() {
      _slot = slot;
      _hasSave = false;
      _restartCount = 0;
      _phase = _Phase.story;
    });
  }

  void _loadGame(SaveGame save) {
    setState(() {
      _slot = save.slot;
      _hasSave = true;
      _game = _gameFrom(save);
      _phase = _Phase.playing;
    });
  }

  StepboundGame _gameFrom(SaveGame save) => StepboundGame(
    world: WorldState.fromJson(save.world),
    tutorialState: save.tutorial,
    unlocked: <HudElement>{
      for (final name in save.hud)
        for (final element in HudElement.values)
          if (element.name == name) element,
    },
    onRest: _store,
    audio: _audio,
  );

  /// Called by the game when Mario rests at a campfire.
  Future<void> _store(GameSnapshot snapshot) async {
    await _saves.save(
      SaveGame(
        slot: _slot,
        savedAt: DateTime.now(),
        place: snapshot.place,
        world: snapshot.world,
        tutorial: snapshot.tutorial,
        hud: snapshot.hud,
      ),
    );
    _hasSave = true;
  }

  void _finishIntro() {
    setState(() => _phase = _Phase.title);
  }

  void _finishTitle() {
    setState(() => _phase = _Phase.outbreak);
  }

  void _finishOutbreak() {
    setState(() {
      _phase = _Phase.dialogue;
      _game = StepboundGame(onRest: _store, audio: _audio)..inputLocked = true;
    });
  }

  void _finishDialogue() {
    setState(() {
      _phase = _Phase.playing;
      _game?.inputLocked = false;
    });
  }

  /// After dying: back to the last campfire if there is one, otherwise the
  /// start of the level.
  Future<void> _restartGame() async {
    final save = _hasSave ? await _saves.load(_slot) : null;
    if (!mounted) {
      return;
    }
    setState(() {
      _restartCount += 1;
      _game = save != null
          ? _gameFrom(save)
          : StepboundGame(
              seed: baseSeed + _restartCount,
              onRest: _store,
              audio: _audio,
            );
      _phase = _Phase.playing;
    });
  }

  void _backToMenu() {
    _audio
      ..silenceAmbience()
      ..playMusic(Music.menu);
    setState(() {
      _game = null;
      _phase = _Phase.menu;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return MaterialApp(
      title: 'Stepbound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff111718),
      ),
      // Browsers only start sound after a tap: the first one lets it play.
      home: Listener(
        onPointerDown: (_) => _audio.unlock(),
        child: AudioScope(audio: _audio, child: _surface(game)),
      ),
    );
  }

  Widget _surface(StepboundGame? game) {
    return ColoredBox(
      key: const ValueKey<String>('stepbound-game-surface'),
      color: const Color(0xff111718),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = IntegerResolutionViewport.scaleFor(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          return Center(
            child: SizedBox(
              width: IntegerResolutionViewport.virtualWidth * scale,
              height: IntegerResolutionViewport.virtualHeight * scale,
              child: switch (_phase) {
                _Phase.menu => MainMenu(
                  saves: _saves,
                  onNewGame: (slot) => unawaited(_newGame(slot)),
                  onLoad: _loadGame,
                ),
                _Phase.story => StoryIntro(onFinished: _finishIntro),
                _Phase.title => TitleSplash(onFinished: _finishTitle),
                _Phase.outbreak => StoryIntro(
                  key: const ValueKey<String>('outbreak-story'),
                  scenes: outbreakScenes,
                  fadeOutAtEnd: true,
                  onFinished: _finishOutbreak,
                ),
                _Phase.dialogue || _Phase.playing when game != null => Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    GameWidget<StepboundGame>(
                      key: const ValueKey<String>('stepbound-game'),
                      game: game,
                    ),
                    if (_phase == _Phase.dialogue) ...<Widget>[
                      GameplayDialogue(onFinished: _finishDialogue),
                      const BlackFade(
                        key: ValueKey<String>('gameplay-fade-in'),
                        toBlack: false,
                      ),
                    ] else
                      // Hidden whenever a text box is on screen, so the
                      // buttons never show through it.
                      ValueListenableBuilder<List<TutorialLine>?>(
                        valueListenable: game.prompt,
                        builder: (context, lines, _) => lines == null
                            ? TouchControls(game: game)
                            : const SizedBox.shrink(),
                      ),
                    if (_phase == _Phase.playing)
                      ValueListenableBuilder<List<TutorialLine>?>(
                        valueListenable: game.prompt,
                        builder: (context, lines, _) {
                          if (lines == null) {
                            return const SizedBox.shrink();
                          }
                          return GameplayDialogue(
                            // A fresh state for every prompt restarts it
                            // from its first line.
                            key: ObjectKey(lines),
                            lines: <DialogueLine>[
                              for (final line in lines)
                                DialogueLine(
                                  speaker: line.speaker,
                                  text: line.text,
                                  portrait: line.portrait,
                                ),
                            ],
                            onFinished: game.dismissPrompt,
                          );
                        },
                      ),
                    ValueListenableBuilder<bool>(
                      valueListenable: game.gameOver,
                      builder: (context, isGameOver, _) {
                        if (!isGameOver) {
                          return const SizedBox.shrink();
                        }
                        return _GameOverOverlay(
                          fromSave: _hasSave,
                          onRestart: () => unawaited(_restartGame()),
                          onMenu: _backToMenu,
                        );
                      },
                    ),
                  ],
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          );
        },
      ),
    );
  }
}

final class _GameOverOverlay extends StatefulWidget {
  const _GameOverOverlay({
    required this.fromSave,
    required this.onRestart,
    required this.onMenu,
  });

  /// True when the restart goes back to the last campfire.
  final bool fromSave;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

final class _GameOverOverlayState extends State<_GameOverOverlay> {
  static const autoRestartSeconds = 60;
  Timer? _timer;
  int _secondsLeft = autoRestartSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsLeft -= 1;
      });
      if (_secondsLeft <= 0) {
        timer.cancel();
        widget.onRestart();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / 216
            : 1.0;
        return ColoredBox(
          key: const ValueKey<String>('game-over-overlay'),
          color: const Color(0xc2180e0c),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Grows with the view, like the dialogue text.
                BloodyTitle('GAME OVER', fontSize: 34 * unit),
                SizedBox(height: 4 * unit),
                TextButton(
                  key: const ValueKey<String>('restart-button'),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xdd4a2823),
                    foregroundColor: const Color(0xffe4705f),
                    side: const BorderSide(color: Color(0xffe4705f), width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    _timer?.cancel();
                    AudioScope.of(context).play(Sfx.uiClick);
                    widget.onRestart();
                  },
                  child: Text(
                    widget.fromSave
                        ? 'RIPRENDI DAL FALÒ ($_secondsLeft)'
                        : 'RICOMINCIA ($_secondsLeft)',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 6 * unit),
                TextButton(
                  key: const ValueKey<String>('menu-button'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xffd8cfbf),
                  ),
                  onPressed: () {
                    _timer?.cancel();
                    AudioScope.of(context).play(Sfx.uiClick);
                    widget.onMenu();
                  },
                  child: const Text(
                    'MENÙ PRINCIPALE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
