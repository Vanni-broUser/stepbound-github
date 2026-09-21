import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/game/input/touch_controls.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/gameplay_dialogue.dart';
import 'package:stepbound/ui/story_intro.dart';
import 'package:stepbound/ui/title_splash.dart';

enum AppFlavor { dev, prod }

/// Opening flow: story scenes, title card, then the protagonist talks over
/// the game before the controls appear.
enum _Phase { story, title, outbreak, dialogue, playing }

final class StepboundApp extends StatefulWidget {
  const StepboundApp({required this.flavor, super.key});

  final AppFlavor flavor;

  @override
  State<StepboundApp> createState() => _StepboundAppState();
}

final class _StepboundAppState extends State<StepboundApp> {
  static const int baseSeed = 20260920;
  StepboundGame? _game;
  _Phase _phase = _Phase.story;
  int _restartCount = 0;

  void _finishIntro() {
    setState(() => _phase = _Phase.title);
  }

  void _finishTitle() {
    setState(() => _phase = _Phase.outbreak);
  }

  void _finishOutbreak() {
    setState(() {
      _phase = _Phase.dialogue;
      _game = StepboundGame()..inputLocked = true;
    });
  }

  void _finishDialogue() {
    setState(() {
      _phase = _Phase.playing;
      _game?.inputLocked = false;
    });
  }

  void _restartGame() {
    setState(() {
      _restartCount += 1;
      _game = StepboundGame(seed: baseSeed + _restartCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return MaterialApp(
      title: 'Stepbound',
      debugShowCheckedModeBanner: widget.flavor == AppFlavor.dev,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff111718),
      ),
      home: ColoredBox(
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
                        TouchControls(game: game),
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
                          return _GameOverOverlay(onRestart: _restartGame);
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
      ),
    );
  }
}

final class _GameOverOverlay extends StatefulWidget {
  const _GameOverOverlay({required this.onRestart});

  final VoidCallback onRestart;

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

final class _GameOverOverlayState extends State<_GameOverOverlay> {
  static const autoRestartSeconds = 4;
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
                SizedBox(height: 34 * unit),
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
                    widget.onRestart();
                  },
                  child: Text(
                    'RICOMINCIA ($_secondsLeft)',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
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
