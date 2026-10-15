#!/usr/bin/env python3
"""Generates SriEdu's bundled seed content.

Why a generator instead of hand-written JSON:
  * the catalogue is a grid (grade x subject x medium) and hand-editing ~500
    rows invites inconsistencies;
  * provenance stays explicit — every generated item carries
    `"linkStatus": "unverified_seed"` until a human verifies it with
    tools/verify_catalogue.py;
  * regenerating after a curriculum change is one command.

Outputs (relative to the repo root):
  assets/data/subjects.json
  assets/data/catalogue.json
  assets/data/official_sources.json
  assets/data/sample_questions.json
  assets/legal/LICENSES.txt

Run:  python3 tools/generate_seed_assets.py
"""

from __future__ import annotations

import json
import os
import pathlib
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "data"
LEGAL = ROOT / "assets" / "legal"


def stable_hash(value: str) -> int:
    """A deterministic 32-bit hash for generated "statistics".

    Python's built-in ``hash()`` is salted per process (PYTHONHASHSEED), so using
    it meant every run produced different file sizes, page counts, download
    counts and trending scores: noisy diffs on every commit, and no way to tell a
    real content change from a re-run. CRC-32 depends only on the input bytes, so
    the bundled seed assets are byte-stable across machines and Python versions.
    """
    return zlib.crc32(value.encode("utf-8"))

# --------------------------------------------------------------------------
# URL conventions
#
# These are *pattern* URLs on real, official domains. They are deliberately
# marked `linkStatus: unverified_seed` and every one of them must be checked
# (tools/verify_catalogue.py does it in bulk) before a store release. The
# intended production path is a Firestore `catalogue` collection populated with
# the verified links (see docs/FIRESTORE_SCHEMA.md and tools/seed_firestore.py).
# --------------------------------------------------------------------------
NIE_TEXTBOOK = "https://nie.lk/textbooks/{medium}/{grade}/{subject}"
DOENETS_PAPER = "https://www.doenets.lk/exam-papers/{exam}/{year}/{subject}-{medium}.pdf"
DOENETS_MARKING = "https://www.doenets.lk/exam-papers/{exam}/{year}/{subject}-{medium}-marking.pdf"
DOENETS_HOME = "https://www.doenets.lk"

# --------------------------------------------------------------------------
# Subjects: en / si / ta names
# --------------------------------------------------------------------------
SUBJECTS = [
    # code, en, si, ta, grades, icon, sortOrder
    ("sinhala", "Sinhala", "සිංහල", "சிங்களம்", list(range(1, 12)), "translate", 10),
    ("tamil", "Tamil", "දෙමළ", "தமிழ்", list(range(1, 12)), "translate", 11),
    ("english", "English", "ඉංග්‍රීසි", "ஆங்கிலம்", list(range(1, 14)), "abc", 12),
    ("mathematics", "Mathematics", "ගණිතය", "கணிதம்", list(range(1, 12)), "calculate", 20),
    ("science", "Science", "විද්‍යාව", "விஞ்ஞானம்", list(range(6, 12)), "science", 30),
    ("environment", "Environment", "පරිසරය", "சுற்றாடல்", list(range(1, 6)), "park", 31),
    ("ict", "ICT", "තොරතුරු තාක්ෂණය", "தகவல் தொழில்நுட்பம்", list(range(9, 14)), "memory", 40),
    ("history", "History", "ඉතිහාසය", "வரலாறு", list(range(6, 12)), "history", 50),
    ("geography", "Geography", "භූගෝල විද්‍යාව", "புவியியல்", list(range(6, 12)), "public", 51),
    ("civic", "Civic Education", "පුරවැසි අධ්‍යාපනය", "பிரஜை உரிமைக் கல்வி", list(range(6, 12)), "gavel", 52),
    ("religion", "Religion", "ආගම", "மதம்", list(range(1, 12)), "self_improvement", 53),
    ("health", "Health & Physical Education", "සෞඛ්‍ය හා ශාරීරික අධ්‍යාපනය", "சுகாதாரம்", list(range(6, 12)), "health", 54),
    ("arts", "Art", "චිත්‍ර කලාව", "கலை", list(range(6, 12)), "palette", 55),
    ("business_studies", "Business Studies", "ව්‍යාපාර අධ්‍යයනය", "வணிகக் கல்வி", [12, 13], "storefront", 60),
    ("accounting", "Accounting", "ගිණුම්කරණය", "கணக்கியல்", [12, 13], "receipt_long", 61),
    ("economics", "Economics", "ආර්ථික විද්‍යාව", "பொருளியல்", [12, 13], "trending_up", 62),
    ("biology", "Biology", "ජීව විද්‍යාව", "உயிரியல்", [12, 13], "biotech", 63),
    ("chemistry", "Chemistry", "රසායන විද්‍යාව", "இரசாயனவியல்", [12, 13], "science", 64),
    ("physics", "Physics", "භෞතික විද්‍යාව", "பௌதிகவியல்", [12, 13], "bolt", 65),
    ("agriculture", "Agriculture", "කෘෂිකර්මය", "விவசாயம்", [12, 13], "agriculture", 66),
]

