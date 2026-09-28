#!/usr/bin/env python3
"""Carica un Android App Bundle su Google Play e lo assegna a una traccia.

Usato dal job CI `deploy_play` (gitlab/deploy-play.yml) a ogni commit su main,
ma eseguibile anche a mano per una release fuori pipeline.

Autenticazione: service account Google Cloud con accesso al Play Console
(chiave JSON). In CI arriva dalla variabile di tipo File
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, che GitLab espone come percorso su disco.

Vincolo Google da conoscere: per una app nuova il PRIMO bundle va caricato a
mano dal Play Console. Finche' non esiste almeno una release nel console le API
rispondono 403/404 sul packageName.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

try:
    import google_auth_httplib2
    import httplib2
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaFileUpload
except ImportError:  # pragma: no cover - dipendenze assenti in locale
    sys.exit(
        "Dipendenze mancanti. Installa con:\n"
        "  pip install -r tools/play/requirements.txt"
    )

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

# Play tronca le note di release a 500 caratteri per lingua e rifiuta il testo
# piu' lungo con un 400, quindi tagliamo prima noi.
MAX_RELEASE_NOTES = 500

# Il default di googleapiclient e' 60 s, troppo poco per i chunk di un bundle
# da decine di MB su un runner con banda modesta: l'upload moriva a meta' con
# un TimeoutError.
HTTP_TIMEOUT_SECONDS = 600

# Riprova i fallimenti transitori invece di far fallire il job: l'API di Play
# restituisce 503 sporadici, e il trasporto puo' cadere a meta' di un chunk.
UPLOAD_RETRIES = 5


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--aab",
        default="build/app/outputs/bundle/release/app-release.aab",
        help="Percorso dell'Android App Bundle da caricare.",
    )
    parser.add_argument(
        "--package-name",
        default=os.environ.get("PLAY_PACKAGE_NAME", "com.genericlab.stepbound"),
        help="applicationId dell'app su Play.",
    )
    parser.add_argument(
        "--track",
        default=os.environ.get("PLAY_TRACK", "alpha"),
        help=(
            "Traccia di destinazione. Il default e' `alpha` (test chiuso), la "
            "traccia scelta per la distribuzione ai corrieri."
        ),
    )
    parser.add_argument(
        "--status",
        default=os.environ.get("PLAY_RELEASE_STATUS", "completed"),
        choices=["completed", "draft", "inProgress", "halted"],
        help="Stato della release. 'draft' carica senza distribuire ai tester.",
    )
    parser.add_argument(
        "--release-name",
        default=os.environ.get("PLAY_RELEASE_NAME"),
        help="Nome della release mostrato nel Play Console.",
    )
    parser.add_argument(
        "--notes",
        default=os.environ.get("PLAY_RELEASE_NOTES", ""),
        help="Note di rilascio per i tester.",
    )
    parser.add_argument(
        "--notes-language",
        default=os.environ.get("PLAY_RELEASE_NOTES_LANGUAGE", "it-IT"),
        help="Codice lingua BCP-47 delle note di rilascio.",
    )
    parser.add_argument(
        "--credentials",
        default=os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"),
        help="Percorso del JSON del service account.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Valida input e credenziali senza caricare nulla su Play.",
    )
    return parser.parse_args()


def load_credentials(path):
    if not path:
        sys.exit(
            "ERRORE: credenziali non fornite. Imposta la variabile CI di tipo File "
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON oppure passa --credentials."
        )
    key_file = Path(path)
    if not key_file.is_file():
        sys.exit("ERRORE: file credenziali non trovato: {}".format(key_file))
    try:
        payload = json.loads(key_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        sys.exit("ERRORE: il file credenziali non e' JSON valido: {}".format(exc))
    if payload.get("type") != "service_account":
        sys.exit(
            "ERRORE: il JSON non e' una chiave di service account (type={!r}).".format(
                payload.get("type")
            )
        )
    print("Service account: {}".format(payload.get("client_email")))
    return service_account.Credentials.from_service_account_info(payload, scopes=SCOPES)


def truncate_notes(text: str) -> str:
    text = text.strip()
    if len(text) <= MAX_RELEASE_NOTES:
        return text
    print(
        "Note di rilascio troncate da {} a {} caratteri.".format(
            len(text), MAX_RELEASE_NOTES
        )
    )
    return text[: MAX_RELEASE_NOTES - 3].rstrip() + "..."


def build_transport() -> "httplib2.Http":
    http = httplib2.Http(timeout=HTTP_TIMEOUT_SECONDS)
    # Il protocollo di resumable upload di Google usa lo status 308 come
    # segnale proprietario "Resume Incomplete" (continua col prossimo chunk,
    # via header Range), non come vero redirect. httplib2 tratta pero' 308
    # come uno dei codici di redirect standard e, non trovando un header
    # Location (che qui non c'e', non essendo un redirect vero), solleva
    # RedirectMissingLocation - e' quello che ha rotto deploy_play dal 29/08.
    # Disattivare il follow automatico lascia che sia googleapiclient a
    # interpretare il 308 nel ciclo dei chunk, come da protocollo.
    http.follow_redirects = False
    if os.environ.get("PLAY_UPLOAD_DEBUG") == "1":
        _wrap_with_debug_logging(http)
    return http


def _wrap_with_debug_logging(http: "httplib2.Http") -> None:
    """Logga status e header (Authorization redatto) di ogni risposta >=300.

    Diagnostica di riserva, attiva solo con PLAY_UPLOAD_DEBUG=1: se il fix
    su follow_redirects non bastasse, questo mostra lo status esatto e gli
    header della risposta che fa fallire l'upload, senza dover indovinare
    di nuovo alla cieca.
    """
    original_request = http.request

    def debug_request(uri, method="GET", body=None, headers=None, **kwargs):
        resp, content = original_request(
            uri, method=method, body=body, headers=headers, **kwargs
        )
        status = getattr(resp, "status", None)
        if status and int(status) >= 300:
            safe_headers = {
                k: ("***" if k.lower() == "authorization" else v)
                for k, v in dict(resp).items()
            }
            print(
                "[debug] {} {} -> {} headers={}".format(
                    method, uri, status, safe_headers
                ),
                file=sys.stderr,
            )
        return resp, content

    http.request = debug_request


def describe_http_error(exc: HttpError) -> str:
    try:
        detail = json.loads(exc.content.decode("utf-8"))
        message = detail.get("error", {}).get("message", "")
    except Exception:  # noqa: BLE001 - il corpo dell'errore non e' garantito JSON
        message = exc.content.decode("utf-8", errors="replace")
    return "HTTP {}: {}".format(exc.resp.status, message)


def main() -> int:
    args = parse_args()

    aab = Path(args.aab)
    if not aab.is_file():
        sys.exit(
            "ERRORE: bundle non trovato: {}. Il job build_aab e' andato a buon fine?".format(aab)
        )
    size_mb = aab.stat().st_size / (1024 * 1024)
    notes = truncate_notes(args.notes)

    print("Bundle:  {} ({:.1f} MB)".format(aab, size_mb))
    print("Package: {}".format(args.package_name))
    print("Track:   {} (status={})".format(args.track, args.status))

    credentials = load_credentials(args.credentials)

    if args.dry_run:
        print("Dry run: nessuna chiamata di scrittura verso Google Play.")
        return 0

    service = build(
        "androidpublisher",
        "v3",
        http=google_auth_httplib2.AuthorizedHttp(
            credentials, http=build_transport()
        ),
        cache_discovery=False,
        static_discovery=True,
    )
    edits = service.edits()

    edit_id = None
    try:
        edit_id = edits.insert(
            body={}, packageName=args.package_name
        ).execute(num_retries=UPLOAD_RETRIES)["id"]
        print("Edit aperta: {}".format(edit_id))

        media = MediaFileUpload(
            str(aab),
            mimetype="application/octet-stream",
            resumable=True,
            chunksize=5 * 1024 * 1024,
        )
        bundle = (
            edits.bundles()
            .upload(
                packageName=args.package_name,
                editId=edit_id,
                media_body=media,
                media_mime_type="application/octet-stream",
            )
            .execute(num_retries=UPLOAD_RETRIES)
        )
        version_code = bundle["versionCode"]
        print("Bundle caricato: versionCode {}".format(version_code))

        release = {"versionCodes": [str(version_code)], "status": args.status}
        if args.release_name:
            release["name"] = args.release_name
        if notes:
            release["releaseNotes"] = [{"language": args.notes_language, "text": notes}]

        edits.tracks().update(
            packageName=args.package_name,
            editId=edit_id,
            track=args.track,
            body={"releases": [release]},
        ).execute(num_retries=UPLOAD_RETRIES)
        print("Release assegnata alla traccia '{}'.".format(args.track))

        edits.commit(packageName=args.package_name, editId=edit_id).execute(
            num_retries=UPLOAD_RETRIES
        )
        edit_id = None
        print("Edit committata: la release e' in distribuzione su Google Play.")
    except HttpError as exc:
        print("ERRORE Google Play API - {}".format(describe_http_error(exc)), file=sys.stderr)
        if "draft app" in exc.content.decode("utf-8", errors="replace"):
            print(
                "-> l'app non ha mai pubblicato una release, quindi Play accetta "
                "solo release in bozza: imposta PLAY_RELEASE_STATUS=draft, oppure "
                "pubblica la prima release dal Play Console.",
                file=sys.stderr,
            )
        return 1
    except Exception as exc:  # noqa: BLE001 - timeout e altri errori di trasporto
        print("ERRORE durante l'upload - {}: {}".format(type(exc).__name__, exc),
              file=sys.stderr)
        return 1
    finally:
        # Anche un timeout lascia una edit aperta su Play: va chiusa comunque,
        # altrimenti si accumulano edit orfane da cancellare a mano.
        if edit_id:
            try:
                edits.delete(
                    packageName=args.package_name, editId=edit_id
                ).execute(num_retries=UPLOAD_RETRIES)
                print("Edit {} annullata.".format(edit_id), file=sys.stderr)
            except Exception:  # noqa: BLE001
                print(
                    "Edit {} non annullata: va chiusa a mano.".format(edit_id),
                    file=sys.stderr,
                )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
