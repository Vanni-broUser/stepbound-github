import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';

/// Conversations inside the Duomo. All of them are triggered by facing the
/// person and using the interaction button, and therefore carry a portrait.
final class DuomoScript extends StoryScript {
  DuomoScript(super.director);

  static const String cultist = 'Cultista';
  static const String cultistPortrait =
      'assets/characters/npcs/portraits/cultist.png';
  static const String initiationImage = 'assets/story/scenes/priest_family.jpg';
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

  static const String massImage = 'assets/story/scenes/priest_mass.jpg';
  static const String crucifiedImage =
      'assets/story/scenes/crucified_zombie.jpg';
  static const String massWelcomeLine =
      'Noi siamo tutti pronti a cominciare giovanotto, accomodati pure!';
  static const String massSermonLine =
      "Il Signore ha mandato questa sciagura contro l'uomo, essa però è "
      'pur sempre opera del Signore ed ha lo scopo di purificare il mondo';

  /// Played when Mario comes back down into the Duomo wearing the robe.
  static const List<CutsceneFrame> massScene = <CutsceneFrame>[
    CutsceneFrame(
      image: massImage,
      speaker: PriestScript.priest,
      text: massWelcomeLine,
    ),
    CutsceneFrame(
      image: crucifiedImage,
      speaker: PriestScript.priest,
      text: massSermonLine,
    ),
  ];

  static const String sermonImage = 'assets/story/scenes/priest_worship.jpg';
  static const String feastImage = 'assets/story/scenes/cultists_feast.jpg';
  static const String mutationImage =
      'assets/story/scenes/cultists_mutation.jpg';
  static const String seizedImage = 'assets/story/scenes/priest_seized.jpg';

  static const String worshipLine =
      'Lo zombi non va temuto. Lo zombi va venerato. Attraverso la nostra '
      'preghiera gli zombi ci salveranno';
  static const String areYouMadLine = 'Cosa fate? Ma siete pazzi?!';
  static const String superZombieLine =
      'Basta un loro morso a trasformare un uomo in zombi, voi li state '
      'direttamente ingerendo... Questo vi sta trasformando in super zombi';
  static const String letMeGoLine = 'No, lasciatemi andare! Nooo';

  /// How the mass ends: the sermon turns into worship, the community eats
  /// of the crucified zombie, Mario works out what that makes of them, and
  /// what they have become takes Don Angelo.
  static const List<CutsceneFrame> massacreScene = <CutsceneFrame>[
    CutsceneFrame(
      image: sermonImage,
      speaker: PriestScript.priest,
      text: worshipLine,
    ),
    CutsceneFrame(
      image: feastImage,
      speaker: 'Mario Rossi',
      text: areYouMadLine,
    ),
    CutsceneFrame(
      image: mutationImage,
      speaker: 'Mario Rossi',
      text: superZombieLine,
    ),
    CutsceneFrame(
      image: seizedImage,
      speaker: PriestScript.priest,
      text: letMeGoLine,
    ),
  ];

  /// The mass and what it turns into, played as one scene: fading back to
  /// the game between the sermon and the feast would cut the moment in two.
  static const List<CutsceneFrame> massSequence = <CutsceneFrame>[
    ...massScene,
    ...massacreScene,
  ];

  static const String keyUsedLine =
      'Hai usato la Chiave del Duomo per aprire la porta';

  static const String outfitChangedLine =
      'Mario cambia abbigliamento uscito dal duomo';
  static const String outfitMenuLine =
      'Puoi cambiare il tuo abbigliamento attraverso una funzione '
      'disponibile nel menù';

  /// Leaves the portal's fade time to lift off the harbour first.
  static const double outfitLessonDelay = 0.8;

  bool _ringDelivered = false;
  bool _massacrePlayed = false;
  bool _leftAfterMassacre = false;

  bool get ringDelivered => _ringDelivered;

  /// True once the mass has ended: Don Angelo is dead, his community are
  /// the four cultists in the nave and the key lies beside his body.
  bool get massacrePlayed => _massacrePlayed;

  @override
  String get key => 'duomo';

