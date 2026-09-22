import 'dart:math';

import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';

/// What should be heard during play: one piece of music, how loud it is,
/// and the level of each ambience.
typedef SoundscapeMix = ({
  Music? music,
  double musicLevel,
  Map<Ambience, double> ambience,
});

/// An effect to play, already attenuated by its distance from Mario.
typedef SfxCue = ({Sfx sfx, double volume});

/// Decides the sound of the game from the state of the world. It holds no
/// player of its own, so tests can drive it tick by tick.
final class Soundscape {
  Soundscape({required this.world, Iterable<FireSpot>? fires, Random? random})
    : fires = List<FireSpot>.unmodifiable(fires ?? streetFireSpots),
      _random = random ?? Random();

  /// Tiles within which a zombie that knows where Mario is turns the music.
  static const int dangerRadius = 12;

  /// The chase music lingers this long after the last threat, so it does
  /// not flicker when a zombie steps in and out of range.
  static const double dangerHoldSeconds = 6;

  /// Tiles within which a fire is heard.
  static const double fireRadius = 6;

  /// Tiles beyond which an effect is not heard any more.
  static const double hearingRadius = 16;

  /// Chance per turn that an idle zombie in earshot groans.
  static const double idleMoanChance = 0.04;

  final WorldState world;
  final List<FireSpot> fires;
  final Random _random;
  double _dangerLeft = 0;

  GridPoint get _player => world.player.component<PositionComponent>().position;

  /// True when a living zombie close by is hunting Mario.
  bool get threatened {
    final player = _player;
    return world.entities.values.any(
      (entity) =>
          entity.kind != EntityKind.player &&
          entity.isAlive &&
          entity.maybeComponent<HearingComponent>()?.lastHeard != null &&
          entity.component<PositionComponent>().position.manhattanDistanceTo(
                player,
              ) <=
              dangerRadius,
    );
  }

  /// The mix for this frame: [indoor] when Mario is inside a building,
  /// [resting] while he kneels by a campfire, [gameOver] once he is dead.
  SoundscapeMix update(
    double dt, {
    required bool indoor,
    bool resting = false,
    bool gameOver = false,
  }) {
    if (gameOver) {
      _dangerLeft = 0;
      return (
        music: null,
        musicLevel: 1,
        ambience: <Ambience, double>{
          Ambience.wind: indoor ? 0 : 0.35,
          Ambience.indoor: indoor ? 0.4 : 0,
          Ambience.fire: 0,
        },
      );
    }
    if (world.player.isAlive && threatened) {
      _dangerLeft = dangerHoldSeconds;
    } else if (_dangerLeft > 0) {
      _dangerLeft = max(0, _dangerLeft - dt);
    }
    final danger = _dangerLeft > 0;
    final fire = indoor ? 0.0 : _fireLevel();
    final Music music;
    if (danger) {
      music = Music.danger;
    } else if (indoor) {
      music = Music.barracks;
    } else {
      music = Music.street;
    }
    // By a fire the crackle takes over; resting there almost hushes the
    // music, a moment of calm.
    final musicLevel = resting
        ? 0.2
        : danger
        ? 1.0
        : 1 - fire * 0.6;
    return (
      music: music,
      musicLevel: musicLevel,
      ambience: <Ambience, double>{
        Ambience.wind: indoor ? 0 : 0.55 * (1 - fire * 0.5),
        Ambience.indoor: indoor ? 0.7 : 0,
        Ambience.fire: fire,
      },
    );
  }

  /// Loudness of the closest fire, 0 to 1; a campfire is heard better
  /// than a burning wreck.
  double _fireLevel() {
    final player = _player;
    var level = 0.0;
    for (final spot in fires) {
      final distance = spot.tile.manhattanDistanceTo(player).toDouble();
      final closeness = 1 - distance / fireRadius;
      if (closeness <= 0) {
        continue;
      }
      final weight = spot.kind == FireKind.campfire ? 1.0 : 0.6;
      level = max(level, closeness * weight);
    }
    return level;
  }

  /// The effects a turn's [events] make, loudest for what happens next to
  /// Mario. Positions are read after the turn, which is close enough.
  List<SfxCue> soundsFor(Iterable<WorldEvent> events) {
    final playerId = world.playerId;
    final cues = <SfxCue>[];
    void add(Sfx sfx, {String? at, GridPoint? tile, double volume = 1}) {
      final level = volume * _attenuation(tile ?? _positionOf(at));
      if (level > 0) {
        cues.add((sfx: sfx, volume: level));
      }
    }

    for (final event in events) {
      switch (event) {
        case MovedEvent(:final entityId) when entityId == playerId:
          add(Sfx.step);
        case DoorChangedEvent(:final at):
          add(Sfx.door, tile: at);
        case TeleportedEvent(:final entityId) when entityId == playerId:
          add(Sfx.door);
        case ShotEvent(:final impact, :final hitEntityId):
          add(Sfx.gunshot);
          if (hitEntityId != null) {
            add(Sfx.hitFlesh, tile: impact);
          }
        case DryFiredEvent():
          add(Sfx.dryFire);
        case PickedUpEvent(:final gun):
          add(gun ? Sfx.pickupGun : Sfx.pickup);
        case CampfireUsedEvent():
          add(Sfx.rest);
        case AlertedEvent(:final entityId):
          add(Sfx.zombieAlert, at: entityId);
        case DamagedEvent(:final entityId) when entityId == playerId:
          add(Sfx.zombieBite);
          add(Sfx.playerHurt, volume: 0.8);
        case DamagedEvent(:final entityId):
          add(Sfx.zombieHurt, at: entityId);
        case DiedEvent(:final entityId) when entityId == playerId:
          add(Sfx.playerFall);
        case DiedEvent(:final entityId):
          add(Sfx.zombieDeath, at: entityId);
        case _:
          break;
      }
    }
    return cues;
  }

  /// Now and then a zombie that has not noticed Mario yet groans, quietly,
  /// so the street never feels empty.
  List<SfxCue> idleMoans() {
    final cues = <SfxCue>[];
    for (final entity in world.entities.values) {
      if (entity.kind == EntityKind.player ||
          !entity.isAlive ||
          entity.maybeComponent<HearingComponent>()?.lastHeard != null) {
        continue;
      }
      if (_random.nextDouble() >= idleMoanChance) {
        continue;
      }
      final level = 0.45 * _attenuation(_positionOf(entity.id));
      if (level > 0) {
        cues.add((sfx: Sfx.zombieAlert, volume: level));
      }
    }
    return cues;
  }

  GridPoint? _positionOf(String? entityId) => entityId == null
      ? null
      : world.entities[entityId]?.maybeComponent<PositionComponent>()?.position;

  /// 1 next to Mario, fading to nothing at [hearingRadius]; a sound with no
  /// place is Mario's own.
  double _attenuation(GridPoint? tile) {
    if (tile == null) {
      return 1;
    }
    final distance = tile.manhattanDistanceTo(_player);
    if (distance >= hearingRadius) {
      return 0;
    }
    return max(0.2, 1 - distance / hearingRadius);
  }

  /// Sends [mix] to [audio].
  static void apply(GameAudio audio, SoundscapeMix mix) {
    audio
      ..playMusic(mix.music)
      ..setMusicLevel(mix.musicLevel);
    mix.ambience.forEach(audio.setAmbience);
  }
}
