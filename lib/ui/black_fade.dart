import 'package:flutter/material.dart';

/// Full-screen black layer that fades in ([toBlack]) or out, then calls
/// [onDone]. It never intercepts taps.
final class BlackFade extends StatefulWidget {
  const BlackFade({
    required this.toBlack,
    this.duration = defaultDuration,
    this.onDone,
    super.key,
  });

  static const Duration defaultDuration = Duration(milliseconds: 900);

  final bool toBlack;
  final Duration duration;
  final VoidCallback? onDone;

  @override
  State<BlackFade> createState() => _BlackFadeState();
}

final class _BlackFadeState extends State<BlackFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onDone?.call();
          }
        })
        ..forward();

  late final Animation<double> _opacity = widget.toBlack
      ? CurvedAnimation(parent: _controller, curve: Curves.easeIn)
      : ReverseAnimation(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _opacity,
        child: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
      ),
    );
  }
}
