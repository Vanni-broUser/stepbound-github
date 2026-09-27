# Salvataggi: cosa si migra e cosa no

I salvataggi dei giocatori vanno tenuti; quelli dello sviluppo no. Per
questo una build legge due formati e nessun altro:

- **il suo**, `SaveGame.format` (`lib/save/save_game.dart`);
- **quello dell'ultima build pubblica**, `publishedSaveFormat`
  (`lib/save/published_save.dart`), portato al formato attuale da
  `migratePublishedSave`.

Un salvataggio di qualunque altro formato si legge come slot vuoto. I
formati intermedi, tra una build pubblica e la successiva, non li ha mai
installati nessuno: non hanno migrazioni tra loro.

```
pubblica A ──► 32 ──► 33 ──► 34 ──► pubblica B ──► 35 ──► ...
    │          ▲      ▲      ▲          │          ▲
    └──────────┴──────┴──────┘          └──────────┘
      ognuna migra da A, non dalla       da qui si migra da B
      precedente
```

La migrazione è sempre una sola: quando il formato cambia di nuovo la si
**riscrive** perché porti da A al formato nuovo, non se ne aggiunge
un'altra in coda.

## Prima della prima build pubblica

`publishedSaveFormat` è `null`: si lavora come sempre, si alza
`SaveGame.format` a ogni cambiamento e i vecchi salvataggi si perdono.

## Quando una build diventa pubblica

1. In `lib/save/published_save.dart`, `publishedSaveFormat` prende il
   valore di `SaveGame.format`, e `migratePublishedSave` torna a lanciare
   l'`UnsupportedError`: la migrazione di prima portava dalla build pubblica
   precedente, non serve più.
2. Si congelano i salvataggi di questa build, uno per scenario di prova
   (`lib/game/test_scenarios.dart`):

   ```bash
   flutter test tools/freeze_published_saves.dart
   ```

   Cancella e riscrive `test/saves/published/`.
3. Si committano insieme i due file e i salvataggi, nello stesso commit
   della build pubblicata.

## Dopo, a ogni cambiamento del formato

1. Si alza `SaveGame.format` come sempre.
2. `test/published_save_test.dart` fallisce: i salvataggi congelati non si
   caricano più ("cannot be migrated from format ...").
3. Si scrive, o si riscrive, `migratePublishedSave`: riceve il JSON della
   build pubblica e restituisce quello che il formato attuale si aspetta
   (il numero di formato lo mette `SaveGame.decode`).
4. Il test torna verde.

Se un cambiamento non tocca i salvataggi della build pubblica (per
esempio aggiunge un campo che quei salvataggi non possono avere), la
migrazione può restare com'è; il test lo conferma.

## Cosa il test non vede

I salvataggi congelati vengono dagli scenari di prova, non da un telefono:
coprono i punti della storia che gli scenari coprono. Il controllo
(`checkRestorable`) ricostruisce il mondo e i progressi, non lo stato degli
script della storia (vedi la voce P3 sui salvataggi nel backlog). Prima di
pubblicare una build che migra, conviene comunque caricare a mano un
salvataggio vero della build precedente.
