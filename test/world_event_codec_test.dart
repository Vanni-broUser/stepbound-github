import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';

/// One event of every kind, every field set to something other than its
/// default. The switch in [_kindOf] is exhaustive over the sealed
/// `WorldEvent`: a new kind of event does not compile until it is listed
/// here too, and so gets its codec tested.
const GridPoint _a = GridPoint(3, 4);
const GridPoint _b = GridPoint(5, 6);

final List<WorldEvent> _oneOfEach = <WorldEvent>[
  const MovedEvent(entityId: 'zombie-1', from: _a, to: _b),
  const BlockedEvent(entityId: 'player', at: _a, reason: 'terrain'),
  const WaitedEvent('zombie-2'),
  const DoorChangedEvent(at: _a, isOpen: true),
  const NoInteractionEvent(_b),
  const NoiseEvent(origin: _a, radius: 7, sourceEntityId: 'player'),
  const NoiseHeardEvent(entityId: 'zombie-3', origin: _b),
  const ShotEvent(
    entityId: 'player',
    origin: _a,
    impact: _b,
    direction: Direction.north,
    hitEntityId: 'zombie-4',
  ),
  const DryFiredEvent(entityId: 'player'),
  const AlertedEvent(entityId: 'zombie-5', at: _a),
  const CampfireUsedEvent(at: _b),
  const ControlUsedEvent(at: _a, opened: GridRect(1, 2, 3, 4)),
  const TravelMapUsedEvent(at: _b),
  const LookedOutEvent(at: _a),
  const FireStartedEvent(at: _b, entityId: 'zombie-burning'),
  const TeleportedEvent(entityId: 'player', from: _a, to: _b),
  const PickedUpEvent(
    pickupId: 'backpack-ammo',
    at: _a,
    ammo: 2,
    gun: true,
    incense: true,
  ),
  const DamagedEvent(entityId: 'player', amount: 1, sourceEntityId: 'z'),
  const DiedEvent('zombie-6'),
];

Type _kindOf(WorldEvent event) => switch (event) {
  MovedEvent() => MovedEvent,
  BlockedEvent() => BlockedEvent,
  WaitedEvent() => WaitedEvent,
  DoorChangedEvent() => DoorChangedEvent,
  NoInteractionEvent() => NoInteractionEvent,
  NoiseEvent() => NoiseEvent,
  NoiseHeardEvent() => NoiseHeardEvent,
  ShotEvent() => ShotEvent,
  DryFiredEvent() => DryFiredEvent,
  AlertedEvent() => AlertedEvent,
  CampfireUsedEvent() => CampfireUsedEvent,
  ControlUsedEvent() => ControlUsedEvent,
  TravelMapUsedEvent() => TravelMapUsedEvent,
  LookedOutEvent() => LookedOutEvent,
  FireStartedEvent() => FireStartedEvent,
  TeleportedEvent() => TeleportedEvent,
  PickedUpEvent() => PickedUpEvent,
  DamagedEvent() => DamagedEvent,
  DiedEvent() => DiedEvent,
};

void main() {
  test('the list holds one event of every kind', () {
    final kinds = _oneOfEach.map(_kindOf).toSet();
    expect(kinds, hasLength(_oneOfEach.length), reason: 'no kind twice');
  });

  for (final event in _oneOfEach) {
    test('${event.runtimeType} survives JSON and back', () {
      final encoded = event.toJson();
      final decoded = WorldEvent.fromJson(
        jsonDecode(jsonEncode(encoded)) as Map<String, Object?>,
      );
      expect(decoded.runtimeType, event.runtimeType);
      expect(decoded.toJson(), encoded);
      expect(decoded.description, event.description);
      expect(event.description, isNotEmpty);
    });
  }

  test('a shot that hit nothing keeps its missing target', () {
    const miss = ShotEvent(
      entityId: 'player',
      origin: _a,
      impact: _b,
      direction: Direction.east,
    );
    final decoded =
        WorldEvent.fromJson(
              jsonDecode(jsonEncode(miss.toJson())) as Map<String, Object?>,
            )
            as ShotEvent;
    expect(decoded.hitEntityId, isNull);
  });

  test('an unknown kind of event is a FormatException', () {
    expect(
      () => WorldEvent.fromJson(const <String, Object?>{'type': 'exploded'}),
      throwsFormatException,
    );
  });
}
