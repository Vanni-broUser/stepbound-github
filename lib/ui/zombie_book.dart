import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/game/zombie_lore.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/story_intro.dart';

/// One card of the book of zombie types. [kind] is null for the
/// types still to come: they stay "???" until the game has them.
final class ZombieCard {
  const ZombieCard({
    required this.kind,
    required this.name,
    required this.portrait,
    required this.description,
  });

  final EntityKind? kind;
  final String name;
  final String portrait;
  final String description;
}

const String _unknownPortrait = 'assets/story/portrait_wanderer.png';

/// Every card, known or not: first the types the game has, as
/// [zombieLore] tells them, then the ones still to come, "???" until they
/// are in the game too.
final List<ZombieCard> zombieCards = <ZombieCard>[
  for (final MapEntry(key: kind, value: lore) in zombieLore.entries)
    ZombieCard(
      kind: kind,
      name: lore.name,
      portrait: lore.portrait,
      description: lore.description,
    ),
  const ZombieCard(
    kind: EntityKind.brute,
    name: 'Bruto',
    portrait: _unknownPortrait,
    description: '',
  ),
  const ZombieCard(
    kind: EntityKind.blind,
    name: 'Cieco',
    portrait: _unknownPortrait,
    description: '',
  ),
  for (var i = 0; i < 4; i++)
    const ZombieCard(
      kind: null,
      name: '',
      portrait: _unknownPortrait,
      description: '',
    ),
];

/// The pictures and lines of each memory, lived again on Mario's cot.
final Map<StoryMemory, List<StoryScene>>
memoryScenes = <StoryMemory, List<StoryScene>>{
  StoryMemory.newsBroadcast: introScenes,
  StoryMemory.outbreakNight: outbreakScenes,
  StoryMemory.luigiTrapped: <StoryScene>[
    for (final frame in MallScript.luigiScene)
      StoryScene(image: frame.image, speaker: frame.speaker, text: frame.text),
  ],
  StoryMemory.luigiRescued: <StoryScene>[
    for (final frame in MallScript.reunionScene)
      StoryScene(image: frame.image, speaker: frame.speaker, text: frame.text),
  ],
  StoryMemory.priestMet: <StoryScene>[
    for (final frame in PriestScript.meetingScene)
      StoryScene(image: frame.image, speaker: frame.speaker, text: frame.text),
  ],
  StoryMemory.priestErrand: <StoryScene>[
    for (final frame in PriestScript.dealScene)
      StoryScene(image: frame.image, speaker: frame.speaker, text: frame.text),
  ],
  StoryMemory.priestWelcomed: <StoryScene>[
    for (final frame in PriestScript.welcomeScene)
      StoryScene(image: frame.image, speaker: frame.speaker, text: frame.text),
  ],
  StoryMemory.priestFamily: <StoryScene>[
    for (final frame in DuomoScript.initiationScene)
      StoryScene(image: frame.image, speaker: frame.speaker, text: frame.text),
  ],
  StoryMemory.priestMass: <StoryScene>[
    for (final frame in DuomoScript.massScene)
      StoryScene(image: frame.image, speaker: frame.speaker, text: frame.text),
  ],
  StoryMemory.luigiAtStation: <StoryScene>[
    for (final frame in StationScript.reunionScene)
      StoryScene(image: frame.image, speaker: frame.speaker, text: frame.text),
  ],
};

/// Every story scene seen so far, one after the other, in the order they
/// were lived: the harbour and the hypermarket can be played in either
/// order, and half of one before the other, so the memories are replayed
/// as [Progress.memories] holds them, not as the enum lists them.
List<StoryScene> seenScenes(Progress progress) => <StoryScene>[
  for (final memory in progress.memories) ...memoryScenes[memory]!,
];

/// The books open on the crate by Mario's cot, aboard the train: the zombie
/// types met so far, the list of cards on one side and the selected one on
/// the other.
final class ZombieBook extends StatefulWidget {
  const ZombieBook({required this.progress, required this.onClose, super.key});

  /// The zombie types met so far.
  final Progress progress;
  final VoidCallback onClose;

  @override
  State<ZombieBook> createState() => _ZombieBookState();
}

final class _ZombieBookState extends State<ZombieBook> {
  int _selectedZombie = 0;

  bool _known(ZombieCard card) =>
      card.kind != null && widget.progress.knownZombies.contains(card.kind);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1.0;
        return ColoredBox(
          color: const Color(0xc2180e0c),
          child: Padding(
            key: const ValueKey<String>('zombie-book'),
            padding: EdgeInsets.all(8 * unit),
            child: _zombies(unit),
          ),
        );
      },
    );
  }

  /// The list of cards on the left, the selected one's portrait and
  /// description on the right.
  Widget _zombies(double unit) {
    final card = zombieCards[_selectedZombie];
    final known = _known(card);
    return Column(
      key: const ValueKey<String>('zombie-book-page'),
      children: <Widget>[
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 96 * unit,
                child: ListView.builder(
                  itemCount: zombieCards.length,
                  itemBuilder: (context, index) {
                    final entry = zombieCards[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 3 * unit),
                      child: MenuButton(
                        key: ValueKey<String>('zombie-book-$index'),
                        label: _known(entry) ? entry.name.toUpperCase() : '???',
                        unit: unit,
                        compact: true,
                        warning: index == _selectedZombie,
                        width: 90,
                        onPressed: () =>
                            setState(() => _selectedZombie = index),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 8 * unit),
              Expanded(
                child: MenuPanel(
                  unit: unit,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: known
                            ? Image.asset(
                                card.portrait,
                                key: ValueKey<String>(
                                  'zombie-book-portrait-$_selectedZombie',
                                ),
                                fit: BoxFit.contain,
                              )
                            // Unknown: just a black shape.
                            : ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Color(0xff050303),
                                  BlendMode.srcIn,
                                ),
                                child: Image.asset(
                                  card.portrait,
                                  fit: BoxFit.contain,
                                ),
                              ),
                      ),
                      SizedBox(height: 4 * unit),
                      Text(
                        known ? card.name.toUpperCase() : '???',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: BloodColors.bright,
                          fontFamily: 'monospace',
                          fontSize: 9 * unit,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 2 * unit),
                      MenuParagraph(
                        known
                            ? card.description
                            : 'Non hai ancora incontrato questo zombi.',
                        key: const ValueKey<String>('zombie-book-description'),
                        unit: unit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4 * unit),
        Align(
          alignment: Alignment.centerLeft,
          child: MenuButton(
            key: const ValueKey<String>('zombie-book-close'),
            label: 'CHIUDI',
            unit: unit,
            compact: true,
            onPressed: widget.onClose,
          ),
        ),
      ],
    );
  }
}
