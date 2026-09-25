import 'package:flutter/material.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/black_fade.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/blood_splat.dart';
import 'package:stepbound/ui/main_menu.dart';

/// One full-screen frame of the intro story with its dialogue line.
final class StoryScene {
  const StoryScene({required this.image, required this.text, this.speaker});

  final String image;
  final String? speaker;
  final String text;
}

const List<StoryScene> introScenes = <StoryScene>[
  StoryScene(
    image: 'assets/story/scene_news.png',
    speaker: 'Telecronista',
    text:
        'Attenzione, interrompiamo le comunicazioni per una edizione '
        'straordinaria del telegiornale',
  ),
  StoryScene(
    image: 'assets/story/scene_blackout.png',
    speaker: 'Telecronista',
    text: '... Che succede? ... Ragazzi, la luce?',
  ),
  StoryScene(
    image: 'assets/story/scene_attack.png',
    speaker: 'Telecronista',
    text: 'Aaaaahhh!',
  ),
];

/// Played after the title card: the night the outbreak spread.
const List<StoryScene> outbreakScenes = <StoryScene>[
  StoryScene(
    image: 'assets/story/scene_outbreak.jpg',
    text:
        'Quella notte migliaia di persone in ogni dove si trasformarono in '
        'zombi, creature non morte prive di una coscienza propria, '
        'interessate solo a divorare altri esseri umani',
  ),
  StoryScene(
    image: 'assets/story/scene_plane_help.jpg',
    speaker: 'Hostess',
    text: 'Aiuto, comandante! Aiuto!',
  ),
  StoryScene(
    image: 'assets/story/scene_plane_captain.jpg',
    speaker: 'Hostess',
    text: 'Comandante?',
  ),
  StoryScene(
    image: 'assets/story/scene_collapse.jpg',
    text:
        "Quella notte l'intera civiltà umana crollò per colpa di "
        'questa malvagia e misteriosa minaccia',
  ),
];

/// Plays the intro story: each scene shows the bare image first, the next
/// tap reveals the dialogue box, the tap after that moves to the next scene.
/// With [fadeOutAtEnd] the last scene fades to black before [onFinished].
/// With [onExit] an exit button stays in the corner, from the first picture
/// on, to leave at any moment (watching a memory again at a camp).
final class StoryIntro extends StatefulWidget {
  const StoryIntro({
    required this.onFinished,
    this.scenes = introScenes,
    this.fadeOutAtEnd = false,
    this.onExit,
    super.key,
  });

  final List<StoryScene> scenes;
  final VoidCallback onFinished;
  final bool fadeOutAtEnd;
  final VoidCallback? onExit;

  @override
  State<StoryIntro> createState() => _StoryIntroState();
}

final class _StoryIntroState extends State<StoryIntro> {
  int _sceneIndex = 0;
  bool _showText = false;
  bool _fadingOut = false;

  /// Where the finger lifted: the tap that turns the story leaves blood
  /// there, on the left of the screen as much as on the right.
  Offset? _tappedAt;

