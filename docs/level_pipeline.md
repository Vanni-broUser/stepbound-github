# Pipeline dei livelli

## Problema

Ogni posto del gioco esiste due volte, in due linguaggi, e fino alla Fase 1
nessun controllo automatico verificava che le due copie fossero d'accordo.

| Cosa | Dove | Linguaggio |
| --- | --- | --- |
| Layout: cosa blocca, cosa e calpestabile, cosa e rumoroso | `<place>Rows` in `lib/core/levels/tutorial/<place>.dart` | Dart |
| Significato dei glifi | `<place>Legend` in `lib/core/levels/tutorial/tutorial_level.dart` | Dart |
| Aspetto: cosa vede il giocatore | `assets/levels/<place>.png`, dipinto da `tools/build_<place>.py` | Python |

Il baker rilegge le righe ASCII dal file Dart cercando i marker
`// <place>-rows-start` / `// <place>-rows-end` e le ridipinge con una catena
di `elif glyph == "T"` scritta a mano. Il glifo `T` significa quindi "panca,
ostacolo" in Dart e "disegna una panca" in Python: due decisioni separate che
devono restare allineate a mano.

La riconciliazione era manuale e nessun gate la verificava: `flutter test`
copre il core, che non sa che i PNG esistano; `flutter analyze` vede un
immagine; la CI non eseguiva Python. Si spostava una panca in `churchRows`, ci
si dimenticava di rilanciare `tools/build_church.py`, e il giocatore
attraversava una panca disegnata o sbatteva contro un muro invisibile.

Per il balance la rete esisteva gia: `dart run tools/generate_balance.dart
--check` in CI rifiuta i dati generati stantii. Per i livelli no, ed e il caso
in cui sbagliare e piu facile e meno visibile.

## Obiettivo

Portare il layout di un posto ad avere una sola sorgente di verita, e nel
frattempo impedire che le due attuali divergano senza che nessuno se ne
accorga.

Le tre fasi sono indipendenti e consegnabili separatamente. La Fase 1 ha
valore anche se le altre non si fanno mai. Le Fasi 1 e 2 restano utili durante
tutta la Fase 3, perche coprono i posti non ancora convertiti.

## Fase 1 - Invariante dimensionale (fatta)

`test/levels/level_background_dimensions_test.dart` verifica, per ogni `Place`
di `tutorialPlaces`, che l'immagine di sfondo misuri esattamente
`width * levelTileSize` per `height * levelTileSize` pixel, e che
l'`alternateBackground`, dove c'e, misuri come il principale. Verifica inoltre
che tutte le righe di un `rows` abbiano la stessa lunghezza: `Place.width`
legge solo `rows.first`, quindi una riga fuori misura sposterebbe in silenzio
tutto quello che viene dipinto dopo.

Non decodifica il PNG: larghezza e altezza stanno nell'header IHDR, byte
16..24, big-endian unsigned. La dimensione del tile viene da `levelTileSize`
(`lib/core/levels/place.dart`), la stessa costante che usa il renderer.

Cattura righe aggiunte o tolte, posti allargati, PNG rigenerato da righe
diverse, PNG sostituito con uno di misura sbagliata. Non cattura una panca
spostata dentro la stessa griglia: e una rete a maglie larghe, ma copre la
classe di errore piu comune, la modifica strutturale, a costo quasi nullo, e
gira in `unit_tests` senza aggiungere dipendenze.

## Fase 2 - Rigenerazione verificata in CI (fatta)

`tools/build_levels.py` e l'unico entry point documentato: esegue tutti gli 11
baker dei livelli in ordine deterministico e dipinge i 19 sfondi. I baker
restano invocabili singolarmente (`python tools/build_church.py`).

`python tools/build_levels.py --check` rigenera in una directory temporanea -
un albero di symlink verso il repository, con `assets/levels` vuoto e
scrivibile, cosi il working tree non viene toccato - e confronta con
`assets/levels`. Esce diverso da zero al primo scostamento, nominando il PNG,
i tile che differiscono e il baker da rilanciare.

Il confronto e sui pixel decodificati, non sui byte del file: la codifica PNG
non e garantita stabile fra versioni di Pillow o di zlib, i pixel si. In
pratica succede: ridipingere `church.png` con Pillow 12.3.0 produce gli stessi
pixel e byte diversi da quelli committati.

`tools/requirements.txt` fissa Pillow alla versione esatta; la versione di
Python la fissa l'immagine del job. Il job `levels_check` di
`gitlab/verify.yml` gira su `python:3.11.15-slim`, `needs: []`, stage
`verify`, e parte con `allow_failure: true` per una settimana, cosi si misura
quanto e stabile prima di renderlo bloccante.

Sui rischi previsti: nessun baker e risultato non deterministico (i seed sono
fissi e `read_rows` gia ordina `os.listdir`; il controllo e verde anche
variando `PYTHONHASHSEED`), il giro completo dura pochi secondi (3,3 s in
locale) quindi non serve spezzarlo per posto, e nessun PNG committato era
divergente dal proprio baker: la Fase 2 nasce verde.

## Fase 3 - Rendering da tile atlas (iniziata)

E la fase che elimina il problema invece di sorvegliarlo. Il renderer
dipinge il posto a runtime dalle stesse `rows` che legge la simulazione,
usando un atlas di tile. Lo sfondo pre-cotto e il baker Python di quel posto
spariscono. Un posto nuovo diventa un file ASCII e basta.

### Come e fatto

