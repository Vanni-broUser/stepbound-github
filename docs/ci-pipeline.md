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
- `deps_check`: dipendenze obsolete, informativo.
- `build_android_debug`: APK debug installabile, manuale e non bloccante.
- `build_android_signed` / `build_ios_signed`: pacchetti release manuali solo su ref
  protette e su runner dedicati.

Il web non ha un job: non distribuiamo il gioco sul browser, lo usiamo solo
per provarlo in locale con `flutter build web` o `flutter run -d chrome`, e
`analyze` piu i test coprono gia gli errori di compilazione.

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
