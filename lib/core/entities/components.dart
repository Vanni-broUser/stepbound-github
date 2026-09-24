import 'package:stepbound/core/grid/grid_point.dart';

sealed class EntityComponent {
  String get type;

  Map<String, Object?> toJson();
}

final class PositionComponent extends EntityComponent {
  PositionComponent({required GridPoint position, required this.facing})
    // A named parameter cannot be private, so the field is set by hand.
    // ignore: prefer_initializing_formals
    : _position = position;

  factory PositionComponent.fromJson(Map<String, Object?> json) {
    return PositionComponent(
      position: GridPoint.fromJson(json['position']! as Map<String, Object?>),
      facing: Direction.values.byName(json['facing']! as String),
    );
  }

  GridPoint _position;
  Direction facing;

  /// Set by the `WorldState` holding this entity, and by nobody else, so
  /// its tile index follows a position written straight into [position] —
  /// which is how the player's action, the AI, the tutorial scripts and the
  /// tests all move somebody.
  void Function(GridPoint from, GridPoint to)? onMoved;

  GridPoint get position => _position;

  set position(GridPoint value) {
    if (value == _position) {
      return;
    }
    final previous = _position;
    _position = value;
    onMoved?.call(previous, value);
  }

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
  AmmoComponent({required this.loaded, this.hasGun = true});

  factory AmmoComponent.fromJson(Map<String, Object?> json) {
    return AmmoComponent(
      loaded: json['loaded']! as int,
      hasGun: json['hasGun'] as bool? ?? true,
    );
  }

  /// Every round found, all of them ready to fire: there is no magazine to
  /// fill and nothing is left behind.
  int loaded;

  /// Bullets can be carried before the pistol is found.
  bool hasGun;

  void add(int rounds) => loaded += rounds;

  @override
  String get type => 'ammo';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'loaded': loaded,
    'hasGun': hasGun,
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
  HearingComponent({required this.range, this.lastHeard, this.hunting = false});

  factory HearingComponent.fromJson(Map<String, Object?> json) {
    final encodedPoint = json['lastHeard'];
    return HearingComponent(
      range: json['range']! as int,
      lastHeard: encodedPoint == null
          ? null
          : GridPoint.fromJson(encodedPoint as Map<String, Object?>),
      hunting: json['hunting']! as bool,
    );
  }

  final int range;

  /// Where the zombie last saw or heard something worth going to: set, it
  /// is aware and heads there, even when it has lost the player.
  GridPoint? lastHeard;

  /// True while the zombie is after the player himself (sees or smells
  /// him), not just checking a spot: each time it turns true, it raises the
  /// alert.
  bool hunting;

  @override
  String get type => 'hearing';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'range': range,
    'lastHeard': lastHeard?.toJson(),
    'hunting': hunting,
  };
}

final class ActorComponent extends EntityComponent {
  ActorComponent({
    required this.tickCost,
    required this.contactDamage,
    this.energy = 0,
    this.attackReach = 1,
    this.stationary = false,
    this.trailsFire = false,
    this.staggers = false,
  });

  factory ActorComponent.fromJson(Map<String, Object?> json) {
    return ActorComponent(
      tickCost: json['tickCost']! as int,
      contactDamage: json['contactDamage']! as int,
      energy: json['energy']! as int,
      attackReach: json['attackReach'] as int? ?? 1,
      stationary: json['stationary'] as bool? ?? false,
      trailsFire: json['trailsFire'] as bool? ?? false,
      staggers: json['staggers'] as bool? ?? false,
    );
  }

  final int tickCost;
  final int contactDamage;

  /// Tiles in a straight line the attack reaches.
  final int attackReach;

  /// Never leaves its tile: it only turns towards the player and bites
  /// whoever comes within [attackReach].
  final bool stationary;

  /// Every tile it steps off is left burning, for good.
  final bool trailsFire;

  /// Never goes after anything: every turn it steps a random way, unless
  /// it has the player next to it to bite.
  final bool staggers;
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
    'attackReach': attackReach,
    'stationary': stationary,
    'trailsFire': trailsFire,
    'staggers': staggers,
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
