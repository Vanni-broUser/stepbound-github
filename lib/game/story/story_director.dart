import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/levels/hometown_stage.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/scripts/backpacks_script.dart';
import 'package:stepbound/game/story/scripts/bar_script.dart';
import 'package:stepbound/game/story/scripts/barracks_script.dart';
import 'package:stepbound/game/story/scripts/duomo_script.dart';
import 'package:stepbound/game/story/scripts/journey_script.dart';
import 'package:stepbound/game/story/scripts/mall_script.dart';
import 'package:stepbound/game/story/scripts/maranza_script.dart';
import 'package:stepbound/game/story/scripts/north_district_script.dart';
import 'package:stepbound/game/story/scripts/priest_script.dart';
import 'package:stepbound/game/story/scripts/roadblock_fire_script.dart';
import 'package:stepbound/game/story/scripts/rome_script.dart';
import 'package:stepbound/game/story/scripts/rooftops_script.dart';
import 'package:stepbound/game/story/scripts/station_script.dart';
import 'package:stepbound/game/story/scripts/street_script.dart';
import 'package:stepbound/game/story/scripts/train_script.dart';
import 'package:stepbound/game/story/scripts/work_in_progress_script.dart';
import 'package:stepbound/game/story/scripts/zombie_sightings_script.dart';
import 'package:stepbound/game/zombie_lore.dart';

export 'package:stepbound/game/story/scripts/backpacks_script.dart';
export 'package:stepbound/game/story/scripts/bar_script.dart';
export 'package:stepbound/game/story/scripts/barracks_script.dart';
export 'package:stepbound/game/story/scripts/duomo_script.dart';
export 'package:stepbound/game/story/scripts/journey_script.dart';
export 'package:stepbound/game/story/scripts/mall_script.dart';
export 'package:stepbound/game/story/scripts/maranza_script.dart';
export 'package:stepbound/game/story/scripts/north_district_script.dart';
export 'package:stepbound/game/story/scripts/priest_script.dart';
export 'package:stepbound/game/story/scripts/roadblock_fire_script.dart';
export 'package:stepbound/game/story/scripts/rome_script.dart';
export 'package:stepbound/game/story/scripts/rooftops_script.dart';
export 'package:stepbound/game/story/scripts/station_script.dart';
export 'package:stepbound/game/story/scripts/street_script.dart';
export 'package:stepbound/game/story/scripts/train_script.dart';
export 'package:stepbound/game/story/scripts/work_in_progress_script.dart';
export 'package:stepbound/game/story/scripts/zombie_sightings_script.dart';

/// A line shown in the dialogue box over the gameplay.
final class StoryLine {
  /// A hint or system message: no name over the box.
  const StoryLine(this.text, {this.speaker, this.portrait, this.demo});

  /// A line spoken by Mario, with his portrait over the box.
  const StoryLine.mario(this.text)
    : speaker = 'Mario Rossi',
      portrait = 'assets/characters/mario/portraits/base.png',
      demo = null;

  /// A line spoken by Luigi, with his portrait over the box.
  const StoryLine.luigi(this.text)
    : speaker = 'Luigi Rovaga',
      portrait = 'assets/characters/npcs/portraits/luigi.png',
      demo = null;

  /// A line spoken by the priest of the Duomo, with his portrait over the
  /// box.
  const StoryLine.priest(this.text)
    : speaker = PriestScript.priest,
      portrait = 'assets/characters/npcs/portraits/priest.png',
      demo = null;

  /// A member of Don Angelo's community inside the Duomo.
  const StoryLine.cultist(this.text)
    : speaker = DuomoScript.cultist,
      portrait = DuomoScript.cultistPortrait,
      demo = null;

  /// Set only when a person is talking.
  final String? speaker;
  final String text;
  final String? portrait;

  /// The gesture played beside the box while the line explains it.
  final ControlDemo? demo;
}

/// A gesture the tutorial plays over and over on a small screen beside the
/// text box, while a line explains it.
enum ControlDemo {
  /// Holding on the right half raises whatever Mario has in hand, dragging
  /// aims and lifting lets it go: once each way, up, right, down and left.
  /// Only the finger is shown, so the same round teaches the pistol and the
  /// molotov alike.
  aim,

