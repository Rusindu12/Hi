# SriEdu

A study companion for Sri Lankan students: textbooks, past papers, timed quizzes,
a study planner and a daily streak — in **Sinhala, Tamil and English**, offline
first, and small enough (< 30 MB) to fit on a budget phone.

SriEdu points at **official sources** (National Institute of Education, Department
of Examinations, Ministry of Education) instead of re-hosting copyrighted material.
See [docs/CONTENT_POLICY.md](docs/CONTENT_POLICY.md).

---

## Screens

| # | Screen | Route | Notes |
| --- | --- | --- | --- |
| 1 | Onboarding (3 slides, skippable, language picker) | `/onboarding` | Language is chosen *inside* slide one so a student who cannot read the default language is not stuck |
| 2 | Home dashboard | `/` (shell) | Greeting, four quick cards, continue-reading, streak + freeze, badges, trending papers |
| 3 | Textbooks | `/textbooks` | Grade 1-13 → subject → medium → PDF reader (last page remembered) |
| 4 | Past papers | `/papers` | Tabs O/L · A/L · Grade 5 · Term tests; filters by subject/year/medium; downloads, file size, marking-scheme link |
| 5 | Quiz | `/quiz` | Timed MCQs from Firestore or the bundled banks, wrong-answer review, try again, local leaderboard |
| 6 | Study planner | `/planner` | Subjects + time slots, daily reminder notifications |
| 7 | My Library | `/library` | Downloads, favourites, history, storage indicator, clear cache |
| 8 | Settings | `/settings` | Language, dark mode, font size, notification toggles, official sources, licences, clear data |

Bottom navigation: **Home · Books · Papers · Quiz · Library**. Settings opens from
the profile icon in the top-right.

## Tech stack

* **Flutter 3.24+**, Android `minSdk 21`, Material 3, provider + ChangeNotifier
* **pdfrx** for PDFs (bundles pdfium/HarfBuzz, so Sinhala and Tamil shape correctly)
* **Hive** for everything local: settings, favourites, reading progress, downloads,
  streaks, badges, quiz history, planner slots, cached catalogue
* **Firebase** (optional, off by default): Firestore, Storage, Messaging,
  Analytics, Crashlytics
* **AdMob**: banner on the three list screens, interstitial after every third
  download, **never** in the reader or the quiz

## Getting started

The app runs with **zero configuration**: no `google-services.json`, no Firebase
project, no network. Content comes from the bundled seed assets.

```bash
flutter pub get
flutter gen-l10n      # writes lib/l10n/generated/ (git-ignored)
flutter run
```

To run against live content instead:

```bash
flutter run --dart-define=USE_FIREBASE=true          # needs android/app/google-services.json
```

Build flags:

| Flag | Default | Meaning |
| --- | --- | --- |
| `USE_FIREBASE` | `false` | `false` = bundled JSON catalogue and question banks |
| `ADS_ENABLED` | `true` | `false` removes AdMob entirely (safest store review build) |
| `ADMOB_BANNER_ANDROID`, `ADMOB_INTERSTITIAL_ANDROID`, `ADMOB_BANNER_IOS`, `ADMOB_INTERSTITIAL_IOS` | Google test unit ids | Replace with real units before release |

## Repository layout

```
lib/
  core/          constants, theme, errors, utils, router
  data/          models, sources (local Hive / remote Firestore), repositories
  features/      one folder per screen: onboarding, home, textbooks, papers,
                 quiz, planner, library, settings, shell, pdf_reader
  services/      ads, analytics, crash reporting, downloads, notifications,
                 external links
  shared/        reusable widgets (cards, controls, empty states, illustrations)
assets/
  data/          seed catalogue, subjects, official sources, question banks
  fonts/         Noto Sans Sinhala + Tamil (SIL OFL, licence text included)
  illustrations/ original SVGs for empty states and the logo
  legal/         LICENSES.txt
tools/           content + asset generators and verification scripts
docs/            schema, policy, listing text, checklists
test/unit/       the automated suite
```

## Tools

| Command | Purpose |
| --- | --- |
| `python3 tools/verify_project.py` | Static verification: ARB parity and usage, content integrity, ad policy, i18n discipline, routes, and API-surface checks that behave like a compiler for the parts a compiler is not needed for |
| `python3 tools/verify_catalogue.py [--limit N --host nie.lk --json out.json --self-test]` | Checks every official link (stdlib only, polite rate limits) |
| `python3 tools/generate_seed_assets.py` | Regenerates `assets/data/*.json` deterministically (CRC-32 seeded, byte-stable) |
| `python3 tools/seed_firestore.py --project <id> [--dry-run]` | Publishes the bundled content to Firestore |
| `python3 tools/make_sample_pdf.py` | Regenerates the bundled 4-page sample PDF |
| `python3 tools/generate_store_assets.py` | Launcher icons + Play listing artwork |

## Documentation

* [docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md) — collections, fields, indexes, security rules, seeding
* [docs/CONTENT_POLICY.md](docs/CONTENT_POLICY.md) — what the app may host, what it only links to
* [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) — Firebase setup, signing, size gate, submission
* [docs/PLAY_LISTING.md](docs/PLAY_LISTING.md) — store text in Sinhala/English, screenshots, data-safety answers
* [docs/TEST_CHECKLIST.md](docs/TEST_CHECKLIST.md) — automated coverage and per-screen manual passes

## Honest status

* Every screen, widget and service in `lib/` is written and passes the static
  checks described above (`tools/verify_project.py` exits 0: no unresolved
  members, no missing ARB keys, no ad code in the off-limits screens, balanced
  sources, no TODOs).
* The project has **not** been compiled in the environment where it was authored
  (no Flutter SDK available there). Before the first store upload, run
  `flutter analyze`, `flutter test` and a release build on a machine with the SDK:
  the checklist in [docs/TEST_CHECKLIST.md](docs/TEST_CHECKLIST.md) is the path.
* Catalogue URLs are **unverified seed patterns** on the correct official domains.
  `tools/verify_catalogue.py` must pass before any content claim is made in the
  store listing.

## Licence and attribution

* App code: no licence file is included yet. Add one (for example
  `LICENSE` with the MIT or Apache-2.0 text) before making the repository public;
  until then it is "all rights reserved" by default, which is worth stating
  explicitly in the Play Console listing.
* Fonts: Noto Sans Sinhala and Noto Sans Tamil, SIL Open Font License 1.1
  (`assets/fonts/OFL-*.txt`).
* Illustrations and the sample PDF: original work created for this project.
* Textbook and past-paper content: © the respective government publishers, linked
  rather than redistributed.