  @override
  void onEvent(WorldEvent event) {
    if (event case TeleportedEvent(
      :final entityId,
      :final from,
      :final to,
    ) when entityId == world.playerId) {
      _leaveAfterMassacre(from, to);
      return;
    }
    // The robe lies in a backpack, like everything Mario picks up.
    if (event case PickedUpEvent(cultistRobe: true)) {
      say(
        StoryPrompt(
          const <StoryLine>[StoryLine(robeFoundLine)],
          delay: StoryDirector.pickupDelay,
          onDismissed: host.hometown.collectCultistRobe,
        ),
      );
      return;
    }
    if (event case NoInteractionEvent(
      :final at,
    ) when at == duomoUpperLockedDoorTile) {
      _tryTheUpperDoor(at);
      return;
    }
    if (event case NoInteractionEvent(:final at)) {
      // Nobody is left in the nave to answer once the mass has ended.
      final line = _massacrePlayed
          ? null
          : switch (at) {
              _ when !_ringDelivered && at == duomoStairCultistTile =>
                const StoryLine.cultist(stairBlockedLine),
              _ when _ringDelivered && at == duomoStairCultistMovedTile =>
                const StoryLine.cultist(welcomeLine),
              _ when at == duomoWelcomingCultistTile => const StoryLine.cultist(
                welcomeLine,
              ),
              _ when at == duomoPriestTile => StoryLine.priest(
                _ringDelivered ? initiationReminderLine : ringReminderLine,
              ),
              _ => null,
            };
      if (line != null) {
        say(StoryPrompt(<StoryLine>[line]));
      }
    }
  }

  /// The locked door in the corner of the upper floor: the key found beside
  /// Don Angelo's body opens it for good and is used up doing so, as the
  /// bar's own key is. Without it, all Mario learns is that it is locked.
  void _tryTheUpperDoor(GridPoint at) {
    if (world.map.tileAt(at).isWalkable) {
      return;
    }
    if (host.isUnlocked(HudElement.duomoKey)) {
      world.map.setTile(at, const Tile(TileKind.floor));
      host.removeHud(HudElement.duomoKey);
      say(StoryPrompt(const <StoryLine>[StoryLine(keyUsedLine)]));
      return;
    }
    say(StoryPrompt(const <StoryLine>[StoryLine(lockedDoorLine)]));
  }

  @override
  void update({required bool turnAnimating}) {
    if (turnAnimating || host.isPromptVisible) {
      return;
    }
    final position = world.player.component<PositionComponent>().position;
    if (_ringDelivered) {
      _startMassIfDressed(position);
      return;
    }
    final ring = world.pickups[episcopalRingPickupId];
    if (ring == null ||
        !ring.collected ||
        placeAt(position)?.id != PlaceId.duomo) {
      return;
    }
    _ringDelivered = true;
    host.playCutscene(
      initiationScene,
      memories: const <StoryMemory>{StoryMemory.priestFamily},
      music: Music.sacred,
      onBlack: _finishInitiation,
      onFinished: () => progress.missions
        ..complete(Mission.findRing)
        ..give(Mission.initiation),
    );
  }

  /// The mass waits for Mario in the Duomo in the occultist robe: coming
  /// down in his own clothes changes nothing, until he is back in there
  /// wearing it. It runs straight into the massacre, and once that has been
  /// played the nave stays as it left it.
  void _startMassIfDressed(GridPoint position) {
    if (_massacrePlayed ||
        progress.activeOutfit != PlayerOutfit.cultist ||
        placeAt(position)?.id != PlaceId.duomo) {
      return;
    }
    _massacrePlayed = true;
    host.playCutscene(
      massSequence,
      memories: const <StoryMemory>{
        StoryMemory.priestMass,
        StoryMemory.priestMassacre,
      },
      music: Music.sacred,
      onBlack: host.hometown.startDuomoMassacre,
      onFinished: () => progress.missions.complete(Mission.initiation),
    );
  }

  /// The first time Mario comes out of the Duomo onto the harbour after
  /// the massacre, the robe comes off: he is back in his own clothes, and
  /// is told the menu can change them. Out in his own clothes already, he
  /// has found the wardrobe by himself, and nothing is said.
  void _leaveAfterMassacre(GridPoint from, GridPoint to) {
    if (!_massacrePlayed ||
        _leftAfterMassacre ||
        placeAt(from)?.id != PlaceId.duomo ||
        placeAt(to)?.id != PlaceId.harbour) {
      return;
    }
    _leftAfterMassacre = true;
    if (progress.activeOutfit != PlayerOutfit.cultist) {
      return;
    }
    host.wearOutfit(PlayerOutfit.base);
    say(
      StoryPrompt(const <StoryLine>[
        StoryLine(outfitChangedLine),
        StoryLine(outfitMenuLine),
      ], delay: outfitLessonDelay),
    );
  }

  void _finishInitiation() {
    host
      ..removeHud(HudElement.episcopalRing)
      ..hometown.openDuomoUpper();
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'ringDelivered': _ringDelivered,
    'massacre': _massacrePlayed,
    'leftAfterMassacre': _leftAfterMassacre,
  };

  @override
  void restore(Map<String, Object?> json) {
    _ringDelivered = json['ringDelivered'] as bool? ?? false;
    _massacrePlayed = json['massacre'] as bool? ?? false;
    _leftAfterMassacre = json['leftAfterMassacre'] as bool? ?? false;
  }
}
