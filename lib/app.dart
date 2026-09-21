import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/game/input/touch_controls.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/ui/story_intro.dart';

enum AppFlavor { dev, prod }

final class StepboundApp extends StatefulWidget {
  const StepboundApp({required this.flavor, super.key});

  final AppFlavor flavor;

  @override
  State<StepboundApp> createState() => _StepboundAppState();
}

final class _StepboundAppState extends State<StepboundApp> {
  static const int baseSeed = 20260920;
  StepboundGame? _game;
  bool _introFinished = false;
  int _restartCount = 0;

  void _finishIntro() {
    setState(() {
      _introFinished = true;
      _game = StepboundGame();
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
                child: !_introFinished || game == null
                    ? StoryIntro(onFinished: _finishIntro)
                    : Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          GameWidget<StepboundGame>(
                            key: const ValueKey<String>('stepbound-game'),
                            game: game,
                          ),
                          TouchControls(game: game),
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
    return ColoredBox(
      key: const ValueKey<String>('game-over-overlay'),
      color: const Color(0xc2180e0c),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Color(0xffe4705f),
                fontFamily: 'monospace',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "L'orda ti ha raggiunto",
              style: TextStyle(
                color: Color(0xffd8cfbf),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
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
  }
}
