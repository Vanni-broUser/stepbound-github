import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// Mario and Luigi's home in the locomotive: talking to Luigi, the books by
/// Mario's cot (the zombie types met so far), the wardrobe (what to wear),
/// the cot itself (the figures of the adventure city by city, their
/// missions and their memories to live again) and the ammunition crate
/// beside it, which loads Mario up to [trainAmmoRefill] rounds whenever he
/// has fewer, and gives him a rocket when his launcher has none.
/// Each says a line first, so Mario always knows what he is using. None of
/// it is used up, so each can be come back to.
final class TrainScript extends StoryScript {
  TrainScript(super.director);

  static StoryLine get luigiLine => StoryLine.luigi(strings.trainLuigiLine);

  /// What Luigi has to say while the train stands in Rome.
  static List<StoryLine> get romeLines => <StoryLine>[
    StoryLine.luigi(strings.trainRomeLines1),
    StoryLine.luigi(strings.trainRomeLines2),
  ];

  /// What the cot says before the figures of the adventure open, from
  /// which the memories can be lived again.
  static String get cotLine => strings.trainCotLine;

  static String get ammoRefilled => strings.trainAmmoRefilled(trainAmmoRefill);

  static String get ammoFull => strings.trainAmmoFull(trainAmmoRefill);

  static String get rocketRefilled => strings.trainRocketRefilled;

  /// Chiara in her corner of the second coach, once she is aboard: where
  /// the train is taking them, and in Rome what she makes of it.
  static List<StoryLine> get chiaraHometownLines => <StoryLine>[
    StoryLine(
      strings.trainChiaraHometownLines1,
      speaker: CompanyScript.chiara,
      portrait: CompanyScript.chiaraPortrait,
    ),
  ];
  static List<StoryLine> get chiaraRomeLines => <StoryLine>[
    StoryLine(
      strings.trainChiaraRomeLines1,
      speaker: CompanyScript.chiara,
      portrait: CompanyScript.chiaraPortrait,
    ),
    StoryLine(
      strings.trainChiaraRomeLines2,
      speaker: CompanyScript.chiara,
      portrait: CompanyScript.chiaraPortrait,
    ),
  ];

  /// What the books say before they open.
  static String get zombieNotes => strings.trainZombieNotes;

  /// What the wardrobe says before the outfits show.
  static String get wardrobeLine => strings.trainWardrobeLine;

  @override
  String get key => 'train';

  @override
  void onEvent(WorldEvent event) {
    if (event is! LookedOutEvent) {
      return;
    }
    if (event.at == trainChiaraTile) {
      if (director.scripts.whereType<CompanyScript>().first.aboard) {
        say(
          StoryPrompt(switch (progress.level) {
            LevelId.hometown => chiaraHometownLines,
            LevelId.rome => chiaraRomeLines,
          }),
        );
      }
      return;
    }
    if (event.at == trainLuigiTile) {
      say(
        StoryPrompt(switch (progress.level) {
          LevelId.hometown => <StoryLine>[luigiLine],
          LevelId.rome => romeLines,
        }),
      );
    } else if (trainBookTiles.contains(event.at)) {
      say(
        StoryPrompt(<StoryLine>[
          StoryLine(zombieNotes),
        ], onDismissed: host.openZombieBook),
      );
    } else if (trainWardrobeTiles.contains(event.at)) {
      say(
        StoryPrompt(<StoryLine>[
          StoryLine(wardrobeLine),
        ], onDismissed: host.openWardrobe),
      );
    } else if (trainCotTiles.contains(event.at)) {
      say(
        StoryPrompt(<StoryLine>[
          StoryLine(cotLine),
        ], onDismissed: host.openAdventureStats),
      );
    } else if (trainAmmoTiles.contains(event.at)) {
      _refill();
    }
  }

  /// With [trainAmmoRefill] rounds or more, and a rocket in the launcher
  /// if he has one, there is nothing to take, and a line says so.
  void _refill() {
    final ammo = world.player.component<AmmoComponent>();
    final rounds = ammo.loaded < trainAmmoRefill;
    final rocket = ammo.hasRocketLauncher && ammo.rockets == 0;
    if (!rounds && !rocket) {
      say(StoryPrompt(<StoryLine>[StoryLine(ammoFull)]));
      return;
    }
    if (rounds) {
      ammo.loaded = trainAmmoRefill;
      host.unlock(HudElement.ammo);
    }
    if (rocket) {
      ammo.rockets = 1;
    }
    say(
      StoryPrompt(<StoryLine>[
        if (rounds) StoryLine(ammoRefilled),
        if (rocket) StoryLine(rocketRefilled),
      ]),
    );
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
