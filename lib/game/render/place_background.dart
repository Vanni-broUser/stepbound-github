import 'package:flame/components.dart';

/// What a place's backdrop owes the game, whichever way it is drawn: a
/// baked picture (LevelBackgroundComponent) or the tile atlas
/// (TilePlaceComponent).
abstract class PlaceBackground extends Component {
  PlaceBackground({super.priority});

  /// Cleared by the game while the place is out of the camera's view, so
  /// the far places' big images are not drawn every frame.
  bool onScreen = true;

  /// What is on screen for this place, for tests and diagnostics.
  String get activeAssetPath;
}
