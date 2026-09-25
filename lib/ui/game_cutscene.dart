import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/story_intro.dart';

enum _Stage { toBlack, story, fromBlack }

/// A story scene during play: the game fades to black, [frames] play like
/// the intro story (picture, then its text on a tap, then the next
/// picture), the last one fades to black and the game fades back in before
/// [onFinished]. The pictures sit on black and are decoded while the game
/// fades out, so the world never shows between one and the next.
final class GameCutscene extends StatefulWidget {
  const GameCutscene({
    required this.frames,
    required this.onFinished,
    this.stayBlack = false,
    super.key,
  });

  final List<CutsceneFrame> frames;
  final VoidCallback onFinished;
  final bool stayBlack;

  @override
  State<GameCutscene> createState() => _GameCutsceneState();
}

final class _GameCutsceneState extends State<GameCutscene> {
  _Stage _stage = _Stage.toBlack;
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) {
      return;
    }
    _precached = true;
    for (final frame in widget.frames) {
      unawaited(precacheImage(AssetImage(frame.image), context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.toBlack => BlackFade(
        key: const ValueKey<String>('cutscene-to-black'),
        toBlack: true,
        onDone: () => setState(() => _stage = _Stage.story),
      ),
      _Stage.story => ColoredBox(
        color: Colors.black,
        child: StoryIntro(
          key: const ValueKey<String>('cutscene-story'),
          scenes: <StoryScene>[
            for (final frame in widget.frames)
              StoryScene(
                image: frame.image,
                speaker: frame.speaker,
                text: frame.text,
              ),
          ],
          fadeOutAtEnd: true,
          onFinished: widget.stayBlack
              ? widget.onFinished
              : () => setState(() => _stage = _Stage.fromBlack),
        ),
      ),
      _Stage.fromBlack => BlackFade(
        key: const ValueKey<String>('cutscene-from-black'),
        toBlack: false,
        onDone: widget.onFinished,
      ),
    };
  }
}
