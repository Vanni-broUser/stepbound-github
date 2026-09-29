import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;

/// Dim indoor lighting: the room is plunged into darkness and each ceiling
/// lamp cuts a stepped pool of light out of it, pixel-art style (hard rings,
/// no gradients). Flickering lamps die out now and then. The player carries
/// a faint halo so they never vanish in the shadows.
///
/// Cutting the pools out of the darkness takes a layer: a room's worth of
/// darkness composed off screen, every ring of every lamp blended into it,
/// every frame. On the cheapest phone we support that layer is the most
/// expensive thing on screen, so the darkness with its steady lamps is
/// composed once, into an image the size of the room, and drawn from there
/// (see [_bake]). Only what changes from frame to frame is still cut live:
/// the flickering lamps, the torches and the player's halo, each in a
/// layer no bigger than its own pool.
final class LightingComponent extends Component {
  LightingComponent({
    required this.area,
    required this.lights,
    required this.playerPosition,
    this.darkness = PlaceSpec.defaultDarkness,
    this.litAreas = const <ui.Rect>[],
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

  /// Where no darkness falls at all, in world pixels: cut out whole, so
  /// they cost nothing once the darkness is composed.
  final List<ui.Rect> litAreas;

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

  /// How high over the feet the player's halo is centred.
  static const double _haloRise = 10;

  late final ui.Paint _dark = ui.Paint()
    ..color = ui.Color.fromRGBO(2, 2, 8, darkness)
    ..isAntiAlias = false;
  final ui.Paint _cut = ui.Paint()
    ..blendMode = ui.BlendMode.dstOut
    ..isAntiAlias = false;
  final ui.Paint _clear = ui.Paint()
    ..blendMode = ui.BlendMode.dstOut
    ..color = const ui.Color(0xff000000)
    ..isAntiAlias = false;
  final ui.Paint _warm = ui.Paint()..isAntiAlias = false;
  final ui.Paint _image = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;
  double _time = 0;

  /// The darkness with the steady lamps cut out of it, once composed.
  ui.Image? _baked;
  bool _removed = false;

  /// The lamps whose light changes from frame to frame, grouped wherever
  /// their pools overlap: each group is cut in one layer, as they all
  /// were before, so overlapping pools still add up the same way.
  late final List<_LiveGroup> _live = _groupLive();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final baked = await _bake();
    // Taken out of the world while it was being composed.
    if (_removed) {
      baked.dispose();
      return;
    }
    _baked = baked;
  }

  @override
  void onRemove() {
    _removed = true;
    _baked?.dispose();
    _baked = null;
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  /// Whether [light]'s pool changes from frame to frame.
  static bool _isLive(LightSpot light) => light.torch || light.flickers;

  ui.Offset _centre(LightSpot light) => ui.Offset(
    light.tile.x * tileSize + tileSize / 2,
    light.tile.y * tileSize + tileSize / 2,
  );

  List<(double, double)> _rings(LightSpot light) =>
      light.torch ? _torchRings : _lampRings;

  /// The world pixels [light]'s pool can touch.
  ui.Rect _reach(LightSpot light) => ui.Rect.fromCircle(
    center: _centre(light),
    radius: _rings(light)[0].$1 + 1,
  );

  List<_LiveGroup> _groupLive() {
    final groups = <_LiveGroup>[];
    for (final (index, light) in lights.indexed) {
      if (!_isLive(light)) {
        continue;
      }
      var group = _LiveGroup(_reach(light), <int>[index]);
      // Pulls in every group it touches, and every group those touch.
      var merged = true;
      while (merged) {
        merged = false;
        for (final other in groups.toList()) {
          if (other.rect.overlaps(group.rect)) {
            groups.remove(other);
            group = _LiveGroup(group.rect.expandToInclude(other.rect), <int>[
              ...group.lights,
              ...other.lights,
            ]);
            merged = true;
          }
        }
      }
      groups.add(group);
    }
    return groups;
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

  void _clearLitAreas(ui.Canvas canvas) {
    for (final lit in litAreas) {
      canvas.drawRect(lit, _clear);
    }
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

  /// The room's darkness with every steady lamp's pool cut out of it, as
  /// an image the size of the room, in world pixels: scaled up with the
  /// rest of the picture, so its rings stay on the same pixel grid as the
  /// tiles they fall on.
  Future<ui.Image> _bake() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..translate(-area.left, -area.top)
      ..saveLayer(area, ui.Paint())
      ..drawRect(area, _dark);
    _clearLitAreas(canvas);
    for (final light in lights) {
      if (!_isLive(light)) {
        _pool(canvas, _centre(light), _rings(light), 1);
      }
    }
    canvas.restore();
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      area.width.round(),
      area.height.round(),
    );
    picture.dispose();
    return image;
  }

  @override
  void render(ui.Canvas canvas) {
    if (!onScreen) {
      return;
    }
    final feet = playerPosition();
    final halo = ui.Offset(feet.x, feet.y - _haloRise);
    final baked = _baked;
    if (baked == null) {
      _renderLive(canvas, halo);
    } else {
      _renderBaked(canvas, baked, halo);
    }
    _renderWarmth(canvas);
  }

  /// Everything cut in one layer: until the darkness is composed.
  void _renderLive(ui.Canvas canvas, ui.Offset halo) {
    canvas
      ..saveLayer(area, ui.Paint())
      ..drawRect(area, _dark);
    _clearLitAreas(canvas);
    for (final (index, light) in lights.indexed) {
      _pool(canvas, _centre(light), _rings(light), _intensity(light, index));
    }
    _pool(canvas, halo, _playerRings, 1);
    canvas.restore();
  }

  /// The composed darkness, except where a live pool falls: there the
  /// darkness is drawn again into a small layer and the pool cut out of it.
  void _renderBaked(ui.Canvas canvas, ui.Image baked, ui.Offset halo) {
    // The player's halo joins whichever live groups it touches, so a halo
    // over a torch cuts into the same layer as the torch.
    var haloRect = ui.Rect.fromCircle(
      center: halo,
      radius: _playerRings[0].$1 + 1,
    );
    final haloLights = <int>[];
    final apart = <_LiveGroup>[];
    var merged = true;
    var pending = _live;
    while (merged) {
      merged = false;
      final rest = <_LiveGroup>[];
      for (final group in pending) {
        if (group.rect.overlaps(haloRect)) {
          haloRect = haloRect.expandToInclude(group.rect);
          haloLights.addAll(group.lights);
          merged = true;
        } else {
          rest.add(group);
        }
      }
      pending = rest;
    }
    apart.addAll(pending);
    final patches = <(ui.Rect, List<int>, bool)>[
      for (final group in apart)
        (group.rect.intersect(area), group.lights, false),
      (haloRect.intersect(area), haloLights, true),
    ];

    canvas.save();
    for (final (rect, _, _) in patches) {
      if (!rect.isEmpty) {
        canvas.clipRect(rect, clipOp: ui.ClipOp.difference, doAntiAlias: false);
      }
    }
    canvas
      ..drawImage(baked, area.topLeft, _image)
      ..restore();

    for (final (rect, indices, withHalo) in patches) {
      if (rect.isEmpty) {
        continue;
      }
      canvas
        ..saveLayer(rect, ui.Paint())
        ..drawImageRect(baked, rect.shift(-area.topLeft), rect, _image);
      for (final index in indices) {
        final light = lights[index];
        _pool(canvas, _centre(light), _rings(light), _intensity(light, index));
      }
      if (withHalo) {
        _pool(canvas, halo, _playerRings, 1);
      }
      canvas.restore();
    }
  }

  /// A warm tint under each working lamp, an orange one round a torch.
  void _renderWarmth(ui.Canvas canvas) {
    for (final (index, light) in lights.indexed) {
      final intensity = _intensity(light, index);
      _warm.color = light.torch
          ? ui.Color.fromRGBO(255, 150, 60, 0.1 * intensity)
          : ui.Color.fromRGBO(255, 200, 120, 0.07 * intensity);
      canvas.drawCircle(_centre(light), light.torch ? 30 : 20, _warm);
    }
  }
}

/// Live lamps whose pools overlap, and the world pixels they cover.
final class _LiveGroup {
  const _LiveGroup(this.rect, this.lights);

  final ui.Rect rect;

  /// Indices into `LightingComponent.lights`.
  final List<int> lights;
}
