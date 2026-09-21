import 'package:flutter/material.dart';
import 'package:stepbound/ui/story_intro.dart';

/// One line spoken over the gameplay view, with the speaker's portrait
/// when the speaker is a character.
final class DialogueLine {
  const DialogueLine({
    required this.text,
    this.speaker = 'Mario Rossi',
    this.portrait = marioPortrait,
  });

  /// A tutorial hint: no portrait.
  const DialogueLine.tutorial(this.text)
    : speaker = 'Tutorial',
      portrait = null;

  static const String marioPortrait = 'assets/story/portrait_mario.png';

  final String speaker;
  final String? portrait;
  final String text;
}

const List<DialogueLine> tutorialOpening = <DialogueLine>[
  DialogueLine(
    text:
        'La città è nel caos più totale! Devo cercare di '
        'mettermi in salvo in qualche modo',
  ),
  DialogueLine.tutorial('Usa le freccette per muoverti'),
];

/// Plays [lines] over the game, one per tap, with the speaker's portrait
/// standing on the dialogue box. Calls [onFinished] after the last line.
final class GameplayDialogue extends StatefulWidget {
  const GameplayDialogue({
    required this.onFinished,
    this.lines = tutorialOpening,
    super.key,
  });

  final List<DialogueLine> lines;
  final VoidCallback onFinished;

  @override
  State<GameplayDialogue> createState() => _GameplayDialogueState();
}

final class _GameplayDialogueState extends State<GameplayDialogue> {
  int _index = 0;

  void _advance() {
    if (_index + 1 < widget.lines.length) {
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
