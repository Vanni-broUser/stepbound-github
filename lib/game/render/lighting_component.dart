import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;

/// Dim indoor lighting: the room is plunged into darkness and each ceiling
/// lamp cuts a stepped pool of light out of it, pixel-art style (hard rings,
/// no gradients). Flickering lamps die out now and then. The player carries
/// a faint halo so they never vanish in the shadows.
final class LightingComponent extends Component {
  LightingComponent({
    required this.area,
    required this.lights,
    required this.playerPosition,
    this.darkness = PlaceSpec.defaultDarkness,
    this.tileSize = 16,
  }) : super(priority: 28);

  /// The lit room, in world pixels.
  final ui.Rect area;

  /// Cleared by the game while the room is out of the camera's view: its
  /// darkness is a full-room layer, costly to compose every frame.
  bool onScreen = true;
  final List<LightSpot> lights;

  /// Feet of the player, in world pixels.
  final Vector2 Function() playerPosition;
  final double tileSize;

  /// How dark the room is between its lights.
  final double darkness;

  /// (radius, how much of the darkness it removes) from outer to inner.
  static const List<(double, double)> _lampRings = <(double, double)>[
    (34, 0.3),
    (25, 0.45),
    (16, 0.66),
  ];

  /// A torch reaches further and burns brighter than a ceiling lamp.
  static const List<(double, double)> _torchRings = <(double, double)>[
    (50, 0.34),
    (38, 0.52),
    (26, 0.74),
  ];
  static const List<(double, double)> _playerRings = <(double, double)>[
    (22, 0.28),
    (13, 0.5),
  ];

  late final ui.Paint _dark = ui.Paint()
    ..color = ui.Color.fromRGBO(2, 2, 8, darkness)
    ..isAntiAlias = false;
  final ui.Paint _cut = ui.Paint()
    ..blendMode = ui.BlendMode.dstOut
    ..isAntiAlias = false;
  final ui.Paint _warm = ui.Paint()..isAntiAlias = false;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  /// 1 when lit, briefly near 0 when a flickering lamp stutters; a torch
  /// breathes gently with its flame instead.
  double _intensity(LightSpot light, int index) {
    if (light.torch) {
      return 0.9 + 0.1 * math.sin(_time * 7.3 + index * 1.7);
    }
    if (!light.flickers) {
      return 1;
    }
    final noise =
        math.sin(_time * 21 + index * 3.1) * math.sin(_time * 6.7 + index);
    return noise > 0.55 ? 0.12 : 1;
  }

  void _pool(
    ui.Canvas canvas,
    ui.Offset center,
    List<(double, double)> rings,
    double intensity,
  ) {
    for (final (radius, strength) in rings) {
      _cut.color = ui.Color.fromRGBO(0, 0, 0, strength * intensity);
      canvas.drawCircle(center, radius, _cut);
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (!onScreen) {
      return;
    }
    canvas
      ..saveLayer(area, ui.Paint())
      ..drawRect(area, _dark);
    for (var i = 0; i < lights.length; i++) {
      final light = lights[i];
      final center = ui.Offset(
        light.tile.x * tileSize + tileSize / 2,
        light.tile.y * tileSize + tileSize / 2,
      );
      _pool(
        canvas,
        center,
        light.torch ? _torchRings : _lampRings,
        _intensity(light, i),
      );
    }
    final feet = playerPosition();
    _pool(canvas, ui.Offset(feet.x, feet.y - 10), _playerRings, 1);
    canvas.restore();

    // A warm tint under each working lamp, an orange one round a torch.
    for (var i = 0; i < lights.length; i++) {
      final light = lights[i];
      final intensity = _intensity(light, i);
      _warm.color = light.torch
          ? ui.Color.fromRGBO(255, 150, 60, 0.1 * intensity)
          : ui.Color.fromRGBO(255, 200, 120, 0.07 * intensity);
      canvas.drawCircle(
        ui.Offset(
          light.tile.x * tileSize + tileSize / 2,
          light.tile.y * tileSize + tileSize / 2,
        ),
        light.torch ? 30 : 20,
        _warm,
      );
    }
  }
}
