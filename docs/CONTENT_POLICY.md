# Content policy

SriEdu is used by school students in Sri Lanka, and the content it points at
belongs to government institutions and private publishers. This document records
what the app is and is not allowed to do with that content, so that a future
contributor (or a Play Store reviewer) does not have to guess.

**Summary: SriEdu links to official sources. It does not re-host textbooks or
past papers.**

---

## 1. What ships inside the APK

| Content | Rights | Why |
| --- | --- | --- |
| `assets/data/sample_textbook.pdf` | `bundled` | Original 4-page reading sample written for this project. It exists so the reader, the page cache and the offline path can be demonstrated without touching anyone's copyright. |
| `assets/data/{subjects,catalogue,official_sources}.json` | metadata only | Titles, subject codes, grades, years, file sizes and *links*. Metadata about a government publication is not the publication. |
| `assets/data/sample_questions.json` | original | 20 MCQs written for this project, trilingual. |
| `assets/illustrations/*.svg` | original | Drawn for this project; see `assets/legal/LICENSES.txt`. |
| `assets/fonts/NotoSansSinhala-Variable.ttf`, `NotoSansTamil-Variable.ttf` | SIL OFL 1.1 | Bundled with their licence text. |

Everything else is a URL.

## 2. What the app does with a link

1. A student taps a textbook or paper.
2. If the item is `official_link` and not cached locally, the app shows a sheet
   that names the publisher, then opens the publisher's own page in the user's
   browser (`ExternalLinkService.open`). The document is fetched by the browser,
   from the publisher, under the publisher's own terms.
3. If the item is `open_license` or `bundled`, the app may copy it into its
   private documents directory so it works offline. The cache is visible in
   My Library and can be cleared in one tap.

The app never scrapes, mirrors, re-compresses, re-uploads or proxies publisher
content, and never presents it inside a SriEdu-branded frame that hides the
origin. Settings › Official sources lists every publisher with its exact URL so
that this claim is checkable by anyone holding the phone.

## 3. Rights values

| `rights` | Meaning | Allowed in the bundled asset? |
| --- | --- | --- |
| `official_link` | Published by NIE / Department of Examinations / Ministry of Education. Open externally only. | Link and metadata only |
| `open_license` | Explicitly licensed for redistribution (e.g. CC BY, government open data). | Yes, with attribution recorded in `assets/legal/LICENSES.txt` |
| `bundled` | Written or commissioned for this project. | Yes |

Add a new value only by extending `ContentRights` in
`lib/core/constants/app_constants.dart` **and** the checker in
`tools/verify_project.py`, so an unknown value can never slip into the catalogue.

## 4. Link lifecycle

Every generated item starts as `"linkStatus": "unverified_seed"`.

```
unverified_seed ──verify_catalogue.py──▶ verified ──▶ shipped
        │
        └── unreachable / wrong path ──▶ fixed or deleted, never shipped
```

Rules:

* A `linkStatus: unverified_seed` catalogue **must not** be published to the Play
  Store listings' "what's new" or announced as complete content. The seed URLs are
  *patterns* (`https://nie.lk/textbooks/{medium}/{grade}/{subject}`) on real
  domains — they are placeholders for humans to replace.
* `python3 tools/verify_catalogue.py` is the gate. Anything it reports as
  `not_found`, `gone` or `html_instead_of_pdf` must be corrected in
  `tools/generate_seed_assets.py` (or in the Firestore console, which is the
  post-launch source of truth) before release.
* Deleted papers stay deleted. Do not "helpfully" keep a dead link, point it at a
  third-party mirror, or attach a PDF that was not published by the rights holder.

## 5. Third-party mirrors, blogs and "paper banks"

Not used, for three reasons:

1. Copyright — the Department of Examinations owns the papers; a blog that
   re-uploads them has no standing to license them to us.
2. Safety — mirrors appear and disappear, change their file names, and serve
   ad-wrapped redirects.
3. Trust — a student preparing for O/L should be reading the paper the
   Department actually published.

If a legitimate mirror exists (for example an official Ministry of Education
CDN), it belongs in `official_sources` with its host added to `hosts`, and the
catalogue validator will then accept links to it.

## 6. Advertising

Ads are banner-only on the list screens (Textbooks, Papers, Library) plus one
interstitial after every third download. They default to Google's *test* ad unit
ids, so a clone of this repository shows "Test Ad" banners, earns nothing, and
cannot trip AdMob's invalid-traffic rules by running against an unpublished app
id. Real unit ids arrive through `--dart-define=ADMOB_BANNER_ANDROID=...` and
friends, and `--dart-define=ADS_ENABLED=false` removes ads entirely. There are no ads in the PDF
reader, the quiz, or onboarding — enforced by code review *and* by
`test/unit/ad_placement_test.dart`, which fails the build if an ad type appears in
those folders.

Content rules for ads: Google-certified ad partners only (the AdMob defaults),
no ad placement that covers a download button, no interstitial before a download
completes, and no ads at all in the reading surface.

## 7. Student data

The app has no accounts, no sign-in, and no server-side profile. Streaks, quiz
results, favourites, planner slots and reading positions live in Hive on the
device; `android:allowBackup="false"` keeps them out of cloud backups. Nothing a
student does is uploaded. Firebase (when enabled) is used for content delivery,
crash reports and anonymous analytics only — see the Firebase section of the
README.

Because there is no personal data, the Play Console data-safety form is answered
"no data collected" except for the anonymous diagnostics/vendor-id entry required
by Crashlytics and the AdMob SDK (only when ads are enabled).

## 8. Takedown and corrections

If a rights holder believes an entry is wrong — a bad link, a mis-attributed
publisher, or metadata describing a document that should not be listed — the fix
is a one-line change in the catalogue JSON or one document in Firestore, and can
be shipped without an app update:

* In-app: Settings › Official sources shows where the link points.
* Repo: edit `assets/data/catalogue.json` (or the Firestore document), set the
  item's `rights`/`sourceUrl`, and bump `config/catalogue.version`.
* Contact: `support@sriedu.lk` (replace with the real address before publishing).

Never mirror first and argue later: removing a link is instant, un-shipping an
APK is not.

## 9. Release gate

Before any store release, all of these must be true:

- [ ] `python3 tools/verify_catalogue.py` exits 0 (or every failure is explained
      in the release notes as "known broken, hidden from the UI").
- [ ] `python3 tools/verify_project.py` exits 0.
- [ ] `grep -r "unverified_seed" assets/data/catalogue.json | wc -l` is either 0,
      or every remaining item is marked hidden/unavailable in the UI.
- [ ] `assets/legal/LICENSES.txt` mentions every font, illustration and licensed
      document the APK contains.
- [ ] No PDF published by a third party is inside the APK: `unzip -l app-release.aab | grep -i pdf`
      should show only `assets/data/sample_textbook.pdf`.
