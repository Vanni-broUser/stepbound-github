import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  AmmoComponent ammo() => world.player.component<AmmoComponent>();

  List<String> shown() => host.shown.last.map((line) => line.text).toList();

  test('the launcher found: the news, how it shoots, where its rounds are, '
      'and its badge; no choice to tell of without a round for it', () {
    ammo()
      ..hasGun = true
      ..hasRocketLauncher = true;
    director.onEvents(<WorldEvent>[
      pickedUp(rocketLauncherPickupId, rocketLauncher: true),
    ]);
    settle();
    expect(shown(), <String>[
      BackpacksScript.rocketLauncherFound,
      BackpacksScript.rocketLauncherLesson,
      BackpacksScript.rocketRoundsLesson,
    ]);
    expect(host.unlocked, contains(HudElement.rockets));
    expect(host.pickupAnimations, 1);
  });

  test('found with the pistol and the rounds from the Duomo already on him: '
      'choosing is taught too, and only once', () {
    ammo()
      ..hasGun = true
      ..hasRocketLauncher = true
      ..rockets = 2;
    director.onEvents(<WorldEvent>[
      pickedUp(rocketLauncherPickupId, rocketLauncher: true),
    ]);
    settle();
    expect(shown().last, BackpacksScript.weaponChoiceLesson);
    expect(shown(), hasLength(4));
    host.dismiss();

    director.onEvents(<WorldEvent>[
      pickedUp(duomoFarTowerBackpackId, rockets: 2),
    ]);
    settle();
    expect(shown(), <String>['Hai trovato 2 colpi per lanciarazzi']);
  });

  test('the rounds found after the launcher, the pistol in hand: the news '
      'of them, then the choice', () {
    ammo()
      ..hasGun = true
      ..hasRocketLauncher = true
      ..rockets = 2;
    director.onEvents(<WorldEvent>[
      pickedUp(duomoFarTowerBackpackId, rockets: 2),
    ]);
    settle();
    expect(shown(), <String>[
      'Hai trovato 2 colpi per lanciarazzi',
      BackpacksScript.weaponChoiceLesson,
    ]);
  });

  test('the launcher alone, no pistol found yet: no choice, and the pistol '
      'found later teaches it', () {
    ammo()
      ..hasGun = false
      ..hasRocketLauncher = true
      ..rockets = 2;
    director.onEvents(<WorldEvent>[
      pickedUp(rocketLauncherPickupId, rocketLauncher: true),
    ]);
    settle();
    expect(shown(), hasLength(3));
    host.dismiss();

    ammo().hasGun = true;
    director.onEvents(<WorldEvent>[pickedUp(gunBackpackId, gun: true)]);
    settle();
    expect(shown().last, BackpacksScript.weaponChoiceLesson);
  });
}
