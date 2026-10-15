# Firestore schema

SriEdu runs with **no Firebase configuration at all** by default: the catalogue,
subjects and question banks are bundled as JSON assets (`USE_FIREBASE=false`).
`--dart-define=USE_FIREBASE=true` switches the repositories over to Firestore and
Cloud Storage, and this document is the contract between the app and those
collections.

The Dart models are the source of truth for field names — `toJson`/`fromJson` are
identical for the bundled assets and for Firestore, which is why
`tools/seed_firestore.py` can push the local JSON straight up without a mapping
layer.

---

## 1. Collections

### `config/catalogue`

A single document the app reads *before* downloading anything, so a normal app
open costs one read instead of ~800.

| field | type | meaning |
| --- | --- | --- |
| `version` | int | Bump whenever content changes. The app compares it with the cached copy and only re-downloads the catalogue when it moves. |
| `counts` | map | `{subjects, catalogue, officialSources, questionBanks}` — for humans in the console. |
| `updatedAt` | string | ISO-8601 timestamp, written by hand or by CI. |

### `subjects/{subjectCode}`

| field | type | notes |
| --- | --- | --- |
| `code` | string | Document id, e.g. `mathematics`. Matches `SubjectCodes` in Dart and `catalogue.subject`. |
| `names` | map | `{en, si, ta}`. `LocalizedText` falls back to `en` when a translation is missing. |
| `grades` | array<int> | Grades this subject is taught in, e.g. `[10, 11]`. |
| `category` | string | `core`, `science`, `commerce`, `arts`, `aesthetic`, `primary` (used for grouping only). |

### `catalogue/{itemId}`

One document per textbook, paper, term test or marking scheme. 778 documents in
the seed set.

| field | type | required | notes |
| --- | --- | --- | --- |
| `id` | string | — | **Do not store.** The app writes the document id into `id` when it reads. |
| `kind` | string | ✔ | `textbook`, `paper`, `term_test`, `marking_scheme`, `syllabus`, `sample`. |
| `title` | map | ✔ | `{en, si, ta}`. |
| `subject` | string | ✔ | A `subjects` document id. |
| `medium` | string | ✔ | `en`, `si` or `ta`. |
| `rights` | string | ✔ | `official_link` (app never hosts the file), `open_license`, or `bundled` (ships inside the APK). |
| `sourceUrl` | string | ✔ for `official_link` | The publisher's own https URL. Verified against the hosts in `official_sources`. |
| `storagePath` | string | for `bundled`/`open_license` | `asset:assets/data/sample_textbook.pdf` for the one bundled sample; otherwise a Cloud Storage object path (`pdfs/<itemId>.pdf`). |
| `fileSizeBytes` | int | ✔ | Shown in the UI and used by the storage indicator. |
| `downloadCount` | int | — | Shown as "N downloads"; trending uses `trendingScore`. |
| `pageCount` | int | — | Lets the reader show "page 12 of 148" before the PDF parses. |
| `examType` | string | papers only | `ol`, `al`, `grade5`, `term`. |
| `year` | int | papers only | 1900-2100. Filter chips are built from the distinct values. |
| `term` | int | term tests only | 1-3. |
| `grade` | int | textbooks only | 1-13. |
| `publisher` | map | — | `{en, si, ta}` for the "published by" line. |
| `markingSchemeId` | string | — | Document id of the matching `marking_scheme` item. The Papers list and the reader sheet both use it. |
| `trendingScore` | int | — | Higher = more prominent on the Home trending rail. |
| `linkStatus` | string | ✔ in practice | `unverified_seed` while the URL is a guess, `verified` once a human checked it. Never ship `unverified_seed` to the store. |
| `updatedAt` | int | — | Epoch millis. |

### `official_sources/{id}`

Powers Settings › Official sources, the screen that makes the app's content policy
auditable.

| field | type | notes |
| --- | --- | --- |
| `id` | string | Document id: `nie`, `doenets`, `moe`. |
| `names` | map | `{en, si, ta}`. |
| `url` | string | Landing page, must be `https`. |
| `hosts` | array<string> | Hostnames this publisher serves from. Every `official_link` `sourceUrl` must live on one of them — `assets/data/catalogue.json` and the app's own checks rely on it. |
| `note` | map | `{en, si, ta}` one-line description of what the publisher provides. |
| `category` | string | Optional grouping (`education`, `government`). |

### `question_banks/{bankKey}`

