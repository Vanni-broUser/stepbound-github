import 'package:flutter/foundation.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/game_cover.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/report/breadcrumbs.dart';

/// What covers the game, one thing at a time, and how each kind goes up
/// and comes down: the text box, a story scene, the work-in-progress
/// screen, the books and figures aboard, the memories, a failed save's
/// notice, the pause menu, game over. The overlays the app draws call the
/// `close`/`dismiss` side; the story and the game call the `show`/`open`
/// side. Whoever comes down is checked to be the one on top: a stale
/// overlay cannot take down what replaced it.
final class CoverController {
  CoverController({
    required this.onShow,
    required this.progress,
    this.onStoryViewed,
    Breadcrumbs? trail,
  }) : trail = trail ?? Breadcrumbs.shared;

  /// What covers the game, if anything.
  final ValueNotifier<GameCover?> cover = ValueNotifier<GameCover?>(null);

  /// Called whenever something goes up: Mario stops where he is.
  final void Function() onShow;

  /// The scenes seen, for whether a cutscene can be skipped, and to mark
  /// the ones just watched.
  final Progress progress;
  final ValueChanged<StoryMemory>? onStoryViewed;
  final Breadcrumbs trail;

  bool get isCovered => cover.value != null;

  /// Puts [what] over the game; Mario stops.
  void show(GameCover what) {
    onShow();
    cover.value = what;
  }

  void dispose() => cover.dispose();

  // ------------------------------------------------------------ prompts

  /// Lines in the dialogue box, one per tap.
  void showPrompt(List<StoryLine> lines, {void Function()? onDismissed}) {
    if (lines.isNotEmpty) {
      final first = lines.first;
      final more = lines.length > 1 ? ' (+${lines.length - 1})' : '';
      trail.add('battuta: ${first.speaker ?? '—'}: ${_clip(first.text)}$more');
    }
    show(
      PromptCover(
        List<StoryLine>.unmodifiable(lines),
        onDismissed: onDismissed,
      ),
    );
  }

  /// Enough of a line to know which one it is.
  static String _clip(String text) =>
      text.length <= 60 ? text : '${text.substring(0, 57)}...';

  /// Called by the dialogue overlay after the last line.
  void dismissPrompt() {
    final prompt = cover.value;
    if (prompt is PromptCover) {
      cover.value = null;
      prompt.onDismissed?.call();
    }
  }

  // ---------------------------------------------------------- cutscenes

  /// A story scene: skippable once every one of its [memories] has been
  /// seen; watching it marks them.
  void playCutscene(
    List<CutsceneFrame> frames, {
    Set<StoryMemory> memories = const <StoryMemory>{},
    void Function()? onFinished,
    void Function()? onBlack,
    bool stayBlack = false,
    Music? music,
  }) {
    final canSkip = memories.isNotEmpty && memories.every(progress.hasViewed);
    show(
      CutsceneCover(
        List<CutsceneFrame>.unmodifiable(frames),
        onFinished: () {
          for (final memory in memories) {
            progress.view(memory);
            onStoryViewed?.call(memory);
          }
          onFinished?.call();
        },
        onBlack: onBlack,
        stayBlack: stayBlack,
        canSkip: canSkip,
        music: music,
      ),
    );
  }

  /// Called by the cutscene overlay once its last frame has faded to black.
  void cutsceneBlack() {
    final cutscene = cover.value;
    if (cutscene is CutsceneCover) {
      cutscene.onBlack?.call();
    }
  }

  /// Called by the cutscene overlay once the game has faded back in.
  void finishCutscene() {
    final cutscene = cover.value;
    if (cutscene is CutsceneCover) {
      cover.value = null;
      cutscene.onFinished?.call();
    }
  }

  // -------------------------------------------------- work in progress

  void showWorkInProgress({void Function()? onClosed}) =>
      show(WorkInProgressCover(onClosed: onClosed));

  /// Called by the work-in-progress screen once it is tapped away.
  void closeWorkInProgress() {
    final end = cover.value;
    if (end is WorkInProgressCover) {
      cover.value = null;
      end.onClosed?.call();
    }
  }

  // ---------------------------------------------------- books aboard

  void openZombieBook() => show(const ZombieBookCover());

  /// Called by the book once it is closed.
  void closeZombieBook() {
    if (cover.value is ZombieBookCover) {
      cover.value = null;
    }
  }

  void openAdventureStats() => show(const AdventureStatsCover());

  /// Called by the figures of the adventure once they are closed.
  void closeAdventureStats() {
    if (cover.value is AdventureStatsCover) {
      cover.value = null;
    }
  }

  /// The memories of [level], played from the figures of the adventure.
  void showMemories(LevelId level) => show(MemoriesCover(level));

  /// Called once the memories are over, or left: back to the figures of
  /// the city they were played from. False when no memories were on.
  bool closeMemories() {
    if (cover.value case MemoriesCover(:final level)) {
      cover.value = AdventureStatsCover(level: level);
      return true;
    }
    return false;
  }

  // ------------------------------------------------------ failed save

  /// The line saying a save could not be written, with the report to
  /// share.
  void showSaveFailed(String line, {void Function()? onDismissed}) =>
      show(SaveFailedCover(line, onDismissed: onDismissed));

  /// Called by the notice of a failed save once the player goes on.
  void dismissSaveFailed() {
    final notice = cover.value;
    if (notice is SaveFailedCover) {
      cover.value = null;
      notice.onDismissed?.call();
    }
  }

  // ------------------------------------------------------- pause menu

  /// The menu from the button in the corner: nothing doing while
  /// something else already covers the game. True when it opened.
  bool openMenu() {
    if (isCovered) {
      return false;
    }
    show(const PauseCover());
    return true;
  }

  /// Only the menu's page of outfits, from the wardrobe aboard.
  void openWardrobe() => show(const PauseCover(wardrobe: true));

  /// Closes it and gives Mario back to the player.
  void closeMenu() {
    if (cover.value is PauseCover) {
      cover.value = null;
    }
  }

  // ------------------------------------------------------ level's end

  /// Black over the game from the end of the level to its results.
  void endLevel() => show(const LevelEndCover());

  // -------------------------------------------------------- game over

  /// Mario is dead, or has no way out left ([reason]); whatever was up
  /// stays under it.
  void gameOver({String? reason}) =>
      cover.value = GameOverCover(reason: reason);
}
