// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: assets/balance/default.json

part of 'balance.dart';

const Map<EntityKind, ActorStats> _defaultActorStats = <EntityKind, ActorStats>{
  EntityKind.player: ActorStats(
    tickCost: 1,
    health: 6,
    vision: 0,
    hearing: 0,
    contactDamage: 0,
  ),
  EntityKind.wanderer: ActorStats(
    tickCost: 2,
    health: 1,
    vision: 6,
    hearing: 8,
    contactDamage: 1,
  ),
  EntityKind.sprinter: ActorStats(
    tickCost: 1,
    health: 1,
    vision: 8,
    hearing: 12,
    contactDamage: 1,
  ),
  EntityKind.brute: ActorStats(
    tickCost: 3,
    health: 2,
    vision: 4,
    hearing: 14,
    contactDamage: 1,
  ),
  EntityKind.blind: ActorStats(
    tickCost: 2,
    health: 1,
    vision: 0,
    hearing: 20,
    contactDamage: 1,
  ),
  EntityKind.carabiniere: ActorStats(
    tickCost: 2,
    health: 1,
    vision: 6,
    hearing: 8,
    contactDamage: 1,
    attackReach: 2,
  ),
  EntityKind.mutilated: ActorStats(
    tickCost: 1,
    health: 1,
    vision: 4,
    hearing: 6,
    contactDamage: 1,
    stationary: true,
  ),
  EntityKind.burning: ActorStats(
    tickCost: 2,
    health: 1,
    vision: 6,
    hearing: 8,
    contactDamage: 1,
    trailsFire: true,
  ),
  EntityKind.drunk: ActorStats(
    tickCost: 2,
    health: 1,
    vision: 6,
    hearing: 8,
    contactDamage: 1,
    staggers: true,
  ),
  EntityKind.cultist: ActorStats(
    tickCost: 2,
    health: 3,
    vision: 6,
    hearing: 8,
    contactDamage: 1,
  ),
};
