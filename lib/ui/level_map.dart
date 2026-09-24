import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';

enum LevelDestination { hometown, rome }

/// Europe as the game's level selector. The route already travelled links
/// Molfetta to Rome; tapping either red marker opens its level card.
final class LevelMap extends StatefulWidget {
  const LevelMap({
    required this.onStartHometown,
    required this.onStartRome,
    super.key,
  });

  static const String mapImage = 'assets/story/level_map_europe.jpg';
  static const String hometownImage = 'assets/story/scene_harbour.jpg';
  static const String romeImage = 'assets/story/level_rome.jpg';

  final VoidCallback onStartHometown;
  final VoidCallback onStartRome;

  @override
  State<LevelMap> createState() => _LevelMapState();
}

final class _LevelMapState extends State<LevelMap> {
  // Fractions of the supplied map artwork.
  static const Offset _rome = Offset(0.51, 0.72);
  static const Offset _molfetta = Offset(0.57, 0.79);

  LevelDestination? _selected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit =
            constraints.maxHeight / IntegerResolutionViewport.virtualHeight;
        return Stack(
          key: const ValueKey<String>('level-map'),
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              LevelMap.mapImage,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
            const CustomPaint(painter: _RoutePainter(_rome, _molfetta)),
            _marker(
              constraints,
              unit,
              _molfetta,
              const ValueKey<String>('level-city-hometown'),
              'MOLFETTA',
              () => setState(() => _selected = LevelDestination.hometown),
            ),
            _marker(
              constraints,
              unit,
              _rome,
              const ValueKey<String>('level-city-rome'),
              'ROMA',
              () => setState(() => _selected = LevelDestination.rome),
            ),
            Positioned(
              left: 8 * unit,
              top: 7 * unit,
              child: Text(
                'SCEGLI LA DESTINAZIONE',
                style: TextStyle(
                  color: const Color(0xfff2e3c7),
                  fontFamily: 'monospace',
                  fontSize: 10 * unit,
                  fontWeight: FontWeight.w900,
                  letterSpacing: unit,
                  decoration: TextDecoration.none,
                  shadows: <Shadow>[
                    Shadow(blurRadius: 4 * unit),
                    Shadow(offset: Offset(unit, unit)),
                  ],
                ),
              ),
            ),
            if (_selected case final destination?)
              Positioned(
                left: 8 * unit,
                top: 30 * unit,
                child: _card(destination, unit),
              ),
          ],
        );
      },
    );
  }

  Widget _marker(
    BoxConstraints constraints,
    double unit,
    Offset point,
    Key key,
    String label,
    VoidCallback onTap,
  ) {
    final size = 12 * unit;
    return Positioned(
      left: constraints.maxWidth * point.dx - size / 2,
      top: constraints.maxHeight * point.dy - size / 2,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Container(
                width: 7 * unit,
                height: 7 * unit,
                decoration: BoxDecoration(
                  color: BloodColors.bright,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xffffdfb8),
                    width: 1.2 * unit,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 3 * unit,
                      spreadRadius: unit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(LevelDestination destination, double unit) {
    final hometown = destination == LevelDestination.hometown;
    return MenuPanel(
      key: const ValueKey<String>('level-card'),
      unit: unit,
      width: 116,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(2 * unit),
            child: Image.asset(
              hometown ? LevelMap.hometownImage : LevelMap.romeImage,
              width: 104 * unit,
              height: 50 * unit,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
          ),
          SizedBox(height: 4 * unit),
          Text(
            hometown ? 'Città Natale' : 'Roma',
            key: const ValueKey<String>('level-card-name'),
            style: TextStyle(
              color: const Color(0xfff2e3c7),
              fontFamily: 'monospace',
              fontSize: 9 * unit,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: 4 * unit),
          MenuButton(
            key: const ValueKey<String>('level-start'),
            label: 'INIZIA LIVELLO',
            unit: unit,
            compact: true,
            width: 102,
            onPressed: hometown ? widget.onStartHometown : widget.onStartRome,
          ),
        ],
      ),
    );
  }
}

final class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.from, this.to);

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    Offset scale(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);
    final path = Path()
      ..moveTo(scale(from).dx, scale(from).dy)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.73,
        scale(to).dx,
        scale(to).dy,
      );
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xcc1b0505)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height / 65
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = BloodColors.bright
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height / 130
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}
