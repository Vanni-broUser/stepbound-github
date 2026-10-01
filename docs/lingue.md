# Lingue

Il gioco parla italiano (l'originale) e inglese. Cambiano solo le parole:
insegne, nomi dei negozi e tutto quello che è dipinto sulle mappe restano in
italiano, perché il gioco è ambientato in Italia. La lingua si cambia dal
menù principale, col bottone tra AUDIO e CREDITI (mostra il codice della
lingua, `IT`/`EN`, e a ogni tocco passa alla successiva).

## Dove stanno le parole

- `lib/l10n/strings.dart`: l'interfaccia `Strings`, una riga per ogni testo
  che il gioco mostra (menù, HUD, missioni, dialoghi, lore degli zombi...).
- `lib/l10n/it.dart`: l'originale italiano.
- `lib/l10n/en.dart`: l'inglese.
- `lib/l10n/language.dart`: l'enum `Language` con le lingue disponibili,
  `Language.current` (quella in uso) e il getter globale `strings`.
- `lib/l10n/language_setting.dart`: la scelta del giocatore nelle
  preferenze (`stepbound.language`); senza scelta vale la lingua del
  telefono se il gioco la parla, altrimenti l'italiano.

Il codice non contiene testi: legge `strings.qualcosa` al momento in cui
li mostra, così un cambio di lingua vale da subito per tutto. Le scene
della storia sono getter che si ricostruiscono a ogni lettura.

I nomi dei luoghi (`Place.name`, i falò) restano nel core in italiano,
perché i salvataggi li conservano: si traducono solo quando si mostrano,
con `strings.place(nome)`, dalla mappa `placeNames` di ogni lingua. I nomi
propri (Piazza dei Cinquecento, Bar Arcobaleno) e quelli delle persone
restano come sono. Il rapporto d'errore e le breadcrumbs sono per lo
sviluppatore e restano in italiano.

## Aggiungere un testo

Una riga in `it.dart`, la stessa in `strings.dart` e in ogni altra lingua:
il compilatore segnala la lingua a cui manca.

## Aggiungere una lingua

1. Copia `lib/l10n/en.dart` in `lib/l10n/<codice>.dart`, rinomina la
   classe (`FrenchStrings implements Strings`) e traduci ogni riga, i
   `placeNames` compresi.
2. Aggiungi il valore all'enum `Language` in `lib/l10n/language.dart`, con
   il codice ISO 639-1 e il nome della lingua nella lingua stessa.
3. Aggiungi il file a `excluded` in `tools/coverage_policy.json`, come
   `en.dart`: sono dati, la completezza la controllano il compilatore e
   `test/l10n_test.dart` (tutti i luoghi, tutti gli zombi).
