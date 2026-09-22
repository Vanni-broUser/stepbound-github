import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/screen_caption.dart';

/// Announces a new place on the way in: the game fades to black, the
/// place's picture fades in with its [name] written along the bottom (like
/// the tutorial's loading screen), holds, fades back to black, then the
/// black lifts on the new map. A tap skips to the fade out.
final class LocationCard extends StatefulWidget {
  const LocationCard({
    required this.name,
    required this.image,
    required this.onFinished,
    this.onBlack,
    super.key,
  });

  static const Duration blackIn = Duration(milliseconds: 600);
  static const Duration imageIn = Duration(milliseconds: 900);
  static const Duration hold = Duration(milliseconds: 2800);
  static const Duration imageOut = Duration(milliseconds: 900);
  static const Duration blackOut = Duration(milliseconds: 700);
  static const Duration total = Duration(milliseconds: 5900);

  final String name;
  final String image;
  final VoidCallback onFinished;

  /// Called once, when the screen has gone fully black and the game behind
  /// can move to the new place unseen.
  final VoidCallback? onBlack;

  @override
  State<LocationCard> createState() => _LocationCardState();
}

final class _LocationCardState extends State<LocationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: LocationCard.total)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onFinished();
          }
        })
        ..addListener(_checkBlack)
        ..forward();

  static final double _blackAt =
      LocationCard.blackIn.inMicroseconds / LocationCard.total.inMicroseconds;
  bool _wentBlack = false;

  void _checkBlack() {
    if (!_wentBlack && _controller.value >= _blackAt) {
      _wentBlack = true;
      widget.onBlack?.call();
    }
  }

  static double _weight(Duration duration) =>
      duration.inMilliseconds.toDouble();

  static final double _imageOutStart =
      (LocationCard.blackIn + LocationCard.imageIn + LocationCard.hold)
          .inMicroseconds /
      LocationCard.total.inMicroseconds;

  late final Animation<double> _black =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 0,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: _weight(LocationCard.blackIn),
        ),
        TweenSequenceItem<double>(
          tween: ConstantTween<double>(1),
          weight: _weight(
            LocationCard.imageIn + LocationCard.hold + LocationCard.imageOut,
          ),
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: _weight(LocationCard.blackOut),
        ),
      ]).animate(_controller);

  late final Animation<double> _picture =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: ConstantTween<double>(0),
          weight: _weight(LocationCard.blackIn),
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 0,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: _weight(LocationCard.imageIn),
        ),
        TweenSequenceItem<double>(
          tween: ConstantTween<double>(1),
          weight: _weight(LocationCard.hold),
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: _weight(LocationCard.imageOut),
        ),
        TweenSequenceItem<double>(
          tween: ConstantTween<double>(0),
          weight: _weight(LocationCard.blackOut),
        ),
      ]).animate(_controller);

  void _skip() {
    if (_controller.value < _imageOutStart) {
      _controller.value = _imageOutStart;
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('location-card'),
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unit = constraints.maxHeight.isFinite
              ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
              : 1.0;
          return FadeTransition(
            opacity: _black,
            child: ColoredBox(
              color: Colors.black,
              child: FadeTransition(
                opacity: _picture,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(widget.image, fit: BoxFit.cover),
                    ScreenCaption(
                      widget.name,
                      key: const ValueKey<String>('location-card-name'),
                      unit: unit,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
