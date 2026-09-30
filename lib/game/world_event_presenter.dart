import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/audio/soundscape.dart';
import 'package:stepbound/game/haptics/game_haptics.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/report/breadcrumbs.dart';
import 'package:stepbound/report/telemetry.dart';

/// What a character is asked to play for an event.
enum CharacterCue {
  fire,

  /// The gun pose again, the rocket launcher on the shoulder.
  fireRocket,
  throwWeapon,
  throwGrapple,
  hit,
  bite,
  death,
  alert,
}

/// The stage the events are played on: what the game lends the presenter,
/// and no more. Animations are asked for by name, so the presenter needs
/// nothing of Flame and a test can stand in for the game.
abstract interface class EventStage {
  String get playerId;

  /// Where Mario is, for the trail.
  String get placeName;

  /// [entityId] plays [cue], facing the way it faces in the simulation.
  void play(String entityId, CharacterCue cue);

  /// Runs [then] [seconds] from now, on the game's own clock.
  void later(double seconds, void Function() then);

  /// A bottle flies from [origin] to [target]; [onLanded] when it breaks.
  void launchMolotov({
    required GridPoint origin,
    required GridPoint target,
    required void Function() onLanded,
  });

  /// A rocket flies from [origin] the way [direction] to [impact], where
  /// it bursts; [onImpact] then.
  void launchRocket({
    required GridPoint origin,
    required GridPoint impact,
    required Direction direction,
    required void Function() onImpact,
  });

  /// Mario kneels by the fire at [campfire], or sits at the table.
  void restAt(GridPoint campfire);

  /// Mario has stepped through a door or along a road.
  void goThrough({required GridPoint from, required GridPoint to});

  /// Mario throws the grappling hook from [from] to catch on [anchor],
  /// the edge across the gap, and goes over along its rope to [to].
  void grapple({
    required GridPoint from,
    required GridPoint anchor,
    required GridPoint to,
  });

  /// The ground at [at] has caught fire.
  void groundCaughtFire(GridPoint at);

  /// Mario is dead: the controls go, and game over comes after his fall.
  void playerDied();
}

/// Turns the events of a turn into what is seen, heard and felt: the
/// trail an error report ends with, the story's cues, the phone's
/// haptics, the sounds, and each character's animation. Every turn is
/// presented once.
final class WorldEventPresenter {
  WorldEventPresenter({
    required this.stage,
    required this.audio,
    required this.soundscape,
    required this.haptics,
    required this.progress,
    required this.onStoryEvents,
    Breadcrumbs? trail,
    Telemetry? telemetry,
    this.kindOf,
  }) : trail = trail ?? Breadcrumbs.shared,
       telemetry = telemetry ?? Telemetry.shared;

  final EventStage stage;
  final GameAudio audio;
  final Soundscape soundscape;
  final GameplayHaptics haptics;
  final Progress progress;

  /// The story's scripts read the events too (`StoryDirector.onEvents`).
  final void Function(List<WorldEvent> events) onStoryEvents;
  final Breadcrumbs trail;

  /// Where the anonymous events of how the game is played go: places
  /// reached, zombies killed, deaths.
  final Telemetry telemetry;

  /// What kind of character an entity is, by its id, for those events;
  /// without it they say `unknown`.
  final EntityKind? Function(String entityId)? kindOf;

  int _presentedTurn = 0;

  /// The place the trail last named.
  String? _crumbPlace;

  /// The turn last presented.
  int get presentedTurn => _presentedTurn;

  /// Presents [events], those of turn [turn], unless that turn has been
  /// presented already.
  void present(int turn, List<WorldEvent> events) {
    if (turn == _presentedTurn) {
      return;
    }
    _presentedTurn = turn;
    _leaveBreadcrumbs(turn, events);
    _track(events);
    onStoryEvents(events);
    haptics.onEvents(events, playerId: stage.playerId);
    for (final cue in <SfxCue>[
      ...soundscape.soundsFor(events),
      ...soundscape.idleMoans(),
    ]) {
      audio.play(cue.sfx, volume: cue.volume);
    }
    _animate(events);
  }

