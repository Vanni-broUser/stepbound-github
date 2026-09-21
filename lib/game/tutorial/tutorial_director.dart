import 'package:stepbound/core/core.dart';

/// A line shown in the dialogue box over the gameplay.
final class TutorialLine {
  const TutorialLine(this.text, {this.speaker = 'Tutorial', this.portrait});

  /// A line spoken by Mario, with his portrait over the box.
  const TutorialLine.mario(this.text)
    : speaker = 'Mario Rossi',
      portrait = 'assets/story/portrait_mario.png';

  final String speaker;
  final String text;
  final String? portrait;
}

/// Touch controls that the tutorial unlocks one at a time. The arrows are
/// always there.
enum HudElement { interact, ammo, shoot }

/// What the director needs from the game.
abstract interface class TutorialHost {
  /// True when the whole tile is inside the camera view.
  bool isTileVisible(GridPoint tile);

  /// Shows [lines] one per tap; the game pauses until [onDismissed].
  void showPrompt(List<TutorialLine> lines, {void Function()? onDismissed});

  bool get isPromptVisible;

  /// Mario's crouch-and-grab, played when a backpack is collected.
  void playPickupAnimation();

  /// Frames the player together with [entityId]; null follows the player
  /// alone again.
  void focusOn(String? entityId);

  /// Adds a zombie that comes out of the dark.
  void spawnZombie(Entity zombie);

  void unlock(HudElement element);
}

final class _QueuedPrompt {
  _QueuedPrompt(this.lines, {this.delay = 0, this.onShown, this.onDismissed});

  final List<TutorialLine> lines;
  double delay;
  final void Function()? onShown;
  final void Function()? onDismissed;
}

/// Runs the scripted tutorial:
/// 1. the zombie east of the crossroads spots the player and steps closer,
///    then the wanderer's pace is explained;
/// 2. seeing the backpack on the north road teaches backpacks and unlocks
///    the interact button; it holds two bullets (the ammo counter appears);
/// 3. at the barracks Mario hopes he is safe; a few steps inside, the
///    carabinieri zombies come out of the dark;
/// 4. past them, a backpack holds the pistol (the shoot button appears).
final class TutorialDirector {
  TutorialDirector({required this.world, required this.host});

  static const String zombieLesson =
      'I normali zombi vaganti faranno un passo verso di te ogni due passi '
      'tuoi';
  static const String backpackLesson =
      'Raccogli gli zaini in giro per trovare nuovo equipaggiamento';
  static const String interactLesson =
      'Usa il nuovo bottone a sinistra per interagire con gli oggetti';
  static const String noGun = 'Non hai una pistola';
  static const String gunFound = 'Hai trovato una pistola';
  static const String shootLesson =
      'Usa il bottone per mirare, scegli una direzione e poi premi '
      'nuovamente il bottone per sparare';
  static const String barracksReached =
      "Ecco, ce l'ho fatta! La caserma dei carabinieri";
  static const String barracksSafe = 'Questo sarà un posto sicuro?';
  static const String carabiniereLesson =
      'Gli zombi carabinieri possono raggiungerti a due celle di distanza '
      'grazie al loro manganello';

  static const String wandererPortrait = 'assets/story/portrait_wanderer.png';
  static const String carabinierePortrait =
      'assets/story/portrait_carabiniere.png';

  /// Leaves time for the camera to pan to the zombie and for its balloon.
  static const double focusDelay = 0.7;

  /// Leaves time for a new sight to register before the text covers it.
  static const double reactionDelay = 0.45;

  /// Lets Mario's pickup animation play before the text box covers it.
  static const double pickupDelay = 0.65;

  /// Steps inside the barracks before the carabinieri come out.
  static const int stepsBeforeCarabinieri = 4;

  final WorldState world;
  final TutorialHost host;
  final List<_QueuedPrompt> _queue = <_QueuedPrompt>[];

  bool _zombieLessonQueued = false;
  bool _backpackLessonQueued = false;
  bool _barracksLinesQueued = false;
  bool _carabinieriOut = false;
  bool _carabiniereLessonQueued = false;
  int _stepsInside = 0;

  /// "Non hai una pistola" only while the player really has none.
  static String ammoFound(int rounds, {required bool hasGun}) => hasGun
      ? 'Hai trovato $rounds proiettili'
      : 'Hai trovato $rounds proiettili. $noGun';