  /// The pistol comes up with its splash, the finger stays in the ring in
  /// the middle a moment and lifts there: nothing is fired.
  cancelShot,

  /// A thumb on the left half drags the stick one way and holds it there
  /// to walk: up, right, down and left in turn.
  move,

  /// Quick taps here and there on the right half, each leaving its splat.
  interact,
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
/// of the screen does nothing until they are unlocked), the ammo badge and
/// the temporary quest-item badges, carried together in the top-left row
/// in the order they were picked up. Walking is always there.
enum HudElement {
  interact,
  ammo,
  shoot,
  incense,
  barKey,
  episcopalRing,
  duomoKey,
  molotov,
  grapplingHook,

  /// The rocket launcher's badge, with the rounds for it counted: dimmed
  /// until the launcher itself is found.
  rockets,
}

extension HudElementLevel on HudElement {
  /// The level whose errand the item is for, or null for what goes with
  /// Mario everywhere. The keys and the rest he carries for somebody in
  /// Molfetta are not taken on the train: they wait for him there, out of
  /// sight elsewhere.
  LevelId? get level => switch (this) {
    HudElement.incense ||
    HudElement.barKey ||
    HudElement.episcopalRing ||
    HudElement.duomoKey => LevelId.hometown,
    _ => null,
  };
}

/// What the director needs from the game.
abstract interface class StoryHost {
  /// True when the whole tile is inside the camera view.
  bool isTileVisible(GridPoint tile);

  /// Shows [lines] one per tap; the game pauses until [onDismissed].
  void showPrompt(List<StoryLine> lines, {void Function()? onDismissed});

  /// True once the player has the controls: not while the opening lines
  /// over the first street are still being read.
  bool get inPlay;

  /// True while anything covers the game (a text box, a story scene...):
  /// prompts wait for it to go.
  bool get isPromptVisible;

  /// True while the missions in the corner still have one to cross out: a
  /// scene that follows straight on from a mission done waits for it, so
  /// that the player sees it ticked off in between.
  bool get missionsSettling;

  /// Drops the steps queued and the arrow held, so that a prompt about to
  /// show finds Mario where it was triggered.
  void stopWalking();

  /// Mario's crouch-and-grab, played when a backpack is collected.
  void playPickupAnimation();

  /// Mario takes one step [direction], like any step of his, and the
  /// player has the controls back only once it is over.
  void walkPlayer(Direction direction);

  /// Brings a view zoomed in with two fingers back to the whole view,
  /// around the player as always.
  void showWholeView();

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

  /// Dresses Mario in [outfit], one he has already found, at once.
  void wearOutfit(PlayerOutfit outfit);

  /// Fades to black and plays [frames] like the intro story, then calls
  /// [onFinished]. Unless [stayBlack] is true, it fades back to the game
  /// first; [onBlack] is called before that, while the screen is still
  /// black, so whatever the scene changes in the world is never seen
  /// happening. With [music] the scene has its own, in place of the game's.
  void playCutscene(
    List<CutsceneFrame> frames, {
    Set<StoryMemory> memories = const <StoryMemory>{},
    void Function()? onFinished,
    void Function()? onBlack,
    bool stayBlack = false,
    Music? music,
  });

  /// Saves the game as it is, Mario aboard the train, and leaves gameplay
  /// for the results screen after the last story frame.
  void completeLevel();

  /// Leaves the train and opens the destination map immediately.
  void openTravelMap();

  /// Shows the work-in-progress screen: the game goes no further yet.
  /// [onClosed] once it is tapped away.
  void showWorkInProgress({void Function()? onClosed});

  /// Opens the book of the zombie types met so far.
  void openZombieBook();

  /// Opens the figures of the adventure, city by city.
  void openAdventureStats();

  /// Opens the outfits to choose from, as the menu's page of them does.
  void openWardrobe();

