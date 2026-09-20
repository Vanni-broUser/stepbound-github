import 'package:stepbound/core/grid/grid_point.dart';

sealed class EntityComponent {
  String get type;

  Map<String, Object?> toJson();
}

final class PositionComponent extends EntityComponent {
  PositionComponent({required this.position, required this.facing});

  factory PositionComponent.fromJson(Map<String, Object?> json) {
    return PositionComponent(
      position: GridPoint.fromJson(json['position']! as Map<String, Object?>),
      facing: Direction.values.byName(json['facing']! as String),
    );
  }

  GridPoint position;
  Direction facing;

  @override
  String get type => 'position';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'position': position.toJson(),
    'facing': facing.name,
  };
}

final class HealthComponent extends EntityComponent {
  HealthComponent({required this.current, required this.maximum});

  factory HealthComponent.fromJson(Map<String, Object?> json) {
    return HealthComponent(
      current: json['current']! as int,
      maximum: json['maximum']! as int,
    );
  }

  int current;
  final int maximum;

  bool get isAlive => current > 0;

  @override
  String get type => 'health';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'current': current,
    'maximum': maximum,
  };
}

final class AmmoComponent extends EntityComponent {
  AmmoComponent({
    required this.loaded,
    required this.reserve,
    required this.magazineCapacity,
  });

  factory AmmoComponent.fromJson(Map<String, Object?> json) {
    return AmmoComponent(
      loaded: json['loaded']! as int,
      reserve: json['reserve']! as int,
      magazineCapacity: json['magazineCapacity']! as int,
    );
  }

  int loaded;
  int reserve;
  final int magazineCapacity;

  @override
  String get type => 'ammo';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'loaded': loaded,
    'reserve': reserve,
    'magazineCapacity': magazineCapacity,
  };
}

final class VisionComponent extends EntityComponent {
  VisionComponent({required this.range, this.fieldOfViewDegrees = 90});

  factory VisionComponent.fromJson(Map<String, Object?> json) {
    return VisionComponent(
      range: json['range']! as int,
      fieldOfViewDegrees: json['fieldOfViewDegrees']! as int,
    );
  }

  final int range;
  final int fieldOfViewDegrees;

  @override
  String get type => 'vision';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'range': range,
    'fieldOfViewDegrees': fieldOfViewDegrees,
  };
}

final class HearingComponent extends EntityComponent {
  HearingComponent({required this.range, this.lastHeard});

  factory HearingComponent.fromJson(Map<String, Object?> json) {
    final encodedPoint = json['lastHeard'];
    return HearingComponent(
      range: json['range']! as int,
      lastHeard: encodedPoint == null
          ? null
          : GridPoint.fromJson(encodedPoint as Map<String, Object?>),
    );
  }

  final int range;
  GridPoint? lastHeard;

  @override
  String get type => 'hearing';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'range': range,
    'lastHeard': lastHeard?.toJson(),
  };
}

final class ActorComponent extends EntityComponent {
  ActorComponent({
    required this.tickCost,
    required this.contactDamage,
    this.energy = 0,
  });

  factory ActorComponent.fromJson(Map<String, Object?> json) {
    return ActorComponent(
      tickCost: json['tickCost']! as int,
      contactDamage: json['contactDamage']! as int,
      energy: json['energy']! as int,
    );
  }

  final int tickCost;
  final int contactDamage;
  int energy;

  bool gainEnergy() {
    energy += 1;
    if (energy < tickCost) {
      return false;
    }
    energy -= tickCost;
    return true;
  }

  @override
  String get type => 'actor';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'tickCost': tickCost,
    'contactDamage': contactDamage,
    'energy': energy,
  };
}

EntityComponent componentFromJson(Map<String, Object?> json) {
  return switch (json['type']) {
    'position' => PositionComponent.fromJson(json),
    'health' => HealthComponent.fromJson(json),
    'ammo' => AmmoComponent.fromJson(json),
    'vision' => VisionComponent.fromJson(json),
    'hearing' => HearingComponent.fromJson(json),
    'actor' => ActorComponent.fromJson(json),
    _ => throw FormatException('Unknown component type: ${json['type']}'),
  };
}
