import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// What covers the game, one thing at a time: while anything does, Mario
/// waits, the touch controls step aside and the tutorial holds its next
/// prompt. The app draws each kind over the game.
sealed class GameCover {
  const GameCover();
}

/// Lines in the dialogue box, one per tap.
final class PromptCover extends GameCover {
  PromptCover(this.lines, {this.onDismissed});

  final List<TutorialLine> lines;
  final void Function()? onDismissed;
}

/// A story scene: pictures and lines between two fades to black.
final class CutsceneCover extends GameCover {
  CutsceneCover(this.frames, {this.onFinished, this.stayBlack = false});

  final List<CutsceneFrame> frames;
  final void Function()? onFinished;
  final bool stayBlack;
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

/// Mario's cot on the train: the story scenes seen so far, played again.
final class MemoriesCover extends GameCover {
  const MemoriesCover();
}

/// The menu the corner button opens, mid-game: back to the last save,
/// the level from the start, or out to the main menu.
final class PauseCover extends GameCover {
  const PauseCover();
}

/// Mario is dead.
final class GameOverCover extends GameCover {
  const GameOverCover();
}
