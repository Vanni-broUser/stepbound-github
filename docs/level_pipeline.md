# Pipeline dei livelli

Ogni posto del gioco e dipinto a runtime dalle sue righe ASCII, con l'atlas
di `assets/levels/tiles` generato da `tools/build_tile_atlas.py`, che elenca
i posti, impacchetta i tile e scrive il manifest. L'arte di ogni posto sta in
un modulo suo, `tools/tile_atlas_<posto>.py` (citta, Duomo, bar, stazione,
aereo, caserma, treno, ipermercato, San Nicola, Termini, ospedale, Terme,
palazzo dopo l'aereo,
azienda sulla strada del palazzo, Elettronica sulla strada a est della
piazza del monumento),
sulla macchina comune di `tools/tile_atlas_core.py`. I painter della citta
stanno in `tools/street_*.py` (vedi "Dividere i file troppo grandi").

## Un modulo per edificio

Ogni edificio di Molfetta sta in un file suo sotto `lib/core/levels/hometown/`
(`palazzo.dart`, `hospital.dart`, `station.dart`, ...): le righe ASCII dei
suoi posti, la legenda, le tile con un nome (porte, scale, zaini, chi ci
sta), le scale per `WorldState.stairs` e le sue porte, gia appaiate nei
due versi, in una mappa `<edificio>Portals`. `hometown.dart` tiene solo
l'elenco dei posti (`hometownPlaces`, nell'ordine in cui sono disposti
sulla griglia: i salvataggi registrano le tile per coordinate, quindi
l'ordine non si tocca), la composizione delle porte e delle scale di tutti
gli edifici e `hometownContents`, che mette in gioco zombi e zaini
leggendo le tile dai moduli. Roma (`rome.dart`) e ancora un file solo e
prendera la stessa strada quando crescera.

Un edificio nuovo: il suo file con righe, legenda, tile e porte; il suo
`PlaceSpec` in coda a `hometownPlaces`; le sue porte in `_portals()` e le
sue scale in `hometownStairs`; quel che contiene in `hometownContents`.

## Niente palazzi larghi una colonna

Le facciate `H` si dividono in palazzi sullo schema dei tetti, a blocchi di
4, 6 e 5 colonne ogni 15. Dove una fila di facciate comincia sull'ultima
colonna di un blocco, o finisce sulla prima, quella colonna resterebbe un
palazzo a sé: la regola `sliver_rule` (`tools/tile_atlas_city.py`) la
ridipinge del colore del palazzo accanto, senza la riga di separazione.
Accanto a un negozio non c'è niente a cui unirla: le tabelle dei negozi
(`tools/street_paint.py`) non devono lasciare colonne sole tra un negozio e
il palazzo dopo, e `lone_columns` ferma la generazione dell'atlas se
succede, dicendo in quale posto e su quale colonna.

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
  non ancora mappato** (come erano le scale del palazzo accanto al tetto
  dell'ospedale, finche non ne sono stati disegnati i due piani): le
  tile della porta (per una scala, l'ultimo scalino) vanno in
  `workInProgressDoors` (`lib/core/levels/game_world.dart`, per Molfetta
  `hometownWorkInProgressDoors`). Calpestarle apre la stessa
  schermata e rimette Mario dove era prima. Quando l'edificio viene
  disegnato, quelle tile escono dall'elenco e diventano una porta vera
  (`pairedDoors`), come e successo alle scale del palazzo dopo l'aereo.
  Le scale di una sola cella nel muro di fondo vanno nello stesso elenco:
  la cella stessa e la porta. Cosi erano le due dell'azienda, una per ala,
  finche non sono stati disegnati il primo e il secondo piano.
  Il test `test/work_in_progress_test.dart` controlla che nessuna sia
  anche una porta vera.
- **Una porta chiusa a chiave davanti a un posto non ancora mappato** (la
  porta dell'appartamento chiuso al terzo piano del palazzo dopo l'aereo):
  la porta e un muro, il posto dietro non si disegna (resta nero come
  fuori mappa) e lo script della porta, senza chiave, dice che e chiusa;
  con la chiave apre la schermata work in progress e la chiave resta a
  Mario per quando il posto ci sara.
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

## Luoghi non rettangolari: il fuori mappa e la telecamera

Un posto puo non essere un rettangolo: le celle ` ` (`Legend.offMap`) sono
fuori mappa, nere, come oltre il bordo (la piazza dei Cinquecento a L, il
quartiere nord sopra la strada chiusa dal tamponamento e sopra
l'ospedale). La telecamera pero di suo si ferma solo ai bordi del
rettangolo del posto: senza altro, dove arriva a quelle celle mostra il
nero dentro l'inquadratura.

Regola fissa: **un posto con celle fuori mappa dichiara le sue zone della
telecamera** (`PlaceSpec.cameraZones`, `CameraZone` in
`lib/core/levels/place.dart`). Ogni zona e un'area dove sta Mario e i
bordi a cui la vista si ferma mentre lui e li, come fosse il bordo della
mappa. Passando da una zona all'altra i bordi scorrono ai nuovi in una
frazione di secondo (`FollowCamera.limitsRate`), senza scatti.

- Una zona comincia dove il suo bordo non si vede ancora: cosi la
  telecamera ci scivola senza che si veda niente fuori mappa, nemmeno
  mentre scorre.
- `test/camera_zones_test.dart` lo controlla per ogni posto con celle
  fuori mappa: con la telecamera vera, su quattro schermi (dal 4:3 al
  2.4:1), da ogni cella calpestabile e a ogni passaggio tra zone, nessuna
  cella fuori mappa entra nell'inquadratura.

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

- `docs/ci-pipeline.md`, job `sprites_check` e `audio_check`, per i
  generatori di sprite e di suoni, che restano fuori da qui
  (`tools/build_sprites.py --check` e `tools/build_audio.py --check`);
  ritratti e scene della storia sono disegnati a mano (`docs/art_direction.md`).
- `docs/ci-pipeline.md` per la struttura dei job.

## Pavimenti sotto gli oggetti negli interni

Un posto puo dire nell'atlas qual e il pavimento sotto le celle che non lo
sono (`ground`, vedi `ground_config` in `tools/tile_atlas_core.py` e
`GroundConfig` in `lib/game/render/tile_atlas.dart`): il piu vicino lungo
la riga, mai attraverso un muro. Le strade lo usano per auto e lampioni;
il palazzo dopo l'aereo per i mobili, i cadaveri e le porte, cosi un
divano sta sul parquet del soggiorno e il fornello sulle piastrelle della
cucina. `ground_of` in `tile_atlas_core.py` ripete passo per passo quello
che fa il renderer, per `--preview` e `--compare`.

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
- Per Molfetta l'elenco e `hometownStairs` (`hometown.dart`), messo
  insieme dalle scale che ogni edificio elenca nel suo modulo
  (`mallStairs`, `rooftopStairs`, `hospitalStairs`, `stationStairs`).
- Le scale di una sola cella dentro un muro (ospedale, Duomo, stazioni,
  Termini) non vanno elencate: il muro ai lati fa gia da ringhiera, e il
  test `test/stairs_test.dart` lo controlla.