  bool _isIndoor(GridPoint tile) => levelRegions.any(
    (region) => region.indoor && region.bounds.contains(tile),
  );

  /// Feeds the events of a resolved turn.
  void onEvents(Iterable<WorldEvent> events) {
    for (final event in events) {
      switch (event) {
        case AlertedEvent(entityId: tutorialZombieId) when !_zombieLessonQueued:
          _zombieLessonQueued = true;
          // Pan so the alert balloon and the zombie's step are on screen.
          host.focusOn(tutorialZombieId);
          _queue.add(
            _QueuedPrompt(
              const <TutorialLine>[
                TutorialLine(zombieLesson, portrait: wandererPortrait),
              ],
              delay: focusDelay,
              onDismissed: () => host.focusOn(null),
            ),
          );
        case AlertedEvent(entityId: final id)
            when !_carabiniereLessonQueued &&
                world.entities[id]?.kind == EntityKind.carabiniere:
          _carabiniereLessonQueued = true;
          host.focusOn(id);
          _queue.add(
            _QueuedPrompt(
              const <TutorialLine>[
                TutorialLine(carabiniereLesson, portrait: carabinierePortrait),
              ],
              delay: focusDelay,
              onDismissed: () => host.focusOn(null),
            ),
          );
        case PickedUpEvent(:final ammo, :final gun):
          host.playPickupAnimation();
          _queue.add(_pickupPrompt(ammo: ammo, gun: gun));
        case MovedEvent(entityId: final id, :final to)
            when id == world.playerId && _isIndoor(to):
          _stepsInside++;
          if (_stepsInside >= stepsBeforeCarabinieri) {
            _releaseCarabinieri();
          }
        case _:
          break;
      }
    }
  }

  _QueuedPrompt _pickupPrompt({required int ammo, required bool gun}) {
    if (gun) {
      return _QueuedPrompt(
        const <TutorialLine>[TutorialLine(gunFound), TutorialLine(shootLesson)],
        delay: pickupDelay,
        onDismissed: () => host.unlock(HudElement.shoot),
      );
    }
    final hasGun = world.player.component<AmmoComponent>().hasGun;
    return _QueuedPrompt(
      <TutorialLine>[TutorialLine(ammoFound(ammo, hasGun: hasGun))],
      delay: pickupDelay,
      onShown: () => host.unlock(HudElement.ammo),
    );
  }

  void _releaseCarabinieri() {
    if (_carabinieriOut) {
      return;
    }
    _carabinieriOut = true;
    final occupied = world.occupiedPoints();
    var index = 0;
    for (final spawn in carabiniereSpawns()) {
      if (!occupied.contains(spawn)) {
        host.spawnZombie(createCarabiniere('carabiniere-${index++}', spawn));
      }
    }
  }

  /// Checks what the camera sees and shows queued prompts once the current
  /// turn has finished animating.
  void update(double dt, {required bool turnAnimating}) {
    _checkBackpackSeen();
    _checkBarracksReached();
    if (_queue.isEmpty || host.isPromptVisible || turnAnimating) {
      return;
    }
    final next = _queue.first;
    if (next.delay > 0) {
      next.delay -= dt;
      return;
    }
    _queue.removeAt(0);
    next.onShown?.call();
    host.showPrompt(next.lines, onDismissed: next.onDismissed);
  }

  void _checkBackpackSeen() {
    if (_backpackLessonQueued) {
      return;
    }
    final backpack = world.pickups[ammoBackpackId];
    if (backpack == null ||
        !backpack.active ||
        !host.isTileVisible(backpack.position)) {
      return;
    }
    _backpackLessonQueued = true;
    _queue.add(
      _QueuedPrompt(
        const <TutorialLine>[
          TutorialLine(backpackLesson),
          TutorialLine(interactLesson),
        ],
        delay: reactionDelay,
        onDismissed: () => host.unlock(HudElement.interact),
      ),
    );
  }

  void _checkBarracksReached() {
    if (_barracksLinesQueued) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (!barracksForecourt.contains(position)) {
      return;
    }
    _barracksLinesQueued = true;
    _queue.add(
      _QueuedPrompt(const <TutorialLine>[
        TutorialLine.mario(barracksReached),
        TutorialLine.mario(barracksSafe),
      ]),
    );
  }
}
