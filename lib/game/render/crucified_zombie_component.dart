import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart' hide PositionComponent;
import 'package:stepbound/game/render/asset_image.dart';

/// The zombie nailed to the cross over the Duomo's altar, as the story
/// frame shows it: cut off at the waist, the arms spread along the beam,
/// the blood of the trunk pouring down the post. It is scenery, not an
/// actor -- it stands on the back wall, it is not in the simulation, it
/// cannot move or bite -- but it is not dead either: it hangs still, it
/// breathes, and every few seconds it thrashes against the nails. Each fit
/// calls [onTwitch], which is where the groan comes from: what it sounds
/// like, and whether anyone is near enough to hear it, is the game's to
/// decide.
///
/// The sheet is `tools/generate_crucified_zombie.py`: four 32x40 frames,
/// hanging, breathing, and two of the fit.
final class CrucifiedZombieComponent extends PositionComponent {
  CrucifiedZombieComponent({
    required GridPoint tile,
    this.onTwitch,
    int seed = 0,
    double tileSize = 16,
  }) : _random = math.Random(seed),
       super(
         position: Vector2(tile.x * tileSize, tile.y * tileSize),
         size: Vector2(frameWidth, frameHeight),
         // Over the wall it hangs on and the top of the altar under it,
         // below the darkness of the room, which its torches cut into.
         priority: 18,
       );

  static const String asset = 'assets/sprites/crucified_zombie.png';
  static const double frameWidth = 32;
  static const double frameHeight = 40;

  /// How long one breath takes, hanging: the two still frames.
  static const double breathSeconds = 2.6;

  /// How long a fit lasts, and how long each of its frames is held.
  static const double twitchSeconds = 0.9;
  static const double twitchFrameSeconds = 0.18;

  /// How long it hangs still between two fits: never the same twice, so
  /// the nave does not tick.
  static const double minRest = 6;
  static const double maxRest = 13;

  /// Called when a fit starts, once per fit.
  final void Function()? onTwitch;

  final math.Random _random;
  ui.Image? _sheet;
  double _time = 0;
  double _twitchLeft = 0;
  late double _restLeft = _nextRest();
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  /// True while it is thrashing.
  bool get isTwitching => _twitchLeft > 0;

  /// The frame drawn now: 0 and 1 hanging, 2 and 3 in a fit.
  int get frame {
    if (_twitchLeft > 0) {
      final elapsed = twitchSeconds - _twitchLeft;
      return 2 + (elapsed ~/ twitchFrameSeconds) % 2;
    }
    return (_time / breathSeconds).floor() % 2;
  }

  double _nextRest() => minRest + _random.nextDouble() * (maxRest - minRest);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _sheet = await loadAssetImage(asset);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_twitchLeft > 0) {
      _twitchLeft -= dt;
      return;
    }
    _restLeft -= dt;
    if (_restLeft > 0) {
      return;
    }
    _restLeft = _nextRest();
    _twitchLeft = twitchSeconds;
    onTwitch?.call();
  }

  @override
  void render(ui.Canvas canvas) {
    final sheet = _sheet;
    if (sheet == null) {
      return;
    }
    canvas.drawImageRect(
      sheet,
      ui.Rect.fromLTWH(frame * frameWidth, 0, frameWidth, frameHeight),
      size.toRect(),
      _paint,
    );
  }
}
