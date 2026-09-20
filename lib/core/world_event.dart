import 'package:stepbound/core/grid/grid_point.dart';

sealed class WorldEvent {
  const WorldEvent();

  factory WorldEvent.fromJson(Map<String, Object?> json) {
    return switch (json['type']) {
      'moved' => MovedEvent.fromJson(json),
      'blocked' => BlockedEvent.fromJson(json),
      'waited' => WaitedEvent.fromJson(json),
      'doorChanged' => DoorChangedEvent.fromJson(json),
      'noInteraction' => NoInteractionEvent.fromJson(json),
      'noise' => NoiseEvent.fromJson(json),
      'noiseHeard' => NoiseHeardEvent.fromJson(json),
      'damaged' => DamagedEvent.fromJson(json),
      'died' => DiedEvent.fromJson(json),
      _ => throw FormatException('Unknown world event: ${json['type']}'),
    };
  }

  String get description;

  Map<String, Object?> toJson();
}

final class MovedEvent extends WorldEvent {
  const MovedEvent({
    required this.entityId,
    required this.from,
    required this.to,
  });

  factory MovedEvent.fromJson(Map<String, Object?> json) {
    return MovedEvent(
      entityId: json['entityId']! as String,
      from: GridPoint.fromJson(json['from']! as Map<String, Object?>),
      to: GridPoint.fromJson(json['to']! as Map<String, Object?>),
    );
  }

  final String entityId;
  final GridPoint from;
  final GridPoint to;

  @override
  String get description => '$entityId moves $from -> $to';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'moved',
    'entityId': entityId,
    'from': from.toJson(),
    'to': to.toJson(),
  };
}

final class BlockedEvent extends WorldEvent {
  const BlockedEvent({
    required this.entityId,
    required this.at,
    required this.reason,
  });

  factory BlockedEvent.fromJson(Map<String, Object?> json) {
    return BlockedEvent(
      entityId: json['entityId']! as String,
      at: GridPoint.fromJson(json['at']! as Map<String, Object?>),
      reason: json['reason']! as String,
    );
  }

  final String entityId;
  final GridPoint at;
  final String reason;

  @override
  String get description => '$entityId is blocked at $at ($reason)';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'blocked',
    'entityId': entityId,
    'at': at.toJson(),
    'reason': reason,
  };
}

final class WaitedEvent extends WorldEvent {
  const WaitedEvent(this.entityId);

  factory WaitedEvent.fromJson(Map<String, Object?> json) {
    return WaitedEvent(json['entityId']! as String);
  }

  final String entityId;

  @override
  String get description => '$entityId waits';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'waited',
    'entityId': entityId,
  };
}

final class DoorChangedEvent extends WorldEvent {
  const DoorChangedEvent({required this.at, required this.isOpen});

  factory DoorChangedEvent.fromJson(Map<String, Object?> json) {
    return DoorChangedEvent(
      at: GridPoint.fromJson(json['at']! as Map<String, Object?>),
      isOpen: json['isOpen']! as bool,
    );
  }

  final GridPoint at;
  final bool isOpen;

  @override
  String get description => 'door at $at is ${isOpen ? 'open' : 'closed'}';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'doorChanged',
    'at': at.toJson(),
    'isOpen': isOpen,
  };
}

final class NoInteractionEvent extends WorldEvent {
  const NoInteractionEvent(this.at);

  factory NoInteractionEvent.fromJson(Map<String, Object?> json) {
    return NoInteractionEvent(
      GridPoint.fromJson(json['at']! as Map<String, Object?>),
    );
  }

  final GridPoint at;

  @override
  String get description => 'nothing to interact with at $at';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'noInteraction',
    'at': at.toJson(),
  };
}

final class NoiseEvent extends WorldEvent {
  const NoiseEvent({
    required this.origin,
    required this.radius,
    required this.sourceEntityId,
  });

  factory NoiseEvent.fromJson(Map<String, Object?> json) {
    return NoiseEvent(
      origin: GridPoint.fromJson(json['origin']! as Map<String, Object?>),
      radius: json['radius']! as int,
      sourceEntityId: json['sourceEntityId']! as String,
    );
  }

  final GridPoint origin;
  final int radius;
  final String sourceEntityId;

  @override
  String get description => '$sourceEntityId makes noise $radius at $origin';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'noise',
    'origin': origin.toJson(),
    'radius': radius,
    'sourceEntityId': sourceEntityId,
  };
}

final class NoiseHeardEvent extends WorldEvent {
  const NoiseHeardEvent({required this.entityId, required this.origin});

  factory NoiseHeardEvent.fromJson(Map<String, Object?> json) {
    return NoiseHeardEvent(
      entityId: json['entityId']! as String,
      origin: GridPoint.fromJson(json['origin']! as Map<String, Object?>),
    );
  }

  final String entityId;
  final GridPoint origin;

  @override
  String get description => '$entityId hears noise from $origin';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'noiseHeard',
    'entityId': entityId,
    'origin': origin.toJson(),
  };
}

final class DamagedEvent extends WorldEvent {
  const DamagedEvent({
    required this.entityId,
    required this.amount,
    required this.sourceEntityId,
  });

  factory DamagedEvent.fromJson(Map<String, Object?> json) {
    return DamagedEvent(
      entityId: json['entityId']! as String,
      amount: json['amount']! as int,
      sourceEntityId: json['sourceEntityId']! as String,
    );
  }

  final String entityId;
  final int amount;
  final String sourceEntityId;

  @override
  String get description =>
      '$entityId takes $amount damage from $sourceEntityId';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'damaged',
    'entityId': entityId,
    'amount': amount,
    'sourceEntityId': sourceEntityId,
  };
}

final class DiedEvent extends WorldEvent {
  const DiedEvent(this.entityId);

  factory DiedEvent.fromJson(Map<String, Object?> json) {
    return DiedEvent(json['entityId']! as String);
  }

  final String entityId;

  @override
  String get description => '$entityId dies';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'died',
    'entityId': entityId,
  };
}