MEDIUMS = ["en", "si", "ta"]
MEDIUM_SHORT = {"en": "e", "si": "s", "ta": "t"}

EXAM_TITLES = {
    "en": {"ol": "O/L", "al": "A/L", "grade5": "Grade 5 Scholarship", "term": "Term Test"},
    "si": {"ol": "සා.පෙ.ළ", "al": "උ.පෙ.ළ", "grade5": "5 ශ්‍රේණියේ විශාරද", "term": "වාර පරීක්ෂණය"},
    "ta": {"ol": "சா.த.", "al": "உ.த.", "grade5": "தரம் 5 புலமைப்பரிசில்", "term": "தவணைத் தேர்வு"},
}

MEDIUM_WORD = {
    "en": {"en": "English medium", "si": "Sinhala medium", "ta": "Tamil medium"},
    "si": {"en": "ඉංග්‍රීසි මාධ්‍යය", "si": "සිංහල මාධ්‍යය", "ta": "දෙමළ මාධ්‍යය"},
    "ta": {"en": "ஆங்கில மொழி", "si": "சிங்கள மொழி", "ta": "தமிழ் மொழி"},
}

NIE_PUBLISHER = {
    "en": "National Institute of Education",
    "si": "ජාතික අධ්‍යාපන ආයතනය",
    "ta": "தேசிய கல்வி நிறுவனம்",
}
DOENETS_PUBLISHER = {
    "en": "Department of Examinations",
    "si": "විභාග දෙපාර්තමේන්තුව",
    "ta": "தேர்வுத் திணைக்களம்",
}


def subjects_payload() -> dict:
    out = []
    for code, en, si, ta, grades, icon, order in SUBJECTS:
        out.append(
            {
                "code": code,
                "names": {"en": en, "si": si, "ta": ta},
                "grades": grades,
                "mediums": MEDIUMS,
                "icon": icon,
                "isExamSubject": code
                in {
                    "mathematics",
                    "science",
                    "sinhala",
                    "tamil",
                    "english",
                    "history",
                    "geography",
                    "ict",
                    "business_studies",
                    "accounting",
                    "economics",
                    "biology",
                    "chemistry",
                    "physics",
                },
                "sortOrder": order,
            }
        )
    return {"version": 1, "subjects": out}


def grade_subject_codes(grade: int) -> list[str]:
    """Curriculum plan: which subjects are taught in each grade."""
    if grade <= 5:
        return ["sinhala", "tamil", "english", "mathematics", "environment", "religion"]
    if grade <= 9:
        return [
            "sinhala",
            "tamil",
            "english",
            "mathematics",
            "science",
            "history",
            "geography",
            "religion",
            "health",
            "arts",
        ]
    if grade <= 11:
        return [
            "sinhala",
            "tamil",
            "english",
            "mathematics",
            "science",
            "history",
            "geography",
            "civic",
            "religion",
            "ict",
        ]
    # A/L: a representative science + commerce + arts mix.
    return [
        "sinhala",
        "tamil",
        "english",
        "biology",
        "chemistry",
        "physics",
        "business_studies",
        "accounting",
        "economics",
        "ict",
    ]


