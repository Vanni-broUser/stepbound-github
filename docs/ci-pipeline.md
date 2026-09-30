# Pipeline CI/CD

Stepbound usa la stessa impostazione di base di Delivery: una sola pipeline per
commit/MR, cache limitata a `.pub-cache`, job interrompibili e configurazione
suddivisa per responsabilita in `gitlab/`.

Gli stage sono quattro: `build-android`, per la compilazione APK e App Bundle;
`build-ios`, per la diagnostica e l'IPA iOS; `verify`, che blocca con analisi e test;
e `deploy`, per la pubblicazione su Google Play (`deploy_play`), TestFlight
(`deploy_testflight`) e GitLab Pages (`privacy_policy_pages`).

## Verifiche e build

- `analyze`: format e analisi statica bloccanti.
- `unit_tests`: JUnit (con `junitreport` fissato alla 2.0.2), LCOV e
  `tools/check_coverage.dart`: soglie per area
  (piattaforma, salvataggi, core, UI, gioco) e totale da
  `tools/coverage_policy.json`, e nessuna libreria con codice lasciata fuori
  dal report perche nessun test la carica.
- `levels_check`: rigenera l'atlas da cui il gioco dipinge ogni posto con
  `python tools/build_levels.py --check` e lo confronta, pixel per pixel,
  con quello committato in `assets/levels`: `tiles/atlas.png`, il manifest e le
  immagini degli oggetti, e fallisce anche su un'immagine di oggetto che
  nessun painter produce piu. Gira su `python:3.11.15-slim` con
  `tools/requirements.txt` (Pillow fissato), non sull'immagine Flutter, e
  sostituisce il `before_script` di default. Fallisce se si cambia un
  painter in `tools/` senza rilanciare `python tools/build_tile_atlas.py`.
  Bloccante dal 2026-09-27, dopo una settimana verde. Il confronto e sui pixel
  decodificati e non sui byte del file perche la codifica PNG non e
  garantita stabile fra versioni di Pillow o di zlib.
- `sprites_check`: lo stesso per tutto il resto che i generatori in `tools/`
  dipingono: gli sprite di zombi e azioni, le tenute di Mario, gli oggetti,
  l'insegna del menu e le icone dell'app. `python tools/build_sprites.py
  --check` fa ripartire la catena dei generatori, nell'ordine in cui si
  leggono l'un l'altro, in una copia temporanea del repository e confronta
  pixel per pixel ogni immagine riscritta con quella committata. Le anteprime
  di `docs/previews` non contano: sono documentazione, disegnata col font che
  la macchina ha. I ritratti e le scene della storia non sono generati:
  sono disegnati a mano e committati come sono, per cui la catena non li
  tocca (`test/story_scenes_test.dart`, in `unit_tests`, controlla che
  ogni scena abbia la misura a cui le schermate la disegnano). Stessa
  immagine Python e stesso `tools/requirements.txt` di `levels_check`.
- `audio_check`: rifa la cottura dei suoni di `assets/audio` con
  `python tools/build_audio.py --check` e confronta ogni file con quello
  committato: byte per byte se l'ffmpeg del job e la build che li ha cotti
  (`FFMPEG_VERSION` nello script), altrimenti per inviluppo di loudness,
  50 ms per 50 ms entro un decibel, perche un altro encoder MP3 cambia i
  byte ma non il suono. Le sorgenti pubbliche (circa 90 MB) restano nella
  cache `audio-sources` fra un job e l'altro; se una sparisce dalla rete
  il job fallisce dicendo quale. Non bloccante (`allow_failure`) finche
  non ha fatto una settimana verde, come fu per `levels_check`.
  Le righe ASCII di un posto non hanno piu una copia dipinta da tenere
  d'accordo: il gioco le dipinge. Cio che dipende ancora dalle righe -- un
  oggetto dipinto per una certa disposizione, come il vagone o un negozio
  -- lo controlla `unit_tests` (`test/levels/tile_atlas_test.dart`), che
  gira sempre e non ha bisogno di Python.
- `deps_check`: dipendenze obsolete, informativo.
- `build_android_debug`: APK debug installabile, manuale e non bloccante.
- `build_android_signed`: AAB release firmato per Google Play su ref protette,
  gira su combusken.
