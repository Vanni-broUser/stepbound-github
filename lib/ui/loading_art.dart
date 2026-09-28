import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/screen_caption.dart';

/// The loading picture, with the Stepbound logo over the top and [caption]
/// along the bottom: by default a man turning into a zombie, stage by
/// stage; a level's own once there is one.
final class LoadingArt extends StatelessWidget {
  const LoadingArt({
    required this.caption,
    this.captionKey,
    this.picture = image,
    super.key,
  });

  static const String image = 'assets/story/ui/title_loading.jpg';

  final String picture;
  final String caption;
  final Key? captionKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1.0;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(picture, fit: BoxFit.cover, gaplessPlayback: true),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 8 * unit),
                child: Image.asset(
                  MainMenu.logo,
                  height: 54 * unit,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
            ScreenCaption(caption, key: captionKey, unit: unit),
          ],
        );
      },
    );
  }
}

/// Covers the game with [LoadingArt] while it loads, instead of a black
/// screen: it shows at once (or, with [fadeIn], its picture fades in over
/// the black a story scene ended on, the black itself hiding the game from
/// the first frame), stays at least [minimum] so it never just flickers,
/// and once [ready] is true fades out on the game. It never intercepts
/// taps.
final class LoadingCover extends StatefulWidget {
  const LoadingCover({
    required this.ready,
    required this.caption,
    this.fadeIn = false,
    this.minimum = const Duration(milliseconds: 900),
    this.artSize,
    this.image = LoadingArt.image,
    super.key,
  });

  static const Duration fadeInDuration = Duration(milliseconds: 350);
  static const Duration fadeOut = Duration(milliseconds: 600);

  final ValueListenable<bool> ready;
  final String caption;
  final bool fadeIn;
  final Duration minimum;

  /// The picture shown.
  final String image;

  /// The size of the picture, centred on black; the whole of the space
  /// when null. It covers the whole screen either way, so nothing laid out
  /// beside the game shows through while it loads.
  final Size? artSize;

  @override
  State<LoadingCover> createState() => _LoadingCoverState();
}

final class _LoadingCoverState extends State<LoadingCover>
    with TickerProviderStateMixin {
  /// The picture over the black, faded in with [LoadingCover.fadeIn].
  late final AnimationController _picture = AnimationController(
    vsync: this,
    duration: LoadingCover.fadeInDuration,
  );

  /// The whole cover, black and all: faded out on the game once it is
  /// ready.
  late final AnimationController _opacity = AnimationController(
    vsync: this,
    value: 1,
    reverseDuration: LoadingCover.fadeOut,
  );
  bool _shownLongEnough = false;
  bool _gone = false;
  Timer? _minimum;

  @override
  void initState() {
    super.initState();
    widget.ready.addListener(_maybeLeave);
    if (widget.fadeIn) {
      unawaited(_picture.forward());
    } else {
      _picture.value = 1;
    }
    _minimum = Timer(widget.minimum, () {
      _shownLongEnough = true;
      _maybeLeave();
    });
  }

  void _maybeLeave() {
    if (!mounted || !_shownLongEnough || !widget.ready.value) {
      return;
    }
    widget.ready.removeListener(_maybeLeave);
    unawaited(
      _opacity.reverse().whenComplete(() {
        if (mounted) {
          setState(() => _gone = true);
        }
      }),
    );
  }

  @override
  void dispose() {
    widget.ready.removeListener(_maybeLeave);
    _minimum?.cancel();
    _picture.dispose();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: FadeTransition(
        key: const ValueKey<String>('loading-cover'),
        opacity: _opacity,
        child: ColoredBox(
          color: Colors.black,
          child: FadeTransition(
            opacity: _picture,
            child: switch (widget.artSize) {
              null => LoadingArt(
                caption: widget.caption,
                picture: widget.image,
              ),
              final size => Center(
                child: SizedBox.fromSize(
                  size: size,
                  child: LoadingArt(
                    caption: widget.caption,
                    picture: widget.image,
                  ),
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}
