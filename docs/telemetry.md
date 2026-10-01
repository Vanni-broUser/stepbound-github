# Telemetria: errori e dati di gioco anonimi

Il gioco manda da solo, senza che il giocatore debba condividere nulla:

- il **rapporto di ogni errore** che nessuno ha gestito (lo stesso testo
  che la schermata d'errore permette di condividere: build, telefono,
  errore con stack trace, slot, posto, salvataggio dello slot, ultimi
  passi), e di ogni **salvataggio non riuscito**;
- **eventi di gioco anonimi**, per capire quanti giocano e come.

Li riceve il server [`stepbound-be`](https://github.com/Vanni-broUser/stepbound-be-github)
(Flask, SQLAlchemy, Postgres), che li raggruppa e risponde alle domande
(`/v1/stats/*`, `/v1/errors`).

Il codice è in `lib/report/telemetry.dart` (la coda e l'invio),
`telemetry_outbox.dart` (i limiti della coda) e `telemetry_transport.dart`
(l'HTTP). Gli eventi partono da `AppFlowController` (partite e livelli) e da
`WorldEventPresenter` (posti, uccisioni, morti).

## Senza rete si gioca lo stesso

Il gioco non aspetta mai la rete. Tutto finisce prima in una coda sul
telefono (le `SharedPreferences`, accanto ai salvataggi) e parte quando il
server risponde:

- all'avvio dell'app;
- ogni volta che l'app torna in primo piano, e quando ne esce;
- subito dopo un errore;
- ogni 50 eventi in coda.

Si inviano a blocchi (200 eventi e un rapporto per richiesta). Se una
richiesta fallisce (niente rete, timeout, server giù, 429, 5xx) resta tutto
in coda e non si riprova per un minuto, poi due, fino a mezz'ora; tornare
in primo piano riprova subito. Un blocco che il server rifiuta per sempre
(400, 401, 413) viene scartato, per non riprovarlo all'infinito.

La coda ha dei limiti, controllati a ogni scrittura
(`TelemetryOutbox.prune`), così un telefono offline per mesi non si riempie:

| Limite | Valore |
| --- | --- |
| Età massima di un elemento | 30 giorni |
| Eventi | 2000, i più vecchi escono per primi |
| Rapporti | 3, i più vecchi escono per primi |
| Peso totale della coda | 800 KB: escono prima gli eventi, poi i rapporti |
| Un singolo rapporto | 150 KB: oltre si taglia il mezzo (il salvataggio), restano testa (errore e stack) e coda (ultimi passi) |

Ogni evento e rapporto ha un id generato sul telefono: se la risposta del
server si perde e il blocco parte due volte, il server lo salva una volta.

## Anonimato e interruttore

Il giocatore è identificato solo da un **id casuale** creato al primo avvio
(32 cifre esadecimali), che non deriva da nulla del telefono. Il server non
salva nemmeno quello: ne tiene un HMAC con un segreto suo. Non si inviano
nomi, email, indirizzi, posizione, contatti, identificatori pubblicitari o
del dispositivo; l'indirizzo IP serve solo al limite di richieste del server
e non viene salvato.

In **IMPOSTAZIONI** (dal menù principale e dal menù di pausa) c'è **"INVIO DATI ANONIMI: SÌ/NO"** (in inglese "SEND ANONYMOUS DATA"), acceso di default. Spento:

- la coda sul telefono si svuota e l'id viene dimenticato;
- il server riceve `/v1/forget` con l'id e cancella tutto quello che ha
  sotto quel giocatore (se non c'è rete, lo chiede a ogni avvio finché non
  risponde);
- riacceso, parte un id nuovo, senza legami con il vecchio.

L'interruttore c'è solo nelle build che hanno un server a cui inviare.

## Cosa viene inviato

Ogni blocco porta, oltre agli eventi, i dati della build e del telefono:
versione (`versionName (versionCode)`), commit, piattaforma, versione del
sistema, marca e modello.

| Evento | Quando | Dati |
| --- | --- | --- |
| `app_opened` | all'avvio | — |
| `session_ended` | l'app esce dal primo piano | `seconds` passati in primo piano |
| `game_started` | nuova partita, caricamento, ritorno al falò, livello ricominciato | `how` (`new`, `load`, `camp`, `restart`), `slot`, `level` (solo `restart`) |
| `level_started` | inizia un livello (Molfetta dopo la storia, una città dal treno) | `level` |
| `level_completed` | il livello finisce sul treno | `level`, `zombiesKilled`/`zombiesTotal`, `zombieKinds`, `backpacks`/`backpacksTotal`, `memories`/`memoriesTotal`, `campfires`/`campfiresTotal`, `steps`, `missions`, `secretMission`, `playSeconds` (ore della partita finora), `saved` |
| `place_entered` | Mario entra in un posto | `level`, `place` |
| `zombie_killed` | muore uno zombi | `level`, `place`, `kind` (`wanderer`, `brute`, …) |
| `player_died` | muore Mario | `level`, `place`, `killer` (il tipo dell'ultimo che l'ha colpito) |

Aggiungere un evento: `Telemetry.shared.track('nome_in_snake_case', {...})`
con soli nomi e numeri, poi aggiungerlo a questa tabella e, se serve una
statistica, a `stepbound_be/stats.py`.

## Configurazione della build

- `--dart-define=STEPBOUND_TELEMETRY_URL=https://…` l'indirizzo del server
  (solo HTTPS);
- `--dart-define=STEPBOUND_TELEMETRY_KEY=…` la chiave `INGEST_KEY` del
  server.

In CI arrivano dalle variabili GitLab omonime, solo nelle build release
(`docs/ci-pipeline.md`, "Telemetria"). Senza URL il gioco non raccoglie
nulla: le build locali, di debug e i test non mandano niente.

Il permesso `INTERNET` è nel manifest principale
(`android/app/src/main/AndroidManifest.xml`); iOS non ne chiede.

## Store: cosa aggiornare prima di pubblicare

Sì, le dichiarazioni sugli store vanno cambiate insieme a questa funzione.

**Google Play — sezione "Sicurezza dei dati" (Data safety)** in Play Console:

- *L'app raccoglie o condivide dati?* Sì, raccoglie; non condivide con terzi.
- *Dati crittografati in transito?* Sì (HTTPS).
- *Gli utenti possono chiedere la cancellazione?* Sì: l'interruttore nel
  IMPOSTAZIONI cancella i dati sul server; in più l'email della privacy.
- Tipi di dati da dichiarare, tutti "raccolti", "non condivisi", finalità
  **Analisi** (e **Funzionalità dell'app** per i crash), trattamento
  **facoltativo** (l'utente può disattivarlo):
  - *Informazioni e prestazioni dell'app → Log degli arresti anomali* e
    *Diagnostica* (i rapporti d'errore);
  - *Attività nell'app → Interazioni con l'app* (livelli, uccisioni,
    morti, posti) e *Altre azioni*;
  - *ID dispositivo o altri ID*: l'id casuale di installazione.
- Aggiornare l'URL dell'informativa privacy se cambia.

**App Store — "Privacy dell'app"** in App Store Connect:

- *Diagnostica → Dati sugli arresti anomali* e *Altri dati diagnostici*;
- *Dati di utilizzo → Interazione con il prodotto*;
- *Identificatori → ID dispositivo*: l'id casuale di installazione (per
  prudenza: non deriva dal dispositivo, ma lo identifica finché l'app resta
  installata);
- per tutti: finalità **Analisi** (e **Funzionalità dell'app** per i
  crash), **non collegati all'identità**, **non usati per il tracciamento**
  (quindi niente richiesta App Tracking Transparency).
- Consigliato: un `ios/Runner/PrivacyInfo.xcprivacy` con gli stessi tipi in
  `NSPrivacyCollectedDataTypes` e `NSPrivacyTracking` a `false`.

**Informativa privacy** (`privacy/index.html`): già aggiornata in questa
modifica; va ripubblicata con il job manuale `privacy_policy_pages`.

**Server**: va messo online (HTTPS) prima della build che lo usa, con il
comando `flask purge` pianificato ogni giorno per rispettare i tempi di
conservazione dichiarati (eventi 13 mesi, rapporti 6 mesi).
