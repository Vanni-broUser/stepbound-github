import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// Mario and Luigi's home in the locomotive: talking to Luigi, the books by
/// Mario's cot (the zombie types met so far), the cot itself (the memories
/// of the city the train stands in) and the ammunition crate beside it,
/// which loads Mario up to [trainAmmoRefill] rounds whenever he has fewer.
/// Each says a line first, so Mario always knows what he is using. None of
/// it is used up, so each can be come back to.
final class TrainScript extends TutorialScript {
  TrainScript(super.director);

  static const TutorialLine luigiLine = TutorialLine.luigi(
    "Sarà un viaggio per l'Europa molto impegnativo",
  );

  /// What Luigi has to say while the train stands in Rome.
  static const List<TutorialLine> romeLines = <TutorialLine>[
    TutorialLine.luigi('Tutte le strade portano a Roma ragazzo'),
    TutorialLine.luigi('Cosa? Dici che l’avevo già detto?'),
  ];

  /// What the cot says before the memories play: only those of the city
  /// the train stands in, each city its own.
  static String memoriesLine(LevelId level) => switch (level) {
    LevelId.hometown => 'Rivedi i ricordi della città natale',
    LevelId.rome => 'Rivedi i ricordi di Roma',
  };

  static const String ammoRefilled =
      'Munizioni ricaricate. Torna qui in qualsiasi momento se hai meno di '
      '$trainAmmoRefill proiettili per ricaricare';

  static const String ammoFull =
      'Hai già abbastanza munizioni. Torna qui quando avrai meno di '
      '$trainAmmoRefill proiettili per ricaricare';

  /// What the books say before they open.
  static const String zombieNotes = 'Appunti sugli zombi conosciuti';

  @override
  String get key => 'train';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent) {
      return;
    }
    if (event.at == trainLuigiTile) {
      say(
        TutorialPrompt(switch (progress.level) {
          LevelId.hometown => const <TutorialLine>[luigiLine],
          LevelId.rome => romeLines,
        }),
      );
    } else if (trainBookTiles.contains(event.at)) {
      say(
        TutorialPrompt(const <TutorialLine>[
          TutorialLine(zombieNotes),
        ], onDismissed: host.openZombieBook),
      );
    } else if (trainCotTiles.contains(event.at)) {
      say(
        TutorialPrompt(<TutorialLine>[
          TutorialLine(memoriesLine(progress.level)),
        ], onDismissed: host.replayMemories),
      );
    } else if (trainAmmoTiles.contains(event.at)) {
      _refill();
    }
  }

  /// With five rounds or more there is nothing to take, and a line says
  /// so.
  void _refill() {
    final ammo = world.player.component<AmmoComponent>();
    if (ammo.loaded >= trainAmmoRefill) {
      say(TutorialPrompt(const <TutorialLine>[TutorialLine(ammoFull)]));
      return;
    }
    ammo.loaded = trainAmmoRefill;
    host.unlock(HudElement.ammo);
    say(TutorialPrompt(const <TutorialLine>[TutorialLine(ammoRefilled)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
