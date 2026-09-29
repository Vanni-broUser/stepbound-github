import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/levels/hometown_stage.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The game, and Molfetta's stage with it.
final class FakeStoryHost implements StoryHost, HometownActions {
  FakeStoryHost([this.progress]);

  final Progress? progress;

  @override
  HometownActions get hometown => this;

  final Set<GridPoint> visible = <GridPoint>{};
  final Set<HudElement> unlocked = <HudElement>{};
  final List<List<StoryLine>> shown = <List<StoryLine>>[];
  final List<Entity> spawned = <Entity>[];
  void Function()? _onDismissed;
  int pickupAnimations = 0;
  int wholeViews = 0;

  @override
  bool isPromptVisible = false;

  @override
  bool missionsSettling = false;

  /// How many times a queued prompt has held Mario still.
  int stops = 0;

  @override
  void stopWalking() => stops++;

  @override
  bool isTileVisible(GridPoint tile) => visible.contains(tile);

  @override
  void showPrompt(List<StoryLine> lines, {void Function()? onDismissed}) {
    shown.add(lines);
    isPromptVisible = true;
    _onDismissed = onDismissed;
  }

  void dismiss() {
    isPromptVisible = false;
    _onDismissed?.call();
    _onDismissed = null;
  }

  @override
  void playPickupAnimation() => pickupAnimations++;

  final List<Direction> walked = <Direction>[];

  @override
  void walkPlayer(Direction direction) => walked.add(direction);

  @override
  void showWholeView() => wholeViews++;

  @override
  void spawnZombie(Entity zombie) => spawned.add(zombie);

  final List<String> killed = <String>[];

  @override
  void killZombies(Iterable<String> zombieIds) => killed.addAll(zombieIds);

  @override
  void unlock(HudElement element) => unlocked.add(element);

  @override
  void removeHud(HudElement element) => unlocked.remove(element);

  int duomoOpenings = 0;
  int duomoUpperOpenings = 0;
  int cultistRobesCollected = 0;

  @override
  void openDuomo() => duomoOpenings++;

  @override
  void openDuomoUpper() => duomoUpperOpenings++;

  @override
  void collectCultistRobe() => cultistRobesCollected++;

  int duomoMassacres = 0;
  final List<PlayerOutfit> outfitsWorn = <PlayerOutfit>[];

  @override
  void wearOutfit(PlayerOutfit outfit) => outfitsWorn.add(outfit);

  @override
  void startDuomoMassacre() => duomoMassacres++;

  @override
  bool isUnlocked(HudElement element) => unlocked.contains(element);

  final List<List<CutsceneFrame>> cutscenes = <List<CutsceneFrame>>[];
  final List<Music?> cutsceneMusic = <Music?>[];
  void Function()? onCutsceneFinished;
  bool cutsceneStaysBlack = false;
  int levelsCompleted = 0;
  int travelMapsOpened = 0;

  @override
  void playCutscene(
    List<CutsceneFrame> frames, {
    Set<StoryMemory> memories = const <StoryMemory>{},
    void Function()? onFinished,
    void Function()? onBlack,
    bool stayBlack = false,
    Music? music,
  }) {
    if (progress case final progress?) {
      memories.forEach(progress.remember);
    }
    cutscenes.add(frames);
    cutsceneMusic.add(music);
    onCutsceneFinished = () {
      onBlack?.call();
      onFinished?.call();
    };
    cutsceneStaysBlack = stayBlack;
  }

  @override
  void completeLevel() => levelsCompleted++;

  @override
  void openTravelMap() => travelMapsOpened++;

  int workInProgressShown = 0;

  @override
  void showWorkInProgress({void Function()? onClosed}) {
    workInProgressShown++;
    onClosed?.call();
  }

  int zombieBooksOpened = 0;

  @override
  void openZombieBook() => zombieBooksOpened++;

  int adventureStatsOpened = 0;

  int wardrobesOpened = 0;

  @override
  void openWardrobe() => wardrobesOpened++;

  @override
  void openAdventureStats() => adventureStatsOpened++;

  int luigiSent = 0;

  @override
  void sendLuigiAway({void Function()? onFinished}) {
    luigiSent++;
    onFinished?.call();
  }
}

/// The world, the game standing in for it, the director and the progress
/// of the test running: set up afresh by [startStory] before each one.
late WorldState world;
late FakeStoryHost host;
late StoryDirector director;
late Progress progress;

GridPoint zombiePosition() =>
    world.entities[tutorialZombieId]!.component<PositionComponent>().position;

/// Runs the director long enough for any queued delay to elapse.
void settle() {
  for (var i = 0; i < 20; i++) {
    director.update(0.1, turnAnimating: false);
  }
}

PickedUpEvent pickedUp(
  String id, {
  int ammo = 0,
  bool gun = false,
  bool incense = false,
  bool episcopalRing = false,
  bool cultistRobe = false,
  bool duomoKey = false,
  bool grapplingHook = false,
  int molotovs = 0,
}) => PickedUpEvent(
  pickupId: id,
  at: world.pickups[id]!.position,
  ammo: ammo,
  gun: gun,
  incense: incense,
  episcopalRing: episcopalRing,
  cultistRobe: cultistRobe,
  duomoKey: duomoKey,
  grapplingHook: grapplingHook,
  molotovs: molotovs,
);

/// Molfetta from the start, a fresh director over it.
void startStory() {
  world = createGameWorld();
  progress = Progress();
  host = FakeStoryHost(progress);
  director = StoryDirector(world: world, host: host, progress: progress);
}
