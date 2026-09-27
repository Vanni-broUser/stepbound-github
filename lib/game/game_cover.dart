import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/story/story_director.dart';

/// What covers the game, one thing at a time: while anything does, Mario
/// waits, the touch controls step aside and the story holds its next
/// prompt. The app draws each kind over the game.
sealed class GameCover {
  const GameCover();
}

/// Lines in the dialogue box, one per tap.
final class PromptCover extends GameCover {
  PromptCover(this.lines, {this.onDismissed});

  final List<StoryLine> lines;
  final void Function()? onDismissed;
}

/// A story scene: pictures and lines between two fades to black.
final class CutsceneCover extends GameCover {
  CutsceneCover(
    this.frames, {
    this.onFinished,
    this.onBlack,
    this.stayBlack = false,
    this.music,
  });

  final List<CutsceneFrame> frames;
  final void Function()? onFinished;

  /// Called once the last frame has faded to black, before the game fades
  /// back in: what the scene changed in the world is already there when it
  /// shows again.
  final void Function()? onBlack;
  final bool stayBlack;

  /// The scene's own music, played over the game's while it lasts.
  final Music? music;
}

/// A place announced on the way in: its picture and its name between two
/// fades to black.
final class PlaceCardCover extends GameCover {
  const PlaceCardCover({required this.name, required this.image});

  final String name;
  final String image;
}

/// The books by Mario's cot on the train: the zombie types met so far.
final class ZombieBookCover extends GameCover {
  const ZombieBookCover();
}

/// The abacus and the calculator on Mario's desk aboard: the figures of
/// the adventure, the same as at the end of a level, city by city.
final class AdventureStatsCover extends GameCover {
  const AdventureStatsCover();
}

/// Mario's cot on the train: the story scenes seen so far, played again.
final class MemoriesCover extends GameCover {
  const MemoriesCover();
}

/// The menu the corner button opens, mid-game: back to the last save,
/// the level from the start, or out to the main menu. With [wardrobe] it
/// is only its page of outfits, opened from the wardrobe aboard.
final class PauseCover extends GameCover {
  const PauseCover({this.wardrobe = false});

  final bool wardrobe;
}

/// The end of what is playable so far, reached at the way out of Termini.
/// [onClosed] runs once it is tapped away.
final class EndOfDemoCover extends GameCover {
  const EndOfDemoCover({this.onClosed});

  final void Function()? onClosed;
}

/// Mario is dead.
final class GameOverCover extends GameCover {
  const GameOverCover();
}
