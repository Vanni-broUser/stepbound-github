import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/story/story_director.dart';

/// The Elettronica's back door, bolted on the inside. Used from inside the
/// shop it says so and opens, and with it the shutter over the door of the
/// same shop on the street behind the barracks, by the camp: from then on
/// the two are one way through. From the street, while it is shut, the
/// shutter only says it is down.
final class ElectronicsShopScript extends StoryScript {
  ElectronicsShopScript(super.director);

  static const String openFromInsideLine = 'Apri la porta dall’interno';
  static const String shutterDownLine =
      'La saracinesca è abbassata. Da fuori non si apre';

  bool _opening = false;

  @override
  String get key => 'electronicsShop';

  @override
  void onEvent(WorldEvent event) {
    if (event case NoInteractionEvent(:final at)) {
      if (at == electronicsShopBackDoor) {
        if (_opening || world.map.tileAt(at).isWalkable) {
          return;
        }
        // The line first, then the bolt drawn and the door open.
        _opening = true;
        say(
          StoryPrompt(
            const <StoryLine>[StoryLine(openFromInsideLine)],
            onDismissed: () {
              _opening = false;
              world.map
                ..setTile(electronicsShopBackDoor, const Tile(TileKind.floor))
                ..setTile(northDistrictShopDoor, const Tile(TileKind.floor));
            },
          ),
        );
      } else if (at == northDistrictShopDoor &&
          !world.map.tileAt(at).isWalkable) {
        say(StoryPrompt(const <StoryLine>[StoryLine(shutterDownLine)]));
      }
    }
  }

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void restore(Map<String, Object?> json) {}
}
