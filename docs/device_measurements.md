# Misure sui telefoni

Le prestazioni di una build release misurate su telefoni veri. Le build
debug non dicono nulla: Dart gira JIT, gli assert sono accesi e l'APK e
parecchie volte piu grande. Le misure vengono dal pannello di diagnostica
(`lib/ui/diagnostics_overlay.dart`), acceso da `STEPBOUND_DIAGNOSTICS=1`
quando si lancia il job GitLab `build_android_release_apk`.

## Come si misura

Il pannello mostra una riga in alto durante la partita:

- **fps**, i fotogrammi dell'ultimo secondo;
- **frame max**, il piu lento dell'ultimo secondo: 16-17 ms e un
  fotogramma normale a 60 Hz, 33 ms uno saltato;
- **avvio**, dall'inizio del caricamento al primo fotogramma giocabile;
- **area**, quanto ha impiegato l'ultima area a comporsi. I posti di
  un'area si compongono uno per fotogramma, quindi e un totale spalmato,
  non un blocco.

Con il telefono collegato via USB (debug USB acceso) si legge la riga una
volta al secondo con `adb shell screencap`, quindici-venti letture per
posto, camminando: fermi i numeri escono migliori del vero. Per il
passaggio d'area si comincia a leggere appena prima di entrare.

Per ogni giro vanno scritti telefono, sistema, build e commit.

## Redmi 9, 2026-09-28

- **Telefono:** Xiaomi Redmi 9 (M2003J15SC), MediaTek Helio G80, 6 GB di
  RAM, Android 12, MIUI 13 (V13.0.3.0.SJOIDXM), schermo a 60 Hz. CPU e GPU
  sono quelle del livello minimo di `docs/target_devices.md`, la RAM no:
  il minimo ha 2 GB.
- **Build:** release firmata, pipeline 402, `STEPBOUND_DIAGNOSTICS=1` e
  `VANNI_DEPLOY=1`, versionCode 402: con ogni probabilita il merge
  `28e5d32`, il primo in cui `STEPBOUND_DIAGNOSTICS=1` accende il pannello.

| Posto | fps tipico / minimo | frame max tipico / peggiore | area |
| --- | --- | --- | --- |
| Citta | 60 / 59 | 16 / 34 ms | 968 ms (partenza) |
| Caserma (lampade) | 58 / 56 | 33 / 35 ms | stessa area della citta |
| Porto | 59 / 54 | 33 / 50 ms | 257 ms |
| Duomo (torce) | 58 / 55 | 33 / 43 ms | 493 ms |

- **Avvio della partita:** 874, 878 e 1114 ms in tre caricamenti.
- **Passaggio al porto:** il porto, le immagini piu grandi del gioco
  (2304×992 piu il livello davanti), si compone in 257 ms, dentro i
  170-300 ms della VM dei test. Il fotogramma peggiore all'ingresso e di
  33-41 ms e gli fps scendono a 54 per un secondo: nessuno scatto a occhio.
- **Luci:** negli interni i fotogrammi saltati crescono. In citta capitano
  in una lettura su tre, in caserma (nove lampade in vista) in due su tre,
  nel Duomo (sei torce che tremolano) quasi ogni secondo. Pesa la parte
  viva di `LightingComponent`, le luci che tremolano e le torce: a occhio
  si gioca bene, ma e il primo posto da guardare su un telefono piu lento.
- **Picchi da 50 ms** al porto, due, lontani dal passaggio d'area e
  durante uno scontro (colpi da 4 a 2, sangue a terra): non ancora
  cercati apposta.
- **Smoke test F0** (`docs/target_devices.md`): superato. Aperta dal
  verticale passa in orizzontale con barre di stato e navigazione nascoste,
  e resta cosi dopo due giri di background e ripresa. Al rientro MIUI
  mostra per un attimo l'anteprima ruotata prima di girare lo schermo.
  Chiusa dalle app recenti, la partita si ritrova nello slot come
  "(in sospeso)" e riprende dallo stesso punto.
- **A schermo:** citta, caserma, porto e Duomo disegnati come nelle
  anteprime.

## Cosa resta da misurare

- Un telefono da 2 GB, il vero minimo: le immagini dell'area del porto
  sono circa 28 MB, quelle della citta circa 29 MB, e la memoria qui non
  e mai stata al limite.
- Il telefono di fascia media di `docs/target_devices.md`.
- I picchi durante uno scontro: sparo, suono, colpo e morte nello stesso
  istante, leggendo la riga mentre si spara.
