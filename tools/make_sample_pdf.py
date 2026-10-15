#!/usr/bin/env python3
"""Writes assets/data/sample_textbook.pdf — a small, self-authored PDF used to
demo the reader with no network.

Why generate it: we cannot bundle a real textbook (copyright) and we do not want
the reader to be untestable offline. This file is written from scratch with the
standard library only (no reportlab), so it is reproducible on any machine and
carries zero third-party licensing.

Run:  python3 tools/make_sample_pdf.py
"""

from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "data" / "sample_textbook.pdf"

PAGES = [
    (
        "SriEdu Sample Reading",
        [
            "This is a generated sample document.",
            "",
            "It exists so the in-app PDF reader can be demonstrated and tested",
            "without downloading a real textbook, and without a network",
            "connection of any kind.",
            "",
            "The file is produced by tools/make_sample_pdf.py using only the",
            "Python standard library, so it is reproducible and carries no",
            "third-party licence obligations.",
            "",
            "Use it to check: page rendering, pinch zoom, page restoration",
            "(reopen and you should land back on the page you left), and the",
            "reader's ad-free guarantee.",
        ],
    ),
    (
        "How the catalogue works",
        [
            "Textbooks and past papers are published by government bodies.",
            "SriEdu does not re-host them. Each catalogue item stores:",
            "",
            "  id          a stable identifier, e.g. ol-2023-science-ta",
            "  kind        textbook | paper | term_test | marking_scheme",
            "  examType    ol | al | grade5 | term",
            "  grade       the school grade (1-13)",
            "  year        exam year, for papers",
            "  medium      en | si | ta",
            "  rights      official_link | open_license | bundled",
            "  sourceUrl   the canonical publisher URL",
            "",
            "Only items whose rights allow it are ever offered for offline",
            "download. Everything else opens on the publisher's site.",
        ],
    ),
    (
        "Quiz data model",
        [
            "Questions live in the Firestore collection 'questions', mirrored",
            "by assets/data/sample_questions.json for offline use.",
            "",
            "Each question carries:",
            "",
            "  subject         subject code, e.g. mathematics",
            "  grade           grade level",
            "  year            exam year the question came from",
            "  examType        ol | al | grade5 | term",
            "  medium          medium of the source paper",
            "  questionText    { en, si, ta }",
            "  options         [ { en, si, ta }, ... ] four of them",
            "  correctAnswer   zero-based index into options",
            "  explanation     { en, si, ta }, shown after answering",
            "",
            "Question banks can also be stored as a single document per",
            "subject/exam/year, which costs one read per quiz and needs no",
            "composite index.",
        ],
    ),
    (
        "Streak rules",
        [
            "A day counts towards the streak when the student either:",
            "",
            "  * opens a textbook or past paper (in-app or at its source), or",
            "  * completes a quiz attempt.",
            "",
            "Rules:",
            "",
            "  * Consecutive calendar days build the streak.",
            "  * One missed day breaks it, unless a streak freeze is spent.",
            "  * One free freeze per calendar week.",
            "  * Longest streak and lifetime study days are never reset.",
            "",
            "Everything is stored on the device. No account, no upload.",
        ],
    ),
]

BASE_FONTS = "F1 Helvetica F2 Helvetica-Bold"


def escape(text: str) -> str:
    return text.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")


def content_stream(title: str, lines: list[str]) -> bytes:
    parts = [
        "BT",
        "/F2 22 Tf",
        "72 770 Td",
        f"({escape(title)}) Tj",
        "ET",
        "0.15 0.55 0.6 RG",
        "1.4 w",
        "72 758 m 523 758 l S",
        "0.06 0.09 0.16 rg",
        "BT",
        "/F1 12 Tf",
        "18 TL",
        "72 730 Td",
    ]
    for line in lines:
        parts.append(f"({escape(line)}) Tj T*")
    parts.append("ET")
    # Footer
    parts += [
        "0.45 0.5 0.58 rg",
        "BT",
        "/F1 9 Tf",
        "72 60 Td",
        "(SriEdu generated sample - safe to redistribute) Tj",
        "ET",
    ]
    return ("\n".join(parts) + "\n").encode("latin-1")


def build() -> bytes:
    page_count = len(PAGES)
    # Object numbering: 1 catalog, 2 pages, 3 font bold, 4 font regular,
    # then per page: page object and content object.
    objects: dict[int, bytes] = {}
    page_obj_ids = [5 + i * 2 for i in range(page_count)]
    content_obj_ids = [6 + i * 2 for i in range(page_count)]

    objects[1] = b"<< /Type /Catalog /Pages 2 0 R >>"
    kids = " ".join(f"{pid} 0 R" for pid in page_obj_ids)
    objects[2] = (
        f"<< /Type /Pages /Kids [{kids}] /Count {page_count} >>".encode("latin-1")
    )
    objects[3] = b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>"
    objects[4] = b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"

    for index, (title, lines) in enumerate(PAGES):
        page_id = page_obj_ids[index]
        content_id = content_obj_ids[index]
        stream = content_stream(title, lines)
        objects[page_id] = (
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
            f"/Resources << /Font << /F1 4 0 R /F2 3 0 R >> >> "
            f"/Contents {content_id} 0 R >>"
        ).encode("latin-1")
        objects[content_id] = (
            f"<< /Length {len(stream)} >>\nstream\n".encode("latin-1")
            + stream
            + b"endstream"
        )

    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets: dict[int, int] = {}
    for obj_id in sorted(objects):
        offsets[obj_id] = len(out)
        out += f"{obj_id} 0 obj\n".encode("latin-1")
        out += objects[obj_id]
        out += b"\nendobj\n"

    xref_offset = len(out)
    max_id = max(objects) + 1
    out += f"xref\n0 {max_id}\n".encode("latin-1")
    out += b"0000000000 65535 f \n"
    for obj_id in range(1, max_id):
        out += f"{offsets.get(obj_id, 0):010d} 00000 n \n".encode("latin-1")
    out += (
        f"trailer\n<< /Size {max_id} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n"
    ).encode("latin-1")
    return bytes(out)


def main() -> int:
    data = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(data)
    print(f"wrote {OUT.relative_to(ROOT)} ({len(data)} bytes, {len(PAGES)} pages)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
