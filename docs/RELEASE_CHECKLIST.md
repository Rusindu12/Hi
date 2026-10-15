# Release checklist

Two paths: **(A)** ship without Firebase (works today, smallest risk, ~20 MB),
**(B)** ship with Firebase (live catalogue, push announcements, crash reports).
Everything below is ordered so that a failure is caught on your laptop rather than
by a 1-star review.

---

## 0. One-time setup

1. **Flutter SDK 3.24 or newer** (`flutter --version`). The floor exists because
   `AppShell` uses `PopScope.onPopInvokedWithResult`.
2. `flutter pub get`
3. `flutter gen-l10n` — writes `lib/l10n/generated/` (git-ignored; the build does
   this automatically thanks to `flutter: generate: true`).
4. **Keystore** (once per app, forever):
   ```bash
   keytool -genkeypair -v -keystore ~/sriedu-upload.jks \
     -keyalg RSA -keysize 4096 -validity 10000 -alias upload
   cp android/key.properties.example android/key.properties   # then fill it in
   ```
   Back the `.jks` file up somewhere you will still have in five years. Losing it
   means you can never update the app on Play again.

## 1. Pre-flight (run these before every release)

```bash
python3 tools/verify_project.py          # must exit 0
python3 tools/verify_catalogue.py        # must exit 0 before you claim "all links work"
flutter analyze                          # must be clean
flutter test                             # unit + content tests
dart format --set-exit-if-changed lib test
```

Then, by hand:

- [ ] `assets/data/catalogue.json` has no `unverified_seed` entries left, or every
      remaining one is hidden from the UI.
- [ ] `assets/legal/LICENSES.txt` lists every font, illustration and licensed
      document that ships.
- [ ] Bump `version:` in `pubspec.yaml` (`1.0.0+1` → `1.0.1+2`). Play rejects a
      build with a `versionCode` it has already seen.
- [ ] Update `docs/PLAY_LISTING.md` release notes.

## 2A. Build without Firebase (recommended first release)

No `google-services.json`, no Firebase console work. Ads stay off unless you
explicitly enable them.

```bash
flutter build appbundle --release \
  --dart-define=USE_FIREBASE=false \
  --dart-define=ADS_ENABLED=false \
  --obfuscate --split-debug-info=build/symbols
```

Two optional AdMob `--dart-define`s when you do enable ads (the defaults are
Google's official *test* units, which never earn revenue and never violate
policy):

```
ADMOB_BANNER_ANDROID=ca-app-pub-<you>/<unit>
ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-<you>/<unit>
```

Also replace `com.google.android.gms.ads.APPLICATION_ID` in
`android/app/src/main/AndroidManifest.xml` — it is currently Google's *test* app
id `ca-app-pub-3940256099942544~3347511713`, which is what you want while
developing and never in production.

## 2B. Build with Firebase

1. **Create the project** in the Firebase console (e.g. `sriedu`), then add an
   Android app with package name `lk.sriedu.app`.
2. **Download `google-services.json`** into `android/app/` (git-ignored — never
   commit it).
3. **Enable, in this order**:
   | Product | Why |
   | --- | --- |
   | Firestore (production mode, region `asia-south1`) | Catalogue + question banks |
   | Cloud Storage | Open-licensed PDFs (`pdfs/{itemId}.pdf`) |
   | Cloud Messaging | "New papers published" announcements |
   | Analytics | Which screens are used, where students drop off |
   | Crashlytics | Crash reports with line numbers (the R8 mapping is uploaded automatically by the Crashlytics Gradle plugin) |
4. **Apply the security rules** from `docs/FIRESTORE_SCHEMA.md` §3 — content is
   read-only for clients.
5. **Seed content**:
   ```bash
   python3 tools/seed_firestore.py --project sriedu --dry-run   # check counts
   gcloud auth application-default login
   python3 tools/seed_firestore.py --project sriedu --use-adc --allow-write
   ```
6. **Set a real catalogue version** (`config/catalogue.version`) and bump it on
   every content change; the app only re-downloads when it increases.
7. Build:
   ```bash
   flutter build appbundle --release \
     --dart-define=USE_FIREBASE=true \
     --dart-define=ADS_ENABLED=false \
     --obfuscate --split-debug-info=build/symbols
   ```
8. Keep `build/symbols/` — Crashlytics and `flutter symbolize` need it, and it is
   the only way to read an obfuscated stack trace.

## 3. Size gate (brief: under 30 MB)

```bash
flutter build appbundle --release --analyze-size --target-platform android-arm64
```

Then check the download size on the Play Console's *App bundle explorer* for the
arm64 device set (Play prints the real download size per device).

If the budget is exceeded, in this order:

1. `--split-per-abi` (Play already does this for an AAB, but it makes local APKs
   honest).
2. Drop the `density` splits in `android/app/build.gradle` if you added any
   density-specific raster assets (this project ships no raster assets beyond the
   launcher icons).
3. Check that no PDFs crept into `assets/`: `unzip -l <aab> | grep -i pdf` should
   list only `sample_textbook.pdf` (~5 KB).
4. Confirm the fonts are still variable (`NotoSansSinhala-Variable.ttf`), not four
   static instances each.

## 4. Smoked test on a real device

Release builds behave differently from debug: R8 strips code, ads are live, and
the signing key changes. Install the AAB locally and walk the list in
`docs/TEST_CHECKLIST.md` §"Release-only checks".

```bash
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=sriedu.apks --ks=~/sriedu-upload.jks --ks-key-alias=upload
bundletool install-apks --apks=sriedu.apks
```

## 5. Play Console submission

1. Create the app: name `SriEdu`, language `English (Sri Lanka)`, free.
2. Complete **App content**: privacy policy URL, ads declaration, content rating
   questionnaire, target audience, data safety (answers in
   `docs/PLAY_LISTING.md` §5).
3. Upload the listing text and assets from `docs/PLAY_LISTING.md`.
4. Upload the AAB to **Production → Create release**, add the release notes
   (English and Sinhala), and complete the roll-out.
5. First release of a new app triggers a manual policy review; expect a few hours
   to a couple of days. Respond to any query referencing
   `docs/CONTENT_POLICY.md` — the app's stance (link to official sources, never
   re-host) is exactly what reviewers want to see.
6. Use **staged roll-out** (10% → 50% → 100%) and watch Crashlytics between
   stages.

## 6. After release

- [ ] Crashlytics: zero new crashes in the first 24 h, or a hotfix.
- [ ] Analytics: `quiz_completed` and `paper_downloaded` events are arriving
      (they are the two signals that the app is actually being used).
- [ ] Re-run `python3 tools/verify_catalogue.py` monthly; government sites move
      pages without redirects.
- [ ] Keep the R8 mapping file for every shipped build — without it, crash reports
      from that version stay unreadable forever.

## 7. Things this repo deliberately does not do

* **No `flutter build` in CI without secrets.** The Firebase config and the
  keystore are ignored files; a CI job that "just builds" would produce an
  unsigned, Firebase-less artifact that looks fine and behaves differently.
* **No x86 ABI in the store build.** Emulator-only ABIs add megabytes for nobody.
* **No ProGuard/R8 exceptions beyond `android/app/proguard-rules.pro`.** Adding
  broad `-keep` rules hides real shrinker problems and inflates the APK.
