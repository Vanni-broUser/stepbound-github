import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  group('San Nicola', () {
    final church = place(PlaceId.church);

    test('its portal stands open on the church square and goes both ways', () {
      final world = createGameWorld();
      // The portal is a hole in the bottom row of the church's own block,
      // with the paving of its little square under it.
      expect(
        harbourRows[churchPortalTile.y -
            place(PlaceId.harbour).origin.y][churchPortalTile.x -
            place(PlaceId.harbour).origin.x],
        '(',
      );
      expect(world.map.tileAt(churchPortalTile).isWalkable, isTrue);
      expect(
        world.map.tileAt(churchPortalTile.step(Direction.north)).isWalkable,
        isFalse,
        reason: 'the front of the church stands over its own door',
      );

      final square = churchPortalTile.step(Direction.south);
      world.player.component<PositionComponent>().position = square;
      var events = const TurnScheduler().advance(
        world,
        const MoveAction(Direction.north),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      final inside = world.player.component<PositionComponent>().position;
      expect(church.bounds.contains(inside), isTrue);

      events = const TurnScheduler().advance(
        world,
        const MoveAction(Direction.south),
      );
      expect(events.whereType<TeleportedEvent>(), hasLength(1));
      expect(world.player.component<PositionComponent>().position, square);
    });

    test('from inside the portal is two cells wide, and either takes Mario '
        'out onto the square', () {
      expect(churchPortalInside, hasLength(2));
      expect(
        churchPortalInside.last.x - churchPortalInside.first.x,
        1,
        reason: 'side by side',
      );
      final square = churchPortalTile.step(Direction.south);
      for (final door in churchPortalInside) {
        final world = createGameWorld();
        world.player.component<PositionComponent>().position = door.step(
          Direction.north,
        );
        final events = const TurnScheduler().advance(
          world,
          const MoveAction(Direction.south),
        );
        expect(events.whereType<TeleportedEvent>(), hasLength(1));
        expect(
          world.player.component<PositionComponent>().position,
          square,
          reason: 'out through $door',
        );
      }
    });

    test('the nave lights the portal, roof holes and incense backpack', () {
      expect(church.indoor, isTrue);
      expect(
        church.lights,
        hasLength(church.tilesOf('^').length + churchPortalInside.length + 1),
        reason:
            'each cell of the portal lets the daylight in, and the '
            'backpack has a dedicated pool of light',
      );
      expect(church.lights.every((light) => !light.flickers), isTrue);
      expect(
        church.lights.any(
          (light) =>
              light.tile ==
              createGameWorld().pickups[incenseBackpackId]!.position,
        ),
        isTrue,
      );
    });

    test('the backpack by the east wall holds the incense, and nothing '
        'else in the game does', () {
      final world = createGameWorld();
      final backpack = world.pickups[incenseBackpackId]!;
      expect(church.bounds.contains(backpack.position), isTrue);
      expect(backpack.ammo, 0);
      expect(backpack.gun, isFalse);
      expect(
        world.pickups.values.where((pickup) => pickup.incense),
        hasLength(1),
      );

      world.player.component<PositionComponent>()
        ..position = backpack.position.step(Direction.south)
        ..facing = Direction.north;
      final events = const TurnScheduler().advance(
        world,
        const InteractAction(),
      );
      final pickedUp = events.whereType<PickedUpEvent>().single;
      expect(pickedUp.incense, isTrue);
      expect(pickedUp.ammo, 0);
      expect(backpack.collected, isTrue);
    });
  });
}
