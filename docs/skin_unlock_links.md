# Link regalo delle skin di Halloween

Un link regalo apre Stepbound e regala una skin (Fantasma, Vampiro,
Jack-o’-lantern, Zombi) ai quattro slot, vuoti o con una partita:

- in uno slot con una partita salvata, la skin è di quella partita;
- in uno slot vuoto, è della partita che ci si inizia;
- sovrascrivendo uno slot con una partita nuova, il regalo di quello slot si
  perde; negli altri slot resta.

Gli slot con almeno un regalo mostrano l’etichetta **REGALO** nelle pagine
«Nuova partita» e «Carica partita». La skin si indossa quando la trama
introduce il cambio d’abito (dopo il Duomo), o dal guardaroba sul treno.

Se il link arriva a partita in corso, la partita riceve subito la skin e
l’app torna al menù principale, dove un riquadro mostra «REGALO», il nome
della skin e Mario che la indossa.

## Scadenza

Ogni link vale **7 giorni** da quando viene generato. Un link scaduto, o
modificato, apre comunque l’app ma mostra «LINK SCADUTO O NON VALIDO» e non
regala niente. La scadenza si confronta con l’orologio del telefono.

## Generare un link

```shell
dart run tools/skin_link.dart vampiro
```

Stampa il link e la data in cui scade. Skin: `fantasma`, `vampiro`, `zucca`,
`zombi`. Per una durata diversa: `--giorni N`. Ogni esecuzione produce un link
diverso, anche per la stessa skin, e ognuno funziona per conto suo fino alla
sua scadenza.

Il link contiene skin, scadenza e un numero casuale, firmati con una chiave
che sta nell’app (`lib/save/skin_links.dart`). L’app non tiene un elenco dei
link: controlla la firma e la scadenza, senza rete. Per questo i link nuovi
funzionano con l’app già installata, senza aggiornarla; serve un aggiornamento
solo per aggiungere skin regalabili o cambiare la chiave (e cambiarla rende
non validi tutti i link già inviati). La chiave è dentro l’APK, quindi chi la
estrae potrebbe generarsi i link da solo; per delle skin è accettabile.

Molte app di messaggistica non rendono cliccabili i link `stepbound://`: in
quel caso vanno aperti da una pagina web o da un QR code.

## Prova su dispositivo

Android, con l’app installata:

```shell
adb shell am start -W -a android.intent.action.VIEW -d "<link>"
```

iOS Simulator, con l’app installata:

```shell
xcrun simctl openurl booted "<link>"
```
