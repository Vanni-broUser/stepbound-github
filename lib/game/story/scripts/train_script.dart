import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// Mario and Luigi's home in the locomotive: talking to Luigi, the books by
/// Mario's cot (the zombie types met so far), the wardrobe (what to wear),
/// the cot itself (the figures of the adventure city by city, their
/// missions and their memories to live again) and the ammunition crate
/// beside it, which loads Mario up to [trainAmmoRefill] rounds whenever he
/// has fewer.
/// Each says a line first, so Mario always knows what he is using. None of
/// it is used up, so each can be come back to.
final class TrainScript extends StoryScript {
  TrainScript(super.director);

  static const StoryLine luigiLine = StoryLine.luigi(
    "Sarà un viaggio per l'Europa molto impegnativo",
  );

  /// What Luigi has to say while the train stands in Rome.
  static const List<StoryLine> romeLines = <StoryLine>[
    StoryLine.luigi('Tutte le strade portano a Roma ragazzo'),
    StoryLine.luigi('Cosa? Dici che l’avevo già detto?'),
  ];

  /// What the cot says before the figures of the adventure open, from
  /// which the memories can be lived again.
  static const String cotLine =
      "Ripensa all'avventura: statistiche, missioni e ricordi";

  static const String ammoRefilled =
      'Munizioni ricaricate. Torna qui in qualsiasi momento se hai meno di '
      '$trainAmmoRefill proiettili per ricaricare';

  static const String ammoFull =
      'Hai già abbastanza munizioni. Torna qui quando avrai meno di '
      '$trainAmmoRefill proiettili per ricaricare';

  /// What the books say before they open.
  static const String zombieNotes = 'Appunti sugli zombi conosciuti';

  /// What the wardrobe says before the outfits show.
  static const String wardrobeLine = 'Scegli quale abbigliamento indossare';

  @override
  String get key => 'train';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent) {
      return;
    }
    if (event.at == trainLuigiTile) {
      say(
        StoryPrompt(switch (progress.level) {
          LevelId.hometown => const <StoryLine>[luigiLine],
          LevelId.rome => romeLines,
        }),
      );
    } else if (trainBookTiles.contains(event.at)) {
      say(
        StoryPrompt(const <StoryLine>[
          StoryLine(zombieNotes),
        ], onDismissed: host.openZombieBook),
      );
    } else if (trainWardrobeTiles.contains(event.at)) {
      say(
        StoryPrompt(const <StoryLine>[
          StoryLine(wardrobeLine),
        ], onDismissed: host.openWardrobe),
      );
    } else if (trainCotTiles.contains(event.at)) {
      say(
        StoryPrompt(const <StoryLine>[
          StoryLine(cotLine),
        ], onDismissed: host.openAdventureStats),
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
      say(StoryPrompt(const <StoryLine>[StoryLine(ammoFull)]));
      return;
    }
    ammo.loaded = trainAmmoRefill;
    host.unlock(HudElement.ammo);
    say(StoryPrompt(const <StoryLine>[StoryLine(ammoRefilled)]));
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
