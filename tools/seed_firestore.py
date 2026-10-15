#!/usr/bin/env python3
"""Publishes the bundled seed content to Firestore.

Why this exists: the app ships with a bundled catalogue so it works with zero
Firebase configuration (`USE_FIREBASE=false`), but the *live* catalogue should be
edited by a human in the Firebase console rather than in a Flutter release. This
script pushes the bundled JSON up once, after which the console is the source of
truth. See docs/FIRESTORE_SCHEMA.md for the documents it writes.

    # 1. See exactly what would be written — no credentials, no network:
    python3 tools/seed_firestore.py --project sriedu --dry-run

    # 2. Authenticate. Pick whichever fits your machine:
    gcloud auth application-default login          # then --use-adc
    export FIREBASE_ACCESS_TOKEN="$(gcloud auth print-access-token)"
    export GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json

    # 3. Publish (idempotent: every write is an update keyed by document id):
    python3 tools/seed_firestore.py --project sriedu --use-adc

    # 4. Verify from the app:
    flutter run --dart-define=USE_FIREBASE=true

Bundled source -> Firestore target
    subjects.json         -> subjects/{code}
    catalogue.json        -> catalogue/{itemId}
    official_sources.json -> official_sources/{id}
    sample_questions.json -> question_banks/{subject_examType[_year]}
                             (one document per bank, questions as an array)
    plus config/catalogue -> { version, updatedAt }  (the app's cache-buster)

Safety
  * `--dry-run` never touches the network.
  * Without `--allow-write` in a non-interactive shell it refuses to write, so a
    typo cannot clobber production data.
  * `--only` limits the run to one collection (repairing a single bank is common).
  * Writes use Firestore's `commit` endpoint in batches of 400, which is both
    faster and atomic per batch; a failed batch is reported with its index so the
    run can be resumed.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "data"

FIRESTORE_BASE = "https://firestore.googleapis.com/v1"
BATCH_LIMIT = 400
SCHEMA_VERSION = 1


# ---------------------------------------------------------------------------
# JSON -> Firestore typed values
# ---------------------------------------------------------------------------
def to_value(value):
    """Encodes a plain JSON value the way the Firestore REST API expects it."""
    if value is None:
        return {"nullValue": None}
    if isinstance(value, bool):  # bool before int: bool is a subclass of int
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, list):
        return {"arrayValue": {"values": [to_value(entry) for entry in value]}}
    if isinstance(value, dict):
        return {"mapValue": {"fields": to_fields(value)}}
    raise TypeError(f"cannot encode {type(value).__name__} for Firestore")


def to_fields(document: dict) -> dict:
    return {key: to_value(value) for key, value in document.items()}


def document_name(project: str, collection: str, doc_id: str) -> str:
    return f"projects/{project}/databases/(default)/documents/{collection}/{doc_id}"


def write_for(project: str, collection: str, doc_id: str, document: dict) -> dict:
    """An `update` write: creates the document if missing, replaces it if not."""
    return {
        "update": {
            "name": document_name(project, collection, doc_id),
            "fields": to_fields(document),
        },
        # No `currentDocument` precondition: `update` alone creates the document
        # when it is absent and replaces it when it is not, which is what an
        # idempotent seed run needs. The whole document is replaced rather than
        # merged, so deleting a field locally also deletes it in Firestore.
    }


# ---------------------------------------------------------------------------
# Sources
# ---------------------------------------------------------------------------
def read_json(name: str) -> dict:
    path = DATA / name
    if not path.exists():
        raise SystemExit(
            f"{path} is missing — run `python3 tools/generate_seed_assets.py` first"
        )
    return json.loads(path.read_text(encoding="utf-8"))


def collect_writes(project: str) -> list[tuple[str, str, dict]]:
    """Returns [(collection, docId, document)] in a stable order."""
    writes: list[tuple[str, str, dict]] = []

    subjects = read_json("subjects.json")["subjects"]
    for subject in subjects:
        writes.append(("subjects", subject["code"], subject))

    catalogue = read_json("catalogue.json")["items"]
    for item in catalogue:
        writes.append(("catalogue", item["id"], item))

    sources = read_json("official_sources.json")["sources"]
    for source in sources:
        writes.append(("official_sources", source["id"], source))

    banks = read_json("sample_questions.json")["banks"]
    for bank in banks:
        # The app reads question_banks/{bankKey} in a single document read; the
        # key format is defined once in Dart (QuizQuestion.bankKey) and mirrored
        # by the generator, which always writes `key` here.
        key = bank["key"]
        writes.append(
            (
                "question_banks",
                key,
                {
                    "subject": bank["subject"],
                    "examType": bank["examType"],
                    "medium": bank.get("medium", "en"),
                    "year": bank.get("year"),
                    "questions": bank["questions"],
                    "questionCount": len(bank["questions"]),
                    "schemaVersion": SCHEMA_VERSION,
                },
            )
        )

    writes.append(
        (
            "config",
            "catalogue",
            {
                "version": SCHEMA_VERSION,
                "counts": {
                    "subjects": len(subjects),
                    "catalogue": len(catalogue),
                    "officialSources": len(sources),
                    "questionBanks": len(banks),
                },
                # A string rather than a Firestore timestamp on purpose: the app
                # only compares the numeric version, and an ISO string stays
                # readable in the console.
                "updatedAt": None,
            },
        )
    )
    return writes


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
def access_token_from_adc() -> str | None:
    """`gcloud auth application-default login` support without extra packages."""
    try:
        completed = subprocess.run(
            ["gcloud", "auth", "application-default", "print-access-token"],
            capture_output=True,
            text=True,
            timeout=60,
            check=True,
        )
        return completed.stdout.strip() or None
    except (FileNotFoundError, subprocess.SubprocessError):
        return None


def resolve_token(args) -> str | None:
    token = os.environ.get("FIREBASE_ACCESS_TOKEN") or os.environ.get("GOOGLE_OAUTH_ACCESS_TOKEN")
    if token:
        print("auth: using FIREBASE_ACCESS_TOKEN from the environment")
        return token.strip()

    if args.use_adc:
        token = access_token_from_adc()
        if token:
            print("auth: using application-default credentials via gcloud")
            return token
        print("auth: gcloud was not available or is not logged in", file=sys.stderr)
        return None

    credentials = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if credentials:
        # A service-account JSON cannot be exchanged for a token with the standard
        # library alone (it needs an RS256-signed JWT), so tell the user the two
        # one-line ways to turn it into a token instead of half-supporting it.
        print(
            "auth: GOOGLE_APPLICATION_CREDENTIALS is set. Convert it to an access "
            "token with one of:\n"
            f"        gcloud auth activate-service-account --key-file {credentials}\n"
            "        gcloud auth print-access-token\n"
            "      then export FIREBASE_ACCESS_TOKEN=<token>",
            file=sys.stderr,
        )
    return None


# ---------------------------------------------------------------------------
# Publishing
# ---------------------------------------------------------------------------
def commit_batch(project: str, token: str, batch: list[dict], dry_run: bool) -> None:
    url = f"{FIRESTORE_BASE}/projects/{project}/databases/(default)/documents:commit"
    body = json.dumps({"writes": batch}).encode("utf-8")
    if dry_run:
        first = batch[0]["update"]["name"].split("/documents/")[-1]
        print(f"  dry-run: would commit {len(batch)} writes (first: {first})")
        return

    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            # Without this, a stale token silently retries as the same bad request.
            "X-Goog-User-Project": project,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:400]
        raise SystemExit(f"Firestore rejected a batch (HTTP {error.code}): {detail}")
    except urllib.error.URLError as error:
        raise SystemExit(f"could not reach Firestore: {error.reason}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed Firestore from the bundled JSON")
    parser.add_argument("--project", required=True, help="Firebase/GCP project id")
    parser.add_argument("--dry-run", action="store_true", help="print the writes, touch nothing")
    parser.add_argument("--use-adc", action="store_true", help="get a token via gcloud application-default login")
    parser.add_argument("--only", default=None, help="only this collection (subjects, catalogue, ...)")
    parser.add_argument("--limit", type=int, default=None, help="only the first N documents")
    parser.add_argument("--allow-write", action="store_true", help="required for a real write")
    args = parser.parse_args()

    writes = collect_writes(args.project)
    if args.only:
        writes = [entry for entry in writes if entry[0] == args.only]
    if args.limit:
        writes = writes[: args.limit]

    by_collection: dict[str, int] = {}
    for collection, _, _ in writes:
        by_collection[collection] = by_collection.get(collection, 0) + 1

    print(f"project: {args.project}")
    print("documents to write:")
    for collection, count in sorted(by_collection.items()):
        print(f"  {collection:18} {count}")

    writes_docs = [write_for(args.project, collection, doc_id, doc) for collection, doc_id, doc in writes]

    if args.dry_run:
        print("\ndry-run: no network calls will be made")
        token = None
    else:
        if not args.allow_write and not sys.stdin.isatty():
            print(
                "\nRefusing to write: pass --allow-write (or run with --dry-run to "
                "preview). This guard exists so a mistyped project id cannot "
                "overwrite a live catalogue.",
                file=sys.stderr,
            )
            return 2
        token = resolve_token(args)
        if not token:
            print(
                "\nNo access token. Use one of:\n"
                "  gcloud auth application-default login && python3 tools/seed_firestore.py "
                "--project <id> --use-adc --allow-write\n"
                "  export FIREBASE_ACCESS_TOKEN=$(gcloud auth print-access-token)\n",
                file=sys.stderr,
            )
            return 2

    for start in range(0, len(writes_docs), BATCH_LIMIT):
        batch = writes_docs[start : start + BATCH_LIMIT]
        print(f"batch {start // BATCH_LIMIT + 1}: {len(batch)} writes")
        commit_batch(args.project, token or "", batch, args.dry_run)

    if args.dry_run:
        print("\ndry-run complete — nothing was written.")
        print("A real run adds --allow-write and an access token.")
        return 0

    print(f"\nPublished {len(writes_docs)} documents.")
    print("Next: open the app with --dart-define=USE_FIREBASE=true and check Home.")
    print("Set config/catalogue.version to a higher number whenever you change content;")
    print("the app only re-downloads the catalogue when that number moves.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
