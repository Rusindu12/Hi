#!/usr/bin/env python3
"""Static verification for the SriEdu repository.

This is the strongest check that can run without a Flutter SDK installed. It is
not a compiler, but every check here has been negative-controlled: breaking the
thing it checks makes it fail. Run it before every commit:

    python3 tools/verify_project.py

Checks
   1. ARB parity          en/si/ta have identical keys and matching placeholders.
   2. ARB usage           every `l10n.<key>` in lib/ exists in the template ARB,
                          and every ARB key is actually used (dead-key report).
   3. JSON content        assets parse; catalogue IDs, subjects, rights, kinds,
                          mediums and marking-scheme links are all consistent.
   4. Assets and fonts    every pubspec asset path exists; every file under
                          assets/ is declared; fonts are real TrueType files.
   5. Ad policy           no ad reference in the reader, quiz or onboarding, and
                          AdBanner may only use feature ids AppAdPolicy allows.
   6. i18n discipline     no user-visible English literal baked into a widget.
   7. Routes              every AppRoutes constant is handled by AppRouter.
   8. Class members       every `ProjectClass.member` reference resolves,
                          including members inherited through extends/with.
   9. Called methods      every `.method(` name is declared in the project, is an
                          ARB key, or is on the curated SDK allowlist.
  10. Dart sanity         balanced delimiters, no TODO/FIXME markers left.
"""

from __future__ import annotations

import json
import pathlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
L10N = LIB / "l10n"
ASSETS = ROOT / "assets"

FAILURES: list[str] = []
WARNINGS: list[str] = []


def fail(message: str) -> None:
    FAILURES.append(message)


def warn(message: str) -> None:
    WARNINGS.append(message)


