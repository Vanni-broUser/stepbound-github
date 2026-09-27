import 'package:flutter/material.dart';

/// A character's portrait, decoded no bigger than it is drawn.
///
/// The portraits are PNGs of 1048x1501, six megabytes each once decoded,
/// and the dialogue box, the book and the wardrobe show them at a fraction
/// of that. Decoded at the height they take on this screen they cost what
/// they show: about a quarter on a phone, and the seventeen of them fit
/// in Flutter's image cache together instead of pushing each other out.
final class PortraitImage extends StatelessWidget {
  const PortraitImage(
    this.asset, {
    this.height,
    this.fit = BoxFit.contain,
    super.key,
  });

  /// The portrait's path in the bundle.
  final String asset;

  /// How tall it is drawn; as tall as it is given when null.
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final drawn = height ?? constraints.maxHeight;
        final ratio = MediaQuery.devicePixelRatioOf(context);
        return Image.asset(
          asset,
          height: height,
          fit: fit,
          cacheHeight: drawn.isFinite && drawn > 0
              ? (drawn * ratio).ceil()
              : null,
        );
      },
    );
  }
}
