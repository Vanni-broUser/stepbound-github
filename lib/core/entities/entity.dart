import 'package:stepbound/core/entities/components.dart';

/// [carabiniere]: a wanderer in uniform whose baton reaches two tiles.
/// [mutilated]: a zombie with no legs left, which never leaves its tile but
/// bites whoever comes next to it.
/// [burning]: a wanderer on fire, which sets alight every tile it leaves.
/// [drunk]: a wanderer that staggers about at random, aware of the player or
/// not, and only bites straight when he is next to it.
/// [cultist]: a towering cultist zombie which walks like a wanderer but
/// survives the first pistol shot.
enum EntityKind {
  player,
  wanderer,
  sprinter,
  brute,
  blind,
  carabiniere,
  mutilated,
  burning,
  drunk,
  cultist,
}

final class Entity {
  Entity({
    required this.id,
    required this.kind,
    required Iterable<EntityComponent> components,
  }) : _components = <Type, EntityComponent>{
         for (final component in components) component.runtimeType: component,
       };

  factory Entity.fromJson(Map<String, Object?> json) {
    final encodedComponents = json['components']! as List<Object?>;
    return Entity(
      id: json['id']! as String,
      kind: EntityKind.values.byName(json['kind']! as String),
      components: encodedComponents.map(
        (component) => componentFromJson(component! as Map<String, Object?>),
      ),
    );
  }

  final String id;
  final EntityKind kind;
  final Map<Type, EntityComponent> _components;

  T component<T extends EntityComponent>() {
    final value = _components[T];
    if (value == null) {
      throw StateError('Entity $id does not have component $T.');
    }
    return value as T;
  }

  T? maybeComponent<T extends EntityComponent>() {
    return _components[T] as T?;
  }

  bool get isAlive => component<HealthComponent>().isAlive;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'components': _components.values
        .map((component) => component.toJson())
        .toList(),
  };
}