  void _advance() {
    if (_fadingOut) {
      return;
    }
    final at = _tappedAt;
    if (at != null) {
      BloodSplatLayer.maybeOf(context)?.splat(at, SplatKind.tap);
    }
    AudioScope.of(context).play(Sfx.dialogue);
    setState(() {
      if (!_showText) {
        _showText = true;
        return;
      }
      if (_sceneIndex + 1 < widget.scenes.length) {
        // A new picture is worth a look on its own before its line covers
        // it; when the next line is spoken over the same one there is
        // nothing new to see, so it comes up with the tap.
        final shown = widget.scenes[_sceneIndex].image;
        _sceneIndex += 1;
        _showText = widget.scenes[_sceneIndex].image == shown;
        return;
      }
      if (widget.fadeOutAtEnd) {
        _fadingOut = true;
        return;
      }
      widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scenes[_sceneIndex];
    return GestureDetector(
      key: const ValueKey<String>('story-intro'),
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _tappedAt = details.globalPosition,
      onTap: _advance,
      child: Semantics(
        label: _showText ? 'Tocca per continuare' : 'Tocca per leggere',
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              scene.image,
              key: ValueKey<String>('story-image-$_sceneIndex'),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
            if (_showText)
              Align(
                alignment: Alignment.bottomCenter,
                child: StoryTextBox(speaker: scene.speaker, text: scene.text),
              ),
            if (widget.onExit != null)
              Align(
                alignment: Alignment.topRight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final unit = constraints.maxHeight.isFinite
                        ? constraints.maxHeight /
                              IntegerResolutionViewport.virtualHeight
                        : 1.0;
                    return Padding(
                      padding: EdgeInsets.all(6 * unit),
                      child: MenuButton(
                        key: const ValueKey<String>('story-exit'),
                        label: 'ESCI',
                        unit: unit,
                        compact: true,
                        width: 44,
                        onPressed: widget.onExit,
                      ),
                    );
                  },
                ),
              ),
            if (_fadingOut)
              BlackFade(
                key: const ValueKey<String>('story-fade-out'),
                toBlack: true,
                onDone: widget.onFinished,
              ),
          ],
        ),
      ),
    );
  }
}

/// Blood poured over the top edge of the dialogue box, with a long run down
/// the right margin shedding drops, and some splashed just above the box.
const BloodPainter _boxBlood = BloodPainter(
  band: 5,
  cornerRadius: 6,
  drips: <BloodDrip>[
    BloodDrip(0.06, 14, 5),
    BloodDrip(0.19, 9, 4),
    BloodDrip(0.37, 16, 5),
    BloodDrip(0.55, 8, 3),
    BloodDrip(0.71, 13, 4),
    BloodDrip(0.9, 19, 6),
    BloodDrip(0, 46, 6, fromRight: 13, falling: <double>[3.4, 2.4]),
  ],
  drops: <BloodDrop>[
    BloodDrop(0.14, -0.1, 3.2),
    BloodDrop(0.47, -0.06, 2.4),
    BloodDrop(0.81, -0.16, 4.2),
  ],
);

/// Blood-stained dialogue box shared by the story scenes and the in-game
/// dialogues. An optional [portrait] of the speaker stands on the box's top
/// edge, its lower part tucked behind the box.
final class StoryTextBox extends StatelessWidget {
  const StoryTextBox({
    required this.text,
    this.speaker,
    this.portrait,
    this.portraitOnRight = false,
    super.key,
  });

  static const double portraitTuck = 4;

  /// Font sizes at the 384x216 base resolution; they grow with the view so
  /// text keeps the same share of the screen on phones and monitors.
  static const double speakerFontSize = 12;
  static const double textFontSize = 13;

  final String? speaker;
  final String text;
  final Widget? portrait;
  final bool portraitOnRight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _layout(
        constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1,
      ),
    );
  }

  Widget _layout(double unit) {
    final portrait = this.portrait;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: portrait == null ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: portraitOnRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          // The portrait takes whatever height the box leaves free, so a
          // long line shrinks it instead of pushing its head off screen.
          if (portrait != null)
            Flexible(
              child: Padding(
                padding: portraitOnRight
                    ? const EdgeInsets.only(right: 24)
                    : const EdgeInsets.only(left: 10),
                child: Transform.translate(
                  offset: const Offset(0, portraitTuck),
                  child: portrait,
                ),
              ),
            ),
          _box(unit),
        ],
      ),
    );
  }

  Widget _box(double unit) {
    return BloodOverlay(
      painter: _boxBlood,
      child: Container(
        key: const ValueKey<String>('story-text'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 20, 26, 12),
        decoration: BoxDecoration(
          color: const Color(0xe0140c0c),
          border: Border.all(color: BloodColors.fresh, width: 2),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x88400000), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (speaker != null)
              Text(
                speaker!,
                style: TextStyle(
                  color: BloodColors.bright,
                  fontFamily: 'monospace',
                  fontSize: speakerFontSize * unit,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
              ),
            Text(
              text,
              style: TextStyle(
                color: const Color(0xffd8cfbf),
                fontFamily: 'monospace',
                fontSize: textFontSize * unit,
                height: 1.25,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