  /// Writes the turn's events into the trail (see [Breadcrumbs]), and the
  /// place whenever it changes. Steps, waits, bumps and noises are left
  /// out: with a whole cast moving every turn they would bury everything
  /// else within seconds.
  void _leaveBreadcrumbs(int turn, List<WorldEvent> events) {
    final place = stage.placeName;
    if (place != _crumbPlace) {
      _crumbPlace = place;
      trail.add('posto: $place (turno $turn)');
    }
    for (final event in events) {
      switch (event) {
        case MovedEvent() ||
            WaitedEvent() ||
            BlockedEvent() ||
            NoInteractionEvent() ||
            NoiseEvent() ||
            NoiseHeardEvent():
          continue;
        default:
          trail.add('evento: ${event.description}');
      }
    }
  }

  /// The turn's events worth counting: the place when Mario enters it,
  /// every death and who caused Mario's.
  void _track(List<WorldEvent> events) {
    if (!telemetry.active) {
      return;
    }
    final place = stage.placeName;
    final level = progress.level.name;
    if (place != _trackedPlace) {
      _trackedPlace = place;
      telemetry.track('place_entered', <String, Object?>{
        'level': level,
        'place': place,
      });
    }
    final playerId = stage.playerId;
    String kind(String id) => kindOf?.call(id)?.name ?? 'unknown';
    for (final event in events) {
      switch (event) {
        case DiedEvent(entityId: final victim) when victim == playerId:
          final bites = events.whereType<DamagedEvent>().where(
            (hit) => hit.entityId == playerId,
          );
          telemetry.track('player_died', <String, Object?>{
            'level': level,
            'place': place,
            'killer': bites.isEmpty
                ? 'unknown'
                : kind(bites.last.sourceEntityId),
          });
        case DiedEvent(entityId: final victim):
          telemetry.track('zombie_killed', <String, Object?>{
            'level': level,
            'place': place,
            'kind': kind(victim),
          });
        case _:
          break;
      }
    }
  }

  /// The place the events last named.
  String? _trackedPlace;

  void _animate(List<WorldEvent> events) {
    final playerId = stage.playerId;
    for (final event in events) {
      switch (event) {
        // Its hits come with the burst, the turn after, once it has landed
        // (see TurnPresentationController.molotovHoldSeconds).
        case MolotovThrownEvent(:final origin, :final target):
          stage.play(playerId, CharacterCue.throwWeapon);
          stage.later(
            CharacterComponent.throwReleaseDelay,
            () => stage.launchMolotov(
              origin: origin,
              target: target,
              onLanded: () => audio.play(Sfx.molotov),
            ),
          );
        case CampfireUsedEvent(:final at):
          stage.restAt(at);
        case MovedEvent(:final entityId) when entityId == playerId:
          progress.countStep();
        case TeleportedEvent(grappled: true, :final from, :final to):
          // Thrown like a molotov: he already faces the way it flies. The
          // edge the hook catches on is the one just behind where it lands
          // him.
          stage.play(playerId, CharacterCue.throwGrapple);
          stage.grapple(
            from: from,
            anchor: GridPoint(
              to.x - (to.x - from.x).sign,
              to.y - (to.y - from.y).sign,
            ),
            to: to,
          );
        case TeleportedEvent(:final from, :final to):
          stage.goThrough(from: from, to: to);
        case AlertedEvent(entityId: final spotter):
          stage.play(spotter, CharacterCue.alert);
        case FireStartedEvent(:final at):
          stage.groundCaughtFire(at);
        case ShotEvent(entityId: final shooter) when shooter == playerId:
          stage.play(playerId, CharacterCue.fire);
        // Its hits come as it passes each one in its way, and the burst
        // at the end of its line is the sound of it (see
        // TurnPresentationController).
        case RocketFiredEvent(
              entityId: final shooter,
              :final origin,
              :final impact,
              :final direction,
            )
            when shooter == playerId:
          stage.play(playerId, CharacterCue.fireRocket);
          stage.launchRocket(
            origin: origin,
            impact: impact,
            direction: direction,
            onImpact: () => audio.play(Sfx.explosion),
          );
        case DamagedEvent(entityId: final target, sourceEntityId: final source)
            when target == playerId:
          stage.play(source, CharacterCue.bite);
        case DamagedEvent(entityId: final target, sourceEntityId: _):
          stage.play(target, CharacterCue.hit);
        case DiedEvent(entityId: final victim) when victim == playerId:
          stage.playerDied();
        case DiedEvent(entityId: final victim):
          stage.play(victim, CharacterCue.death);
        case _:
          break;
      }
    }
  }
}
