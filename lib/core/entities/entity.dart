import 'package:stepbound/core/entities/components.dart';

enum EntityKind { player, wanderer, sprinter, brute, blind }

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
