import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:url_launcher/url_launcher.dart';

/// The work-in-progress screen: the developer at his laptop, and the
/// words saying the demo ends here, what is still to be made and where to
/// tell him what you think of it. It comes up wherever the game goes no
/// further yet, at every walkable edge of a map that has no next map
/// (`workInProgressEnds`): in the game as it is, the streets off Piazza di
/// Santa Maria Maggiore. A tap takes it away and Mario is back a step
/// inside; a tap on the link opens Instagram instead. Every unfinished way
/// out shows this same screen, in any level: see docs/level_pipeline.md,
/// "Strade incomplete".
final class WorkInProgressScreen extends StatelessWidget {
  const WorkInProgressScreen({
    required this.onBack,
    this.openLink = _launch,
    super.key,
  });

  static const String image = 'assets/story/placeholders/work_in_progress.jpg';
  static const String title =
      'La demo finisce qui,\nil seguito deve ancora essere programmato';
  static const String missingItems =
      'I seguenti oggetti non sono ancora stati implementati:\n'
      'Estintore, Piede di porco';
  static const String feedback = 'Fammi sapere se il gioco ti piace';

  /// The Instagram pages to write to, in the order they are shown.
  static const List<String> instagramHandles = <String>[
    'fastsite_',
    'vannicolasanto',
  ];
  static Uri instagram(String handle) =>
      Uri.parse('https://www.instagram.com/$handle/');

  final VoidCallback onBack;

  /// Opens an [instagram] page: the browser or the app, outside the game.
  /// Tests pass their own.
  final Future<void> Function(Uri link) openLink;

  static Future<void> _launch(Uri link) async {
    await launchUrl(link, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('work-in-progress'),
      behavior: HitTestBehavior.opaque,
      onTap: onBack,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unit =
              constraints.maxHeight / IntegerResolutionViewport.virtualHeight;
          TextStyle style(double size, {Color color = _cream}) => TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontSize: size * unit,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2 * unit,
            decoration: TextDecoration.none,
            decorationColor: color,
            // A dark outline all round each letter, and a soft shadow: the
            // words read on the picture without darkening it.
            shadows: <Shadow>[
              for (final (dx, dy) in _outline)
                Shadow(offset: Offset(dx * unit, dy * unit)),
              Shadow(blurRadius: 4 * unit),
            ],
          );
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                image,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
              ),
              ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
              // Down the left, over the rubble, clear of the laptop and
              // the hands on it.
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10 * unit, 0, 0, 8 * unit),
                  child: Column(
                    key: const ValueKey<String>('work-in-progress-caption'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.37,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(title, style: style(12)),
                            SizedBox(height: 4 * unit),
                            Text(missingItems, style: style(7.5)),
                            SizedBox(height: 3 * unit),
                            Text(feedback, style: style(7.5)),
                          ],
                        ),
                      ),
                      // The one line let run on past the column, under the
                      // laptop: the pages all on it, fastsite_ first.
                      Padding(
                        padding: EdgeInsets.only(top: 3 * unit),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text('Instagram', style: style(8)),
                            for (final handle in instagramHandles)
                              GestureDetector(
                                key: ValueKey<String>(
                                  'work-in-progress-link-$handle',
                                ),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => openLink(instagram(handle)),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    6 * unit,
                                    2 * unit,
                                    0,
                                    2 * unit,
                                  ),
                                  child: Text(
                                    '@$handle',
                                    style: style(8, color: _link).copyWith(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const Color _cream = Color(0xffe8dfcc);
  static const List<(double, double)> _outline = <(double, double)>[
    (-1, -1),
    (0, -1),
    (1, -1),
    (-1, 0),
    (1, 0),
    (-1, 1),
    (0, 1),
    (1, 1),
  ];
  static const Color _link = Color(0xfff2b8d8);
}