- `build_android_release_apk`: la stessa release Android come APK firmato,
  da installare a mano sul telefono per prove dirette.
- `check_macos_runner`: diagnostica runner macOS per iOS.
- `build_ios_signed`: pacchetto IPA release firmato per iOS su ref protette,
  gira sul Mac.
- `deploy_play`: carica l'AAB su Google Play sulla traccia configurata in
  `PLAY_TRACK` (default `alpha` per test chiuso). Richiede
  `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
- `deploy_testflight`: carica l'IPA su TestFlight via `xcrun altool`. Richiede
  `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`.
- `privacy_policy_pages`: job manuale disponibile solo sulla branch predefinita.
  Pubblica `privacy/index.html` come pagina GitLab Pages; e' l'ultimo passo
  del rituale di pubblicazione (`docs/save_policy.md`, "Quando una build
  diventa pubblica"). La pagina porta gia' denominazione legale e contatto
  privacy dell'editore; il job si ferma se nella pagina ricompare un
  segnaposto `REPLACE_BEFORE_PUBLICATION`. L'URL effettivo si trova in
  **Deploy > Pages** dopo il completamento del job; verificare che sia
  accessibile senza login prima di inserirlo in Play Console.

Il web non ha un job: non distribuiamo il gioco sul browser, lo usiamo solo
per provarlo in locale con `flutter build web` o `flutter run -d chrome`, e
`analyze` piu i test coprono gia gli errori di compilazione.

## GitHub Actions

Il repository e specchiato su GitHub, dove vivono le pull request, e
`.github/workflows/ci.yml` rifa li le stesse verifiche: `analyze` (con
`generate_balance.dart --check`, formato e analisi), `unit_tests` (test,
copertura e `check_coverage.dart`, con `lcov.info` come artefatto),
`levels_check` e `sprites_check`, bloccanti come i loro gemelli, e
`audio_check` (con l'ffmpeg di Ubuntu e `actions/cache` per le sorgenti),
non bloccante come il suo.

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

I job Android firmati girano su combusken (tag `combusken-docker`), una
nostra macchina Linux, nell'immagine Flutter degli altri job: sulla
macchina servono solo il runner, con esecutore Docker, e Docker. La chiave
arriva dalle variabili GitLab protette e mascherate, come in Delivery:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

I file di firma creati dal job vengono rimossi sempre in `after_script`.

L'immagine Flutter non ha NDK, platform e CMake che la build Android
installa da sola, e ogni container ricomincerebbe da zero, dipendenze di
Gradle comprese. I due job li tengono nella cache locale di combusken
(chiave `android-release-<versione di Flutter>`): la home di Gradle in
`.gradle-home/` e i pacchetti dell'SDK in `.android-sdk-cache/`, che
`gitlab/android_sdk_cache.sh` collega nell'SDK dell'immagine prima della
build e ci rimette dopo. La cache si salva anche quando la build fallisce;
cambiando versione di Flutter ne parte una nuova. Per svuotarla: "Clear
runner caches" nella pagina Pipelines del progetto.

La chiave di release non si puo cambiare ne perdere: un APK firmato con
un'altra chiave non aggiorna quello installato, e Android lo rifiuta ("il
pacchetto e in conflitto con un pacchetto esistente"). Tenerne una copia di
sicurezza fuori da GitLab.

Senza `android/key.properties`, in locale `flutter build apk --release`
firma con la chiave di debug della macchina: serve a provare una release sul
telefono, ma quell'APK non aggiorna ne e aggiornato da quello firmato con la
chiave vera. Le build di debug hanno l'id `com.genericlab.stepbound.debug`
e il nome "Stepbound debug": si installano accanto alla release, senza
conflitti. Gli APK di debug della CI pero hanno ognuno una chiave diversa
(il container la genera ogni volta), e fra loro vanno ancora disinstallati.

## Differenze intenzionali rispetto a Delivery

La pubblicazione automatica su Play e TestFlight non e inclusa: richiede app
gia create sugli store, service account, certificati, profili e identificativi
specifici di Stepbound. I job firmati producono comunque AAB e IPA pronti per
la distribuzione, senza riusare credenziali di Delivery.
