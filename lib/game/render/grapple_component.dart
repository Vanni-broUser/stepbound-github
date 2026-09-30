import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide PositionComponent;
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/character_component.dart';

/// The grappling hook thrown across a gap. Mario winds up as he does with
/// a molotov, the hook in his hand (his own throw, see
/// `CharacterComponent.playThrow`); at the release it spins over to the
/// edge on the far side trailing its rope, bites into it, and the rope
/// stays taut from there to his hands while he goes over along it (the
/// turn carries him: see `TurnPresentationController`). Removes itself
/// once he has landed.
final class GrappleComponent extends Component {
  GrappleComponent({
    required this.from,
    required this.anchor,
    required this.mario,
    this.tileSize = 16,
  }) : super(priority: 29);

  /// Where Mario throws from.
  final GridPoint from;

  /// The edge across the gap the hook catches on.
  final GridPoint anchor;

  /// Mario's feet, as drawn: the rope follows him over.
  final Vector2 Function() mario;
  final double tileSize;

  /// Seconds of the wind-up, the hook still in Mario's hand.
  static const double releaseSeconds = CharacterComponent.throwReleaseDelay;

  /// Seconds the hook takes to fly over once let go.
  static const double flightSeconds = 0.35;

  /// Seconds from the throw to the hook catching: Mario sets off then.
  static const double throwSeconds = releaseSeconds + flightSeconds;

  /// Seconds from the throw to Mario landing on the far side.
  static const double totalSeconds = throwSeconds + 0.7;

  static const Color _rope = Color(0xffdca454);
  static const Color _ropeShade = Color(0xff7a4c1e);
  static const Color _steel = Color(0xffc8d0da);
  static const Color _steelDark = Color(0xff5c626e);

  final Paint _paint = Paint()..isAntiAlias = false;
  double _elapsed = 0;

  /// Where the rope leaves Mario: his hands, a little above his feet.
  Offset get _hands {
    final feet = mario();
    return Offset(feet.x, feet.y - 9);
  }

  Offset get _catch => Offset(
    anchor.x * tileSize + tileSize / 2,
    anchor.y * tileSize + tileSize / 2,
  );

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= totalSeconds) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final hands = _hands;
    if (_elapsed < releaseSeconds) {
      // Still in his hand: the throwable pose draws it.
      return;
    }
    if (_elapsed < throwSeconds) {
      final t = (_elapsed - releaseSeconds) / flightSeconds;
      // Thrown up and over: an arc, the hook turning as it flies.
      final straight = Offset.lerp(hands, _catch, t)!;
      final hook = straight - Offset(0, math.sin(t * math.pi) * tileSize);
      _ropeTo(canvas, hands, hook);
      _hook(canvas, hook, t * math.pi * 4);
      return;
    }
    _ropeTo(canvas, hands, _catch);
    _hook(canvas, _catch, _restingAngle);
  }

  /// The hook bitten into the edge, its prongs towards Mario's side.
  double get _restingAngle {
    final away = Offset(
      (anchor.x - from.x).sign.toDouble(),
      (anchor.y - from.y).sign.toDouble(),
    );
    return math.atan2(away.dy, away.dx) - math.pi / 2;
  }

  void _ropeTo(Canvas canvas, Offset start, Offset end) {
    _paint
      ..strokeWidth = 1
      ..color = _ropeShade;
    canvas.drawLine(
      start + const Offset(0, 1),
      end + const Offset(0, 1),
      _paint,
    );
    _paint.color = _rope;
    canvas.drawLine(start, end, _paint);
  }

  /// The hook: a shank and three prongs, drawn about [at] turned by
  /// [angle] (0 has the prongs pointing down the screen).
  void _hook(Canvas canvas, Offset at, double angle) {
    canvas
      ..save()
      ..translate(at.dx.roundToDouble(), at.dy.roundToDouble())
      ..rotate(angle);
    _paint.color = _steelDark;
    canvas
      ..drawRect(const Rect.fromLTWH(-0.5, -3, 2, 6), _paint)
      ..drawRect(const Rect.fromLTWH(-3, 2, 7, 2), _paint);
    _paint.color = _steel;
    canvas
      ..drawRect(const Rect.fromLTWH(-0.5, -3, 1, 5), _paint)
      ..drawRect(const Rect.fromLTWH(-3, 2, 6, 1), _paint)
      ..drawRect(const Rect.fromLTWH(-3, 0, 1, 2), _paint)
      ..drawRect(const Rect.fromLTWH(2, 0, 1, 2), _paint)
      ..restore();
  }
}
