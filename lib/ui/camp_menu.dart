import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/story_intro.dart';

/// One card of the camp's list of zombie types. [kind] is null for the
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

/// Every card, known or not. Many are still "???": more types will come.
final List<ZombieCard> zombieCards = <ZombieCard>[
  const ZombieCard(
    kind: EntityKind.wanderer,
    name: 'Vagante',
    portrait: 'assets/story/portrait_wanderer.png',
    description:
        'Il più comune: fino a poco fa era una persona qualunque. Lento e '
        'goffo, fa un passo ogni due dei tuoi. Da solo si evita, in gruppo '
        'ti chiude la strada.',
  ),
  const ZombieCard(
    kind: EntityKind.carabiniere,
    name: 'Carabiniere',
    portrait: 'assets/story/portrait_carabiniere.png',
    description:
        'Porta ancora la divisa e stringe il manganello: ti colpisce fino a '
        'due celle di distanza. Si muove come un vagante, ma non lasciarlo '
        'avvicinare.',
  ),
  const ZombieCard(
    kind: EntityKind.sprinter,
    name: 'Veloce',
    portrait: 'assets/story/portrait_sprinter.png',
    description:
        'Si muove alla tua stessa velocità: correndo non lo semini. Ti vede '
        'e ti sente da più lontano degli altri.',
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
  for (var i = 0; i < 7; i++)
    const ZombieCard(
      kind: null,
      name: '',
      portrait: _unknownPortrait,
      description: '',
    ),
];

/// The pictures and lines of each memory.
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
  StoryMemory.luigiAtStation: <StoryScene>[
    for (final frame in StationScript.reunionScene)
      StoryScene(image: frame.image, speaker: frame.speaker, text: frame.text),
  ],
};

enum _CampPage { home, zombies }

/// Opens at a campfire, over the game: save, look up the zombie types met
/// so far, or watch the story scenes seen so far. Starting the level over
/// is not here: it belongs with the other ways out, in the menu the corner
/// button opens.
final class CampMenu extends StatefulWidget {
  const CampMenu({
    required this.progress,
    required this.onSave,
    required this.onClose,
    this.onMemories,
    super.key,
  });

  /// The zombie types met and the story scenes seen so far.
  final Progress progress;
  final Future<void> Function() onSave;
  final VoidCallback onClose;

  /// Told true when the memories start playing and false when they end,
  /// so the story's sound can take over from the camp's.
  final ValueChanged<bool>? onMemories;

  @override
  State<CampMenu> createState() => _CampMenuState();
}

final class _CampMenuState extends State<CampMenu> {
  _CampPage _page = _CampPage.home;
  bool _saving = false;
  bool _saved = false;
  int _selectedZombie = 0;
  bool _watchingMemories = false;

  /// Every story scene seen so far, one after the other, in the order they
  /// were lived: the harbour and the hypermarket can be played in either
  /// order, and half of one before the other, so the memories are replayed
  /// as [Progress.memories] holds them, not as the enum lists them.
  List<StoryScene> get _seenScenes => <StoryScene>[
    for (final memory in widget.progress.memories) ...memoryScenes[memory]!,
  ];

  bool _known(ZombieCard card) =>
      card.kind != null && widget.progress.knownZombies.contains(card.kind);

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave();
    if (mounted) {
      setState(() {
        _saving = false;
        _saved = true;
      });
    }
  }

  void _open(_CampPage page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    if (_watchingMemories) {
      void back() {
        widget.onMemories?.call(false);
        setState(() => _watchingMemories = false);
      }

      return StoryIntro(
        key: const ValueKey<String>('camp-memories-story'),
        scenes: _seenScenes,
        onFinished: back,
        onExit: back,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1.0;
        // No backdrop: the buttons float over the world, which stays in
        // view.
        return Padding(
          key: const ValueKey<String>('camp-menu'),
          padding: EdgeInsets.all(8 * unit),
          child: switch (_page) {
            _CampPage.zombies => _zombies(unit),
            _ => Center(child: SingleChildScrollView(child: _list(unit))),
          },
        );
      },
    );
  }

  Widget _list(double unit) {
    return MenuColumn(
      unit: unit,
      // Apart from the choices: leaving the fire is not one of them.
      trailing: MenuButton(
        key: const ValueKey<String>('camp-close'),
        label: 'TORNA AL GIOCO',
        unit: unit,
        compact: true,
        onPressed: widget.onClose,
      ),
      children: <Widget>[
        MenuButton(
          key: const ValueKey<String>('camp-save'),
          label: _saved ? 'SALVATAGGIO COMPLETATO' : 'SALVA IL GIOCO',
          unit: unit,
          compact: true,
          onPressed: _saving || _saved ? null : () => unawaited(_save()),
        ),
        MenuButton(
          key: const ValueKey<String>('camp-zombies'),
          label: 'TIPI DI ZOMBI',
          unit: unit,
          compact: true,
          onPressed: () => _open(_CampPage.zombies),
        ),
        MenuButton(
          key: const ValueKey<String>('camp-memories'),
          label: 'RIVEDI I RICORDI',
          unit: unit,
          compact: true,
          onPressed: () {
            widget.onMemories?.call(true);
            setState(() => _watchingMemories = true);
          },
        ),
      ],
    );
  }

  Widget _back(double unit, {String label = 'INDIETRO'}) => MenuButton(
    key: const ValueKey<String>('camp-back'),
    label: label,
    unit: unit,
    compact: true,
    onPressed: () => _open(_CampPage.home),
  );

  /// The list of cards on the left, the selected one's portrait and
  /// description on the right.
  Widget _zombies(double unit) {
    final card = zombieCards[_selectedZombie];
    final known = _known(card);
    return Column(
      key: const ValueKey<String>('camp-zombie-page'),
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
                        key: ValueKey<String>('camp-zombie-$index'),
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
                                  'camp-portrait-$_selectedZombie',
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
                        key: const ValueKey<String>('camp-zombie-description'),
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
        Align(alignment: Alignment.centerLeft, child: _back(unit)),
      ],
    );
  }
}