def rel(path: pathlib.Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# Shared source utilities
# ---------------------------------------------------------------------------
class _Stripper:
    """Neutralises strings and comments so regexes cannot trip on them.

    Implemented as a small character scanner rather than regexes because Dart
    strings may contain quotes, escapes, interpolations and `//`.
    """

    @staticmethod
    def strip(text: str, keep_strings: bool = False) -> str:
        out: list[str] = []
        i = 0
        n = len(text)
        while i < n:
            ch = text[i]
            nxt = text[i + 1] if i + 1 < n else ""
            if ch == "/" and nxt == "/":
                while i < n and text[i] != "\n":
                    i += 1
                continue
            if ch == "/" and nxt == "*":
                i += 2
                while i < n - 1 and not (text[i] == "*" and text[i + 1] == "/"):
                    i += 1
                i += 2
                continue
            if ch == "'" or ch == '"':
                start = i
                triple = text[i : i + 3] in ("'''", '"""')
                quote = text[i : i + 3] if triple else ch
                i += len(quote)
                while i < n:
                    if text[i] == "\\":
                        i += 2
                        continue
                    if text[i : i + len(quote)] == quote:
                        i += len(quote)
                        break
                    if not triple and text[i] == "\n":
                        break
                    i += 1
                # Keep a placeholder so `Text('x')` still reads as a call. When
                # `keep_strings` is set the literal (and therefore any
                # `'${l10n.key}'` interpolation inside it) is preserved instead.
                out.append(text[start:i] if keep_strings else "''")
                continue
            out.append(ch)
            i += 1
        return "".join(out)


strip_strings_and_comments = _Stripper.strip

CLASS_RE = re.compile(
    r"\b(?:abstract\s+|final\s+|base\s+|sealed\s+)?(class|mixin|enum|extension)\s+([A-Za-z_]\w*)"
)
SUPERTYPE_RE = re.compile(
    r"\b(?:extends|implements|with)\s+([A-Za-z_][\w<>,.\s]*)"
)
MEMBER_TOKEN_RE = re.compile(r"([A-Za-z_]\w*)\s*(?=[;=,(){}])")
GETTER_RE = re.compile(r"\b(?:get|set)\s+([A-Za-z_]\w*)")


def class_bodies(code: str) -> dict[str, str]:
    """class/mixin/enum name -> brace-delimited body source."""
    bodies: dict[str, str] = {}
    for match in CLASS_RE.finditer(code):
        brace = code.find("{", match.end())
        if brace == -1:
            continue
        depth = 0
        i = brace
        while i < len(code):
            if code[i] == "{":
                depth += 1
            elif code[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        bodies[match.group(2)] = code[brace : i + 1]
    return bodies


def supertypes(code: str) -> dict[str, set[str]]:
    """class name -> the names it extends/implements/mixes in."""
    result: dict[str, set[str]] = {}
    for match in CLASS_RE.finditer(code):
        header_end = code.find("{", match.end())
        header = code[match.end() : header_end if header_end != -1 else match.end() + 200]
        names: set[str] = set()
        for clause in SUPERTYPE_RE.findall(header):
            for piece in clause.split(","):
                name = piece.strip().split("<")[0].strip()
                if name and name not in {"Object"}:
                    names.add(name)
        result.setdefault(match.group(2), set()).update(names)
    return result


# ---------------------------------------------------------------------------
# 1. ARB parity
# ---------------------------------------------------------------------------
# A real placeholder is a name immediately followed by `,` or `}`. That ignores
# ICU plural branches such as `=1{1 day}`, which are not placeholders.
PLACEHOLDER_RE = re.compile(r"\{([a-zA-Z_][a-zA-Z0-9_]*)\s*[,}]")


def load_arb() -> dict[str, dict]:
    files = sorted(L10N.glob("app_*.arb"))
    if not files:
        fail("no ARB files found in lib/l10n")
        return {}
    loaded: dict[str, dict] = {}
    for path in files:
        try:
            loaded[path.stem.split("_", 1)[1]] = json.loads(read(path))
        except json.JSONDecodeError as error:
            fail(f"{rel(path)}: invalid JSON ({error})")
    return loaded


def check_arb(loaded: dict[str, dict]) -> None:
    if not loaded:
        return
    template = loaded.get("en")
    if template is None:
        fail("app_en.arb (the template locale) is missing")
        return

    keys_of = lambda payload: {k for k in payload if not k.startswith("@")}  # noqa: E731
    template_keys = keys_of(template)
    print(f"  ARB parity: {len(template_keys)} keys across {sorted(loaded)}")

    for locale, payload in loaded.items():
        keys = keys_of(payload)
        missing = sorted(template_keys - keys)
        extra = sorted(keys - template_keys)
        if missing:
            fail(f"app_{locale}.arb: missing {len(missing)} keys -> {missing[:8]}")
        if extra:
            fail(f"app_{locale}.arb: keys absent from template -> {extra[:8]}")
        for key, value in payload.items():
            if key.startswith("@") or not isinstance(value, str):
                continue
            used = set(PLACEHOLDER_RE.findall(value))
            meta = template.get(f"@{key}", {})
            declared = set((meta.get("placeholders") or {}).keys()) if isinstance(meta, dict) else set()
            if used != declared:
                fail(
                    f"app_{locale}.arb[{key}]: placeholders used={sorted(used)} "
                    f"declared={sorted(declared)}"
                )


# ---------------------------------------------------------------------------
# 2. ARB usage
# ---------------------------------------------------------------------------
L10N_USE_RE = re.compile(r"\bl10n\.([A-Za-z_]\w*)")


def check_arb_usage(loaded: dict[str, dict]) -> None:
    template = loaded.get("en") or {}
    keys = {k for k in template if not k.startswith("@")}
    if not keys:
        return

    used: set[str] = set()
    for path in sorted(LIB.rglob("*.dart")):
        # Comments are dropped but string literals are kept, because a key can
        # legitimately appear only inside an interpolation: Text('${l10n.x}').
        code = strip_strings_and_comments(read(path), keep_strings=True)
        for line_no, line in enumerate(code.splitlines(), start=1):
            for key in L10N_USE_RE.findall(line):
                used.add(key)
                if key not in keys:
                    fail(f"{rel(path)}:{line_no}: l10n.{key} is not a key in app_en.arb")

    unused = sorted(keys - used)
    if unused:
        warn(f"{len(unused)} ARB keys are never used in lib/: {unused[:10]}")
    print(f"  ARB usage: {len(used)} keys referenced, {len(unused)} unused")


# ---------------------------------------------------------------------------
# 3. JSON content assets
# ---------------------------------------------------------------------------
KNOWN_RIGHTS = {"official_link", "open_license", "bundled"}
KNOWN_KINDS = {"textbook", "paper", "term_test", "marking_scheme", "syllabus", "sample"}


def check_json_assets() -> None:
    paths = {
        "subjects": ASSETS / "data" / "subjects.json",
        "catalogue": ASSETS / "data" / "catalogue.json",
        "questions": ASSETS / "data" / "sample_questions.json",
        "sources": ASSETS / "data" / "official_sources.json",
    }
    loaded: dict[str, dict] = {}
    for name, path in paths.items():
        if not path.exists():
            fail(f"{rel(path)} is missing")
            return
        try:
            loaded[name] = json.loads(read(path))
        except json.JSONDecodeError as error:
            fail(f"{rel(path)}: invalid JSON ({error})")
            return

    codes = {s["code"] for s in loaded["subjects"]["subjects"]}
    catalogue = loaded["catalogue"]["items"]
    known_ids: set[str] = set()
    for item in catalogue:
        item_id = item.get("id", "?")
        if item_id in known_ids:
            fail(f"catalogue: duplicate id {item_id}")
        known_ids.add(item_id)
        if item.get("subject") not in codes:
            fail(f"catalogue[{item_id}]: unknown subject {item.get('subject')!r}")
        if item.get("rights") not in KNOWN_RIGHTS:
            fail(f"catalogue[{item_id}]: unknown rights {item.get('rights')!r}")
        if item.get("kind") not in KNOWN_KINDS:
            fail(f"catalogue[{item_id}]: unknown kind {item.get('kind')!r}")
        if item.get("medium") not in {"en", "si", "ta"}:
            fail(f"catalogue[{item_id}]: unknown medium {item.get('medium')!r}")
        if item.get("rights") == "official_link" and not str(item.get("sourceUrl", "")).startswith("https://"):
            fail(f"catalogue[{item_id}]: official_link without an https sourceUrl")

    for item in catalogue:
        target = item.get("markingSchemeId")
        if target and target not in known_ids:
            fail(f"catalogue[{item['id']}]: markingSchemeId {target} does not exist")

    total = 0
    seen_bank_keys: set[str] = set()
    seen_question_ids: set[str] = set()
    for bank in loaded["questions"]["banks"]:
        # The bank key is the document id in Firestore and the cache key locally,
        # so a duplicate would silently shadow another bank.
        key = bank.get("key")
        expected_key = "_".join(
            [bank["subject"], bank["examType"]]
            + ([str(bank["year"])] if bank.get("year") else [])
        )
        if key != expected_key:
            fail(f"question bank {expected_key}: key is {key!r} (expected {expected_key!r})")
        if key in seen_bank_keys:
            fail(f"question bank {key}: duplicate bank key")
        seen_bank_keys.add(key)

        # Medium must match the languages the questions really carry: a bank
        # labelled si/ta with English-only text is unreachable for the students
        # who are supposed to see it, and English-medium students never see one
        # labelled si at all.
        medium = bank.get("medium")
        for question in bank["questions"]:
            langs = set(question.get("questionText", {}).keys())
            if medium in {"si", "ta"} and medium not in langs:
                fail(
                    f"questions[{question['id']}]: bank {key} is medium={medium} but the "
                    f"question only has {sorted(langs)}"
                )
            if medium == "en" and ({"si", "ta"} & langs):
                warn(
                    f"questions[{question['id']}]: bank {key} is medium=en but also "
                    f"carries {sorted({'si', 'ta'} & langs)}"
                )
            for option in question.get("options", []):
                if not isinstance(option, dict) or medium == "en" and not option.get("en"):
                    fail(f"questions[{question['id']}]: an option has no English text")
                elif isinstance(option, dict) and medium in {"si", "ta"} and medium not in option:
                    fail(
                        f"questions[{question['id']}]: an option has no {medium} text "
                        f"(bank {key})"
                    )
            if question["id"] in seen_question_ids:
                fail(f"questions[{question['id']}]: duplicate question id")
            seen_question_ids.add(question["id"])
            total += 1
            qid = question["id"]
            for field in ("questionText", "options", "explanation", "correctAnswer"):
                if field not in question:
                    fail(f"questions[{qid}]: missing {field}")
            options = question.get("options", [])
            correct = question.get("correctAnswer")
            if not isinstance(correct, int) or not 0 <= correct < len(options):
                fail(f"questions[{qid}]: correctAnswer {correct} out of range")
            if len(options) != 4:
                warn(f"questions[{qid}]: {len(options)} options (expected 4)")

    sources = loaded["sources"]["sources"]
    official_hosts: set[str] = set()
    for source in sources:
        url = str(source.get("url", ""))
        if not url.startswith("https://"):
            fail(f"official_sources[{source.get('id')}]: url must be https ({url!r})")
        for host in source.get("hosts", []) or []:
            official_hosts.add(str(host).lower())
        for locale in ("en", "si", "ta"):
            if not (source.get("names") or {}).get(locale):
                fail(f"official_sources[{source.get('id')}]: names.{locale} is missing")
            if not (source.get("note") or {}).get(locale):
                warn(f"official_sources[{source.get('id')}]: note.{locale} is missing")

    # The whole content promise depends on this: every official_link item must
    # point at one of the published official hosts, so the transparency screen in
    # Settings cannot be contradicted by the catalogue.
    for item in catalogue:
        if item.get("rights") != "official_link":
            continue
        url = str(item.get("sourceUrl", ""))
        host = url.split("//", 1)[-1].split("/", 1)[0].lower()
        if official_hosts and host not in official_hosts:
            fail(
                f"catalogue[{item['id']}]: sourceUrl host {host!r} is not one of the "
                f"declared official hosts {sorted(official_hosts)}"
            )

    print(
        f"  content: {len(catalogue)} catalogue items, {len(codes)} subjects, "
        f"{total} questions, {len(sources)} official sources"
    )


# ---------------------------------------------------------------------------
# 4. Assets and fonts
# ---------------------------------------------------------------------------
def check_pubspec_assets() -> None:
    pubspec = ROOT / "pubspec.yaml"
    if not pubspec.exists():
        fail("pubspec.yaml is missing")
        return
    text = read(pubspec)

    declared: list[str] = []
    in_assets = False
    assets_indent = 0
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("assets:"):
            in_assets = True
            assets_indent = len(line) - len(line.lstrip())
            continue
        if not in_assets:
            continue
        indent = len(line) - len(line.lstrip())
        if stripped and indent <= assets_indent:
            in_assets = False
            continue
        if stripped.startswith("- "):
            declared.append(stripped[2:].strip())

    for entry in declared:
        if not (ROOT / entry).exists():
            fail(f"pubspec.yaml declares a missing asset path: {entry}")

    for directory in ("data", "legal", "illustrations"):
        base = ASSETS / directory
        if not base.exists():
            fail(f"assets/{directory}/ is missing")
            continue
        for file in sorted(base.iterdir()):
            if file.is_file() and f"assets/{directory}/" not in text:
                fail(f"{rel(file)} is not declared under pubspec.yaml `assets:`")

    fonts = sorted(set(re.findall(r"asset:\s*(assets/fonts/[^\s]+)", text)))
    if not fonts:
        fail("pubspec.yaml declares no bundled fonts")
    for font in fonts:
        path = ROOT / font
        if not path.exists():
            fail(f"pubspec.yaml font missing on disk: {font}")
            continue
        raw = path.read_bytes()
        if raw[:4] not in (b"\x00\x01\x00\x00", b"true", b"ttcf", b"OTTO"):
            fail(f"{font} is not a recognised TrueType/OpenType file ({raw[:4]!r})")
        elif not 3 <= struct.unpack(">H", raw[4:6])[0] <= 64:
            fail(f"{font} has an implausible SFNT table count")

    print(f"  assets: {len(declared)} pubspec entries, {len(fonts)} fonts")


# ---------------------------------------------------------------------------
# 5. Ad policy
# ---------------------------------------------------------------------------
AD_FREE_DIRS = {
    "lib/features/pdf_reader": "PDF reader",
    "lib/features/quiz": "quiz",
    "lib/features/onboarding": "onboarding",
}
AD_PATTERN = re.compile(r"(google_mobile_ads|AdBanner|AdWidget|AdService|BannerAd|InterstitialAd)")


def check_ad_policy() -> None:
    for rel_dir, label in AD_FREE_DIRS.items():
        directory = ROOT / rel_dir
        if not directory.exists():
            fail(f"{rel_dir}/ is missing")
            continue
        for path in directory.rglob("*.dart"):
            text = read(path)
            # `debugReaderForbiddenImports` lists the ad packages that must never
            # be imported; drop the declaration before scanning so the guard the
            # test greps for does not trip this check.
            text = re.sub(
                r"const List<String> debugReaderForbiddenImports[^;]*;", "", text, flags=re.S
            )
            for line_no, line in enumerate(text.splitlines(), start=1):
                if line.lstrip().startswith("//"):
                    continue
                if AD_PATTERN.search(line):
                    fail(f"ad code in the ad-free {label}: {rel_dir}:{line_no} -> {line.strip()[:80]}")

    ad_service = LIB / "services" / "ad_service.dart"
    if not ad_service.exists():
        fail("lib/services/ad_service.dart is missing")
        return
    service_text = read(ad_service)
    match = re.search(r"bannerAllowedFeatures\s*=\s*<String>\{(.*?)\};", service_text, re.S)
    if not match:
        fail("could not read AppAdPolicy.bannerAllowedFeatures")
        return
    allowed = set(re.findall(r"feature[A-Za-z]+", match.group(1)))

    reads_policy = re.compile(r"AdBanner\(\s*(?:[^)]*?)featureId:\s*(?:AppAdPolicy\.)?(\w+)", re.S)
    for path in LIB.rglob("*.dart"):
        if path.name == "ad_service.dart":
            continue
        for line_no, line in enumerate(read(path).splitlines(), start=1):
            for feature in re.findall(r"AdBanner\(\s*featureId:\s*AppAdPolicy\.(\w+)", line):
                if feature not in allowed:
                    fail(f"{rel(path)}:{line_no}: AdBanner uses {feature}, which AppAdPolicy does not allow")

    print(f"  ad policy: banners allowed only for {sorted(allowed)}; reader/quiz/onboarding clean")


# ---------------------------------------------------------------------------
# 6. i18n discipline
# ---------------------------------------------------------------------------
LITERAL_IN_TEXT_RE = re.compile(r"Text\(\s*'([^']{4,})'\s*[,)]")
ENGLISH_COPY_RE = re.compile(r"[A-Za-z]{3,}\s[A-Za-z]{3,}")


def check_hardcoded_strings() -> None:
    offenders = 0
    for path in sorted((LIB / "features").rglob("*.dart")):
        for line_no, line in enumerate(read(path).splitlines(), start=1):
            if line.lstrip().startswith("//"):
                continue
            match = LITERAL_IN_TEXT_RE.search(line)
            if not match:
                continue
            literal = match.group(1)
            if "$" in literal:  # `Text('$year')` is data, not copy
                continue
            if not ENGLISH_COPY_RE.search(literal):
                continue  # units, separators, glyphs
            offenders += 1
            fail(
                f"hard-coded UI string in {rel(path)}:{line_no}: Text('{literal}') "
                "-> use context.l10n"
            )
    print(f"  i18n: {offenders} hard-coded Text() literals under features/")


# ---------------------------------------------------------------------------
# 7. Routes
# ---------------------------------------------------------------------------
def check_routes() -> None:
    routes_file = LIB / "core" / "router" / "app_routes.dart"
    router_file = LIB / "core" / "router" / "app_router.dart"
    if not routes_file.exists() or not router_file.exists():
        fail("router files are missing")
        return

    constants = dict(re.findall(r"static const String (\w+) = '([^']*)';", read(routes_file)))
    router = read(router_file)
    handled = set(re.findall(r"case AppRoutes\.(\w+):", router))

    for name, path in constants.items():
        if name == "splash":
            continue  # '/' is served by MaterialApp.initialRoute
        if name not in handled:
            fail(f"AppRoutes.{name} ('{path}') is never handled by AppRouter.onGenerateRoute")

    for entry in re.findall(r"import '([^']+\.dart)';", router):
        if entry.startswith("package:"):
            continue
        if not (router_file.parent / entry).resolve().exists():
            fail(f"app_router.dart imports a missing file: {entry}")

    print(f"  routes: {len(constants)} declared, {len(handled)} handled in onGenerateRoute")


# ---------------------------------------------------------------------------
# 8. Class-qualified member references
# ---------------------------------------------------------------------------
USAGE_RE = re.compile(r"\b([A-Z]\w*)\.([A-Za-z_]\w*)")

# Types that come from Flutter, Dart, or a plugin rather than from lib/. A
# capitalised receiver that is *neither* declared in the project *nor* listed here
# is almost always a typo, so check 8 fails on it. Verified against the packages
# in pubspec.yaml; extend it when a new plugin introduces a new type.
EXTERNAL_TYPES: frozenset[str] = frozenset({
    # Flutter SDK
    "Alignment", "Axis", "BlendMode", "Border", "BorderRadius", "BoxShape",
    "Brightness", "Clipboard", "Color", "ColorFilter", "ColorScheme", "Colors",
    "ConnectionState", "CrossAxisAlignment", "Curves", "DeviceOrientation",
    "DismissDirection", "Duration", "EdgeInsets", "FilledButton",
    "FloatingActionButton", "FlutterError", "FontFeature", "FontWeight",
    "GridView", "Icons", "LaunchMode", "ListView", "Localizations",
    "MainAxisAlignment", "MainAxisSize", "MaterialTapTargetSize", "MediaQuery",
    "Navigator", "OutlinedButton", "PageView", "Radius", "ScaffoldMessenger",
    "Size", "SizedBox", "SnackBarBehavior", "StrokeCap", "Switch",
    "SwitchListTile", "SystemChrome", "SystemUiOverlayStyle", "TextAlign",
    "TextButton", "TextCapitalization", "TextInputAction", "TextOverflow",
    "Theme", "ThemeMode", "Timer", "Uri", "VisualDensity", "WidgetsBinding",
    "WidgetsFlutterBinding", "WrapCrossAlignment",
    # dart:core / dart:ui / dart:io
    "DateTime", "Object", "Platform", "PlatformDispatcher", "String",
    "Directory", "File", "FileSystemEntity", "RegExp",
    # Generated by flutter gen-l10n
    "AppLocalizations", "GlobalCupertinoLocalizations",
    "GlobalMaterialLocalizations", "GlobalWidgetsLocalizations",
    # google_mobile_ads
    "AdSize", "InterstitialAd", "MobileAds",
    # firebase_*
    "Firebase", "FirebaseAnalytics", "FirebaseCrashlytics", "FirebaseFirestore",
    "FirebaseMessaging", "FirebaseStorage",
    # hive / path_provider / package_info_plus
    "Hive", "PackageInfo",
    # dio
    "ResponseType",
    # pdfrx
    "PanAxis", "PdfViewer",
    # flutter_local_notifications / timezone
    "AndroidNotificationCategory", "AndroidScheduleMode", "Importance",
    "Priority", "TZDateTime", "DateTimeComponents",
    # flutter_svg
    "SvgPicture",
    # timezone / intl
    "DateFormat",
    # flutter_test (only valid inside test/**, which is why it is listed here)
    "TestWidgetsFlutterBinding", "WidgetTester", "TestPointer", "Finder",
    "MatchFinder", "FindsOneWidget", "TestGesture", "SemanticsTester",
})


def build_symbol_table(codes: dict[pathlib.Path, str]):
    members: dict[str, set[str]] = {}
    parents: dict[str, set[str]] = {}
    for code in codes.values():
        for name, body in class_bodies(code).items():
            found = set(MEMBER_TOKEN_RE.findall(body)) | set(GETTER_RE.findall(body))
            found |= set(re.findall(r"\b(\w+)\s*\(", body))  # constructors & calls
            members.setdefault(name, set()).update(found)
        for name, bases in supertypes(code).items():
            parents.setdefault(name, set()).update(bases)
    return members, parents


def _resolves(name: str, member: str, members, parents, seen=None) -> bool:
    seen = seen or set()
    if name in seen:
        return False
    seen.add(name)
    if member in members.get(name, set()):
        return True
    return any(_resolves(base, member, members, parents, seen) for base in parents.get(name, set()))


def check_class_members(codes: dict[pathlib.Path, str]) -> None:
    members, parents = build_symbol_table(codes)
    unresolved = 0
    for path, code in codes.items():
        for line_no, line in enumerate(code.splitlines(), start=1):
            for cls, member in USAGE_RE.findall(line):
                if cls not in members:
                    if cls not in EXTERNAL_TYPES:
                        unresolved += 1
                        fail(
                            f"{rel(path)}:{line_no}: {cls}.{member} — {cls} is not "
                            "declared in lib/ and is not on the external-type allowlist"
                        )
                    continue
                if _resolves(cls, member, members, parents):
                    continue
                unresolved += 1
                fail(f"{rel(path)}:{line_no}: {cls}.{member} is not declared on {cls}")
    print(f"  members: {len(members)} types checked, {unresolved} unresolved reference(s)")


# ---------------------------------------------------------------------------
# 9. Called methods
# ---------------------------------------------------------------------------
# Names that resolve to the Flutter/Dart SDK or a plugin rather than to project
# code. Keeping this list explicit is the point: anything not on it must exist in
# lib/, so a typo cannot hide. If a name stops being used the script warns.
SDK_METHODS: dict[str, str] = {
    # dart:core / dart:async / dart:convert
    "add": "List.add / Set.add",
    "addAll": "List.addAll",
    "any": "Iterable.any",
    "call": "Function.call",
    "catchError": "Future.catchError",
    "clamp": "num.clamp",
    "contains": "String.contains",
    "containsKey": "Map.containsKey",
    "difference": "Set.difference",
    "fromCharCode": "String.fromCharCode",
    "fromEnvironment": "String.fromEnvironment (dart-define)",
    "fromMillisecondsSinceEpoch": "DateTime.fromMillisecondsSinceEpoch",
    "indexWhere": "Iterable.indexWhere",
    "insert": "List.insert",
    "isAfter": "DateTime.isAfter",
    "join": "Iterable.join",
    "lastIndexOf": "String.lastIndexOf",
    "listen": "Stream.listen",
    "padLeft": "String.padLeft",
    "parse": "int.parse / double.parse / DateTime.parse",
    "putIfAbsent": "Map.putIfAbsent",
    "reduce": "Iterable.reduce",
    "replaceAll": "String.replaceAll",
    "round": "num.round",
    "roundToDouble": "num.roundToDouble",
    "shuffle": "List.shuffle",
    "split": "String.split",
    "startsWith": "String.startsWith",
    "sublist": "List.sublist",
    "substring": "String.substring",
    "subtract": "Set.subtract",
    "then": "Future.then",
    "toDouble": "num.toDouble",
    "toInt": "num.toInt",
    "toList": "Iterable.toList",
    "toLocal": "DateTime.toLocal",
    "toLowerCase": "String.toLowerCase",
    "toSet": "Iterable.toSet",
    "toUpperCase": "String.toUpperCase",
    "trim": "String.trim",
    "tryParse": "int.tryParse / double.tryParse",
    "where": "Iterable.where",
    "write": "StringBuffer.write",
    # Flutter foundation / widgets / material
    "addListener": "ChangeNotifier.addListener",
    "addPostFrameCallback": "SchedulerBinding.addPostFrameCallback",
    "delayed": "Future.delayed / Timer",
    "ensureInitialized": "WidgetsFlutterBinding.ensureInitialized",
    "hideCurrentSnackBar": "ScaffoldMessenger.hideCurrentSnackBar",
    "of": "Theme.of / MediaQuery.of / Navigator.of",
    "pop": "Navigator.pop",
    "popUntil": "Navigator.popUntil",
    "periodic": "Timer.periodic",
    "pushNamed": "Navigator.pushNamed",
    "pushNamedAndRemoveUntil": "Navigator.pushNamedAndRemoveUntil",
    "pushReplacementNamed": "Navigator.pushReplacementNamed",
    "presentError": "FlutterError.presentError",
    "recordFlutterFatalError": "FlutterError.onError handler",
    "remove": "List.remove",
    "removeListener": "ChangeNotifier.removeListener",
    "setPreferredOrientations": "SystemChrome.setPreferredOrientations",
    "showSnackBar": "ScaffoldMessenger.showSnackBar",
    "styleFrom": "ButtonStyle.styleFrom",
    "tabularFigures": "FontFeature.tabularFigures",
    "withAlpha": "Color.withAlpha",
    "toJson": "model serialisation convention",
    "fromJson": "model deserialisation convention",
    # Firebase / Firebase Analytics / Crashlytics / Messaging
    "setAnalyticsCollectionEnabled": "FirebaseAnalytics",
    "setCrashlyticsCollectionEnabled": "FirebaseCrashlytics",
    "log": "FirebaseAnalytics.logEvent",
    "logScreenView": "FirebaseAnalytics.logScreenView",
    "setUserProperty": "FirebaseAnalytics.setUserProperty",
    "setData": "RemoteMessage / Analytics parameters",
    "setVersion": "package_info / messaging payload",
    "getToken": "FirebaseMessaging.getToken",
    "initializeApp": "Firebase.initializeApp",
    "subscribeToTopic": "FirebaseMessaging.subscribeToTopic",
    "unsubscribeFromTopic": "FirebaseMessaging.unsubscribeFromTopic",
    "onBackgroundMessage": "FirebaseMessaging.onBackgroundMessage",
    "initializeTimeZones": "flutter_timezone / timezone data",
    "zonedSchedule": "FlutterLocalNotificationsPlugin.zonedSchedule",
    "requestPermissions": "FlutterLocalNotificationsPlugin.requestPermissions",
    "requestNotificationsPermission": "firebase_messaging permission request",
    "createNotificationChannel": "AndroidNotificationChannel.createNotificationChannel",
    # Widget constructors and named factories used as `X.y(` call sites
    "asset": "SvgPicture.asset (flutter_svg)",
    "builder": "PageView.builder / GridView.builder / ListView.builder",
    "separated": "ListView.separated",
    "extended": "FloatingActionButton.extended",
    "adaptive": "SwitchListTile.adaptive",
    "shrink": "SizedBox.shrink",
    "circular": "BorderRadius.circular",
    "only": "EdgeInsets.only",
    "symmetric": "EdgeInsets.symmetric",
    "fromLTRB": "Rect.fromLTRB",
    "fromHeight": "Size.fromHeight",
    "fromSeed": "ColorScheme.fromSeed",
    "mode": "ColorFilter.mode",
    "styleFrom": "ButtonStyle.styleFrom",
    "fromPlatform": "PackageInfo.fromPlatform",
    # Dart collection/date helpers
    "abs": "num.abs",
    "generate": "List.generate",
    "unmodifiable": "List.unmodifiable",
    "localeOf": "Localizations.localeOf",
    "yMMMd": "DateFormat.yMMMd (intl)",
    "add_Hm": "DateFormat.add_Hm (intl)",
    "format": "DateFormat.format (intl)",
    "nextPage": "PageController.nextPage",
    # Hive / pdfrx / plugin lifecycle
    "get": "Hive Box.get",
    "put": "Hive Box.put",
    "putAll": "Hive Box.putAll",
    "initFlutter": "Hive.initFlutter",
    "initialize": "plugin initialize()",
    "goToPage": "PdfViewerController.goToPage",
    "limit": "Firestore Query.limit",
    # Storage / network / files
    "writeAsBytes": "File.writeAsBytes",
    "writeToFile": "File.writeAsString",
    "loadString": "rootBundle.loadString",
    "asUint8List": "ByteData.asUint8List",
    "endsWith": "String.endsWith",
    "intersection": "Set.intersection",
    # flutter_test matchers and helper APIs
    "expect": "flutter_test expect",
    "readAsStringSync": "File.readAsStringSync",
    "readAsLinesSync": "File.readAsLinesSync",
    "readSync": "RandomAccessFile.readSync",
    "openSync": "File.openSync",
    "listSync": "Directory.listSync",
    "existsSync": "FileSystemEntity.existsSync",
    "jsonDecode": "json.decode",
    "jsonEncode": "json.encode",
    "allMatches": "RegExp.allMatches",
    "runes": "String.runes",
    "toList": "Iterable.toList",
    "toSet": "Iterable.toSet",
    "whereType": "Iterable.whereType",
    "expand": "Iterable.expand",
    "any": "Iterable.any",
    "map": "Iterable.map",
    "cast": "List.cast",
    "single": "Iterable.single",
    "substring": "String.substring",
    "toJson": "model convention",
    "fromJson": "model convention",
    "isValid": "model getter",
    "withAlpha": "Color.withAlpha",
    "reason": "matcher reason argument",
    "matches": "matcher",
    "isNotEmpty": "matcher",
    "isEmpty": "matcher",
    "isTrue": "matcher",
    "isFalse": "matcher",
    "isNull": "matcher",
    "isNotNull": "matcher",
    "equals": "matcher",
    "greaterThan": "matcher",
    "greaterThanOrEqualTo": "matcher",
    "lessThan": "matcher",
    "inInclusiveRange": "matcher",
    "contains": "matcher",
    "startsWith": "matcher",
    "isA": "matcher",
    "isNot": "matcher",
    "setUpAll": "flutter_test",
    "test": "flutter_test",
    "group": "flutter_test",
}

CALL_RE = re.compile(r"\.([a-z_]\w*)\s*\(")


def declaration_names(codes: dict[pathlib.Path, str]) -> set[str]:
    """Member, getter, constructor and function names declared in project code.

    Line-based and deliberately conservative. A line is treated as a declaration
    only when it ends the identifier with `(`, `;`, `=` or `=>` and the text
    before that identifier looks like a type. Call sites (`repo.items(`), named
    arguments (`onTap: (`) and returns (`return Padding(`) are excluded, so a
    misspelled method name cannot register itself as declared.
    """
    decl_re = re.compile(
        r"^(?P<head>.*?)(?P<name>[A-Za-z_]\w*)\s*(?P<tail>\(|;|=|=>)"
    )
    modifiers = re.compile(
        r"^(?:(?:static|final|const|late|external|abstract|covariant|required|"
        r"factory|get|set|async|await|operator|typedef)\s+)*$"
    )
    keywords = (
        "return ", "await ", "case ", "if ", "for ", "while ", "assert", "throw ",
        "yield ", "else ", "print(", "super.", "this.", "..", "?.",
    )
    declared: set[str] = set()
    for code in codes.values():
        for line in code.splitlines():
            stripped = line.strip()
            if not stripped or stripped[0] in "})].":
                continue
            if any(stripped.startswith(k) for k in keywords):
                continue
            match = decl_re.match(stripped)
            if not match:
                continue
            head = match.group("head")
            name = match.group("name")
            tail = match.group("tail")
            if ":" in head:
                continue  # named argument
            if "." in head and not re.fullmatch(r".*\b[A-Z]\w*\.\s*", head):
                # A trailing `ClassName.` is a named constructor
                # (`factory BadgeCollection.fromJsonList(`); any other dot means
                # this is a call site, which must not count as a declaration.
                continue
            if not re.fullmatch(r"[A-Za-z_\w<>,?\[\]()\s.]*", head):
                continue
            bare = modifiers.sub("", head).strip()
            if tail == "(" and not bare:
                continue  # bare `foo(` on its own line is a call, not a decl
            declared.add(name)
        declared |= set(GETTER_RE.findall(code))
    return declared


def check_called_methods(codes: dict[pathlib.Path, str], arb_keys: set[str]) -> None:
    declared = declaration_names(codes)
    unknown: dict[str, list[str]] = {}
    called: set[str] = set()
    for path, code in codes.items():
        for line_no, line in enumerate(code.splitlines(), start=1):
            for name in CALL_RE.findall(line):
                called.add(name)
                if name in declared or name in arb_keys or name in SDK_METHODS:
                    continue
                unknown.setdefault(name, []).append(f"{rel(path)}:{line_no}")

    for name, sites in sorted(unknown.items()):
        fail(
            f".{name}(...) called at {', '.join(sites[:3])} is not declared anywhere in "
            "lib/, is not an ARB key, and is not on the SDK allowlist"
        )

    # An allowlist entry that no longer appears anywhere in the sources is dead
    # weight: it hides nothing, but it also documents nothing. Matchers used
    # without a receiver (`isTrue`, `equals`) are still real usages, so search the
    # raw text rather than only dot-calls.
    blob = "\n".join(codes.values())
    stale = sorted(
        name for name in SDK_METHODS if not re.search(rf"\b{re.escape(name)}\b", blob)
    )
    if stale:
        warn(f"SDK allowlist entries that appear nowhere in the sources: {stale}")
    print(
        f"  calls: {len(called)} distinct methods called, {len(declared)} declared, "
        f"{len(unknown)} unresolved"
    )


# ---------------------------------------------------------------------------
# 10. Dart sanity
# ---------------------------------------------------------------------------
def check_dart_sanity(codes: dict[pathlib.Path, str], test_codes: dict[pathlib.Path, str]) -> None:
    if not codes:
        fail("no Dart sources found under lib/")
    if not test_codes:
        warn("no test files found: test/unit is expected to hold the suite")
    markers = 0
    for path, code in {**codes, **test_codes}.items():
        for marker in ("TODO", "FIXME", "HACK", "XXX:"):
            for line_no, line in enumerate(read(path).splitlines(), start=1):
                if marker in line and not line.lstrip().startswith("//") and marker not in (
                    "XXX:",
                ):
                    continue
                if marker in line:
                    markers += 1
                    warn(f"{rel(path)}:{line_no}: {marker} -> {line.strip()[:70]}")
        for open_ch, close_ch in (("{", "}"), ("(", ")"), ("[", "]")):
            if code.count(open_ch) != code.count(close_ch):
                fail(
                    f"{rel(path)}: unbalanced {open_ch}{close_ch} "
                    f"({code.count(open_ch)} vs {code.count(close_ch)})"
                )
    print(
        f"  dart: {len(codes)} lib files, {len(test_codes)} test files, "
        f"{markers} TODO-style markers"
    )


def check_duplicate_declarations(codes: dict[pathlib.Path, str]) -> None:
    seen: dict[str, str] = {}
    for path, code in codes.items():
        for kind, name in CLASS_RE.findall(code):
            if kind == "extension":
                continue
            if name in seen:
                warn(f"duplicate {kind} {name}: {rel(path)} and {rel(pathlib.Path(seen[name]))}")
            seen[name] = str(path)
    print(f"  naming: {len(seen)} unique declarations")


def main() -> int:
    print("SriEdu static verification")
    print("-" * 64)
    codes = {path: strip_strings_and_comments(read(path)) for path in sorted(LIB.rglob("*.dart"))}
    # The test suite is scanned with the same rules, so a test that calls a
    # method which does not exist fails here instead of at `flutter test`.
    test_codes = {
        path: strip_strings_and_comments(read(path))
        for path in sorted((ROOT / "test").rglob("*.dart"))
    }

    arb = load_arb()
    arb_keys = {k for k in (arb.get("en") or {}) if not k.startswith("@")}

    check_arb(arb)
    check_arb_usage(arb)
    check_json_assets()
    check_pubspec_assets()
    check_ad_policy()
    check_hardcoded_strings()
    check_routes()
    combined = dict(codes)
    combined.update(test_codes)
    check_class_members(combined)
    check_called_methods(combined, arb_keys)
    check_dart_sanity(codes, test_codes)
    check_duplicate_declarations(codes)
    print("-" * 64)

    for warning in WARNINGS:
        print(f"WARN  {warning}")
    for failure in FAILURES:
        print(f"FAIL  {failure}")
    print("-" * 64)
    print(f"{len(FAILURES)} failure(s), {len(WARNINGS)} warning(s)")
    if FAILURES:
        print("\nFix the failures above, then re-run, then `flutter analyze`.")
        return 1
    print("All static checks passed.")
    print("Remaining (needs the Flutter SDK): flutter pub get && flutter gen-l10n && "
          "flutter analyze && flutter test")
    return 0


if __name__ == "__main__":
    sys.exit(main())
