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
/// the flickering lamps, the torches, the player's halo and the beacons,
/// each in a layer no bigger than its own pool.
///
/// A beacon is a small light that blinks over something left to find in
/// the dark, a backpack, for as long as it is there to be found.
final class LightingComponent extends Component {
  LightingComponent({
    required this.area,
    required this.lights,
    required this.playerPosition,
    this.darkness = PlaceSpec.defaultDarkness,
    this.litAreas = const <ui.Rect>[],
    this.beacons = _noBeacons,
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

  /// The tiles blinking now, anywhere in the world: those outside [area]
  /// are left alone.
  final Iterable<GridPoint> Function() beacons;

  static Iterable<GridPoint> _noBeacons() => const <GridPoint>[];

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

  /// A beacon's pool: smaller than a lamp's, but it cuts deep.
  static const List<(double, double)> _beaconRings = <(double, double)>[
    (22, 0.3),
    (12, 0.62),
  ];

  /// How many times a second a beacon blinks.
  static const double _beaconRate = 1.4;

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
    final beacon = _beaconIntensity;
    final extras = <_Pool>[
      (
        centre: ui.Offset(feet.x, feet.y - _haloRise),
        rings: _playerRings,
        intensity: 1,
      ),
      for (final tile in beacons())
        if (area.contains(_tileCentre(tile)))
          (centre: _tileCentre(tile), rings: _beaconRings, intensity: beacon),
    ];
    final baked = _baked;
    if (baked == null) {
      _renderLive(canvas, extras);
    } else {
      _renderBaked(canvas, baked, extras);
    }
    _renderWarmth(canvas, extras.skip(1));
  }

  ui.Offset _tileCentre(GridPoint tile) => ui.Offset(
    tile.x * tileSize + tileSize / 2,
    tile.y * tileSize + tileSize / 2,
  );

  /// Full while a beacon is lit, faint between its blinks.
  double get _beaconIntensity =>
      math.sin(_time * _beaconRate * 2 * math.pi) > -0.2 ? 1 : 0.25;

  /// Everything cut in one layer: until the darkness is composed.
  void _renderLive(ui.Canvas canvas, List<_Pool> extras) {
    canvas
      ..saveLayer(area, ui.Paint())
      ..drawRect(area, _dark);
    _clearLitAreas(canvas);
    for (final (index, light) in lights.indexed) {
      _pool(canvas, _centre(light), _rings(light), _intensity(light, index));
    }
    for (final extra in extras) {
      _pool(canvas, extra.centre, extra.rings, extra.intensity);
    }
    canvas.restore();
  }

  /// The composed darkness, except where a live pool falls: there the
  /// darkness is drawn again into a small layer and the pool cut out of it.
  /// The player's halo and the beacons join whichever live groups they
  /// touch, and one another, so pools that overlap cut into one layer.
  void _renderBaked(ui.Canvas canvas, ui.Image baked, List<_Pool> extras) {
    var pending = <({ui.Rect rect, List<int> lights, List<_Pool> extras})>[
      for (final group in _live)
        (rect: group.rect, lights: group.lights, extras: const <_Pool>[]),
      for (final extra in extras)
        (
          rect: ui.Rect.fromCircle(
            center: extra.centre,
            radius: extra.rings[0].$1 + 1,
          ),
          lights: const <int>[],
          extras: <_Pool>[extra],
        ),
    ];
    final patches = <({ui.Rect rect, List<int> lights, List<_Pool> extras})>[];
    while (pending.isNotEmpty) {
      var patch = pending.removeLast();
      var merged = true;
      while (merged) {
        merged = false;
        final rest = <({ui.Rect rect, List<int> lights, List<_Pool> extras})>[];
        for (final other in pending) {
          if (other.rect.overlaps(patch.rect)) {
            patch = (
              rect: patch.rect.expandToInclude(other.rect),
              lights: <int>[...patch.lights, ...other.lights],
              extras: <_Pool>[...patch.extras, ...other.extras],
            );
            merged = true;
          } else {
            rest.add(other);
          }
        }
        pending = rest;
      }
      patches.add((
        rect: patch.rect.intersect(area),
        lights: patch.lights,
        extras: patch.extras,
      ));
    }

    canvas.save();
    for (final patch in patches) {
      if (!patch.rect.isEmpty) {
        canvas.clipRect(
          patch.rect,
          clipOp: ui.ClipOp.difference,
          doAntiAlias: false,
        );
      }
    }
    canvas
      ..drawImage(baked, area.topLeft, _image)
      ..restore();

    for (final patch in patches) {
      if (patch.rect.isEmpty) {
        continue;
      }
      canvas
        ..saveLayer(patch.rect, ui.Paint())
        ..drawImageRect(
          baked,
          patch.rect.shift(-area.topLeft),
          patch.rect,
          _image,
        );
      for (final index in patch.lights) {
        final light = lights[index];
        _pool(canvas, _centre(light), _rings(light), _intensity(light, index));
      }
      for (final extra in patch.extras) {
        _pool(canvas, extra.centre, extra.rings, extra.intensity);
      }
      canvas.restore();
    }
  }

  /// A warm tint under each working lamp, an orange one round a torch, a
  /// pale one on each beacon while it is lit.
  void _renderWarmth(ui.Canvas canvas, Iterable<_Pool> beacons) {
    for (final beacon in beacons) {
      _warm.color = ui.Color.fromRGBO(255, 240, 190, 0.12 * beacon.intensity);
      canvas.drawCircle(beacon.centre, 9, _warm);
    }
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

/// A pool of light that is not one of the room's lamps: the player's halo
/// or a beacon.
typedef _Pool = ({
  ui.Offset centre,
  List<(double, double)> rings,
  double intensity,
});
