import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// The first journey from the Europe map, to Rome or back home: once the
/// train has arrived, before Mario can move, what he takes with him from
/// one level to the next. In Rome it comes after Luigi's welcome, which
/// [RomeScript] queues first.
final class JourneyScript extends TutorialScript {
  JourneyScript(super.director);

  static const List<TutorialLine> carryLines = <TutorialLine>[
    TutorialLine(
      'Le munizioni e gli oggetti consumabili, come i proiettili o le '
      "molotov, non possono essere portati tra un livello e l'altro",
    ),
    TutorialLine(
      'Gli oggetti non consumabili invece, come la pistola o il rampino, '
      'possono essere portati tra i vari livelli',
    ),
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
      TutorialPrompt(
        carryLines,
        // Alone, it leaves the loading picture time to fade; after Luigi,
        // only a breath between his lines and these.
        delay: director.isIdle
            ? RomeScript.arrivalDelay
            : TutorialDirector.reactionDelay,
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
