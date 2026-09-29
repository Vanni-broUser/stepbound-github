# Pipeline dei livelli

Ogni posto del gioco e dipinto a runtime dalle sue righe ASCII, con l'atlas
di `assets/levels/tiles` generato da `tools/build_tile_atlas.py`, che elenca
i posti, impacchetta i tile e scrive il manifest. L'arte di ogni posto sta in
un modulo suo, `tools/tile_atlas_<posto>.py` (citta, Duomo, bar, stazione,
aereo, caserma, treno, ipermercato, San Nicola, Termini, ospedale, Terme),
sulla macchina comune di `tools/tile_atlas_core.py`. I painter della citta
stanno in `tools/street_*.py` (vedi "Dividere i file troppo grandi").

## Strade incomplete: la schermata work in progress

Regola fissa, per ogni livello presente e futuro: **ogni strada, binario o
passaggio che esce dal bordo di una mappa senza una mappa successiva porta
alla schermata work in progress**, l'immagine dello sviluppatore al portatile
(`assets/story/placeholders/work_in_progress.jpg`) con le scritte "Vanni deve
ancora programmarla questa parte / Fagli sapere se ti piace il gioco". Un tocco
la chiude e Mario torna un passo indietro, girato verso l'interno. Mai un
errore, mai un vicolo senza spiegazione.

Non va scritto niente a mano: la regola e generale.

- `Place.edgeEnds` (`lib/core/levels/place.dart`): le tile calpestabili sul
  bordo esterno di un posto, ognuna con la direzione per tornare dentro.
- `workInProgressEnds` (`lib/core/levels/game_world.dart`): quelle di tutti i
  posti di tutti i livelli, tranne le tile che sono porte (portal) verso
  un'altra mappa.
- `WorkInProgressScript` (`lib/game/story/scripts/work_in_progress_script.dart`):
  quando Mario ci mette piede chiede `showWorkInProgress`, che apre
  `WorkInProgressCover`; l'app la disegna con `WorkInProgressScreen`
  (`lib/ui/work_in_progress_screen.dart`).

Cosa fare quando si disegna un posto:

- **Una strada che per ora finisce li**: basta lasciarla aperta fino al
  bordo, calpestabile. La schermata parte da sola.
- **Una scala, una porta o una botola dentro un posto verso un edificio
  non ancora mappato** (per esempio le scale del palazzo dopo l'aereo): le
  tile della porta (per una scala, l'ultimo scalino) vanno in
  `workInProgressDoors` (`lib/core/levels/game_world.dart`, per Molfetta
  `hometownWorkInProgressDoors`). Calpestarle apre la stessa
  schermata e rimette Mario dove era prima. Quando l'edificio viene
  disegnato, quelle tile escono dall'elenco e diventano una porta vera
  (`pairedDoors`). Il test `test/work_in_progress_test.dart` controlla che
  nessuna sia anche una porta vera.
- **Una strada che prosegue in una mappa nuova**: si mette una porta
  (`pairedDoors` o un `Portal`) sulla tile di bordo; una tile con porta non e
  piu un punto work in progress.
- **Un bordo che non deve portare da nessuna parte**: lo si chiude con muri,
  carcasse o fuoco, come le strade bloccate di Molfetta. Una tile chiusa in
  una sacca (nessuna tile calpestabile verso l'interno) resta fuori.
- Non aggiungere liste di bordi per livello (come faceva `romeStreetEnds`):
  la regola generale le copre tutte.

`test/work_in_progress_test.dart` controlla che ogni tile di bordo
calpestabile di ogni posto sia una porta o un punto work in progress, e che
il passo indietro cada dentro lo stesso posto; il test in
`test/widget/dialogue_box_test.dart` ("walking off a map with no next map, thumb still
down...") rifa, sul bordo est di piazza dei Cinquecento, il caso segnalato
col pollice ancora sul joystick mentre la schermata toglie i controlli (a
ovest, dove fu segnalato, oggi la strada finisce contro le Terme di
Diocleziano).

## Cosa resta da fare

### Confronto a schermo con la versione precedente

Tempi di caricamento e frame rate dei posti dipinti a runtime sono stati
misurati su un telefono (`docs/device_measurements.md`), e citta, caserma,
porto e Duomo sono risultati disegnati come nelle anteprime
(`python tools/build_tile_atlas.py --preview DIR`). Resta il confronto
fianco a fianco con la versione precedente alla conversione, per primi i
quattro posti della citta, dove tetti e facciate sono cambiati.

### Dividere i file troppo grandi

- Fatto (2026-09-29): `tools/build_tile_atlas.py` e sceso da 5400 a 460
  righe, ogni interno in un modulo `tools/tile_atlas_<posto>.py`; il modulo
  piu grande e quello del Duomo, 1400 righe per sei posti. Il taglio e
  verificato da `build_tile_atlas.py --check`: atlas, manifest e oggetti
  identici pixel per pixel a prima. L'ordine dei posti in `PLACES` decide
  come i tile sono impacchettati: chi ne aggiunge uno lo mette in coda.
- Fatto (2026-09-29): `tools/build_street_level.py`, i painter della
  citta, e diviso in `tools/street_paint.py` (tavolozza, glifi, font,
  `rect` e `shade`, le righe e `Level`), `tools/street_ground.py`
  (pavimenti: strada, marciapiedi, selciato, cortili, erba, acqua e
  parapetti), `tools/street_buildings.py` (edifici, dai palazzi al Duomo,
  all'ospedale e alla stazione), `tools/street_props.py` (oggetti di scena:
  auto, cestini, cartelli, corpi) e `tools/street_airliner.py` (l'aereo
  caduto visto dalla strada). Ogni modulo prende solo da `street_paint`;
  chi li usa importa dal modulo giusto, `tile_atlas_city.py` con un alias
  per modulo. Verificato da `build_tile_atlas.py --check`, identico pixel
  per pixel.

## Riferimenti

- `docs/maintainability_and_scalability_backlog.md`, voce "What is left of
  asset generation", per i generatori di sprite, audio e immagini della
  storia, che restano fuori da qui (`tools/build_sprites.py --check` e
  `tools/build_audio.py --check`).
- `docs/ci-pipeline.md` per la struttura dei job.

## Le scale

Regola per ogni scala visibile di piu scalini, presente e futura (come
quelle del centro commerciale): **il primo scalino e calpestabile e non fa
niente, l'ultimo e la porta**. Sulla scala si sale e si scende scalino per
scalino, e ci si sposta di lato restando sugli scalini; ci si sale solo dal
pavimento davanti al primo scalino, e se ne esce solo lungo la scala. Dai
lati e dal fondo, dove ci sono muro o ringhiera, non si entra. Vale per
Mario e per gli zombie.

- `WorldState.stairs` (`lib/core/world.dart`): ogni scalino con la direzione
  in cui si sale; `WorldState.canStep` applica la regola a ogni passo
  (Mario, il percorso degli zombie, gli ubriachi che barcollano).
- Per Molfetta l'elenco e `hometownStairs` (`hometown.dart`).
- Le scale di una sola cella dentro un muro (ospedale, Duomo, stazioni,
  Termini) non vanno elencate: il muro ai lati fa gia da ringhiera, e il
  test `test/stairs_test.dart` lo controlla.
