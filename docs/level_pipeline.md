# Pipeline dei livelli: cosa resta

Ogni posto del gioco e dipinto a runtime dalle sue righe ASCII, con l'atlas
di `assets/levels/tiles` generato da `tools/build_tile_atlas.py` (interni) e
`tools/tile_atlas_city.py` (citta). Restano da fare:

## Confronto a schermo con la versione precedente

Tempi di caricamento e frame rate dei posti dipinti a runtime sono stati
misurati su un telefono (`docs/device_measurements.md`), e citta, caserma,
porto e Duomo sono risultati disegnati come nelle anteprime
(`python tools/build_tile_atlas.py --preview DIR`). Resta il confronto
fianco a fianco con la versione precedente alla conversione, per primi i
quattro posti della citta, dove tetti e facciate sono cambiati.

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
