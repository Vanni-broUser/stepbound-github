import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

void main() {
  test('the Caparezza wanderer stands by the fountain, looking west', () {
    final contents = hometownContents(EntityFactory(BalanceConfig.standard()));
    final caparezza = contents.entities.singleWhere(
      (entity) => entity.id == caparezzaZombieId,
    );
    // Only his look is his own: in the game he is a plain wanderer.
    expect(caparezza.kind, EntityKind.wanderer);
    final position = caparezza.component<PositionComponent>();
    expect(position.facing, Direction.west);
    final fountain = place(PlaceId.northDistrict).tilesOf('O');
    expect(
      fountain.any((tile) => tile.manhattanDistanceTo(position.position) == 1),
      isTrue,
    );
  });
}
