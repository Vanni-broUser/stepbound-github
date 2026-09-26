import 'dart:ui';

import 'package:flame/components.dart';

/// Something the game stops drawing while the camera cannot see it. Flame
/// draws every component of the world every frame, wherever it is: the
/// fires of a whole city are thousands of small rectangles a frame, spent
/// on streets nobody is looking at. Its children go with it (a torch's
/// flame); its updates go on, so an animation stays in step.
mixin OffscreenCulled on Component {
  /// Cleared by the game while [reach] lies outside the camera's view.
  bool onScreen = true;

  /// Everything this draws into, children included, in world pixels.
  Rect get reach;

  @override
  void renderTree(Canvas canvas) {
    if (onScreen) {
      super.renderTree(canvas);
    }
  }
}
