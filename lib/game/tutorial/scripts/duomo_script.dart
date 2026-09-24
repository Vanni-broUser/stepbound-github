import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';

/// Conversations inside the Duomo. All of them are triggered by facing the
/// person and using the interaction button, and therefore carry a portrait.
final class DuomoScript extends TutorialScript {
  DuomoScript(super.director);

  static const String cultist = 'Cultista';
  static const String cultistPortrait = 'assets/story/portrait_cultist.png';
  static const String initiationImage = 'assets/story/scene_priest_family.jpg';
  static const String stairBlockedLine =
      'Potrai passare da qui solo quando sarai anche tu davvero parte '
      'della nostra comunità';
  static const String welcomeLine =
      'Che bello vedere nuovi fedeli che si uniscono a noi';
  static const String ringReminderLine =
      "Non hai ancora recuperato l'anello episcopale?";
  static const String familyWelcomeLine =
      'Ottimo giovanotto, sei davvero un prodigio! Benvenuto nella nostra '
      'grande famiglia';
  static const String robeLine =
      'Abbiamo preparato una tunica anche per te, la trovi al piano '
      'superiore';
  static const String initiationReminderLine =
      'Indossa la tunica e preparati per la tua cerimonia di iniziazione';
  static const String lockedDoorLine =
      'Questa porta è chiusa. Serve una chiave';
  static const String robeFoundLine = 'Hai trovato una tunica da occultista';

  static const List<CutsceneFrame> initiationScene = <CutsceneFrame>[
    CutsceneFrame(
      image: initiationImage,
      speaker: PriestScript.priest,
      text: familyWelcomeLine,
    ),
    CutsceneFrame(
      image: initiationImage,
      speaker: PriestScript.priest,
      text: robeLine,
    ),
  ];

  bool _ringDelivered = false;

  bool get ringDelivered => _ringDelivered;

  @override
  String get key => 'duomo';

  @override
  void onEvent(WorldEvent event) {
    if (event case NoInteractionEvent(:final at)) {
      if (at == duomoUpperRobeTile &&
          !progress.unlockedOutfits.contains(PlayerOutfit.cultist)) {
        say(
          TutorialPrompt(const <TutorialLine>[
            TutorialLine(robeFoundLine),
          ], onDismissed: host.collectCultistRobe),
        );
        return;
      }
      final line = switch (at) {
        _ when !_ringDelivered && at == duomoStairCultistTile =>
          const TutorialLine.cultist(stairBlockedLine),
        _ when _ringDelivered && at == duomoStairCultistMovedTile =>
          const TutorialLine.cultist(welcomeLine),
        _ when at == duomoWelcomingCultistTile => const TutorialLine.cultist(
          welcomeLine,
        ),
        _ when at == duomoPriestTile => TutorialLine.priest(
          _ringDelivered ? initiationReminderLine : ringReminderLine,
        ),
        _ when at == duomoUpperLockedDoorTile => const TutorialLine(
          lockedDoorLine,
        ),
        _ => null,
      };
      if (line != null) {
        say(TutorialPrompt(<TutorialLine>[line]));
      }
    }
  }

  @override
  void update({required bool turnAnimating}) {
    if (_ringDelivered || turnAnimating || host.isPromptVisible) {
      return;
    }
    final ring = world.pickups[episcopalRingPickupId];
    final position = world.player.component<PositionComponent>().position;
    if (ring == null ||
        !ring.collected ||
        placeAt(position)?.id != PlaceId.duomo) {
      return;
    }
    _ringDelivered = true;
    progress.remember(StoryMemory.priestFamily);
    host.playCutscene(initiationScene, onFinished: _finishInitiation);
  }

  void _finishInitiation() {
    host
      ..removeHud(HudElement.episcopalRing)
      ..openDuomoUpper();
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'ringDelivered': _ringDelivered,
  };

  @override
  void restore(Map<String, Object?> json) {
    _ringDelivered = json['ringDelivered'] as bool? ?? false;
  }
}
