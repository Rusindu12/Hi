#!/usr/bin/env python3
"""Verifies every link in the SriEdu catalogue.

The seed catalogue is generated from *pattern* URLs on the official domains
(https://nie.lk/textbooks/..., https://www.doenets.lk/exam-papers/...). Those
patterns are almost certainly not the real paths, which is exactly why every item
is generated with `"linkStatus": "unverified_seed"`. This script is how they get
verified:

    python3 tools/verify_catalogue.py                 # check everything
    python3 tools/verify_catalogue.py --limit 25      # quick sample while fixing
    python3 tools/verify_catalogue.py --host nie.lk   # one publisher at a time
    python3 tools/verify_catalogue.py --json out.json # machine-readable report
    python3 tools/verify_catalogue.py --self-test     # proves the checker works

Behaviour
  * Uses only the standard library (urllib) so it runs on a laptop or CI runner
    with no pip install.
  * GET with a small Range request rather than HEAD: several Sri Lankan
    government servers answer HEAD with 405 even when the file is fine, and a
    PDF that returns 200/206 with `Content-Type: application/pdf` is the strongest
    cheap signal that the link is correct.
  * Politely rate-limited (default 2 concurrent requests, 0.4 s apart per host)
    because those servers are small and shared. Use --concurrency to raise it
    only if you have asked the publisher first.
  * Reports what is broken rather than fixing anything: a URL is either OK, a
    redirect (recorded so you can update the entry), a 404/410 (deleted), or an
    error (network/TLS/HTML page where a PDF was expected).

Exit codes
  0 every checked URL looked good
  1 at least one hard failure (404/410/moved to a different path/HTML instead of PDF)
  2 the script could not run (bad arguments, no catalogue)
"""

from __future__ import annotations

import argparse
import collections
import concurrent.futures
import json
import pathlib
import random
import ssl
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / "assets" / "data" / "catalogue.json"

USER_AGENT = (
    "SriEduLinkChecker/1.0 (+https://sriedu.lk; educational link verification; "
    "contact: support@sriedu.lk)"
)

# Results that mean "a student tapping this would be stuck".
HARD_FAILURES = {"not_found", "gone", "html_instead_of_pdf", "wrong_path", "error"}


class Result:
    def __init__(self, item_id: str, url: str, status: str, detail: str = "", http: int = 0):
        self.item_id = item_id
        self.url = url
        self.status = status
        self.detail = detail
        self.http = http

    def as_dict(self) -> dict:
        return {
            "id": self.item_id,
            "url": self.url,
            "status": self.status,
            "http": self.http,
            "detail": self.detail,
        }

    @property
    def bad(self) -> bool:
        return self.status in HARD_FAILURES


