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

**Oggi.** Nessun posto ha piu un PNG, quindi il controllo delle dimensioni
dei PNG non ha piu niente da misurare ed e stato tolto. Resta quello sulle
righe tutte della stessa lunghezza, in `test/levels/place_rows_test.dart`;
il tile dell'atlas lo tiene uguale a `levelTileSize`
`test/levels/tile_atlas_test.dart`.

## Fase 2 - Rigenerazione verificata in CI (fatta)

`tools/build_levels.py` era l'unico entry point documentato: eseguiva gli
11 baker dei livelli, che dipingevano 19 sfondi, in ordine deterministico.

**Oggi** non c'e piu nessun baker (vedi la Fase 3) e `build_levels.py` resta
solo come entry point che i job di CI chiamano: `--check` rigenera l'atlas in
una directory temporanea e confronta `atlas.png`, il manifest e ogni
immagine di `assets/tiles/objects`, sui pixel come prima, e fallisce anche
se in `objects` resta un'immagine che nessun painter produce piu. Quanto
segue descrive il gate come e nato.

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

## Fase 3 - Rendering da tile atlas (fatta)

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
- Durante la conversione i due renderer convivevano, scelti dal
  `PlaceSpec` (un posto convertito non aveva piu `background`). Con
  l'ultimo posto convertito il percorso cotto e stato tolto:
  `LevelBackgroundComponent`, `background` e `alternateBackground` non ci
  sono piu, e `assets/levels` nemmeno.

Tutti i diciotto posti sono dipinti dall'atlas. I quattro della citta sono
stati gli ultimi, e un problema diverso: la sezione "La citta" sotto dice
come.

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
  dopo. Il baker `build_duomo_upper.py` (120 righe) non c'e piu.
  `build_station.py`, `build_mall.py` e `build_airliner.py`, che a quel
  punto dipingevano ancora altri posti, sono oggi solo librerie di painter:
  non hanno piu un `main` ne un PNG da produrre.

- **Quasi tutto "sborda sulla cella sopra".** In vista 3/4 un monitor, uno
  scaffale, una pianta o la gamba di un cancello stanno nella riga sopra
  quella che li possiede. Una regola puo quindi portarsi dietro `up`: per
  ogni suo bucket, i tile che cadono sulla cella sopra, con la stessa
  variante, cosi le due meta restano un disegno solo (`leaning()` dipinge su
  una tela alta due celle e taglia). Le righe si disegnano in ordine di
  lettura, e cio che un pezzo piu in basso appoggia sulla riga sopra sta
  sopra a cio che quella riga aveva disegnato, come nel ciclo dall'alto in
  basso del baker.
- **Un oggetto che non e una corsa di un glifo dice dove sta.** Le vetrine di
  un centro commerciale hanno ognuna un nome e un aspetto che nessun glifo
  dice, e il muso della locomotiva segue una curva calcolata dalle righe.
  Un oggetto puo dire `at` e portarsi dietro `under`, le righe sopra cui e
  stato dipinto: il test fallisce appena non sono piu quelle del posto, e
  non c'e modo di lasciare un'immagine sopra a una disposizione per cui non
  e stata dipinta. Sono anche gli unici punti in cui il generatore legge le
  righe di un posto, e per questo motivo.
- **Le chiavi nate dal lavoro.** `rowHas` (la riga contiene il glifo: il
  corridoio di una cabina e ogni riga senza sedili), `beforeRun` (cosa c'e
  prima della corsa di questo glifo: il cuscino di un lettino sta dal lato
  del muro), `between` (qualcosa sopra e qualcosa sotto nella colonna: il
  vuoto fra due tetti, distinto dal buio fuori mappa). Piu `pattern` per i
  motivi che i baker scrivevano sulla posizione, che sono tantissimi:
  `(x * 5) % 12`, `(x * 7 + y * 5) % 6`, `x % 4`.
- **Un flusso casuale per posto.** Un solo generatore condiviso spostava
  tutti i posti dopo quello aggiunto, e ogni conversione riscriveva quelle
  gia fatte. Ora ogni posto e seminato dal proprio nome.
- **Un renderer scritto due volte va tenuto d'accordo.** Il disegno di
  riferimento del generatore (`--preview`) e il renderer Dart sono due
  scritture della stessa cosa. `TILE_RENDER_DUMP=DIR flutter test
  test/levels/tile_place_render_test.dart` scrive cio che il gioco disegna e
  `python tools/build_tile_atlas.py --compare DIR` lo confronta al byte con
  il riferimento: i 14 posti concordano.
