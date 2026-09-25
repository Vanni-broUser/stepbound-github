import 'package:flutter/material.dart';

/// The line written along the bottom of a full-screen picture, such as
/// "Caricamento del tutorial" or the name of a place: pale bold letters
/// with a soft black shadow. [unit] scales it with the view, like the
/// dialogue text.
final class ScreenCaption extends StatelessWidget {
  const ScreenCaption(this.text, {required this.unit, super.key});

  final String text;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12 * unit),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xffe8dfcc),
            fontFamily: 'monospace',
            fontSize: 13 * unit,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2 * unit,
            decoration: TextDecoration.none,
            shadows: <Shadow>[
              Shadow(blurRadius: 4 * unit),
              Shadow(offset: Offset(unit, unit)),
            ],
          ),
        ),
      ),
    );
  }
}
