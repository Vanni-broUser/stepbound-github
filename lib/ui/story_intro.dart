import 'package:flutter/material.dart';

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
    text: '... Che succede? ... Ragazzi, la luce?',
  ),
  StoryScene(image: 'assets/story/scene_attack.png', text: 'Aaaaahhh!'),
];

/// Plays the intro story: each scene shows the bare image first, the next
/// tap reveals the dialogue box, the tap after that moves to the next scene.
final class StoryIntro extends StatefulWidget {
  const StoryIntro({
    required this.onFinished,
    this.scenes = introScenes,
    super.key,
  });

  final List<StoryScene> scenes;
  final VoidCallback onFinished;

  @override
  State<StoryIntro> createState() => _StoryIntroState();
}

final class _StoryIntroState extends State<StoryIntro> {
  int _sceneIndex = 0;
  bool _showText = false;

  void _advance() {
    setState(() {
      if (!_showText) {
        _showText = true;
        return;
      }
      if (_sceneIndex + 1 < widget.scenes.length) {
        _sceneIndex += 1;
        _showText = false;
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
                child: _StoryTextBox(scene: scene),
              ),
          ],
        ),
      ),
    );
  }
}

final class _StoryTextBox extends StatelessWidget {
  const _StoryTextBox({required this.scene});

  final StoryScene scene;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        key: const ValueKey<String>('story-text'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
        decoration: BoxDecoration(
          color: const Color(0xdd10181a),
          border: Border.all(color: const Color(0xff8a8377), width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (scene.speaker != null)
              Text(
                scene.speaker!,
                style: const TextStyle(
                  color: Color(0xffe4705f),
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
              ),
            Text(
              scene.text,
              style: const TextStyle(
                color: Color(0xffd8cfbf),
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.25,
                decoration: TextDecoration.none,
              ),
            ),
            const Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.arrow_drop_down,
                color: Color(0xffd8cfbf),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
