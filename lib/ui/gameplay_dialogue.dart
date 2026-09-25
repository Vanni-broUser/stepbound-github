import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/blood_splat.dart';
import 'package:stepbound/ui/story_intro.dart';

/// One line spoken over the gameplay view, with the speaker's portrait
/// when the speaker is a character.
final class DialogueLine {
  const DialogueLine({
    required this.text,
    this.speaker = 'Mario Rossi',
    this.portrait = marioPortrait,
  });

  /// A hint or narration: no name over the box and no portrait.
  const DialogueLine.tutorial(this.text) : speaker = null, portrait = null;

  static const String marioPortrait = 'assets/story/portrait_mario.png';

  /// Shown over the text only when a person is talking.
  final String? speaker;
  final String? portrait;
  final String text;
}

const List<DialogueLine> tutorialOpening = <DialogueLine>[
  DialogueLine(
    text:
        'La città è nel caos più totale! Devo cercare di '
        'mettermi in salvo in qualche modo',
  ),
  DialogueLine.tutorial(
    'Trascina il dito sulla parte sinistra dello schermo per muoverti',
  ),
];

/// Plays [lines] over the game, one per tap, with the speaker's portrait
/// standing on the dialogue box. Calls [onFinished] after the last line.
final class GameplayDialogue extends StatefulWidget {
  const GameplayDialogue({
    required this.onFinished,
    this.lines = tutorialOpening,
    super.key,
  });

  static const Duration defaultSettleTime = Duration(milliseconds: 500);

  /// A line ignores taps for this long. The box often opens while an arrow
  /// is being held down or tapped over and over to walk: without the pause
  /// those taps eat the first lines before they can be read. Tests that
  /// only tap through the lines set it to zero.
  static Duration settleTime = defaultSettleTime;

  final List<DialogueLine> lines;
  final VoidCallback onFinished;

  @override
  State<GameplayDialogue> createState() => _GameplayDialogueState();
}

final class _GameplayDialogueState extends State<GameplayDialogue> {
  int _index = 0;

  /// False until the line on screen has been there long enough to be read.
  bool _settled = false;
  Timer? _settling;

  /// A tap counts only if the finger came down while the line was settled:
  /// one already resting on an arrow button when the box opened does not.
  bool _pressWasFresh = false;

  /// Where the finger lifted: a tap that turns the line leaves blood there,
  /// wherever on the screen it was.
  Offset? _tappedAt;

  @override
  void initState() {
    super.initState();
    _settle();
  }

  @override
  void dispose() {
    _settling?.cancel();
    super.dispose();
  }

  void _settle() {
    _settling?.cancel();
    final wait = GameplayDialogue.settleTime;
    _settled = wait <= Duration.zero;
    _settling = _settled ? null : Timer(wait, () => _settled = true);
  }

  void _press() => _pressWasFresh = _settled;

  void _advance() {
    if (!_pressWasFresh) {
      return;
    }
    _pressWasFresh = false;
    final at = _tappedAt;
    if (at != null) {
      BloodSplatLayer.maybeOf(context)?.splat(at, SplatKind.tap);
    }
    AudioScope.of(context).play(Sfx.dialogue);
    if (_index + 1 < widget.lines.length) {
      _settle();
      setState(() => _index += 1);
      return;
    }
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.lines[_index];
    final portrait = line.portrait;
    return GestureDetector(
      key: const ValueKey<String>('gameplay-dialogue'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(),
      onTapUp: (details) => _tappedAt = details.globalPosition,
      onTap: _advance,
      child: Semantics(
        label: 'Tocca per continuare',
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: StoryTextBox(
                speaker: line.speaker,
                text: line.text,
                portraitOnRight: true,
                portrait: portrait == null
                    ? null
                    : Transform.flip(
                        flipX: true,
                        child: Image.asset(
                          portrait,
                          key: ValueKey<String>('dialogue-portrait-$_index'),
                          height: constraints.maxHeight * 0.66,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
