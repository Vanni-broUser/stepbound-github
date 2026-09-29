import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/levels/hometown_stage.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// A host that does nothing: for a [StoryDirector] built only to read a
/// save's story back, as `checkRestorable` does before a slot is offered,
/// where there is no game to show anything on.
final class SilentStoryHost implements StoryHost, HometownActions {
  const SilentStoryHost();

  @override
  bool isTileVisible(GridPoint tile) => false;

  @override
  void showPrompt(List<StoryLine> lines, {void Function()? onDismissed}) {}

  @override
  bool get inPlay => false;

  @override
  bool get isPromptVisible => false;

  @override
  bool get missionsSettling => false;

  @override
  void stopWalking() {}

  @override
  void playPickupAnimation() {}

  @override
  void walkPlayer(Direction direction) {}

  @override
  void showWholeView() {}

  @override
  void spawnZombie(Entity zombie) {}

  @override
  void killZombies(Iterable<String> zombieIds) {}

  @override
  bool isUnlocked(HudElement element) => false;

  @override
  void unlock(HudElement element) {}

  @override
  void removeHud(HudElement element) {}

  @override
  void wearOutfit(PlayerOutfit outfit) {}

  @override
  void playCutscene(
    List<CutsceneFrame> frames, {
    Set<StoryMemory> memories = const <StoryMemory>{},
    void Function()? onFinished,
    void Function()? onBlack,
    bool stayBlack = false,
    Music? music,
  }) {}

  @override
  void completeLevel() {}

  @override
  void openTravelMap() {}

  @override
  void showWorkInProgress({void Function()? onClosed}) {}

  @override
  void openZombieBook() {}

  @override
  void openAdventureStats() {}

  @override
  void openWardrobe() {}

  @override
  HometownActions get hometown => this;

  @override
  void openDuomo() {}

  @override
  void openDuomoUpper() {}

  @override
  void collectCultistRobe() {}

  @override
  void startDuomoMassacre() {}

  @override
  void sendLuigiAway({void Function()? onFinished}) {}
}
