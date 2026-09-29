import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/audio/soundscape.dart';
import 'package:stepbound/game/haptics/game_haptics.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/character_component.dart';
import 'package:stepbound/game/render/molotov_blast_component.dart';
import 'package:stepbound/report/breadcrumbs.dart';

/// What a character is asked to play for an event.
enum CharacterCue { fire, throwWeapon, throwGrapple, hit, bite, death, alert }

/// The stage the events are played on: what the game lends the presenter,
/// and no more. Animations are asked for by name, so the presenter needs
/// nothing of Flame and a test can stand in for the game.
abstract interface class EventStage {
  String get playerId;

  /// Where Mario is, for the trail.
  String get placeName;

  /// [entityId] plays [cue], facing the way it faces in the simulation.
  void play(String entityId, CharacterCue cue);

  /// [entityId] is dead but stays standing until its death is played.
  void holdDeath(String entityId);

  /// Runs [then] [seconds] from now, on the game's own clock.
  void later(double seconds, void Function() then);

  /// A bottle flies from [origin] to [target]; [onLanded] when it breaks.
  void launchMolotov({
    required GridPoint origin,
    required GridPoint target,
    required void Function() onLanded,
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
  }) : trail = trail ?? Breadcrumbs.shared;

  final EventStage stage;
  final GameAudio audio;
  final Soundscape soundscape;
  final GameplayHaptics haptics;
  final Progress progress;

  /// The story's scripts read the events too (`StoryDirector.onEvents`).
  final void Function(List<WorldEvent> events) onStoryEvents;
  final Breadcrumbs trail;

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

  void _animate(List<WorldEvent> events) {
    final playerId = stage.playerId;
    // The hits of a molotov show once the bottle has landed, not as it
    // leaves Mario's hand: they follow its event in the same turn.
    var blastDelay = 0.0;
    for (final event in events) {
      switch (event) {
        case MolotovThrownEvent(:final origin, :final target):
          stage.play(playerId, CharacterCue.throwWeapon);
          blastDelay =
              CharacterComponent.throwReleaseDelay +
              MolotovBlastComponent.flightSeconds;
          stage.later(
            CharacterComponent.throwReleaseDelay,
            () => stage.launchMolotov(
              origin: origin,
              target: target,
              onLanded: () => audio.play(Sfx.molotov),
            ),
          );
        case DamagedEvent(entityId: final target, sourceEntityId: final source)
            when source == playerId && blastDelay > 0:
          stage.later(blastDelay, () => stage.play(target, CharacterCue.hit));
        case DiedEvent(entityId: final victim)
            when victim != playerId && blastDelay > 0:
          stage.holdDeath(victim);
          stage.later(blastDelay, () => stage.play(victim, CharacterCue.death));
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
