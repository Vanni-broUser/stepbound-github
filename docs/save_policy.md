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
4. Il commit di `main` da cui si fa la build prende un tag (`v<versione>`,
   la versione di `pubspec.yaml`): ogni build che arriva su un telefono
   fuori dal team deve poter essere ricondotta al suo commit.
5. Si pubblica la pagina privacy: il job manuale `privacy_policy_pages`
   sulla branch predefinita (`docs/ci-pipeline.md`).

Tutti e cinque i passi si fanno nel momento in cui la build esce, non
prima: finche' non c'e' una build pubblica non c'e' niente da congelare
ne' da taggare.

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
(`checkRestorable`) ricostruisce il mondo, i progressi e lo stato degli
script della storia, come fa il gioco all'avvio; non gioca. Prima di
pubblicare una build che migra, conviene comunque caricare a mano un
salvataggio vero della build precedente.

## Cosa una migrazione tiene

Il JSON di un salvataggio tiene il progresso tra i livelli (`progress`:
zombi conosciuti, memorie, vestiti, passi, falò accesi) in un oggetto suo,
separato dalla partita in corso (`world`, `story`, `hud`).
Quando un cambiamento di formato non può portare avanti la partita in
corso, la migrazione tiene `progress` e sostituisce il resto con l'inizio
del livello, com'è quando il livello ricomincia: il giocatore perde il
punto in cui era, non ciò che ha scoperto. Non serve tenere i due pezzi in
chiavi diverse dello storage per questo: una scrittura sola resta più
sicura di due.

## Il salvataggio sospeso

Oltre al salvataggio del falò, uno slot può tenere la partita **come era
quando è stata messa giù**: l'app che va in secondo piano, o il giocatore
che torna al menu principale, la scrivono sotto la chiave
`stepbound.save.<slot>.suspended` (`SaveRepository.suspend`). Non viene
scritta in mezzo a una battuta, a una scena o a una sosta al fuoco: da lì
gli script non saprebbero ripartire.

Il menu mostra e carica quella, segnata "(in sospeso)"; il falò a cui
tornare resta il salvataggio dello slot (`SaveRepository.load`). La
scrittura del falò successivo, il ritorno al falò e una nuova partita la
cancellano. Se la cancellazione non riesce (o l'app muore fra la scrittura
del falò e la cancellazione), il falò resta comunque scritto e non conta
come salvataggio fallito: `read` confronta le date (`savedAt`) e lascia da
parte una partita sospesa più vecchia del falò, così il menu non propone
mai uno stato precedente all'ultimo salvataggio.

L'app scrive la partita sospesa una volta per ogni uscita in secondo
piano. Una scrittura lenta durante la quale il giocatore è tornato in primo
piano non conta: se l'app è di nuovo in secondo piano quando finisce, la
partita viene riscritta com'è adesso (`PutDownWriter`).

È un `SaveGame` come gli altri, dello stesso formato: `SaveGame.decode` la
legge e la migra con le stesse regole, e una danneggiata lascia giocare il
falò. I salvataggi congelati della build pubblica non ne includono uno:
non ce n'è bisogno, il formato è quello.