The recommended quiz layout: **one document per bank**, one read per quiz start.
`bankKey` is `subject_examType[_year]` — the same string
`QuizQuestion.bankKey()` produces in Dart, e.g. `mathematics_ol_2019` or
`science_al`.

| field | type | notes |
| --- | --- | --- |
| `subject` | string | Subject code. |
| `examType` | string | `ol`, `al`, `grade5`, `term`. |
| `medium` | string | The language the bank is *for*. A `si`/`ta` bank must carry `si`/`ta` question text; English-only content must use `medium: "en"`. |
| `year` | int or null | `null` for a bank that spans years. |
| `questions` | array<map> | See below. Firestore's 1 MiB document limit holds roughly 1,000-1,500 MCQs, i.e. several years of one subject. |
| `questionCount` | int | Convenience for the console. Ignored by the app. |
| `schemaVersion` | int | Currently `1`. |

Each element of `questions`:

| field | type | notes |
| --- | --- | --- |
| `id` | string | Unique inside the bank; used for local answer history and the leaderboard. |
| `questionText` | map | `{en, si, ta}`. |
| `options` | array<map> | Exactly four maps of `{en, si, ta}`; the UI labels them A-D. |
| `correctAnswer` | int | 0-based index into `options`. Must be `0..3`. |
| `explanation` | map | `{en, si, ta}` — shown in the wrong-answer review. |
| `grade` | int | Optional. |
| `difficulty` | int | Optional, 1-5. |

### `questions` (fallback only)

A flat collection with one document per question, queried by
`subject` + `examType` + `year` + `medium`. The app only touches this when a bank
document is missing, because it needs a composite index and costs one read per
question. **If you create it, add this index:**

```
collection:  questions
fields:      subject  ASC
             examType ASC
             year     ASC
             medium   ASC
```

Put the fields in that order; Firestore rejects the query (and the app falls back
to the bundled bank) otherwise.

---

## 2. Cloud Storage layout

```
pdfs/{itemId}.pdf        open-licensed PDFs the app may cache offline
covers/{itemId}.jpg      optional; not used yet
```

Only `open_license` and `bundled` items may have a `storagePath`. Anything
published by the NIE or the Department of Examinations stays `official_link` and
is opened in the user's browser — that is a deliberate legal choice, see
[CONTENT_POLICY.md](CONTENT_POLICY.md).

---

## 3. Security rules

Content is public and read-only; nothing a student produces is ever uploaded
(there is no account, and quiz results/streaks live in Hive on the device).

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /subjects/{doc}       { allow read: if true; allow write: if false; }
    match /catalogue/{doc}      { allow read: if true; allow write: if false; }
    match /official_sources/{doc} { allow read: if true; allow write: if false; }
    match /question_banks/{doc} { allow read: if true; allow write: if false; }
    match /questions/{doc}      { allow read: if true; allow write: if false; }
    match /config/{doc}         { allow read: if true; allow write: if false; }
  }
}
```

Writes happen from the Firebase console or from
`tools/seed_firestore.py` with an admin token, never from the app. That also
means a compromised APK cannot deface the catalogue.

---

## 4. Seeding and updating

```bash
# Regenerate the bundled assets (deterministic; same input, same bytes)
python3 tools/generate_seed_assets.py

# Check every official URL before publishing it
python3 tools/verify_catalogue.py --self-test
python3 tools/verify_catalogue.py --host doeneets.lk --json report.json

# Preview the writes (no credentials, no network)
python3 tools/seed_firestore.py --project sriedu --dry-run

# Publish
gcloud auth application-default login
python3 tools/seed_firestore.py --project sriedu --use-adc --allow-write
```

After seeding, bump `config/catalogue.version`. The app caches the catalogue for
`AppConfig.catalogueCacheTtl` (12 hours) and only replaces it when the version
increases.

Cost expectation: one read for `config/catalogue` per cold start, ~800 reads the
first time a device syncs, one read per quiz start (bank document). No writes from
client devices at all.

---

## 5. Failure behaviour (already implemented)

| situation | what the app does |
| --- | --- |
| `USE_FIREBASE=false` | Reads the bundled JSON. Firebase packages are never initialised. |
| Firestore unreachable | Keeps the cached catalogue (Hive, key `CacheKeys.catalogueJson`) and shows the Home error strip. |
| `config/catalogue` missing | Treats the version as `0` and fetches the collection. |
| Bank document missing | Falls back to the `questions` query, then to the bundled bank, then shows "no questions for this subject yet". |
| Item without `sourceUrl` | Hides the open button instead of opening a broken link. |
