import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/scripts/backpacks_script.dart';
import 'package:stepbound/game/tutorial/scripts/bar_script.dart';
import 'package:stepbound/game/tutorial/scripts/barracks_script.dart';
import 'package:stepbound/game/tutorial/scripts/duomo_script.dart';
import 'package:stepbound/game/tutorial/scripts/mall_script.dart';
import 'package:stepbound/game/tutorial/scripts/north_district_script.dart';
import 'package:stepbound/game/tutorial/scripts/priest_script.dart';
import 'package:stepbound/game/tutorial/scripts/rooftops_script.dart';
import 'package:stepbound/game/tutorial/scripts/station_script.dart';
import 'package:stepbound/game/tutorial/scripts/street_script.dart';
import 'package:stepbound/game/tutorial/scripts/train_script.dart';
import 'package:stepbound/game/tutorial/scripts/zombie_sightings_script.dart';
import 'package:stepbound/game/zombie_lore.dart';

export 'package:stepbound/game/tutorial/scripts/backpacks_script.dart';
export 'package:stepbound/game/tutorial/scripts/bar_script.dart';
export 'package:stepbound/game/tutorial/scripts/barracks_script.dart';
export 'package:stepbound/game/tutorial/scripts/duomo_script.dart';
export 'package:stepbound/game/tutorial/scripts/mall_script.dart';
export 'package:stepbound/game/tutorial/scripts/north_district_script.dart';
export 'package:stepbound/game/tutorial/scripts/priest_script.dart';
export 'package:stepbound/game/tutorial/scripts/rooftops_script.dart';
export 'package:stepbound/game/tutorial/scripts/station_script.dart';
export 'package:stepbound/game/tutorial/scripts/street_script.dart';
export 'package:stepbound/game/tutorial/scripts/train_script.dart';
export 'package:stepbound/game/tutorial/scripts/zombie_sightings_script.dart';

/// A line shown in the dialogue box over the gameplay.
final class TutorialLine {
  /// A hint or system message: no name over the box.
  const TutorialLine(this.text, {this.speaker, this.portrait});

  /// A line spoken by Mario, with his portrait over the box.
  const TutorialLine.mario(this.text)
    : speaker = 'Mario Rossi',
      portrait = 'assets/story/portrait_mario.png';

  /// A line spoken by Luigi, with his portrait over the box.
  const TutorialLine.luigi(this.text)
    : speaker = 'Luigi Rovaga',
      portrait = 'assets/story/portrait_luigi.png';

  /// A line spoken by the priest of the Duomo, with his portrait over the
  /// box.
  const TutorialLine.priest(this.text)
    : speaker = PriestScript.priest,
      portrait = 'assets/story/portrait_priest.png';

  /// A member of Don Angelo's community inside the Duomo.
  const TutorialLine.cultist(this.text)
    : speaker = DuomoScript.cultist,
      portrait = DuomoScript.cultistPortrait;

  /// Set only when a person is talking.
  final String? speaker;
  final String text;
  final String? portrait;
}

/// One full-screen picture of a story scene played during the game: the
/// picture first, then [text] on a tap, then the next picture.
final class CutsceneFrame {
  const CutsceneFrame({required this.image, required this.text, this.speaker});

  final String image;
  final String? speaker;
  final String text;
}

/// What the tutorial hands over: interacting and shooting (the right half
/// of the screen does nothing until they are unlocked), the ammo counter
/// and the temporary quest-item badges in the top-left corner. Walking is
/// always there.
enum HudElement {
  interact,
  ammo,
  shoot,
  incense,
  barKey,
  episcopalRing,
  duomoKey,
}

/// What the director needs from the game.
abstract interface class TutorialHost {
  /// True when the whole tile is inside the camera view.
  bool isTileVisible(GridPoint tile);

  /// Shows [lines] one per tap; the game pauses until [onDismissed].
  void showPrompt(List<TutorialLine> lines, {void Function()? onDismissed});

  /// True while anything covers the game (a text box, a story scene...):
  /// prompts wait for it to go.
  bool get isPromptVisible;

  /// Drops the steps queued and the arrow held, so that a prompt about to
  /// show finds Mario where it was triggered.
  void stopWalking();

  /// Mario's crouch-and-grab, played when a backpack is collected.
  void playPickupAnimation();

  /// Frames the player together with [entityId]; null follows the player
  /// alone again.
  void focusOn(String? entityId);

  /// Adds a zombie that comes out of the dark.
  void spawnZombie(Entity zombie);

  /// Cuts down the zombies with those ids where they stand, someone else's
  /// doing: Luigi with his axe once the shutter is up.
  void killZombies(Iterable<String> zombieIds);

  /// Whether the player can already use the interact button.
  bool isUnlocked(HudElement element);

  void unlock(HudElement element);

  /// Removes a quest object from the inventory HUD when it is handed over
  /// or consumed.
  void removeHud(HudElement element);

  /// Opens the churchyard and moves Don Angelo from the gate to the altar.
  void openDuomo();

  /// Clears the Duomo stair, moves its guard aside and consumes the ring.
  void openDuomoUpper();

  /// Collects the robe upstairs, fades to black and dresses Mario in it.
  void collectCultistRobe();

  /// What the mass leaves behind, once its scene is over: Don Angelo's
  /// community are four mutated cultists standing across the nave, his body
  /// lies behind them and the backpack beside it, with the key of the upper
  /// floor, can be picked up.
  void startDuomoMassacre();

