# Test checklist

Two parts: what the **automated checks** already cover, and what a human has to
tap through on a real device before a release.

---

## 1. Automated

```bash
python3 tools/verify_project.py     # static: ARB parity, ad policy, routes, API surface, assets
python3 tools/verify_catalogue.py   # every official link resolves
flutter analyze
flutter test                        # test/unit/*
```

| Check | What it catches |
| --- | --- |
| `verify_project.py` §1-2 | A string missing from Sinhala or Tamil, a lost `{placeholder}`, an ARB key nothing uses |
| §3-4 | A catalogue item pointing at a subject that does not exist, a broken `markingSchemeId`, a bank whose `medium` disagrees with its question languages, an undeclared asset |
| §5 | An ad import or `AdBanner` outside the three allowed list screens |
| §6 | English copy hard-coded in a widget instead of `context.l10n` |
| §7-9 | A route nothing handles, a `Class.member` or `.method(` that does not exist (this is what a compiler would say, without a Flutter SDK) |
| `test/unit/ad_placement_test.dart` | The brief's hardest rule: zero ads in the reader, quiz and onboarding |
| `test/unit/content_assets_test.dart` | The bundled content is internally consistent (778 items, unique ids, 4 options per question, host allow-list) |
| `test/unit/i18n_test.dart` | Sinhala/Tamil are real translations, not English copies, and no message lost a placeholder |
| `test/unit/models_test.dart` | Filters, localisation fallback, number formatting, quiz shuffle determinism, streak + freeze rules |

---

## 2. Per-screen manual checklist

