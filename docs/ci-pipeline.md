# Pipeline CI/CD

Stepbound usa la stessa impostazione di base di Delivery: una sola pipeline per
commit/MR, cache limitata a `.pub-cache`, job interrompibili e configurazione
suddivisa per responsabilita in `gitlab/`.

Gli stage sono due: prima `build`, dove stanno tutti i job che producono un
pacchetto, poi `verify`, che blocca. I job di build sono manuali e non
bloccanti, quindi si possono lanciare appena parte la pipeline, senza aspettare
analisi e test; le verifiche hanno `needs: []` e partono subito lo stesso.
Un pacchetto costruito cosi non e ancora verificato: prima di distribuirlo
guarda che `verify` sia verde.

## Verifiche e build

- `analyze`: format e analisi statica bloccanti.
- `unit_tests`: JUnit, LCOV e `tools/check_coverage.dart`: soglie per area
  (piattaforma, salvataggi, core, UI, gioco) e totale da
  `tools/coverage_policy.json`, e nessuna libreria con codice lasciata fuori
  dal report perche nessun test la carica.
- `levels_check`: rigenera gli sfondi dei livelli con
  `python tools/build_levels.py --check` e li confronta, pixel per pixel,
  con quelli committati in `assets/levels`. Gira su `python:3.11.15-slim`
  con `tools/requirements.txt` (Pillow fissato), non sull'immagine Flutter,
  e sostituisce il `before_script` di default. Fallisce se si cambia un
  `rows` in `lib/core/levels/tutorial` senza rilanciare il baker: il
  messaggio nomina il PNG, i tile che differiscono e il baker da rilanciare.
  Nasce con `allow_failure: true` per una settimana, il tempo di misurarne
  la stabilita; poi si toglie e diventa bloccante. Il confronto e sui pixel
  decodificati e non sui byte del file perche la codifica PNG non e
  garantita stabile fra versioni di Pillow o di zlib.
  L'invariante piu grossolana, ogni sfondo grande esattamente quanto la sua
  griglia, e coperta anche da `unit_tests`
  (`test/levels/level_background_dimensions_test.dart`), che gira sempre e
  non ha bisogno di Python.
- `deps_check`: dipendenze obsolete, informativo.
- `build_android_debug`: APK debug installabile, manuale e non bloccante.
- `build_android_signed` / `build_ios_signed`: pacchetti release manuali solo su ref
  protette e su runner dedicati.

Il web non ha un job: non distribuiamo il gioco sul browser, lo usiamo solo
per provarlo in locale con `flutter build web` o `flutter run -d chrome`, e
`analyze` piu i test coprono gia gli errori di compilazione.

## GitHub Actions

Il repository e specchiato su GitHub, dove vivono le pull request, e
`.github/workflows/ci.yml` rifa li le stesse verifiche: `analyze` (con
`generate_balance.dart --check`, formato e analisi), `unit_tests` (test,
copertura e `check_coverage.dart`, con `lcov.info` come artefatto) e
`levels_check`, non bloccante come il suo gemello.

In piu c'e `android_debug`, che non ha un equivalente automatico su GitLab:
costruisce l'APK di debug e lo carica come artefatto scaricabile. Si prende da
Actions, aprendo la run, sotto Artifacts, come
`stepbound-debug-apk-<sha corto>`; GitHub lo serve come zip, dentro c'e
`app-debug.apk` da installare con `adb install app-debug.apk`. Resta
disponibile 14 giorni.

GitLab resta la pipeline canonica: i job firmati e i runner locali stanno solo
li, e `main` si protegge di la. Le differenze volute rispetto a GitLab sono
due: `android_debug` parte da solo a ogni push e pull request, mentre
`build_android_debug` su GitLab e manuale per non occupare i runner condivisi,
e su GitHub non ci sono i job di firma. Per il resto i job sono gemelli:
cambiandone uno va cambiato anche l'altro.

## Firma Android

Il runner puo continuare a fornire `android/key.properties`. In alternativa,
come in Delivery, impostare come variabili GitLab protette e mascherate:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

I file di firma creati dal job vengono rimossi sempre in `after_script`.

## Differenze intenzionali rispetto a Delivery

La pubblicazione automatica su Play e TestFlight non e inclusa: richiede app
gia create sugli store, service account, certificati, profili e identificativi
specifici di Stepbound. I job firmati producono comunque AAB e IPA pronti per
la distribuzione, senza riusare credenziali di Delivery.