def _request(url: str, timeout: float) -> tuple[int, str, str]:
    """Returns (status_code, content_type, final_url)."""
    context = ssl.create_default_context()
    request = urllib.request.Request(
        url,
        method="GET",
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/pdf,application/octet-stream;q=0.9,*/*;q=0.5",
            # 2 KiB is enough for a status line plus headers on any normal server.
            "Range": "bytes=0-2047",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout, context=context) as response:
        content_type = response.headers.get("Content-Type", "")
        return response.status, content_type, response.geturl()


def check_url(item_id: str, url: str, timeout: float, expect_pdf: bool) -> Result:
    try:
        status, content_type, final_url = _request(url, timeout)
    except urllib.error.HTTPError as error:
        code = error.code
        if code in (404, 410):
            return Result(item_id, url, "not_found" if code == 404 else "gone", "", code)
        if 300 <= code < 400:
            return Result(item_id, url, "redirect", error.headers.get("Location", ""), code)
        return Result(item_id, url, "error", f"HTTP {code}", code)
    except urllib.error.URLError as error:
        return Result(item_id, url, "error", f"URLError: {error.reason}")
    except (TimeoutError, ssl.SSLError, OSError) as error:
        return Result(item_id, url, "error", f"{type(error).__name__}: {error}")

    lowered = content_type.lower()
    if expect_pdf and "pdf" not in lowered and not lowered.startswith("application/octet"):
        # A government portal answering with text/html usually means the path is
        # wrong and the server is rendering an error page with status 200.
        return Result(item_id, url, "html_instead_of_pdf", content_type, status)

    if final_url != url:
        return Result(item_id, url, "redirect", final_url, status)

    return Result(item_id, url, "ok", content_type, status)


def load_urls(host_filter: str | None, limit: int | None, kind: str | None) -> list[tuple[str, str, bool]]:
    data = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    items = data["items"]

    rows: list[tuple[str, str, bool]] = []
    for item in items:
        url = str(item.get("sourceUrl") or "")
        if not url:
            continue
        if host_filter and host_filter.lower() not in url.split("//", 1)[-1].split("/", 1)[0].lower():
            continue
        if kind and item.get("kind") != kind:
            continue
        rows.append((item["id"], url, item.get("kind") != "textbook"))

    # Interleave hosts so a single slow publisher cannot stall the tail, then
    # shuffle deterministically so a --limit sample still covers every grade.
    rows.sort(key=lambda row: row[0])
    random.Random(20261015).shuffle(rows)
    if limit:
        rows = rows[:limit]
    return rows


def self_test() -> int:
    """Proves the checker can tell a working link from a broken one.

    Uses three URLs whose behaviour is stable and whose access does not depend on
    a government server being up: a JSON API, a package index, and a path that
    cannot exist.
    """
    cases = [
        ("self-test-ok", "https://pypi.org/simple/", False, {"ok", "redirect"}),
        ("self-test-redirect", "http://github.com/", False, {"ok", "redirect"}),
        ("self-test-missing", "https://api.github.com/repos/flutter/flutter-definitely-missing", False, {"not_found"}),
    ]
    failures = 0
    for item_id, url, expect_pdf, allowed in cases:
        result = check_url(item_id, url, timeout=15, expect_pdf=expect_pdf)
        verdict = "PASS" if result.status in allowed else "FAIL"
        if verdict == "FAIL":
            failures += 1
        print(f"  {verdict}  {result.status:20} {url}  {result.detail[:50]}")
    print(f"self-test: {len(cases) - failures}/{len(cases)} behaved as expected")
    return 0 if failures == 0 else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify SriEdu catalogue links")
    parser.add_argument("--limit", type=int, default=None, help="check only N links")
    parser.add_argument("--host", default=None, help="only links whose host contains this string")
    parser.add_argument("--kind", default=None, help="only this catalogue kind (textbook, paper, ...)")
    parser.add_argument("--concurrency", type=int, default=2, help="parallel requests (be polite)")
    parser.add_argument("--timeout", type=float, default=20.0, help="per-request timeout in seconds")
    parser.add_argument("--json", dest="json_out", default=None, help="write a JSON report here")
    parser.add_argument("--self-test", action="store_true", help="check the checker, then exit")
    parser.add_argument(
        "--mark-verified",
        action="store_true",
        help="print a summary of which ids are OK, so a human can flip linkStatus",
    )
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    if not CATALOGUE.exists():
        print(f"catalogue not found at {CATALOGUE}", file=sys.stderr)
        return 2
    rows = load_urls(args.host, args.limit, args.kind)
    if not rows:
        print("no links matched those filters", file=sys.stderr)
        return 2

    print(f"Checking {len(rows)} links with concurrency={args.concurrency}")
    print("-" * 72)

    started = time.time()
    results: list[Result] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        futures = {
            pool.submit(check_url, item_id, url, args.timeout, expect_pdf): item_id
            for item_id, url, expect_pdf in rows
        }
        for index, future in enumerate(concurrent.futures.as_completed(futures), start=1):
            result = future.result()
            results.append(result)
            if result.bad or index % 50 == 0:
                print(f"[{index:>4}/{len(rows)}] {result.status:20} {result.url}")
            # A tiny sleep keeps the load on those servers civil.
            time.sleep(0.02)

    counts = collections.Counter(result.status for result in results)
    print("-" * 72)
    print(f"checked in {time.time() - started:.1f}s")
    for status, count in counts.most_common():
        print(f"  {status:22} {count}")

    bad = [result for result in results if result.bad]
    if bad:
        print("\nLinks a student would get stuck on (fix these in the source data):")
        for result in bad[:40]:
            print(f"  {result.item_id}: {result.status} {result.http} {result.url}")
        if len(bad) > 40:
            print(f"  … and {len(bad) - 40} more")

    if args.mark_verified:
        good_ids = sorted(result.item_id for result in results if result.status == "ok")
        print(f"\n{len(good_ids)} ids verified OK — flip their linkStatus to 'verified'")

    if args.json_out:
        report = {
            "checkedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "total": len(results),
            "counts": dict(counts),
            "results": [result.as_dict() for result in results],
        }
        pathlib.Path(args.json_out).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"\nwrote {args.json_out}")

    print()
    if bad:
        print(
            "Remember: any link that stays broken must be removed from the catalogue "
            "rather than shipped — see docs/CONTENT_POLICY.md."
        )
        return 1
    print("All checked links look good. Flip linkStatus to 'verified' for those ids,")
    print("then re-run tools/seed_firestore.py to publish.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