Run on the smallest phone you can find (5" / 720p) **and** with the system font
scale at 130%: that is where layout bugs appear. Do the pass once in English, then
repeat the bolded lines in Sinhala and Tamil.

### 1. Onboarding

- [ ] Three slides, swipeable, with the progress dots tracking the swipe.
- [ ] Language can be changed from the first slide and the whole slide re-renders
      immediately (no restart, no half-translated text).
- [ ] **Skip jumps straight to Home and does not ask again on the next launch.**
- [ ] The student-name field accepts Sinhala/Tamil input and the Home greeting
      uses it; leaving it empty still shows a greeting.
- [ ] Returning to Onboarding does not re-run it unprompted.

### 2. Home dashboard

- [ ] Greeting, the four quick cards (Textbooks, Past Papers, Quizzes, My Library)
      each open the right tab.
- [ ] "Continue where you left off" shows the last book *with its page number* and
      resumes there.
- [ ] The streak flame shows the current count; the freeze button is disabled
      after it has been used this week and explains why.
- [ ] Badges section shows progress (e.g. 3/7) and unlocks without a reload.
- [ ] Trending papers rail scrolls horizontally and opens the Papers tab filtered.
- [ ] Empty states show an illustration and a sentence, not a blank card.
- [ ] Pull to refresh keeps the cached catalogue when offline (and says so).

### 3. Textbooks (grades → subjects → medium → reader)

- [ ] Grade grid lists 1-13 with the right count of subjects per grade.
- [ ] Grade 12/13 shows only the A/L stream subjects.
- [ ] Medium step is only offered for mediums that actually have a book.
- [ ] Tapping a book *without* an offline copy shows the official-source sheet,
      and the URL that opens is the publisher's (https, correct host).
- [ ] Tapping the bundled sample book downloads it, then opens it.
- [ ] Back from the reader returns to the same subject list, not to Home.
- [ ] Second launch: the sample book opens instantly from disk (no download).

### 4. Past papers

- [ ] Tabs O/L, A/L, Grade 5 and Term tests each show a plausible list.
- [ ] The filter sheet narrows by subject, year and medium; the active filters show
      as removable chips and clearing them restores the list.
- [ ] Each row shows download count, file size, and a marking-scheme chip.
- [ ] **Tapping the marking-scheme chip opens the marking scheme (not the paper),
      and a paper without one explains that instead of doing nothing.**
- [ ] Every third download shows an interstitial — and no interstitial ever
      appears inside the reader (test this by downloading 3 in a row, opening the
      third immediately).

### 5. Quiz mode

- [ ] Subject + year selection lists only banks that exist.
- [ ] The timer counts down, turns warning-coloured near the end, and auto-submits
      at zero.
- [ ] **No ad appears anywhere between question 1 and the result screen.**
- [ ] Result screen: score, correct/wrong/skipped, time taken, new-record badge.
- [ ] Wrong-answer review shows the question, your answer, the correct answer and
      the explanation, in the current language.
- [ ] "Try again" starts a new attempt with the same bank; the previous attempt is
      still in the local leaderboard.
- [ ] Finishing a quiz increments the streak exactly once (check Home after).
- [ ] Killing the app mid-quiz does not corrupt the leaderboard.

### 6. Study planner

- [ ] Add a slot: subject + day + time, saved and listed.
- [ ] A reminder notification arrives at the scheduled time (allow the permission
      prompt once; on Android 13+ the prompt must appear).
- [ ] Deleting a slot removes its scheduled notification.
- [ ] Reminder text is in the app's current language.
- [ ] Timezone changes (Settings › Date & time) do not shift existing reminders.

### 7. My Library

- [ ] Tabs: Downloads / Favourites / History, each with the right illustration when
      empty.
- [ ] Storage bar matches the sum of the downloaded files; clearing the cache drops
      it to near zero and keeps favourites.
- [ ] Favourites toggle from both the Library and the list screens and stay in sync.
- [ ] Deleting a download from the Library removes the file (check with a file
      manager) and the row's "read offline" state updates.
- [ ] History keeps the last N entries and reopening one resumes the right page.

### 8. Settings

- [ ] Language switch re-renders the app immediately, including the bottom nav.
- [ ] Dark mode: check contrast on cards, chips, the ad banner placeholder and the
      reader's page background.
- [ ] Font size scales the reading text, not just the labels, and nothing clips at
      130%.
- [ ] Notification toggles: turning reminders off cancels scheduled notifications;
      turning announcements off stops topic subscription.
- [ ] Official sources: every publisher opens in the browser and shows its URL.
- [ ] Open-source licences shows the font licences and Flutter's own list.
- [ ] Clear cache vs Clear data: cache keeps favourites/settings, data resets
      everything and returns to Onboarding.
- [ ] The version string matches the installed build.

### Release-only checks (R8 makes release behave differently)

- [ ] Install the AAB (not the APK you built locally) and walk screens 3-5 once.
- [ ] PDF rendering still works (a shrunk native library is the classic
      R8 failure) — open the bundled sample *and* a second book.
- [ ] Notifications still fire after a device reboot (receivers are easy to strip).
- [ ] Ads: banners appear on the three list screens only; with real unit ids on a
      Play-track build, test ads turn into real ads.
- [ ] Crashlytics: force a crash on a test track and confirm the symbolicated
      stack trace appears (proves the mapping file uploaded).
- [ ] No white flash on cold start (launch theme), and the launcher icon is the
      adaptive one on Android 8+.

---

## 3. Devices to cover

| Device class | Why |
| --- | --- |
| Android 5.0 / 6.0, 1 GB RAM | minSdk 21 floor; PDF rendering is the memory spike |
| Android 8-9, 720p, 5" | the actual majority of school phones here |
| Android 13/14 mid-range | notification permission prompt, dynamic colour, predictive back |
| Tablet / large screen | the grade grid and paper rows should not stretch to two columns of text |
| Sinhala system locale | the launcher label and the notification channel names come from `values-si` |

---

## 4. Regression triggers

Re-run the relevant manual checklist when any of these change:

| Change | Re-check |
| --- | --- |
| `assets/data/*.json` regenerated | Papers filters, Textbooks grades, Quiz banks |
| `pubspec.yaml` dependencies bumped | Release-only checks (R8 keeps), app size |
| ARB files edited | Whole app in all three languages |
| `ad_service.dart` / any `AdBanner` call | Ad policy checks + quiz/reader |
| Reader or download code | Resume page, storage indicator, clear cache |