def textbooks() -> list[dict]:
    items = []
    subject_names = {s[0]: (s[1], s[2], s[3]) for s in SUBJECTS}
    for grade in range(1, 14):
        for code in grade_subject_codes(grade):
            en, si, ta = subject_names[code]
            for medium in MEDIUMS:
                title = {
                    "en": f"{en} — Grade {grade}",
                    "si": f"{si} — {grade} ශ්‍රේණිය",
                    "ta": f"{ta} — தரம் {grade}",
                }
                items.append(
                    {
                        "id": f"tb-{grade}-{code}-{medium}",
                        "kind": "textbook",
                        "title": title,
                        "subject": code,
                        "medium": medium,
                        "grade": grade,
                        "rights": "official_link",
                        "linkStatus": "unverified_seed",
                        "sourceUrl": NIE_TEXTBOOK.format(
                            medium=medium, grade=grade, subject=code
                        ),
                        "publisher": NIE_PUBLISHER,
                        "fileSizeBytes": 8_400_000 + (stable_hash(f"{grade}{code}{medium}") % 9) * 900_000,
                        "pageCount": 120 + (stable_hash(f"p{grade}{code}") % 160),
                        "downloadCount": 12_000 + (stable_hash(f"d{grade}{code}{medium}") % 90_000),
                        "trendingScore": stable_hash(f"t{grade}{code}") % 500,
                        "updatedAt": 1_730_000_000_000,
                    }
                )
    # Bundled demo title so the reader is demonstrable with no network at all.
    items.append(
        {
            "id": "sample-reading-en",
            "kind": "textbook",
            "title": {
                "en": "SriEdu Sample Reading (demo)",
                "si": "SriEdu නියැදි කියවීම (නිදර්ශන)",
                "ta": "SriEdu மாதிரி வாசிப்பு (மாதிரி)",
            },
            "subject": "mathematics",
            "medium": "en",
            "grade": 6,
            "rights": "bundled",
            "linkStatus": "bundled",
            # `asset:` paths are copied out of the APK on first "download" so the
            # reader can be demoed on a plane with no connection.
            "storagePath": "asset:assets/data/sample_textbook.pdf",
            "sourceUrl": "",
            "publisher": {"en": "SriEdu (generated sample)"},
            "fileSizeBytes": 4200,
            "pageCount": 4,
            "downloadCount": 0,
            "trendingScore": 0,
        }
    )
    return items


def papers() -> list[dict]:
    items = []
    subject_names = {s[0]: (s[1], s[2], s[3]) for s in SUBJECTS}
    plan = [
        ("ol", [2019, 2020, 2021, 2022, 2023], ["mathematics", "science", "english", "sinhala", "tamil", "history"]),
        ("al", [2019, 2020, 2021, 2022, 2023], ["biology", "chemistry", "physics", "business_studies", "accounting", "economics"]),
        ("grade5", [2019, 2020, 2021, 2022, 2023], ["mathematics", "english", "environment"]),
    ]
    for exam, years, codes in plan:
        for year in years:
            for code in codes:
                en, si, ta = subject_names[code]
                for medium in MEDIUMS:
                    paper_id = f"{exam}-{year}-{code}-{medium}"
                    titles = {
                        "en": f"{en} — {EXAM_TITLES['en'][exam]} {year}",
                        "si": f"{si} — {EXAM_TITLES['si'][exam]} {year}",
                        "ta": f"{ta} — {EXAM_TITLES['ta'][exam]} {year}",
                    }
                    has_marking = medium == "en" or exam != "grade5"
                    items.append(
                        {
                            "id": paper_id,
                            "kind": "paper",
                            "title": titles,
                            "subject": code,
                            "medium": medium,
                            "examType": exam,
                            "year": year,
                            "rights": "official_link",
                            "linkStatus": "unverified_seed",
                            "sourceUrl": DOENETS_PAPER.format(
                                exam=exam, year=year, subject=code, medium=medium
                            ),
                            "publisher": DOENETS_PUBLISHER,
                            "fileSizeBytes": 1_200_000 + (stable_hash(paper_id) % 12) * 180_000,
                            "pageCount": 8 + (stable_hash(f"pp{paper_id}") % 12),
                            "downloadCount": 40_000 + (stable_hash(f"dc{paper_id}") % 260_000),
                            "trendingScore": 1000 + (stable_hash(f"tr{paper_id}") % 4000),
                            "markingSchemeId": f"{paper_id}-ms" if has_marking else None,
                            "updatedAt": 1_730_000_000_000,
                        }
                    )
                    if has_marking:
                        items.append(
                            {
                                "id": f"{paper_id}-ms",
                                "kind": "marking_scheme",
                                "title": {
                                    "en": f"{en} — {EXAM_TITLES['en'][exam]} {year} — Marking scheme",
                                    "si": f"{si} — {EXAM_TITLES['si'][exam]} {year} — පිළිතුරු පත්‍රය",
                                    "ta": f"{ta} — {EXAM_TITLES['ta'][exam]} {year} — விடைக்குறிப்பு",
                                },
                                "subject": code,
                                "medium": medium,
                                "examType": exam,
                                "year": year,
                                "rights": "official_link",
                                "linkStatus": "unverified_seed",
                                "sourceUrl": DOENETS_MARKING.format(
                                    exam=exam, year=year, subject=code, medium=medium
                                ),
                                "publisher": DOENETS_PUBLISHER,
                                "fileSizeBytes": 420_000,
                                "pageCount": 6,
                                "downloadCount": 18_000 + (stable_hash(f"ms{paper_id}") % 40_000),
                                "trendingScore": 200,
                                "updatedAt": 1_730_000_000_000,
                            }
                        )
    return items


