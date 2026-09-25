import 'package:meta/meta.dart';
import 'package:stepbound/core/grid/grid_point.dart';

/// A backpack lying on the map. It blocks the tile it sits on, is collected
/// with an interaction from a neighbouring tile and can start inactive
/// (hidden and intangible) until a script reveals it.
final class Pickup {
  Pickup({
    required this.id,
    required this.position,
    this.ammo = 0,
    this.gun = false,
    this.incense = false,
    this.episcopalRing = false,
    this.cultistRobe = false,
    this.active = true,
    this.collected = false,
  });

  factory Pickup.fromJson(Map<String, Object?> json) {
    return Pickup(
      id: json['id']! as String,
      position: GridPoint.fromJson(json['position']! as Map<String, Object?>),
      ammo: json['ammo']! as int,
      gun: json['gun']! as bool,
      incense: json['incense']! as bool,
      episcopalRing: json['episcopalRing']! as bool,
      cultistRobe: json['cultistRobe']! as bool,
      active: json['active']! as bool,
      collected: json['collected'] as bool? ?? false,
    );
  }

  final String id;
  final GridPoint position;
  final int ammo;
  final bool gun;

  /// The censer's worth of incense Don Angelo asked for: there is one
  /// such backpack, in San Nicola.
  final bool incense;

  /// Don Angelo's episcopal ring, hidden in the Bar Arcobaleno storeroom.
  final bool episcopalRing;

  /// The occultist robe, upstairs in the Duomo's dormitory.
  final bool cultistRobe;

  /// False while hidden by a script and after it has been collected.
  bool active;

  bool collected;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'position': position.toJson(),
    'ammo': ammo,
    'gun': gun,
    'incense': incense,
    'episcopalRing': episcopalRing,
    'cultistRobe': cultistRobe,
    'active': active,
    'collected': collected,
  };
}

/// Where a door leads: stepping on its tile moves the player to [to],
/// looking towards [facing].
final class Portal {
  const Portal({required this.to, required this.facing});

  factory Portal.fromJson(Map<String, Object?> json) => Portal(
    to: GridPoint.fromJson(json['to']! as Map<String, Object?>),
    facing: Direction.values.byName(json['facing']! as String),
  );

  final GridPoint to;
  final Direction facing;

  Map<String, Object?> toJson() => <String, Object?>{
    'to': to.toJson(),
    'facing': facing.name,
  };
}

/// Inclusive rectangle of tiles.
@immutable
final class GridRect {
  const GridRect(this.left, this.top, this.right, this.bottom);

  factory GridRect.fromJson(Map<String, Object?> json) => GridRect(
    json['left']! as int,
    json['top']! as int,
    json['right']! as int,
    json['bottom']! as int,
  );

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool contains(GridPoint point) =>
      point.x >= left &&
      point.x <= right &&
      point.y >= top &&
      point.y <= bottom;

  @override
  bool operator ==(Object other) =>
      other is GridRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  Map<String, Object?> toJson() => <String, Object?>{
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };
}
