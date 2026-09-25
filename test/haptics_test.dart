import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/haptics/game_haptics.dart';

void main() {
  test('combat events use distinct haptic cues', () {
    final played = <HapticCue>[];

    GameplayHaptics(sink: played.add).onEvents(<WorldEvent>[
      const DamagedEvent(
        entityId: 'player',
        amount: 1,
        sourceEntityId: 'zombie',
      ),
      const ShotEvent(
        entityId: 'player',
        origin: GridPoint(1, 1),
        impact: GridPoint(2, 1),
        direction: Direction.east,
        hitEntityId: 'zombie',
      ),
      const DryFiredEvent(entityId: 'player'),
    ], playerId: 'player');

    expect(played, <HapticCue>[
      HapticCue.playerHurt,
      HapticCue.hitLanded,
      HapticCue.emptyMagazine,
    ]);
  });

  test('misses and damage to other entities do not vibrate', () {
    final played = <HapticCue>[];

    GameplayHaptics(sink: played.add).onEvents(<WorldEvent>[
      const ShotEvent(
        entityId: 'player',
        origin: GridPoint(1, 1),
        impact: GridPoint(3, 1),
        direction: Direction.east,
      ),
      const DamagedEvent(
        entityId: 'zombie',
        amount: 1,
        sourceEntityId: 'player',
      ),
      const DryFiredEvent(entityId: 'zombie'),
    ], playerId: 'player');

    expect(played, isEmpty);
  });
}