- `tools/build_tile_atlas.py` dipinge `assets/tiles/atlas.png` e il suo
  manifest. Li e finita l'*arte* dei baker convertiti; la loro
  *composizione* e morta. Un baker sapeva due cose: come si dipinge una
  panchina, e dove sono le panchine. La seconda sta nelle righe ASCII ed e
  del gioco; solo la prima e nell'atlas, che infatti non legge mai un posto.
- Il manifest dichiara, per posto, regole ordinate: per questi glifi, su
  questo layer, prendi un tile da questo mucchio. Il mucchio lo scelgono
  poche chiavi booleane (la parita della cella, la riga, un vicino), il
  tile dentro al mucchio un hash della posizione: la resa e identica a ogni
  avvio e non c'e nessun seed da salvare.
- `TilePlaceComponent` (lib/game/render/) compone il posto **una volta** in
  un'immagine e poi disegna quella: un ciclo sui tile a ogni frame
  costerebbe mille draw sul dispositivo minimo senza comprare niente. Un
  posto che la storia puo aprire viene composto due volte, chiuso e aperto,
  e il cambio e solo una scelta di immagine.
- La scelta fra i due renderer sta nel `PlaceSpec`: un posto convertito non
  ha piu `background`. I due percorsi convivono, dietro `PlaceBackground`,
  finche l'ultimo posto non e convertito.

### I primi due posti

`duomoUpper` (interno ordinato, `lit`) e `stationFarSide` (esterno sporco,
con le interazioni di Luigi). Scelti insieme perche sono due regimi opposti,
e la misura lo conferma: nel duomo il muro e letteralmente la stessa cella
71 volte su 72, nella stazione **nessuna cella si ripete mai**.

Confronto con la versione cotta, pixel per pixel:

| Posto | Pixel diversi | Cosa differisce |
| --- | --- | --- |
| duomoUpper | 1,2% | la graniglia del pavimento, 3 px per cella |
| stationFarSide | 11,5% | massicciata (26 rettangoli casuali per cella), colature sul vagone, bolle sul muro |

La struttura combacia esattamente in entrambi: muri, orlo giallo della
banchina, binari, panchine, pali, sagoma e livrea del vagone. Quello che non
coincide e *dove cade il rumore casuale*, che non ha una posizione giusta.
`python tools/build_tile_atlas.py --preview DIR` ridisegna i posti
convertiti per l'occhio, senza dispositivo.

### Cosa si e imparato

- **Il timore non si e avverato.** Il piano temeva che un renderer a tile
  appiattisse l'aspetto. Con 12 varianti per tipo di tile il carattere
  regge anche sull'esterno sporco.
- **Il vagone non e fatto di tile, ed e giusto cosi.** Il baker lo dipinge
  come un oggetto unico steso su un rettangolo, con colature che
  attraversano la griglia. E diventato uno sprite, la "decorazione fuori
  griglia" che il piano prevedeva. La porta che si apre quando Luigi e
  salvo e un secondo sprite, non piu una seconda immagine dell'intero posto.
- **L'arte di un oggetto dipende dal layout.** Lo sprite del vagone e
  dipinto per una corsa di `M` di 27x3 tile, e
  `test/levels/tile_atlas_test.dart` fallisce se le righe smettono di
  essere d'accordo. E la stessa rete della
  Fase 1, applicata agli oggetti.
- **Il renderer taglia cio che il baker lasciava sbordare.** I painter
  scrivevano 1-2 px nella riga di vuoto sotto: 52 pixel in tutto, e tagliarli
  e piu corretto.
- **Peso.** I tre PNG cancellati pesavano 43 KB, l'atlas piu i tre oggetti
  piu il manifest ne pesano 27, e serviranno a tutti i posti convertiti
  dopo. Il baker `build_duomo_upper.py` (120 righe) non c'e piu;
  `build_station.py` resta perche dipinge ancora la stazione e il
  sottopasso, e si potra cancellare quando saranno convertiti anche quelli.

### Cosa manca

Gli altri 16 posti, un MR per posto (`feat/tile-rendering-<place>`), nel
resto dell'ordine suggerito: `barBackroom`, `church`, `barracks`, poi gli
altri. `street`, `harbour` e `northDistrict` per ultimi: sono i piu grandi e
i loro baker sono i piu elaborati. Ogni conversione cancella il baker
corrispondente e la sua riga in `BAKERS` di `tools/build_levels.py`; quando
un baker ne dipinge piu d'uno, si cancella con l'ultimo posto che serviva.

Criteri di accettazione, per ogni posto convertito: il posto non ha piu
`background` nel suo `PlaceSpec`; il suo PNG in `assets/levels/` e sparito;
confronto visivo a schermo con la versione precedente allegato all'MR; i
test esistenti del posto passano invariati, perche la simulazione non
cambia; nessuna regressione di frame rate sul dispositivo minimo di
`docs/target_devices.md`.

## Fuori ambito

- I generatori di sprite e di audio (`generate_*.py`, `build_audio.py`):
  stesso problema di ambiente non fissato, tema diverso.
- Il percorso hardcoded in `tools/process_story_images.py`: resta nel backlog
  generale.
- Le immagini di `assets/story/` usate come `cardImage`: sono illustrazioni,
  non layout, e non hanno una sorgente ASCII.
- Il formato di salvataggio: nessuna fase tocca `SaveGame`. Il rendering di un
  posto non e stato salvato.

## Riferimenti

- `docs/maintainability_and_scalability_backlog.md`, voce "P2 - Make asset
  generation reproducible": ne descrive il sintomo, la riproducibilita.
  Questo documento ne isola la causa, la doppia sorgente di verita.
- `docs/ci-pipeline.md` per la struttura dei job.
- `docs/art_direction.md` per le regole visive che la Fase 3 deve rispettare.
