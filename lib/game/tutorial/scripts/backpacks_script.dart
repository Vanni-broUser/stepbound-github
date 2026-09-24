import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// Backpacks, wherever they are: the first one seen teaches picking them up
/// and unlocks the interact button (slipping past the first zombie can lead
/// to the accident one first); each one collected says what it held,
/// unlocking the ammo counter and, with the pistol, the shoot button.
final class BackpacksScript extends TutorialScript {
  BackpacksScript(super.director);

  static const String backpackLesson =
      'Raccogli gli zaini in giro per trovare nuovo equipaggiamento';
  static const String interactLesson =
      'Usa il nuovo bottone a destra per interagire con gli oggetti';
  static const String noGun = 'Non hai una pistola';
  static const String gunFound = 'Hai trovato una pistola';
  static const String incenseFound = "Hai trovato dell'incenso";
  static const String shootLesson =
      'Usa il bottone per mirare, scegli una direzione e poi premi '
      'nuovamente il bottone per sparare';

  /// "Non hai una pistola" only while the player really has none.
  static String ammoFound(int rounds, {required bool hasGun}) => hasGun
      ? 'Hai trovato $rounds proiettili'
      : 'Hai trovato $rounds proiettili. $noGun';

  bool _lessonGiven = false;

  @override
  String get key => 'backpacks';

  @override
  void onEvent(WorldEvent event) {
    if (event case PickedUpEvent(:final ammo, :final gun, :final incense)) {
      host.playPickupAnimation();
      say(_found(ammo: ammo, gun: gun, incense: incense));
    }
  }

  TutorialPrompt _found({
    required int ammo,
    required bool gun,
    required bool incense,
  }) {
    if (incense) {
      // The censer goes up in the corner as soon as the box is read, so
      // the news and the icon appearing are one moment.
      return TutorialPrompt(
        const <TutorialLine>[TutorialLine(incenseFound)],
        delay: TutorialDirector.pickupDelay,
        onShown: () => host.unlock(HudElement.incense),
      );
    }
    if (gun) {
      return TutorialPrompt(
        const <TutorialLine>[TutorialLine(gunFound), TutorialLine(shootLesson)],
        delay: TutorialDirector.pickupDelay,
        onDismissed: () => host.unlock(HudElement.shoot),
      );
    }
    final hasGun = world.player.component<AmmoComponent>().hasGun;
    return TutorialPrompt(
      <TutorialLine>[TutorialLine(ammoFound(ammo, hasGun: hasGun))],
      delay: TutorialDirector.pickupDelay,
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
      TutorialPrompt(
        const <TutorialLine>[
          TutorialLine(backpackLesson),
          TutorialLine(interactLesson),
        ],
        delay: TutorialDirector.reactionDelay,
        onDismissed: () => host.unlock(HudElement.interact),
      ),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{'lesson': _lessonGiven};

  @override
  void restore(Map<String, Object?> json) {
    _lessonGiven = json['lesson'] as bool? ?? false;
  }
}
