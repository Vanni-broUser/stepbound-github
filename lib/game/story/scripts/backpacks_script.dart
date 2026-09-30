import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// Backpacks, wherever they are: the first one seen teaches picking them up
/// and unlocks interacting (slipping past the first zombie can lead
/// to the accident one first); each one collected says what it held,
/// unlocking the ammo counter and, with the pistol, shooting.
final class BackpacksScript extends StoryScript {
  BackpacksScript(super.director);

  static const String backpackLesson =
      'Raccogli gli zaini in giro per trovare nuovo equipaggiamento';
  static const String interactLesson =
      'Tocca la parte destra dello schermo per interagire con gli oggetti '
      'vicini';
  static const String noGun = 'Non hai una pistola';
  static const String gunFound = 'Hai trovato una pistola';
  static const String incenseFound = "Hai trovato dell'incenso";
  static const String ringFound = 'Hai trovato un anello episcopale';
  static const String duomoKeyFound =
      'Hai trovato la Chiave del Duomo vicino il cadavere di Don Angelo';
  static const String grapplingHookFound = 'Hai trovato un rampino';
  static const String palazzoKeyFound = 'Hai trovato la Chiave del terzo piano';
  static const String goldIngotFound = "Hai trovato un lingotto d'oro";
  static const String goldIngotThought =
      'Questo andrà bene per quei due maranza. Non penso di poterne fare '
      "qualcos'altro";
  static const String grapplingHookLesson =
      'Con il rampino puoi raggiungere i tetti vicini che non riuscivi a '
      'raggiungere';
  static const String noRocketLauncher = 'Non hai un lanciarazzi';

  /// "Non hai un lanciarazzi" only while the player really has none.
  static String rocketsFound(int rounds, {required bool hasLauncher}) {
    final found = rounds == 1
        ? 'Hai trovato 1 colpo per lanciarazzi'
        : 'Hai trovato $rounds colpi per lanciarazzi';
    return hasLauncher ? found : '$found. $noRocketLauncher';
  }

  static String molotovFound(int count) => 'Hai trovato $count molotov';
  static const String molotovLesson = 'Le molotov fanno danno ad area';

  /// Told once, the first time Mario has more than one weapon to hold.
  static const String weaponChoiceLesson =
      "Puoi impugnare un'arma per volta, tocca l'arma che vuoi impugnare tra "
      "gli oggetti dell'inventario. Le fiamme indicheranno l'arma attiva";
  static const String aimLesson =
      'Tieni premuto sulla parte destra dello schermo per iniziare a mirare';
  static const String fireLesson =
      'Mentre tieni premuto trascina verso una direzione, appena alzi il '
      'dito parte il colpo';
  static const String cancelLesson =
      'Puoi annullare il colpo di pistola senza consumare proiettili alzando '
      'il dito mentre sei nel punto centrale';

  /// "Non hai una pistola" only while the player really has none.
  static String ammoFound(int rounds, {required bool hasGun}) => hasGun
      ? 'Hai trovato $rounds proiettili'
      : 'Hai trovato $rounds proiettili. $noGun';

  bool _lessonGiven = false;

  /// Whether [weaponChoiceLesson] has been told.
  bool _weaponChoiceTaught = false;

  /// [weaponChoiceLesson], the first time Mario holds both the pistol and
  /// a molotov; nothing otherwise.
  List<StoryLine> _weaponChoice({
    required bool hasGun,
    required bool hasMolotov,
  }) {
    if (_weaponChoiceTaught || !hasGun || !hasMolotov) {
      return const <StoryLine>[];
    }
    _weaponChoiceTaught = true;
    return const <StoryLine>[StoryLine(weaponChoiceLesson)];
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
    )) {
      host.playPickupAnimation();
      // The Duomo's script tells of the robe: it dresses Mario in it.
      if (cultistRobe) {
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
            const <StoryLine>[
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
            const <StoryLine>[
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
            const <StoryLine>[StoryLine(palazzoKeyFound)],
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
            const <StoryLine>[StoryLine(duomoKeyFound)],
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
            const <StoryLine>[StoryLine(ringFound)],
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
                const StoryLine(molotovLesson, demo: ControlDemo.aim),
              ..._weaponChoice(
                hasGun: world.player.component<AmmoComponent>().hasGun,
                hasMolotov: true,
              ),
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
        const <StoryLine>[StoryLine(incenseFound)],
        delay: StoryDirector.pickupDelay,
        onShown: () => host.unlock(HudElement.incense),
      );
    }
    if (gun) {
      return StoryPrompt(
        <StoryLine>[
          const StoryLine(gunFound),
          const StoryLine(aimLesson, demo: ControlDemo.aim),
          const StoryLine(fireLesson, demo: ControlDemo.aim),
          const StoryLine(cancelLesson, demo: ControlDemo.cancelShot),
          ..._weaponChoice(
            hasGun: true,
            hasMolotov: world.player.component<AmmoComponent>().molotovs > 0,
          ),
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
        const <StoryLine>[
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
