import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/stepbound_game.dart';

enum AppFlavor { dev, prod }

final class StepboundApp extends StatefulWidget {
  const StepboundApp({required this.flavor, super.key});

  final AppFlavor flavor;

  @override
  State<StepboundApp> createState() => _StepboundAppState();
}

final class _StepboundAppState extends State<StepboundApp> {
  late final StepboundGame _game = StepboundGame();

  @override
  Widget build(BuildContext context) {
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
                child: GameWidget<StepboundGame>(
                  key: const ValueKey<String>('stepbound-game'),
                  game: _game,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
