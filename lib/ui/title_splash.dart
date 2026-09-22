import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/ui/loading_art.dart';

/// Title card shown between the intro story and the tutorial: unlike the
/// story scenes it fades in from black, holds, then fades back to black.
/// A tap skips straight to the fade out. The picture carries no text: the
/// Stepbound logo is laid over its top and [caption] along its bottom.
final class TitleSplash extends StatefulWidget {
  const TitleSplash({
    required this.onFinished,
    this.caption = 'Caricamento del tutorial',
    super.key,
  });

  static const Duration fade = Duration(milliseconds: 900);
  static const Duration hold = Duration(milliseconds: 2600);
  static const Duration total = Duration(milliseconds: 900 * 2 + 2600);

  final String caption;
  final VoidCallback onFinished;

  @override
  State<TitleSplash> createState() => _TitleSplashState();
}

final class _TitleSplashState extends State<TitleSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: TitleSplash.total)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onFinished();
          }
        })
        ..forward();

  static final double _fadeOutStart =
      (TitleSplash.fade + TitleSplash.hold).inMicroseconds /
      TitleSplash.total.inMicroseconds;

  late final Animation<double> _opacity =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 0,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: TitleSplash.fade.inMilliseconds.toDouble(),
        ),
        TweenSequenceItem<double>(
          tween: ConstantTween<double>(1),
          weight: TitleSplash.hold.inMilliseconds.toDouble(),
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: TitleSplash.fade.inMilliseconds.toDouble(),
        ),
      ]).animate(_controller);

  void _skip() {
    if (_controller.value < _fadeOutStart) {
      _controller.value = _fadeOutStart;
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
      key: const ValueKey<String>('title-splash'),
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: ColoredBox(
        color: Colors.black,
        child: FadeTransition(
          opacity: _opacity,
          child: LoadingArt(
            caption: widget.caption,
            captionKey: const ValueKey<String>('title-splash-caption'),
          ),
        ),
      ),
    );
  }
}