def term_tests() -> list[dict]:
    """A few school term-test style entries, to exercise the Term tests tab."""
    items = []
    subject_names = {s[0]: (s[1], s[2], s[3]) for s in SUBJECTS}
    schools = {
        "en": ["Royal College Colombo", "Mahamaya Girls' School Kandy"],
        "si": ["රාජකීය විද්‍යාලය කොළඹ", "මහාමායා බාලිකා විද්‍යාලය මහනුවර"],
        "ta": ["ரோயல் கல்லூரி கொழும்பு", "மகாமாயா மகளிர் பாடசாலை கண்டி"],
    }
    for code in ["mathematics", "science", "english"]:
        en, si, ta = subject_names[code]
        for term in (1, 2, 3):
            for medium in MEDIUMS:
                item_id = f"term-2023-t{term}-{code}-{medium}"
                items.append(
                    {
                        "id": item_id,
                        "kind": "term_test",
                        "title": {
                            "en": f"{en} — Term {term} Test 2023",
                            "si": f"{si} — {term} වන වාර පරීක්ෂණය 2023",
                            "ta": f"{ta} — {term} ஆம் தவணைத் தேர்வு 2023",
                        },
                        "subject": code,
                        "medium": medium,
                        "examType": "term",
                        "year": 2023,
                        "term": term,
                        "rights": "official_link",
                        "linkStatus": "unverified_seed",
                        "sourceUrl": f"https://www.moe.gov.lk/term-tests/2023/{term}/{code}-{medium}.pdf",
                        "publisher": {"en": schools["en"][term % 2], "si": schools["si"][term % 2], "ta": schools["ta"][term % 2]},
                        "fileSizeBytes": 900_000 + term * 120_000,
                        "pageCount": 4 + term,
                        "downloadCount": 3_000 + (stable_hash(item_id) % 9_000),
                        "trendingScore": 120 * term,
                        "updatedAt": 1_730_000_000_000,
                    }
                )
    return items


def catalogue_payload() -> dict:
    items = textbooks() + papers() + term_tests()
    return {
        "version": 1,
        "generatedBy": "tools/generate_seed_assets.py",
        "rightsPolicy": "Items with rights=official_link open on the publisher's site and are never cached by the app. See docs/CONTENT_POLICY.md.",
        "linkStatusNote": (
            "Every 'unverified_seed' URL follows the documented pattern in this "
            "script and MUST be verified (tools/verify_catalogue.py) or replaced "
            "with the real link in Firestore before a store release."
        ),
        "items": items,
    }


def official_sources_payload() -> dict:
    return {
        "version": 1,
        "sources": [
            {
                "id": "nie",
                "names": {
                    "en": "National Institute of Education",
                    "si": "ජාතික අධ්‍යාපන ආයතනය",
                    "ta": "தேசிய கல்வி நிறுவனம்",
                },
                "url": "https://nie.lk",
                "hosts": ["nie.lk", "www.nie.lk"],
                "note": {
                    "en": "Publishes the government school textbooks used by SriEdu.",
                    "si": "SriEdu භාවිතා කරන රජයේ පාසල් පෙළපොත් පළ කරයි.",
                    "ta": "SriEdu பயன்படுத்தும் அரச பாடநூல்களை வெளியிடுகிறது.",
                },
                "category": "textbooks",
            },
            {
                "id": "doenets",
                "names": {
                    "en": "Department of Examinations",
                    "si": "විභාග දෙපාර්තමේන්තුව",
                    "ta": "தேர்வுத் திணைக்களம்",
                },
                "url": DOENETS_HOME,
                "hosts": ["doenets.lk", "www.doenets.lk"],
                "note": {
                    "en": "Publishes O/L, A/L and Grade 5 past papers and marking schemes.",
                    "si": "සා.පෙ.ළ, උ.පෙ.ළ සහ 5 ශ්‍රේණියේ පසුගිය ප්‍රශ්න පත්‍ර පළ කරයි.",
                    "ta": "சா.த., உ.த. மற்றும் தரம் 5 வினாத்தாள்களை வெளியிடுகிறது.",
                },
                "category": "papers",
            },
            {
                "id": "moe",
                "names": {
                    "en": "Ministry of Education",
                    "si": "අධ්‍යාපන අමාත්‍යාංශය",
                    "ta": "கல்வி அமைச்சு",
                },
                "url": "https://moe.gov.lk",
                "hosts": ["moe.gov.lk", "www.moe.gov.lk"],
                "note": {
                    "en": "Circulars, term test guidance and school notices.",
                    "si": "චක්‍රලේඛ, වාර පරීක්ෂණ මාර්ගෝපදේශ සහ පාසල් නිවේදන.",
                    "ta": "சுற்றறிக்கைகள், தவணைத் தேர்வு வழிகாட்டல் மற்றும் பாடசாலை அறிவிப்புகள்.",
                },
                "category": "notices",
            },
        ],
    }


