import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/screen_caption.dart';

/// Temporary end of the playable build. A tap returns to the Europe map.
final class RomePlaceholder extends StatelessWidget {
  const RomePlaceholder({required this.onBack, super.key});

  static const String image = 'assets/story/rome_placeholder.jpg';
  static const String message =
      'Vanni deve ancora programmarla questa parte\n'
      'Fagli sapere se ti piace il gioco';

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('rome-placeholder'),
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
                key: const ValueKey<String>('rome-placeholder-caption'),
                unit: unit,
              ),
            ],
          );
        },
      ),
    );
  }
}
