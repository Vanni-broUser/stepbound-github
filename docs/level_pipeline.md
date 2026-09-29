# Pipeline dei livelli

Ogni posto del gioco e dipinto a runtime dalle sue righe ASCII, con l'atlas
di `assets/levels/tiles` generato da `tools/build_tile_atlas.py` (interni) e
`tools/tile_atlas_city.py` (citta).

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
down...") rifa il caso segnalato a ovest di Termini col pollice ancora sul
joystick mentre la schermata toglie i controlli.

## Cosa resta da fare

### Confronto a schermo con la versione precedente

Tempi di caricamento e frame rate dei posti dipinti a runtime sono stati
misurati su un telefono (`docs/device_measurements.md`), e citta, caserma,
porto e Duomo sono risultati disegnati come nelle anteprime
(`python tools/build_tile_atlas.py --preview DIR`). Resta il confronto
fianco a fianco con la versione precedente alla conversione, per primi i
quattro posti della citta, dove tetti e facciate sono cambiati.

### Dividere i file troppo grandi

- `tools/build_tile_atlas.py` tiene tutti gli interni in circa 2700 righe.
  La citta ha gia un modulo suo (`tools/tile_atlas_city.py`) sulla macchina
  comune di `tools/tile_atlas_core.py`: gli interni vanno portati allo
  stesso modo, un modulo per posto o per gruppo di posti.
- `tools/build_street_level.py`, oggi solo painter della citta, e ancora
  circa 2300 righe: va diviso in pavimenti, edifici e oggetti di scena.

## Riferimenti

- `docs/maintainability_and_scalability_backlog.md`, voce "P2 - Make asset
  generation reproducible", per i generatori di sprite, audio e immagini
  della storia, che restano fuori da qui.
- `docs/ci-pipeline.md` per la struttura dei job.
