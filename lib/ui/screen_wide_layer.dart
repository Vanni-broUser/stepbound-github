import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lays [child] out as wide as the screen and as tall as the game picture,
/// centred on it: on a phone longer than 16:9 the touch controls and the
/// dialogue box spread into the bands beside the picture instead of
/// covering it. Only sideways: on a tablet the bands above and below stay
/// empty, and nothing grows with the screen's height.
///
/// The safe area comes out the same on both sides, the larger of the two,
/// so a camera cutout on one edge does not push the buttons on that side
/// further in than the others. Top and bottom keep only what the band
/// above or below the picture does not already clear.
final class ScreenWideLayer extends StatelessWidget {
  const ScreenWideLayer({
    required this.pictureHeight,
    required this.child,
    super.key,
  });

  final double pictureHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final band = math.max(0, (constraints.maxHeight - pictureHeight) / 2);
        final padding = symmetricPadding(media.padding, band: band.toDouble());
        return Center(
          child: SizedBox(
            width: constraints.maxWidth,
            height: pictureHeight,
            child: MediaQuery(
              data: media.copyWith(
                padding: padding,
                viewPadding: symmetricPadding(
                  media.viewPadding,
                  band: band.toDouble(),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// [padding] with both sides at the larger of the two, and the top and
  /// bottom less the [band] between the picture and the screen's edge.
  static EdgeInsets symmetricPadding(EdgeInsets padding, {double band = 0}) {
    final side = math.max(padding.left, padding.right);
    return EdgeInsets.fromLTRB(
      side,
      math.max(0, padding.top - band),
      side,
      math.max(0, padding.bottom - band),
    );
  }
}