  /// Fades to black and plays [frames] like the intro story, then calls
  /// [onFinished]. Unless [stayBlack] is true, it fades back to the game
  /// first.
  void playCutscene(
    List<CutsceneFrame> frames, {
    void Function()? onFinished,
    bool stayBlack = false,
  });

  /// Saves the game as it is, Mario aboard the train, and leaves gameplay
  /// for the results screen after the last story frame.
  void completeLevel();

  /// Leaves the train and opens the destination map immediately.
  void openTravelMap();

  /// Opens the book of the zombie types met so far.
  void openZombieBook();

  /// Plays again every story scene seen so far.
  void replayMemories();

  /// Luigi walks off through the shop's open shutter and vanishes, once he
  /// has agreed to meet Mario again; calls [onFinished] once he is gone.
  void sendLuigiAway({void Function()? onFinished});
}

/// Lines waiting their turn: they show [delay] seconds after the previous
/// ones are gone and the turn has finished animating.
final class TutorialPrompt {
  TutorialPrompt(this.lines, {this.delay = 0, this.onShown, this.onDismissed});

  final List<TutorialLine> lines;
  double delay;
  final void Function()? onShown;
  final void Function()? onDismissed;
}

/// One part of the tutorial, for a place or a theme: it watches what
/// happens and queues its prompts through the [director]. What it has done
/// is saved under its [key].
abstract class TutorialScript {
  TutorialScript(this.director);

  final TutorialDirector director;

  String get key;

  WorldState get world => director.world;
  TutorialHost get host => director.host;
  Progress get progress => director.progress;

  void say(TutorialPrompt prompt) => director.queue(prompt);

  /// Each event of a resolved turn.
  void onEvent(WorldEvent event) {}

  /// Every frame, to check what the camera shows or where Mario stands.
  void update({required bool turnAnimating}) {}

  Map<String, Object?> toJson();

  /// Restores [toJson]; anything missing counts as not happened yet.
  void restore(Map<String, Object?> json);
}

/// Runs the tutorial's scripts and shows their prompts one after the
/// other: the backpacks, the first street, the barracks, the north
/// district, the hypermarket, the Duomo, the station, the train Mario and
/// Luigi live in, the roofs the crashed airliner came down in and the zombie
/// types met on sight. It records what the player comes to know in
/// [progress].
final class TutorialDirector {
  TutorialDirector({
    required this.world,
    required this.host,
    required this.progress,
  }) {
    scripts = <TutorialScript>[
      BackpacksScript(this),
      BarScript(this),
      StreetScript(this),
      BarracksScript(this),
      DuomoScript(this),
      NorthDistrictScript(this),
      MallScript(this),
      PriestScript(this),
      StationScript(this),
      TrainScript(this),
      RooftopsScript(this),
      ZombieSightingsScript(this),
    ];
  }

  /// Leaves time for the camera to pan to a zombie and for its balloon.
  static const double focusDelay = 0.7;

  /// Leaves time for a new sight to register before the text covers it.
  static const double reactionDelay = 0.45;

  /// Lets Mario's pickup animation play before the text box covers it.
  static const double pickupDelay = 0.65;

  final WorldState world;
  final TutorialHost host;
  final Progress progress;
  late final List<TutorialScript> scripts;
  final List<TutorialPrompt> _queue = <TutorialPrompt>[];

  void queue(TutorialPrompt prompt) => _queue.add(prompt);

  /// Nothing waiting to be said and nothing covering the game.
  bool get isIdle => _queue.isEmpty && !host.isPromptVisible;

  /// The first meeting with [zombie]'s type, the same for every type (see
  /// [ZombieLore]): the type is known from now on, and the book lists it;
  /// the camera frames the zombie with Mario while its lesson is shown with
  /// its portrait, and goes back to Mario alone once it is dismissed.
  void introduceZombie(Entity zombie) {
    final lore = zombieLore[zombie.kind]!;
    progress.meet(zombie.kind);
    host.focusOn(zombie.id);
    queue(
      TutorialPrompt(
        <TutorialLine>[TutorialLine(lore.lesson, portrait: lore.portrait)],
        delay: focusDelay,
        onDismissed: () => host.focusOn(null),
      ),
    );
  }

  /// What has already happened, script by script, to be saved.
  Map<String, Object?> toJson() => <String, Object?>{
    for (final script in scripts) script.key: script.toJson(),
  };

  void restore(Map<String, Object?> json) {
    for (final script in scripts) {
      script.restore(
        json[script.key] as Map<String, Object?>? ?? const <String, Object?>{},
      );
    }
  }

  /// Feeds the events of a resolved turn.
  void onEvents(Iterable<WorldEvent> events) {
    for (final event in events) {
      for (final script in scripts) {
        script.onEvent(event);
      }
    }
  }

  /// Lets the scripts look at the world, then shows the next prompt once
  /// nothing covers the game and the turn has finished animating.
  void update(double dt, {required bool turnAnimating}) {
    for (final script in scripts) {
      script.update(turnAnimating: turnAnimating);
    }
    if (_queue.isEmpty || host.isPromptVisible) {
      return;
    }
    // A prompt belongs where it was triggered: Mario stops instead of
    // walking on for as long as the arrow stays down, and its delay runs
    // on the clock rather than on the few frames between one step and the
    // next — held down, those would stretch it over half the street.
    host.stopWalking();
    final next = _queue.first;
    if (next.delay > 0) {
      next.delay -= dt;
      return;
    }
    if (turnAnimating) {
      return;
    }
    _queue.removeAt(0);
    next.onShown?.call();
    host.showPrompt(next.lines, onDismissed: next.onDismissed);
  }
}
