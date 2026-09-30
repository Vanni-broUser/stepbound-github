import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// The first journey from the Europe map, to Rome or back home: once the
/// train has arrived, before Mario can move, what he takes with him from
/// one level to the next. In Rome it comes after Luigi's welcome, which
/// [RomeScript] queues first.
final class JourneyScript extends StoryScript {
  JourneyScript(super.director);

  static List<StoryLine> get carryLines => <StoryLine>[
    StoryLine(strings.journeyCarryLines1),
    StoryLine(strings.journeyCarryLines2),
  ];

  bool _taught = false;

  @override
  String get key => 'journey';

  @override
  void update({required bool turnAnimating}) {
    if (_taught || !progress.hasTravelled) {
      return;
    }
    _taught = true;
    host.stopWalking();
    say(
      StoryPrompt(
        carryLines,
        // Alone, it leaves the loading picture time to fade; after Luigi,
        // only a breath between his lines and these.
        delay: director.isIdle
            ? RomeScript.arrivalDelay
            : StoryDirector.reactionDelay,
        holdsInput: true,
      ),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{'taught': _taught};

  @override
  void restore(Map<String, Object?> json) {
    _taught = json['taught'] as bool? ?? false;
  }
}
