import 'package:flutter/widgets.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';

/// Lays [child] out on the 16:9 picture in the middle of the screen, the
/// shape story frames and menus are drawn for, and paints [color] over the
/// whole screen behind it: the bands beside the picture get the same
/// backdrop as the picture, so a cover over the full-screen game hides (or
/// dims) all of it.
final class Letterbox extends StatelessWidget {
  const Letterbox({required this.color, required this.child, super.key});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = IntegerResolutionViewport.scaleFor(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        return ColoredBox(
          color: color,
          child: Center(
            child: SizedBox(
              width: IntegerResolutionViewport.virtualWidth * scale,
              height: IntegerResolutionViewport.virtualHeight * scale,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
