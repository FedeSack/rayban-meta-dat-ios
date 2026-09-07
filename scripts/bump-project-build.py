#!/usr/bin/env python3
"""Bump CURRENT_PROJECT_VERSION in GlassesDAT.xcodeproj. Never reuse or decrease.

Used by scripts/macos-archive-ipa.sh before archive. BUILD_NUMBER overrides the
next value when it is a positive integer strictly greater than the current one.
Does not touch secrets, certificates, or Meta placeholders.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

BUILD_LINE = re.compile(r"(CURRENT_PROJECT_VERSION = )([^;]+)(;)")
MARKETING_LINE = re.compile(r"MARKETING_VERSION = ([^;]+);")
SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
POSITIVE_INT = re.compile(r"^[1-9][0-9]*$")


def die(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_versions(text: str) -> tuple[str, int]:
    builds = [m.group(2).strip() for m in BUILD_LINE.finditer(text)]
    marketings = [m.group(1).strip() for m in MARKETING_LINE.finditer(text)]
    if not builds:
        die("no CURRENT_PROJECT_VERSION in pbxproj")
    if not marketings:
        die("no MARKETING_VERSION in pbxproj")

    parsed: list[int] = []
    for raw in builds:
        if not POSITIVE_INT.fullmatch(raw):
            die(f"CURRENT_PROJECT_VERSION must be a positive integer (got {raw!r})")
        parsed.append(int(raw))
    if len(set(parsed)) != 1:
        die(f"inconsistent CURRENT_PROJECT_VERSION values in pbxproj: {parsed}")

    marketing_values = list(dict.fromkeys(marketings))
    if len(marketing_values) != 1:
        die(f"inconsistent MARKETING_VERSION values in pbxproj: {marketing_values}")
    marketing = marketing_values[0]
    if not SEMVER.fullmatch(marketing):
        die(f"MARKETING_VERSION must be MAJOR.MINOR.PATCH (got {marketing!r})")
    return marketing, parsed[0]


def next_build(current: int, override: str | None) -> int:
    if override is None or override == "":
        return current + 1
    if not POSITIVE_INT.fullmatch(override):
        die(f"BUILD_NUMBER must be a positive integer (got {override!r})")
    new = int(override)
    if new <= current:
        die(
            f"BUILD_NUMBER {new} must be greater than current "
            f"CURRENT_PROJECT_VERSION {current} (never reuse or decrease)"
        )
    return new


def apply_build(text: str, new_build: int) -> str:
    updated, count = BUILD_LINE.subn(rf"\g<1>{new_build}\3", text)
    if count == 0:
        die("failed to write CURRENT_PROJECT_VERSION")
    return updated


def format_report(marketing: str, build: int) -> str:
    return "\n".join(
        [
            f"MARKETING_VERSION={marketing}",
            f"CURRENT_PROJECT_VERSION={build}",
            f"CFBundleShortVersionString={marketing}",
            f"CFBundleVersion={build}",
            f"version={marketing} ({build})",
            f"git_tag=v{marketing}+{build}",
        ]
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Increment CURRENT_PROJECT_VERSION before a TestFlight/IPA archive."
    )
    parser.add_argument("pbxproj", help="Path to project.pbxproj")
    parser.add_argument(
        "--build-number",
        default="",
        help="Absolute next build (must be > current). Default: current + 1.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the next versions without writing the pbxproj.",
    )
    args = parser.parse_args(argv)

    path = Path(args.pbxproj)
    if not path.is_file():
        die(f"missing Xcode project at {path}")

    text = path.read_text()
    marketing, current = read_versions(text)
    new_build = next_build(current, args.build_number)
    if not args.dry_run:
        path.write_text(apply_build(text, new_build))
    print(format_report(marketing, new_build))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
