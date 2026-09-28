import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/screen_caption.dart';

/// The work-in-progress screen: the developer at his laptop, and the
/// words saying this part is still to be made. It comes up wherever the
/// game goes no further yet, at every walkable edge of a map that has no
/// next map (`workInProgressEnds`); a tap takes it away and Mario is back
/// a step inside. Every unfinished way out shows this same screen, in any
/// level: see docs/level_pipeline.md, "Strade incomplete".
final class WorkInProgressScreen extends StatelessWidget {
  const WorkInProgressScreen({required this.onBack, super.key});

  static const String image = 'assets/story/placeholders/work_in_progress.jpg';
  static const String message =
      'Vanni deve ancora programmarla questa parte\n'
      'Fagli sapere se ti piace il gioco';

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('work-in-progress'),
      behavior: HitTestBehavior.opaque,
      onTap: onBack,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unit =
              constraints.maxHeight / IntegerResolutionViewport.virtualHeight;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                image,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
              ),
              ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
              ScreenCaption(
                message,
                key: const ValueKey<String>('work-in-progress-caption'),
                unit: unit,
              ),
            ],
          );
        },
      ),
    );
  }
}
