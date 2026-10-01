import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/blood_splat.dart';
import 'package:stepbound/ui/control_demo.dart';
import 'package:stepbound/ui/portrait_image.dart';
import 'package:stepbound/ui/story_intro.dart';

/// One line spoken over the gameplay view, with the speaker's portrait
/// when the speaker is a character.
final class DialogueLine {
  const DialogueLine({
    required this.text,
    this.speaker = 'Mario Rossi',
    this.portrait = marioPortrait,
    this.demo,
    this.advanceOnRightDrag = false,
  });

  /// A hint or narration: no name over the box and no portrait.
  const DialogueLine.tutorial(
    this.text, {
    this.demo,
    this.advanceOnRightDrag = false,
  }) : speaker = null,
       portrait = null;

  static const String marioPortrait =
      'assets/characters/mario/portraits/base.png';

  /// Shown over the text only when a person is talking.
  final String? speaker;
  final String? portrait;
  final String text;

  /// The gesture played on a small screen beside the box, over and over,
  /// while the line is up.
  final ControlDemo? demo;

  /// Lets this exceptional line advance when the player tries the movement
  /// control instead of tapping through the tutorial first: a rightward
  /// drag anywhere, or a tap or a drag in any direction on the left half of
  /// the screen, where the joystick is, or on the gesture's panel.
  final bool advanceOnRightDrag;
}

List<DialogueLine> get tutorialOpening => <DialogueLine>[
  DialogueLine(text: strings.tutorialChaos),
  DialogueLine.tutorial(
    strings.tutorialMove,
    demo: ControlDemo.move,
    advanceOnRightDrag: true,
  ),
];

/// Plays [lines] over the game, one per tap, with the speaker's portrait
/// standing on the dialogue box. Calls [onFinished] after the last line.
final class GameplayDialogue extends StatefulWidget {
  const GameplayDialogue({required this.onFinished, this.lines, super.key});

  static const Duration defaultSettleTime = Duration(milliseconds: 500);

  /// A line ignores taps for this long. The box often opens while an arrow
  /// is being held down or tapped over and over to walk: without the pause
  /// those taps eat the first lines before they can be read. Tests that
  /// only tap through the lines set it to zero.
  static Duration settleTime = defaultSettleTime;

  /// Where the panel of a line's gesture stands, and how tall it is, as
  /// shares of the view's height: over the box, out of the corner badges.
  static const double demoTop = 0.16;
  static const double demoHeight = 0.48;

  /// The tutorial's opening lines when null.
  final List<DialogueLine>? lines;
  final VoidCallback onFinished;

  @override
  State<GameplayDialogue> createState() => _GameplayDialogueState();
}

final class _GameplayDialogueState extends State<GameplayDialogue> {
  /// The tutorial's opening taken once, so its words stay as they were
  /// when it started.
  late final List<DialogueLine> _opening = tutorialOpening;

  List<DialogueLine> get _lines => widget.lines ?? _opening;

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

  /// Movement accumulated while the opening movement hint is on screen.
  Offset _dragDelta = Offset.zero;

  /// Whether that drag started where the joystick is, or on the panel
  /// showing it: then any direction counts.
  bool _dragOnPad = false;

  /// The panel playing the line's gesture, to tell a touch on it.
  final GlobalKey _demoKey = GlobalKey();

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

  void _press({bool allowUnsettled = false}) {
    _pressWasFresh = _settled || allowUnsettled;
  }

  void _advance({bool leavesSplat = true}) {
    if (!_pressWasFresh) {
      return;
    }
    _pressWasFresh = false;
    final at = _tappedAt;
    _tappedAt = null;
    if (leavesSplat && at != null) {
      BloodSplatLayer.maybeOf(context)?.splat(at, SplatKind.tap);
    }
    AudioScope.of(context).play(Sfx.dialogue);
    if (_index + 1 < _lines.length) {
      _settle();
      setState(() => _index += 1);
      return;
    }
    widget.onFinished();
  }

  /// On the left half of the screen, where the joystick is, or on the
  /// panel showing the gesture.
  bool _onPad(Offset global) {
    final box = context.findRenderObject();
    if (box is RenderBox &&
        box.hasSize &&
        box.globalToLocal(global).dx < box.size.width / 2) {
      return true;
    }
    final demo = _demoKey.currentContext?.findRenderObject();
    return demo is RenderBox &&
        demo.hasSize &&
        (Offset.zero & demo.size).contains(demo.globalToLocal(global));
  }

  void _tapDown(TapDownDetails details) {
    final line = _lines[_index];
    // Like a drag, a touch where the joystick is means to try it: no need
    // to wait for the line to settle.
    _press(
      allowUnsettled: line.advanceOnRightDrag && _onPad(details.globalPosition),
    );
  }

  void _dragStart(DragStartDetails details) {
    _dragDelta = Offset.zero;
    _dragOnPad = _onPad(details.globalPosition);
    _tappedAt = null;
    // Unlike ordinary dialogue input, this is an intentional attempt to use
    // the control the line is teaching, so it need not wait for the guard
    // against a finger already resting on an old movement button.
    _press(allowUnsettled: true);
  }

  void _dragUpdate(DragUpdateDetails details) {
    _dragDelta += details.delta;
  }

  void _dragEnd() {
    if (_dragDelta.dx > 0 || (_dragOnPad && _dragDelta != Offset.zero)) {
      _advance(leavesSplat: false);
    } else {
      _pressWasFresh = false;
    }
    _dragDelta = Offset.zero;
    _dragOnPad = false;
  }

  @override
  Widget build(BuildContext context) {
    final line = _lines[_index];
    final portrait = line.portrait;
    return GestureDetector(
      key: const ValueKey<String>('gameplay-dialogue'),
      behavior: HitTestBehavior.opaque,
      onTapDown: _tapDown,
      onTapUp: (details) => _tappedAt = details.globalPosition,
      onTap: _advance,
      onPanStart: line.advanceOnRightDrag ? _dragStart : null,
      onPanUpdate: line.advanceOnRightDrag ? _dragUpdate : null,
      onPanEnd: line.advanceOnRightDrag ? (_) => _dragEnd() : null,
      onPanCancel: line.advanceOnRightDrag ? _dragEnd : null,
      child: Semantics(
        label: strings.tapToContinue,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final demo = line.demo;
            final box = Align(
              alignment: Alignment.bottomCenter,
              child: StoryTextBox(
                speaker: line.speaker,
                text: line.text,
                portraitOnRight: true,
                portrait: portrait == null
                    ? null
                    : Transform.flip(
                        flipX: true,
                        child: PortraitImage(
                          portrait,
                          key: ValueKey<String>('dialogue-portrait-$_index'),
                          height: constraints.maxHeight * 0.66,
                        ),
                      ),
              ),
            );
            if (demo == null) {
              return box;
            }
            final height = constraints.maxHeight * GameplayDialogue.demoHeight;
            return Stack(
              children: <Widget>[
                Positioned(
                  left: ControlDemoView.standsRight(demo) ? null : 16,
                  right: ControlDemoView.standsRight(demo) ? 16 : null,
                  top: constraints.maxHeight * GameplayDialogue.demoTop,
                  height: height,
                  // Keyed by the gesture: lines that show the same one keep
                  // it playing on without starting over.
                  child: KeyedSubtree(
                    key: _demoKey,
                    child: ControlDemoView(
                      key: ValueKey<ControlDemo>(demo),
                      demo: demo,
                    ),
                  ),
                ),
                box,
              ],
            );
          },
        ),
      ),
    );
  }
}
