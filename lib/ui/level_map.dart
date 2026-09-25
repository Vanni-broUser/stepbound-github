import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';

enum LevelDestination { hometown, rome, northCape }

/// Europe as the game's level selector. The travelled route links Molfetta
/// to Rome; Capo Nord is an unconnected preview and has no playable level.
/// Tapping any marker opens its destination card.
final class LevelMap extends StatefulWidget {
  const LevelMap({
    required this.onStartHometown,
    required this.onStartRome,
    super.key,
  });

  static const String mapImage = 'assets/story/level_map_europe.jpg';
  static const String hometownImage = 'assets/story/scene_harbour.jpg';
  static const String romeImage = 'assets/story/level_rome.jpg';
  static const String northCapeImage = 'assets/story/level_north_cape.jpg';

  final VoidCallback onStartHometown;
  final VoidCallback onStartRome;

  @override
  State<LevelMap> createState() => _LevelMapState();
}

final class _LevelMapState extends State<LevelMap> {
  // Pixels of the 1376x768 map artwork, as fractions of it.
  static const Size _artwork = Size(1376, 768);
  // Rome sits just inland of the Tyrrhenian coast, level with the Gargano.
  static final Offset _rome = _pixel(668, 588);
  // Molfetta is on the Adriatic, south-east of the Gargano towards Bari.
  static final Offset _molfetta = _pixel(738, 601);
  // Capo Nord is the tip of Norway, straight above the Gulf of Bothnia.
  static final Offset _northCape = _pixel(808, 59);
  // The railway from Rome: down the Liri valley through Frosinone and Cassino
  // to Caserta, across the Apennines by Benevento to Foggia, then along the
  // Adriatic through Barletta to Molfetta.
  static final List<Offset> _railway = <Offset>[
    _rome,
    _pixel(683, 593),
    _pixel(692, 597),
    _pixel(700, 603),
    _pixel(708, 602),
    _pixel(720, 596),
    _pixel(733, 598),
    _molfetta,
  ];

  static Offset _pixel(double x, double y) =>
      Offset(x / _artwork.width, y / _artwork.height);

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
            CustomPaint(painter: _RoutePainter(_railway)),
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
            _marker(
              constraints,
              unit,
              _northCape,
              const ValueKey<String>('level-city-north-cape'),
              'CAPO NORD',
              () => setState(() => _selected = LevelDestination.northCape),
            ),
            Positioned(
              left: 8 * unit,
              top: 7 * unit,
              child: IgnorePointer(
                child: Text(
                  'SCEGLI LA DESTINAZIONE',
                  style: TextStyle(
                    color: const Color(0xfff2e3c7),
                    fontFamily: 'monospace',
                    fontSize: 8 * unit,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5 * unit,
                    decoration: TextDecoration.none,
                    shadows: <Shadow>[
                      Shadow(blurRadius: 4 * unit),
                      Shadow(offset: Offset(unit, unit)),
                    ],
                  ),
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
    final rome = destination == LevelDestination.rome;
    final image = switch (destination) {
      LevelDestination.hometown => LevelMap.hometownImage,
      LevelDestination.rome => LevelMap.romeImage,
      LevelDestination.northCape => LevelMap.northCapeImage,
    };
    final name = switch (destination) {
      LevelDestination.hometown => 'Città Natale',
      LevelDestination.rome => 'Roma',
      LevelDestination.northCape => 'Capo Nord',
    };
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
              image,
              width: 104 * unit,
              height: 50 * unit,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
          ),
          SizedBox(height: 4 * unit),
          Text(
            name,
            key: const ValueKey<String>('level-card-name'),
            style: TextStyle(
              color: const Color(0xfff2e3c7),
              fontFamily: 'monospace',
              fontSize: 9 * unit,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          if (hometown || rome) ...<Widget>[
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
        ],
      ),
    );
  }
}

final class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.stops);

  final List<Offset> stops;

  @override
  void paint(Canvas canvas, Size size) {
    Offset scale(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);
    final points = stops.map(scale).toList();
    // Rounded through the midpoints, so the line curves like a track instead
    // of turning sharp corners at each town.
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final middle = Offset.lerp(points[i], points[i + 1], 0.5)!;
      path.quadraticBezierTo(points[i].dx, points[i].dy, middle.dx, middle.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xcc1b0505)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height / 90
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = BloodColors.bright
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height / 180
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      !listEquals(oldDelegate.stops, stops);
}
