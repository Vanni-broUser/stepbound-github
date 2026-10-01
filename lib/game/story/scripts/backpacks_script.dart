import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/l10n/language.dart';

/// Backpacks, wherever they are: the first one seen teaches picking them up
/// and unlocks interacting (slipping past the first zombie can lead
/// to the accident one first); each one collected says what it held,
/// unlocking the ammo counter and, with the pistol, shooting.
final class BackpacksScript extends StoryScript {
  BackpacksScript(super.director);

  static String get backpackLesson => strings.backpacksBackpackLesson;
  static String get interactLesson => strings.backpacksInteractLesson;
  static String get noGun => strings.backpacksNoGun;
  static String get gunFound => strings.backpacksGunFound;
  static String get incenseFound => strings.backpacksIncenseFound;
  static String get ringFound => strings.backpacksRingFound;
  static String get duomoKeyFound => strings.backpacksDuomoKeyFound;
  static String get grapplingHookFound => strings.backpacksGrapplingHookFound;
  static String get palazzoKeyFound => strings.backpacksPalazzoKeyFound;
  static String get goldIngotFound => strings.backpacksGoldIngotFound;
  static String get goldIngotThought => strings.backpacksGoldIngotThought;
  static String get grapplingHookLesson => strings.backpacksGrapplingHookLesson;
  static String get noRocketLauncher => strings.backpacksNoRocketLauncher;
  static String get rocketLauncherFound => strings.backpacksRocketLauncherFound;
  static String get rocketLauncherLesson =>
      strings.backpacksRocketLauncherLesson;
  static String get rocketRoundsLesson => strings.backpacksRocketRoundsLesson;

  /// "Non hai un lanciarazzi" only while the player really has none.
  static String rocketsFound(int rounds, {required bool hasLauncher}) {
    final found = strings.backpacksRocketsFound(rounds);
    return hasLauncher ? found : '$found. $noRocketLauncher';
  }

  static String molotovFound(int count) =>
      strings.backpacksMolotovsFound(count);
  static String get molotovLesson => strings.backpacksMolotovLesson;

  /// Told once, the first time Mario has more than one weapon to hold.
  static String get weaponChoiceLesson => strings.backpacksWeaponChoiceLesson;
  static String get aimLesson => strings.backpacksAimLesson;
  static String get fireLesson => strings.backpacksFireLesson;
  static String get cancelLesson => strings.backpacksCancelLesson;

  /// "Non hai una pistola" only while the player really has none.
  static String ammoFound(int rounds, {required bool hasGun}) => hasGun
      ? strings.backpacksBulletsFound(rounds)
      : '${strings.backpacksBulletsFound(rounds)}. $noGun';

  bool _lessonGiven = false;

  /// Whether [weaponChoiceLesson] has been told.
  bool _weaponChoiceTaught = false;

  /// [weaponChoiceLesson], the first time Mario has more than one weapon
  /// to hold (the pistol, a molotov, the launcher with a round for it);
  /// nothing otherwise.
  List<StoryLine> _weaponChoice() {
    final ammo = world.player.component<AmmoComponent>();
    final weapons = <bool>[
      ammo.hasGun,
      ammo.molotovs > 0,
      ammo.hasRocketLauncher && ammo.rockets > 0,
    ].where((held) => held).length;
    if (_weaponChoiceTaught || weapons < 2) {
      return const <StoryLine>[];
    }
    _weaponChoiceTaught = true;
    return <StoryLine>[StoryLine(weaponChoiceLesson)];
  }

  @override
  String get key => 'backpacks';