def questions_payload() -> dict:
    """Two trilingual banks plus an English-only bank.

    The mathematics bank has a full ten questions so a complete quiz can be run
    offline straight after install.
    """

    def q(qid, text_en, text_si, text_ta, options, correct, expl_en, expl_si, expl_ta):
        return {
            "id": qid,
            "questionText": {"en": text_en, "si": text_si, "ta": text_ta},
            "options": [
                {"en": o[0], "si": o[1], "ta": o[2]} for o in options
            ],
            "correctAnswer": correct,
            "explanation": {"en": expl_en, "si": expl_si, "ta": expl_ta},
        }

    def opt(en, si, ta):
        return (en, si, ta)

    math = [
        q(
            "math-2019-01",
            "What is 15% of 240?",
            "240 හි 15% කීයද?",
            "240 இன் 15% என்ன?",
            [opt("24", "24", "24"), opt("36", "36", "36"), opt("32", "32", "32"), opt("48", "48", "48")],
            1,
            "15% = 15/100, and 240 x 15 / 100 = 36.",
            "15% = 15/100, එවිට 240 x 15 / 100 = 36.",
            "15% = 15/100, எனவே 240 x 15 / 100 = 36.",
        ),
        q(
            "math-2019-02",
            "Simplify: 3(2x - 4) + 5x",
            "සරල කරන්න: 3(2x - 4) + 5x",
            "எளிமைப்படுத்துக: 3(2x - 4) + 5x",
            [opt("11x - 12", "11x - 12", "11x - 12"), opt("6x - 4", "6x - 4", "6x - 4"),
             opt("11x - 4", "11x - 4", "11x - 4"), opt("x - 12", "x - 12", "x - 12")],
            0,
            "Expand: 6x - 12 + 5x = 11x - 12.",
            "විස්තර කරන්න: 6x - 12 + 5x = 11x - 12.",
            "விரிவாக்குக: 6x - 12 + 5x = 11x - 12.",
        ),
        q(
            "math-2019-03",
            "The area of a circle with radius 7 cm is (take pi = 22/7):",
            "අරය 7 cm වූ වෘත්තයක වර්ගඵලය (pi = 22/7 ලෙස ගන්න):",
            "ஆரை 7 cm உள்ள வட்டத்தின் பரப்பளவு (pi = 22/7 எனக் கொள்க):",
            [opt("154 cm²", "154 cm²", "154 cm²"), opt("44 cm²", "44 cm²", "44 cm²"),
             opt("49 cm²", "49 cm²", "49 cm²"), opt("308 cm²", "308 cm²", "308 cm²")],
            0,
            "A = pi r² = (22/7) x 49 = 154 cm².",
            "A = pi r² = (22/7) x 49 = 154 cm².",
            "A = pi r² = (22/7) x 49 = 154 cm².",
        ),
        q(
            "math-2019-04",
            "If x + 5 = 12, then 3x = ?",
            "x + 5 = 12 නම්, 3x = ?",
            "x + 5 = 12 எனில், 3x = ?",
            [opt("21", "21", "21"), opt("15", "15", "15"), opt("27", "27", "27"), opt("36", "36", "36")],
            0,
            "x = 7, so 3x = 21.",
            "x = 7, එවිට 3x = 21.",
            "x = 7, எனவே 3x = 21.",
        ),
        q(
            "math-2019-05",
            "A shirt costs Rs. 1800 after a 10% discount. What was the original price?",
            "10% වට්ටමකින් පසු කමිසයක මිල රු. 1800 කි. මුල් මිල කීයද?",
            "10% தள்ளுபடிக்குப் பின் ஒரு சட்டையின் விலை ரூ. 1800. மூல விலை என்ன?",
            [opt("Rs. 1980", "රු. 1980", "ரூ. 1980"), opt("Rs. 2000", "රු. 2000", "ரூ. 2000"),
             opt("Rs. 1900", "රු. 1900", "ரூ. 1900"), opt("Rs. 2200", "රු. 2200", "ரூ. 2200")],
            1,
            "1800 = 90% of the original, so original = 1800 x 100 / 90 = 2000.",
            "1800 යනු මුල් මිලෙන් 90% කි. එවිට මුල් මිල = 1800 x 100 / 90 = 2000.",
            "1800 என்பது மூல விலையின் 90%. மூல விலை = 1800 x 100 / 90 = 2000.",
        ),
        q(
            "math-2019-06",
            "Which of these is a prime number?",
            "මේවායින් ප්‍රථමක සංඛ්‍යාව කුමක්ද?",
            "இவற்றில் பகா எண் எது?",
            [opt("21", "21", "21"), opt("27", "27", "27"), opt("29", "29", "29"), opt("33", "33", "33")],
            2,
            "29 has no divisors other than 1 and itself. 21 = 3x7, 27 = 3x9, 33 = 3x11.",
            "29 හට 1 සහ එයම හැර බෙදුම්කරුවන් නොමැත. 21 = 3x7, 27 = 3x9, 33 = 3x11.",
            "29 க்கு 1 மற்றும் அதே தவிர வேறு வகுப்பிகள் இல்லை. 21 = 3x7, 27 = 3x9, 33 = 3x11.",
        ),
        q(
            "math-2019-07",
            "The sum of the interior angles of a triangle is:",
            "ත්‍රිකෝණයක අභ්‍යන්තර කෝණවල එකතුව:",
            "ஒரு முக்கோணத்தின் உள் கோணங்களின் கூட்டுத்தொகை:",
            [opt("90°", "90°", "90°"), opt("180°", "180°", "180°"), opt("270°", "270°", "270°"), opt("360°", "360°", "360°")],
            1,
            "Every triangle's interior angles add up to 180°.",
            "සෑම ත්‍රිකෝණයකම අභ්‍යන්තර කෝණවල එකතුව 180° කි.",
            "எல்லா முக்கோணங்களின் உள் கோணங்களின் கூட்டுத்தொகை 180°.",
        ),
        q(
            "math-2019-08",
            "What is the value of 2³ + 3²?",
            "2³ + 3² හි අගය කීයද?",
            "2³ + 3² இன் பெறுமதி என்ன?",
            [opt("17", "17", "17"), opt("13", "13", "13"), opt("36", "36", "36"), opt("25", "25", "25")],
            0,
            "2³ = 8 and 3² = 9, so the sum is 17.",
            "2³ = 8 සහ 3² = 9, එවිට එකතුව 17 කි.",
            "2³ = 8, 3² = 9, எனவே கூட்டுத்தொகை 17.",
        ),
        q(
            "math-2019-09",
            "In a class of 40 students, 60% are girls. How many boys are there?",
            "සිසුන් 40 ක පන්තියක 60% ගැහැණු ළමයින්ය. පිරිමි ළමයින් කී දෙනෙක්ද?",
            "40 மாணவர்கள் உள்ள வகுப்பில் 60% பெண்கள். ஆண்கள் எத்தனை பேர்?",
            [opt("24", "24", "24"), opt("16", "16", "16"), opt("20", "20", "20"), opt("18", "18", "18")],
            1,
            "40% of 40 = 16 boys (60% of 40 = 24 girls).",
            "40 න් 40% = පිරිමි 16 කි (40 න් 60% = ගැහැණු 24 කි).",
            "40 இல் 40% = 16 ஆண்கள் (40 இல் 60% = 24 பெண்கள்).",
        ),
        q(
            "math-2019-10",
            "A train travels 180 km in 3 hours. What is its average speed?",
            "දුම්රියක් පැය 3 කින් කි.මී. 180 ක් ගමන් කරයි. සාමාන්‍ය වේගය කීයද?",
            "ஒரு ரயில் 3 மணித்தியாலங்களில் 180 கி.மீ. செல்கிறது. சராசரி வேகம் என்ன?",
            [opt("45 km/h", "පැයට කි.මී. 45", "ம.மீ/மணி 45"), opt("60 km/h", "පැයට කි.මී. 60", "ம.மீ/மணி 60"),
             opt("54 km/h", "පැයට කි.මී. 54", "ம.மீ/மணி 54"), opt("90 km/h", "පැයට කි.මී. 90", "ம.மீ/மணி 90")],
            1,
            "Speed = distance / time = 180 / 3 = 60 km/h.",
            "වේගය = දුර / කාලය = 180 / 3 = 60 km/h.",
            "வேகம் = தூரம் / நேரம் = 180 / 3 = 60 km/h.",
        ),
    ]

    science = [
        q(
            "sci-2019-01",
            "Which gas do plants absorb during photosynthesis?",
            "ප්‍රභාසංශ්ලේෂණයේදී ශාක අවශෝෂණය කරන වායුව කුමක්ද?",
            "ஒளிச்சேர்க்கையின் போது தாவரங்கள் உட்கொள்ளும் வாயு எது?",
            [opt("Oxygen", "ඔක්සිජන්", "ஆக்சிஜன்"), opt("Carbon dioxide", "කාබන් ඩයොක්සයිඩ්", "கரிம வாயு"),
             opt("Nitrogen", "නයිට්‍රජන්", "நைட்ரஜன்"), opt("Hydrogen", "හයිඩ්‍රජන්", "ஹைட்ரஜன்")],
            1,
            "Plants take in CO2 and release O2 during photosynthesis.",
            "ප්‍රභාසංශ්ලේෂණයේදී ශාක CO2 ලබාගෙන O2 නිකුත් කරයි.",
            "ஒளிச்சேர்க்கையில் தாவரங்கள் CO2 உட்கொண்டு O2 வெளியிடும்.",
        ),
        q(
            "sci-2019-02",
            "The SI unit of force is:",
            "බලයේ SI ඒකකය:",
            "விசையின் SI அலகு:",
            [opt("Joule", "ජූල්", "ஜூல்"), opt("Watt", "වොට්", "வாட்"), opt("Newton", "නිව්ටන්", "நியூட்டன்"), opt("Pascal", "පැස්කල්", "பாஸ்கல்")],
            2,
            "Force is measured in newtons (kg·m/s²).",
            "බලය නිව්ටන් වලින් මනිනු ලැබේ (kg·m/s²).",
            "விசை நியூட்டனில் அளவிடப்படுகிறது (kg·m/s²).",
        ),
        q(
            "sci-2019-03",
            "Which part of the human body produces insulin?",
            "මිනිස් සිරුරේ ඉන්සියුලින් නිපදවන අවයවය කුමක්ද?",
            "மனித உடலில் இன்சுலின் உற்பத்தி செய்யும் உறுப்பு எது?",
            [opt("Liver", "අක්මාව", "கல்லீரல்"), opt("Pancreas", "අග්න්‍යාශය", "கணையம்"),
             opt("Kidney", "වකුගඩුව", "சிறுநீரகம்"), opt("Spleen", "ප්ලීහාව", "மண்ணீரல்")],
            1,
            "The beta cells of the pancreas produce insulin.",
            "අග්න්‍යාශයේ බීටා සෛල ඉන්සියුලින් නිපදවයි.",
            "கணையத்தின் பீட்டா செல்கள் இன்சுலின் உற்பத்தி செய்கின்றன.",
        ),
        q(
            "sci-2019-04",
            "Water boils at what temperature at sea level?",
            "මුහුදු මට්ටමේදී ජලය උනු වන උෂ්ණත්වය කුමක්ද?",
            "கடல் மட்டத்தில் நீர் எந்த வெப்பநிலையில் கொதிக்கும்?",
            [opt("90 °C", "90 °C", "90 °C"), opt("100 °C", "100 °C", "100 °C"), opt("110 °C", "110 °C", "110 °C"), opt("80 °C", "80 °C", "80 °C")],
            1,
            "At standard atmospheric pressure water boils at 100 °C.",
            "සම්මත වායු පීඩනයේදී ජලය 100 °C දී උනු වේ.",
            "நிலையான வளிமண்டல அழுத்தத்தில் நீர் 100 °C இல் கொதிக்கும்.",
        ),
        q(
            "sci-2019-05",
            "Which of the following is a renewable energy source?",
            "පහත සඳහන් දේවලින් පුනර්ජනනීය බලශක්ති මූලාශ්‍රය කුමක්ද?",
            "கீழ்வற்றில் புதுப்பிக்கத்தக்க எரிசக்தி மூலம் எது?",
            [opt("Coal", "ගල් අඟුරු", "நிலக்கரி"), opt("Solar", "සූර්ය බලය", "சூரிய சக்தி"),
             opt("Diesel", "ඩීසල්", "டீசல்"), opt("Natural gas", "ස්වාභාවික වායු", "இயற்கை வாயு")],
            1,
            "Sunlight is naturally replenished; fossil fuels are not.",
            "සූර්යාලෝකය ස්වාභාවිකව නැවත පිරවේ; ෆොසිල ඉන්ධන නොවේ.",
            "சூரிய ஒளி இயற்கையாக மீளும்; புதைபடிவ எரிபொருட்கள் அல்ல.",
        ),
        q(
            "sci-2019-06",
            "The pH value of a neutral solution is:",
            "උදාසීන ද්‍රාවණයක pH අගය:",
            "நடுநிலை கரைசலின் pH பெறுமதி:",
            [opt("0", "0", "0"), opt("7", "7", "7"), opt("10", "10", "10"), opt("14", "14", "14")],
            1,
            "Neutral solutions such as pure water have pH 7.",
            "පිරිසිදු ජලය වැනි උදාසීන ද්‍රාවණවල pH අගය 7 කි.",
            "சுத்த நீர் போன்ற நடுநிலை கரைசல்களின் pH 7.",
        ),
    ]

    # English-medium bank: an English paper's questions are English in every
    # medium, so si/ta are intentionally omitted and `LocalizedText.resolve`
    # falls back to English.
    english = []
    for idx, (prompt, options, correct, explanation) in enumerate(
        [
            ("Choose the correct sentence:", ["He go to school daily.", "He goes to school daily.", "He going to school daily.", "He gone to school daily."], 1, "'He' takes 'goes' in the simple present."),
            ("Pick the antonym of 'ancient':", ["old", "modern", "past", "historic"], 1, "'Modern' is the opposite of 'ancient'."),
            ("Fill in the blank: She has been studying ___ two hours.", ["since", "for", "from", "during"], 1, "'For' is used with a duration; 'since' with a point in time."),
            ("Choose the correct plural of 'child':", ["childs", "childes", "children", "child"], 2, "'Child' has the irregular plural 'children'."),
        ],
        start=1,
    ):
        english.append(
            {
                "id": f"eng-2019-{idx:02d}",
                "questionText": {"en": prompt},
                "options": [{"en": o} for o in options],
                "correctAnswer": correct,
                "explanation": {"en": explanation},
            }
        )

    def bank(subject, exam, year, questions, medium="si"):
        # `key` mirrors QuizQuestion.bankKey() in lib/data/models/question.dart:
        # subject_examType[_year]. It is written here so the Firestore seeder and
        # the bundled asset use one spelling of the same id, and so a bank's
        # medium can never drift from the languages its questions actually carry
        # (see the medium/content check in tools/verify_project.py).
        return {
            "key": "_".join([subject, exam] + ([str(year)] if year else [])),
            "subject": subject,
            "examType": exam,
            "medium": medium,
            "year": year,
            "questions": [
                {**item, "subject": subject, "examType": exam, "medium": medium, "year": year, "grade": 11}
                for item in questions
            ],
        }

    return {
        "version": 1,
        "generatedBy": "tools/generate_seed_assets.py",
        "note": (
            "Bank key format is subject_examType[_year]. The repository looks for an "
            "exact-year bank first, then a subject-wide bank, then Firestore."
        ),
        "banks": [
            bank("mathematics", "ol", 2019, math),
            bank("science", "ol", 2019, science),
            # English-only content, so medium="en": see the checker that
            # refuses a si/ta bank whose questions have no si/ta text.
            bank("english", "ol", 2019, english, medium="en"),
        ],
    }


def write_json(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # ensure_ascii=False keeps Sinhala/Tamil readable in the file, which matters
    # when a translator reviews the content in a text editor.
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )
    size = path.stat().st_size
    print(f"  wrote {path.relative_to(ROOT)} ({size / 1024:.0f} KB)")


def main() -> int:
    print("Generating SriEdu seed assets…")
    write_json(DATA / "subjects.json", subjects_payload())
    write_json(DATA / "catalogue.json", catalogue_payload())
    write_json(DATA / "official_sources.json", official_sources_payload())
    write_json(DATA / "sample_questions.json", questions_payload())

    catalogue = catalogue_payload()
    counts: dict[str, int] = {}
    for item in catalogue["items"]:
        counts[item["kind"]] = counts.get(item["kind"], 0) + 1
    print("  catalogue breakdown:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print(
        "  NOTE: every catalogue URL is an unverified seed URL. "
        "Run tools/verify_catalogue.py before release."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
