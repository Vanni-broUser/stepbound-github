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
- `levels_check`: rigenera l'atlas da cui il gioco dipinge ogni posto con
  `python tools/build_levels.py --check` e lo confronta, pixel per pixel,
  con quello committato in `assets/levels`: `tiles/atlas.png`, il manifest e le
  immagini degli oggetti, e fallisce anche su un'immagine di oggetto che
  nessun painter produce piu. Gira su `python:3.11.15-slim` con
  `tools/requirements.txt` (Pillow fissato), non sull'immagine Flutter, e
  sostituisce il `before_script` di default. Fallisce se si cambia un
  painter in `tools/` senza rilanciare `python tools/build_tile_atlas.py`.
  Nasce con `allow_failure: true` per una settimana, il tempo di misurarne
  la stabilita; poi si toglie e diventa bloccante. Il confronto e sui pixel
  decodificati e non sui byte del file perche la codifica PNG non e
  garantita stabile fra versioni di Pillow o di zlib.
  Le righe ASCII di un posto non hanno piu una copia dipinta da tenere
  d'accordo: il gioco le dipinge. Cio che dipende ancora dalle righe -- un
  oggetto dipinto per una certa disposizione, come il vagone o un negozio
  -- lo controlla `unit_tests` (`test/levels/tile_atlas_test.dart`), che
  gira sempre e non ha bisogno di Python.
- `deps_check`: dipendenze obsolete, informativo.
- `build_android_debug`: APK debug installabile, manuale e non bloccante.
- `build_android_signed` / `build_ios_signed`: pacchetti release manuali solo su ref
  protette, su combusken (Android) e sul Mac (iOS).
- `build_android_release_apk`: la stessa release Android come APK firmato,
  da installare a mano sul telefono (prove prima dello store, o la demo
  distribuita direttamente). Stesse regole e stessa chiave di
  `build_android_signed`.

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