  @override
  void onEvent(WorldEvent event) {
    if (event case PickedUpEvent(
      :final ammo,
      :final gun,
      :final molotovs,
      :final incense,
      :final episcopalRing,
      :final cultistRobe,
      :final duomoKey,
      :final grapplingHook,
      :final palazzoKey,
      :final goldIngot,
      :final rockets,
      :final rocketLauncher,
    )) {
      host.playPickupAnimation();
      // The Duomo's script tells of the robe: it dresses Mario in it.
      if (cultistRobe) {
        return;
      }
      if (rocketLauncher) {
        say(
          StoryPrompt(
            <StoryLine>[
              StoryLine(rocketLauncherFound),
              StoryLine(rocketLauncherLesson),
              StoryLine(rocketRoundsLesson),
              ..._weaponChoice(),
            ],
            delay: StoryDirector.pickupDelay,
            onShown: () => host.unlock(HudElement.rockets),
          ),
        );
        return;
      }
      if (rockets > 0) {
        final hasLauncher = world.player
            .component<AmmoComponent>()
            .hasRocketLauncher;
        say(
          StoryPrompt(
            <StoryLine>[
              StoryLine(rocketsFound(rockets, hasLauncher: hasLauncher)),
              ..._weaponChoice(),
            ],
            delay: StoryDirector.pickupDelay,
            onShown: () => host.unlock(HudElement.rockets),
          ),
        );
        return;
      }
      if (grapplingHook) {
        say(
          StoryPrompt(
            <StoryLine>[
              StoryLine(grapplingHookFound),
              StoryLine(grapplingHookLesson),
            ],
            delay: StoryDirector.pickupDelay,
            onShown: () => host.unlock(HudElement.grapplingHook),
          ),
        );
        return;
      }
      if (goldIngot) {
        // What Tonino and Marcello asked for: it is theirs once Mario has
        // taken it to them (see MaranzaScript).
        say(
          StoryPrompt(
            <StoryLine>[
              StoryLine(goldIngotFound),
              StoryLine.mario(goldIngotThought),
            ],
            delay: StoryDirector.pickupDelay,
            onShown: () => host.unlock(HudElement.goldIngot),
          ),
        );
        return;
      }
      if (palazzoKey) {
        say(
          StoryPrompt(
            <StoryLine>[StoryLine(palazzoKeyFound)],
            delay: StoryDirector.pickupDelay,
            onShown: () => host.unlock(HudElement.palazzoKey),
          ),
        );
        return;
      }
      if (duomoKey) {
        // Whose it was is the news, as much as the key itself.
        say(
          StoryPrompt(
            <StoryLine>[StoryLine(duomoKeyFound)],
            delay: StoryDirector.pickupDelay,
            onShown: () => host.unlock(HudElement.duomoKey),
          ),
        );
        return;
      }
      if (episcopalRing) {
        // Like the incense: the news and the badge are one moment.
        say(
          StoryPrompt(
            <StoryLine>[StoryLine(ringFound)],
            delay: StoryDirector.pickupDelay,
            onShown: () => host.unlock(HudElement.episcopalRing),
          ),
        );
        return;
      }
      if (molotovs > 0) {
        say(
          StoryPrompt(
            <StoryLine>[
              StoryLine(molotovFound(molotovs)),
              if (!host.isUnlocked(HudElement.molotov))
                // The same finger that fires the pistol throws the
                // bottle: the gesture plays beside the line about it.
                StoryLine(molotovLesson, demo: ControlDemo.aim),
              ..._weaponChoice(),
            ],
            delay: StoryDirector.pickupDelay,
            onShown: () => host.unlock(HudElement.molotov),
          ),
        );
        return;
      }
      say(_found(ammo: ammo, gun: gun, incense: incense));
    }
  }

  StoryPrompt _found({
    required int ammo,
    required bool gun,
    required bool incense,
  }) {
    if (incense) {
      // The censer goes up in the corner as soon as the box is read, so
      // the news and the icon appearing are one moment.
      return StoryPrompt(
        <StoryLine>[StoryLine(incenseFound)],
        delay: StoryDirector.pickupDelay,
        onShown: () => host.unlock(HudElement.incense),
      );
    }
    if (gun) {
      return StoryPrompt(
        <StoryLine>[
          StoryLine(gunFound),
          StoryLine(aimLesson, demo: ControlDemo.aim),
          StoryLine(fireLesson, demo: ControlDemo.aim),
          StoryLine(cancelLesson, demo: ControlDemo.cancelShot),
          ..._weaponChoice(),
        ],
        delay: StoryDirector.pickupDelay,
        onDismissed: () => host.unlock(HudElement.shoot),
      );
    }
    final hasGun = world.player.component<AmmoComponent>().hasGun;
    return StoryPrompt(
      <StoryLine>[StoryLine(ammoFound(ammo, hasGun: hasGun))],
      delay: StoryDirector.pickupDelay,
      onShown: () => host.unlock(HudElement.ammo),
    );
  }

  @override
  void update({required bool turnAnimating}) {
    if (_lessonGiven) {
      return;
    }
    final seen = world.pickups.values.any(
      (backpack) => backpack.active && host.isTileVisible(backpack.position),
    );
    if (!seen) {
      return;
    }
    _lessonGiven = true;
    say(
      StoryPrompt(
        <StoryLine>[
          StoryLine(backpackLesson),
          StoryLine(interactLesson, demo: ControlDemo.interact),
        ],
        delay: StoryDirector.reactionDelay,
        onDismissed: () => host.unlock(HudElement.interact),
      ),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'lesson': _lessonGiven,
    'weaponChoice': _weaponChoiceTaught,
  };

  @override
  void restore(Map<String, Object?> json) {
    _lessonGiven = json['lesson'] as bool? ?? false;
    _weaponChoiceTaught = json['weaponChoice'] as bool? ?? false;
  }
}
