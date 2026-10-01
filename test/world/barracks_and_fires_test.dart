import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('a carabiniere zombie patrols the park behind the mall', () {
    final world = createGameWorld();
    final park = place(PlaceId.mallNorthStreet);
    final carabinieri = world.entities.values.where(
      (entity) =>
          entity.kind == EntityKind.carabiniere &&
          park.bounds.contains(entity.component<PositionComponent>().position),
    );
    expect(carabinieri, hasLength(1));
  });

  test('the barracks has lamps and two carabinieri waiting in the dark', () {
    expect(place(PlaceId.barracks).lights, isNotEmpty);
    expect(
      place(PlaceId.barracks).lights.where((light) => light.flickers),
      isNotEmpty,
    );
    expect(carabiniereSpawns, hasLength(2));
    final world = createGameWorld();
    for (final spawn in carabiniereSpawns) {
      expect(world.map.tileAt(spawn).isWalkable, isTrue);
    }
  });

  test('the carabiniere in the middle steps south into the lamp light', () {
    final world = createGameWorld();
    // Mario a few steps past the front door, where the carabinieri come out.
    world.player.component<PositionComponent>().position = GridPoint(
      place(PlaceId.barracks).origin.x + 12,
      place(PlaceId.barracks).origin.y + 11,
    );
    final spawn = carabiniereSpawns.firstWhere(
      (tile) => tile.x == place(PlaceId.barracks).origin.x + 12,
    );
    final carabiniere = createCarabiniere('carabiniere-0', spawn);
    world.addEntity(carabiniere);
    final position = carabiniere.component<PositionComponent>();
    var before = position.position;
    while (true) {
      const TurnScheduler().advance(world, const WaitAction());
      if (position.position.y > before.y) {
        break;
      }
      before = position.position;
    }
    bool lit(GridPoint tile) => place(PlaceId.barracks).lights.any(
      (light) =>
          (light.tile.x - tile.x).abs() + (light.tile.y - tile.y).abs() <= 1,
    );
    expect(lit(before), isFalse, reason: 'still in the dark at $before');
    expect(
      lit(position.position),
      isTrue,
      reason: 'lit at ${position.position}',
    );
  });

  test('fires burn on the street, in the north district, at the harbour and '
      'in the pile-up behind the hypermarket', () {
    int count(List<FireSpot> spots, FireKind kind) =>
        spots.where((s) => s.kind == kind).length;
    final street = streetFireSpots;
    // The dead-end street off the road north has two burning cars and a
    // window on fire of its own.
    expect(count(street, FireKind.car), 4);
    expect(count(street, FireKind.bin), 2);
    expect(count(street, FireKind.window), 4);
    final all = hometownFireSpots;
    final behindMall = place(PlaceId.mallNorthStreet).bounds;
    expect(
      all.where(
        (spot) => spot.kind == FireKind.car && behindMall.contains(spot.tile),
      ),
      hasLength(7),
      reason:
          'the burning wrecks blocking both streets west, and one in the '
          'pile-up under the park',
    );
    // And two on the overturned car burning at the station, and one on
    // the street out of the palazzo past the airliner, with a bin and
    // two windows on fire, and three more in the pile-up at its east end;
    // and on the monument's square past it, a car, two bins and three
    // windows, and one more in the pile-up at the end of its east road;
    // and four in the north district round the crossroads west of the
    // hypermarket's road, three of them in the pile-up closing its road
    // north, either side of the burning lane and on the pavement,
    // with three more windows on fire along the new streets.
    expect(count(all, FireKind.car), 25 + stationWreckFireSpots.length);
    expect(stationWreckFireSpots, hasLength(2));
    expect(count(all, FireKind.bin), 12);
    expect(count(all, FireKind.window), 23);
    expect(count(all, FireKind.campfire), 7);
    // Two camps in the north district, behind the barracks and by the
    // burning pile-up north of the crossroads, one in the dead end the wrecks
    // leave at the west end of the shopping street behind the mall, two
    // at the harbour: the Duomo sagrato and the south-east road end, one
    // on the hospital's roof, and one on the street out of the palazzo
    // past the airliner.
    expect(
      all
          .where((spot) => spot.kind == FireKind.campfire)
          .map((spot) => placeAt(spot.tile)?.id)
          .toSet(),
      <PlaceId>{
        PlaceId.northDistrict,
        PlaceId.mallNorthStreet,
        PlaceId.harbour,
        PlaceId.hospitalRoof,
        PlaceId.industryStreet,
      },
    );
  });

  test('the camp burns at the closed east end of the north street', () {
    final world = createGameWorld();
    final camp = world.campfires.firstWhere(
      place(PlaceId.northDistrict).bounds.contains,
    );
    final (x, y) = (
      camp.x - place(PlaceId.northDistrict).origin.x,
      camp.y - place(PlaceId.northDistrict).origin.y,
    );
    final row = northDistrictRows[y];
    expect(row.indexOf('B', x), lessThan(x + 4), reason: 'a dead end');
    expect(x, greaterThan(_outdoorColumn('e')), reason: 'past the barracks');
  });

  test('the flagpole stands on the barracks forecourt', () {
    final pole = flagpoleTile;
    expect(barracksForecourt.contains(pole), isTrue);
    expect(createGameWorld().map.tileAt(pole).isWalkable, isFalse);
  });

  test('resting at the camp beyond the barracks asks the game to save', () {
    final world = createGameWorld();
    final camp = world.campfires.firstWhere(
      place(PlaceId.northDistrict).bounds.contains,
    );
    expect(campfireNames[camp], 'Dietro la caserma');
    expect(world.map.tileAt(camp).isWalkable, isFalse);
    world.player.component<PositionComponent>()
      ..position = camp.step(Direction.west)
      ..facing = Direction.east;
    final events = const TurnScheduler().advance(world, const InteractAction());
    expect(events.whereType<CampfireUsedEvent>().single.at, camp);
  });
}

int _outdoorColumn(String glyph) =>
    northDistrictRows.firstWhere((row) => row.contains(glyph)).indexOf(glyph);