- **Peso, in tutto l'MR.** I 15 PNG cancellati pesavano 199 KB. L'atlas (52 KB), i 20
  oggetti (22 KB) e il manifest (113 KB, testo che l'APK comprime) ne
  pesano 187, e l'atlas si decodifica una volta sola per tutto il gioco.

### Come si converte un posto

La ricetta, dopo averla fatta due volte. Un MR per posto,
`feat/tile-rendering-<place>`.

1. **Misura prima.** Quante celle del PNG cotto sono davvero distinte, e
   quante volte si ripete la piu ripetuta. Una cella che torna decine di
   volte vuol dire che il posto e gia arte a tile; nessuna ripetizione vuol
   dire o rumore per cella (va benissimo, bastano le varianti) o disegno
   che attraversa la griglia (serve un oggetto). Distinguere i due casi e
   tutto il lavoro di progetto: guarda quanti colori usa il glifo.
2. **Leggi il baker e separalo in due.** Da una parte i painter, che
   diventano tile; dall'altra il ciclo sui glifi, che diventa il renderer.
   I painter con dipendenze dal contesto (`room.at(x - 1, y)`) diventano
   chiavi `neighbour`; quelli con un pattern sulla posizione diventano
   `pattern`; quelli che guardano una riga notevole diventano `firstRow`,
   `rowHas`, `beforeRun` o `between`. Quelli che scrivono sopra la propria
   cella diventano `leaning()`; quelli che scrivono su un'area, oggetti.
3. **Aggiungi il posto a `PLACES` in `tools/build_tile_atlas.py`.** I
   painter che servono solo a quel posto si spostano dentro il generatore;
   quelli condivisi restano nel loro modulo (`build_station.py`,
   `build_mall.py`, `build_airliner.py`, che dopo l'ultima conversione sono
   solo librerie di painter).
4. **Verifica prima di scrivere una riga di Dart:**
   `python tools/build_tile_atlas.py --preview DIR` e confronta con il PNG
   cotto, per glifo: la struttura (muri, porte, arredi) deve venire a 0% e
   la differenza stare nel rumore casuale. Se non ci somigli qui, il
   renderer non ci somigliera.
5. **Togli `background` dal `PlaceSpec`**, cancella il PNG, la riga in
   `BAKERS` di `tools/build_levels.py`, e il baker se non dipinge altro.
6. **`python tools/build_levels.py --check`**, `dart format`,
   `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, e la
   verifica del renderer (`--compare`, sopra).
7. **Guarda il posto a schermo** e allega il confronto all'MR.

### Le trappole gia pagate

- **La parita del pavimento.** `paint_floor(d, rng, x, y)` prende
  coordinate in *tile* e ricava lui i pixel: generare la variante di
  parita 1 chiedendo `x = 1` dipinge fuori dal tile. Si dipinge su una
  tela larga due celle e si ritaglia quella giusta (`cell()`).
- **L'ordine dei bit delle chiavi.** Il bucket e `bit0 + 2*bit1`, e il bit
  e la chiave *come e scritta*, non come la pensa il painter: il muro
  della stazione ha `top = sopra non c'e muro`, la chiave e `sopra c'e
  muro`. Invertirlo costa il 9% dei pixel e non si vede finche non misuri.
- **I painter che dipingono un'area.** Se un painter prende un rettangolo
  invece di una cella, non e un tile: e un oggetto. Non provare a
  spezzarlo.
- **Il vicinato finto va costruito attorno alla cella giusta.** Un painter
  che chiede `room.at(x - 1, y)` riceve un `Neighbourhood`, e `cell` e dove
  e dipinto. Se il tile si dipinge in `(gx, 0)` perche la parita lo
  richiede, i vicini si chiedono attorno a `(gx, 0)`, non a `(0, 0)`.
- **Le varianti di un tile con overhang vanno in coppia.** `atlas.pairs`
  scarta una variante solo se ripete una coppia gia vista, dall'una e
  dall'altra parte: due liste deduplicate ciascuna per conto suo avrebbero
  lunghezze diverse e le due meta di un disegno si staccherebbero.
- **Gli oggetti e le regole hanno un ordine.** Gli oggetti si disegnano dopo
  `structures` e prima di `foreground`: cio che il baker dipingeva dopo un
  oggetto (i bordi scuri di lato, le panche) va in `foreground`.
- **`comment_references` e attivo** e `--fatal-infos` lo rende bloccante:
  un `[nome]` in un commento deve essere visibile da dove sta il commento.
- **L'immagine dell'atlas sta su `LoadedTileAtlas`**, non sul manifest, che
  ne tiene solo il percorso.

### Come e andata

Pixel diversi dal PNG cotto che ogni posto ha sostituito. Non sono errori: e
dove cade il rumore casuale, che non ha una posizione giusta. Per ogni posto
la struttura (muri, porte, scale, arredi) viene a 0%.

| Posto | Tile | Pixel diversi | Cosa differisce |
| --- | --- | --- | --- |
| `duomoUpper` | 38x22 | 1,2% | grana del pavimento |
| `trainInterior` | 77x12 | 1,5% | grana del pavimento, rifiuti, carte |
| `mallGround` | 48x28 | 1,8% | fuliggine sulle vetrine, sporco |
| `airlinerCabin` | 44x13 | 1,9% | grana della moquette, pannelli |
| `mallFirst` | 36x15 | 2,4% | fuliggine, sporco, merci sparse |
| `airlinerRoofs` | 30x20 | 3,4% | grana del catrame, macerie |
| `barracks` | 22x17 | 3,8% | grana, carte, monitor e fogli delle scrivanie |
| `barArcobaleno` | 22x14 | 3,9% | affresco che si scrosta, vetri |
| `stationUnderpass` | 30x8 | 5,8% | mattonelle saltate, sporco |
| `church` | 24x20 | 6,2% | affresco dell'abside, macerie |
| `stationFarSide` | 36x15 | 11,5% | massicciata, colature, bolle |
| `station` | 36x20 | 15,4% | massicciata, macerie, colature |

`duomo` e `barBackroom`, convertiti prima, hanno la loro misura nei commit.
Le percentuali piu alte sono i posti sporchi all'aperto, dove nessuna cella
si ripete mai.

Per la citta la percentuale non dice niente, e non e riportata: i palazzi
sono divisi altrove (sotto), quindi quasi ogni tetto e ogni facciata
cambia, e la differenza sta fra il 38% del porto e il 64% della strada.
Quello che si confronta a occhio e il carattere, e regge; quello che resta
identico al pixel sono gli edifici unici, dipinti dal painter originale.

### La citta

Il piano indicava i quattro posti della citta come il punto in cui la Fase 3
poteva ancora dire di no. La misura spiegava perche:

| Posto | Tile | Celle di edificio | Glifi distinti |
| --- | --- | --- | --- |
| `street` | 44x42 | 76% | 26 |
| `mallNorthStreet` | 74x43 | 59% | 37 |
| `northDistrict` | 90x60 | 79% | 36 |
| `harbour` | 144x62 | 26% | 44 |

e tre problemi, che sono stati risolti cosi.

- **Gli edifici non stavano nelle righe.** Il baker divideva ogni fascia di
  edificio in palazzi larghi 3-6 tile scelti a caso, e a caso colore, tetto
  e finestre di ognuno: dove finiva un palazzo era uno stato del baker.
  Ora e un pattern sulla posizione: un edificio comincia ogni 15 colonne
  alle colonne 0, 4 e 10 (quindi larghi 4, 6 e 5) e ogni 4 righe, e
  tetti e facciate si dividono negli stessi punti. Il colore di un
  edificio lo scelgono le stesse chiavi, costanti dentro l'edificio e
  diverse fra due vicini. Sono chiavi `pattern` lette a blocchi (`divX`,
  `divY`) o con piu resti accettati (`values`). Spostare una strada sposta
  i suoi edifici; i palazzi non sono piu gli stessi del baker, e non
  potevano esserlo. L'unico edificio senza divisioni, il retro
  dell'ipermercato, e una regione dichiarata con due chiavi.
- **Il pavimento aveva un contesto lungo.** `Level.surface` decide su cosa
  sta un oggetto scorrendo riga e colonna fino a un marciapiede, una strada
  o un selciato, e in caso di parita fa votare i vicini. Non e diventato una
  chiave: e stato portato in Dart tale e quale (`GroundConfig`), e le
  regole del layer `ground` guardano il pavimento risolto invece del
  glifo. Il disegno di riferimento chiama l'originale Python, quindi
  `--compare` tiene il port uguale all'originale su tutte le celle.
- **Cio che restava erano oggetti, e tanti.** Si sono divisi in due. Le
  cose piccole che si ripetono (auto, panchine, barche, alberi, palme,
  fontanelle) sono regole ancorate alla prima cella della loro corsa, con
  `pieces` per il resto del disegno: si spostano con le righe. Le cose
  uniche (caserma, ipermercato, ospedale, stazione, Duomo, San Nicola, la
  barca sullo scalo, la gru, l'aereo, i negozi con il nome) sono oggetti
  dipinti dal loro painter originale, al pixel, e piazzati con `at` e
  `under`: se le righe sotto cambiano il test fallisce e si rilancia il
  generatore. E il compromesso onesto: un edificio unico e un disegno, non
  un pattern.

Cosa e costato:

- **Peso.** I quattro PNG pesavano 582 KB. L'atlas intero, di tutti i
  diciotto posti, e 4532 tile e 142 KB; gli oggetti 41 immagini; il
  manifest 285 KB di testo, che l'APK comprime.
- **Tempo di caricamento.** Un posto della citta si compone in 170-300 ms
  nella VM dei test, contro la decodifica di un PNG. Si fa una volta,
  all'avvio della partita, non a ogni frame: a ogni frame resta
  un'immagine per posto, come prima, e la memoria e la stessa (le immagini
  composte hanno la misura dei PNG che sostituiscono). Il renderer manda i
  tile di un layer al canvas con una sola `drawRawAtlas`; con una
  `drawImageRect` per tile la suite di test passava da 1 a 2,4 minuti.
- **Da verificare sul dispositivo minimo**: il tempo di caricamento, che
  nei test non si misura.

### Criteri di accettazione, per ogni posto convertito

Il posto non ha piu un PNG (oggi non ne ha nessuno); confronto visivo a schermo con la versione
precedente allegato all'MR; i test esistenti del posto passano invariati,
perche la simulazione non cambia; nessuna regressione di frame rate sul
dispositivo minimo di `docs/target_devices.md`.

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
