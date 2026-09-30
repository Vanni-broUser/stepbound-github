import 'dart:ui' as ui;

import 'package:flame/components.dart';

/// Someone standing on the floor: drawn in front of whoever stands further
/// north, whatever order the two came into the world in.
mixin StandsOnFloor on PositionComponent {
  /// How far south their feet are, in world pixels.
  double get feetY => position.y;
}

/// The game's world, drawing the characters by where their feet are.
///
/// A character is taller than its cell: whoever stands one row south of
/// someone covers their legs with the head. With one priority for them all
/// they would be drawn in the order they were added, so Mario could stand
/// over the head of a cultist in front of him. They all share a priority,
/// so they come one after the other among the world's children: that run
/// is sorted by [StandsOnFloor.feetY] before it is drawn.
final class DepthSortedWorld extends World {
  final List<StandsOnFloor> _standing = <StandsOnFloor>[];

  @override
  void renderChild(ui.Canvas canvas, Component child) {
    if (child is StandsOnFloor) {
      _standing.add(child);
      return;
    }
    _drawStanding(canvas);
    super.renderChild(canvas, child);
  }

  @override
  void afterChildrenRendered(ui.Canvas canvas) {
    _drawStanding(canvas);
    super.afterChildrenRendered(canvas);
  }

  void _drawStanding(ui.Canvas canvas) {
    if (_standing.isEmpty) {
      return;
    }
    // Insertion sort: a handful of characters, and it is stable, so two
    // on the same row keep the order they were added in.
    for (var i = 1; i < _standing.length; i++) {
      final character = _standing[i];
      var j = i - 1;
      while (j >= 0 && _standing[j].feetY > character.feetY) {
        _standing[j + 1] = _standing[j];
        j--;
      }
      _standing[j + 1] = character;
    }
    for (final character in _standing) {
      super.renderChild(canvas, character);
    }
    _standing.clear();
  }
}