  /// Molfetta's stage, for what its story moves: Don Angelo, his
  /// community, Luigi.
  HometownActions get hometown;
}

/// Lines waiting their turn: they show [delay] seconds after the previous
/// ones are gone and the turn has finished animating. With [holdsInput]
/// Mario cannot act while they wait: they come before the player has the
/// game.
final class StoryPrompt {
  StoryPrompt(
    this.lines, {
    this.delay = 0,
    this.onShown,
    this.onDismissed,
    this.holdsInput = false,
  });

  final List<StoryLine> lines;
  double delay;
  final bool holdsInput;
  final void Function()? onShown;
  final void Function()? onDismissed;
}

/// One part of the story, for a place or a theme: it watches what
/// happens and queues its prompts through the [director]. What it has done
/// is saved under its [key].
abstract class StoryScript {
  StoryScript(this.director);

  final StoryDirector director;

  String get key;

  WorldState get world => director.world;
  StoryHost get host => director.host;
  Progress get progress => director.progress;

  void say(StoryPrompt prompt) => director.queue(prompt);

  /// Each event of a resolved turn.
  void onEvent(WorldEvent event) {}

  /// Every frame, to check what the camera shows or where Mario stands.
  void update({required bool turnAnimating}) {}

  Map<String, Object?> toJson();

  /// Restores [toJson]; anything missing counts as not happened yet.
  void restore(Map<String, Object?> json);
}

/// Runs the story's scripts and shows their prompts one after the
/// other: the backpacks, the first street, the barracks, the north
/// district, the hypermarket, the Duomo, the station, the train Mario and
/// Luigi live in, the roofs the crashed airliner came down in, the arrival
/// in Rome, the ways that go nowhere yet, what the train carries from one
/// level to the next and the zombie types met on sight. It records what
/// the player comes to know in [progress].
final class StoryDirector {
  StoryDirector({
    required this.world,
    required this.host,
    required this.progress,
  }) {
    scripts = <StoryScript>[
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
      RoadblockFireScript(this),
      RomeScript(this),
      WorkInProgressScript(this),
      MaranzaScript(this),
      JourneyScript(this),
      ZombieSightingsScript(this),
    ];
  }

  /// Leaves time for a new sight to register before the text covers it.
  static const double reactionDelay = 0.45;

  /// Lets Mario's pickup animation play before the text box covers it.
  static const double pickupDelay = 0.65;

  final WorldState world;
  final StoryHost host;
  final Progress progress;
  late final List<StoryScript> scripts;
  final List<StoryPrompt> _queue = <StoryPrompt>[];

  void queue(StoryPrompt prompt) => _queue.add(prompt);

  /// Nothing waiting to be said and nothing covering the game.
  bool get isIdle => _queue.isEmpty && !host.isPromptVisible;

  /// The first meeting with [zombie]'s type, the same for every type (see
  /// [ZombieLore]): the type is known from now on, and the book lists it,
  /// and its lesson is shown straight away with its portrait. The camera
  /// does not move: every zombie met is placed so that it is already in the
  /// whole view when it notices Mario (or he sees it), on any screen; a
  /// view zoomed in only goes back to the whole view. [then] is said after
  /// the lesson.
  void introduceZombie(
    Entity zombie, {
    List<StoryLine> then = const <StoryLine>[],
  }) {
    final lore = zombieLore[zombie.kind]!;
    progress.meet(zombie.kind);
    host.showWholeView();
    queue(
      StoryPrompt(<StoryLine>[
        StoryLine(lore.lesson, portrait: lore.portrait),
        ...then,
      ]),
    );
  }

  /// Luigi or Don Angelo has just been found: once both have, there are
  /// other survivors, and that mission is done.
  void foundSurvivor() {
    if (progress.hasExperienced(StoryMemory.luigiTrapped) &&
        progress.hasExperienced(StoryMemory.priestMet)) {
      progress.missions.complete(Mission.findSurvivors);
    }
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

  /// Whether a prompt waiting its turn keeps Mario from acting.
  bool get holdsInput => _queue.any((prompt) => prompt.holdsInput);

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
