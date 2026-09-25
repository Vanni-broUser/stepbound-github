# Pipeline dei livelli: cosa resta

Ogni posto del gioco e dipinto a runtime dalle sue righe ASCII, con l'atlas
di `assets/tiles` generato da `tools/build_tile_atlas.py` (interni) e
`tools/tile_atlas_city.py` (citta). Restano da fare:

## Verifica sul dispositivo minimo

Nessuna conversione e stata guardata su un telefono: i confronti sono stati
fatti pixel per pixel e a occhio sulle anteprime
(`python tools/build_tile_atlas.py --preview DIR`). Sul dispositivo minimo
di `docs/target_devices.md` vanno fatti:

- **il confronto a schermo** dei posti con la versione precedente, per
  primi i quattro della citta, dove tetti e facciate sono cambiati;
- **il tempo di caricamento**: un posto della citta si compone in 170-300 ms
  nella VM dei test, una volta all'avvio della partita. Va misurato in
  release;
- **il frame rate**, che non dovrebbe cambiare (a ogni frame resta
  un'immagine per posto, come prima) ma va confermato.

## Rendere bloccante `levels_check`

Il job di CI (`gitlab/verify.yml`, `.github/workflows/ci.yml`) e nato con
`allow_failure: true` / `continue-on-error: true` per misurarne la
stabilita. Se e rimasto verde, va tolto e il job diventa bloccante.

## Dividere i file troppo grandi

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
