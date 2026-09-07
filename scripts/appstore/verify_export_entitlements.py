#!/usr/bin/env python3
"""Verify the exported IPA has production CloudKit and push entitlements."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path


def load_codesign_entitlements(raw: bytes) -> dict:
    xml_start = raw.find(b"<?xml")
    if xml_start != -1:
        return plistlib.loads(raw[xml_start:])
    bplist_start = raw.find(b"bplist")
    if bplist_start != -1:
        return plistlib.loads(raw[bplist_start:])
    try:
        return plistlib.loads(raw)
    except plistlib.InvalidFileException as error:
        raise SystemExit(
            "codesign entitlements dump was not an XML or binary plist. "
            "Dump XML with `codesign -d --entitlements :-`."
        ) from error


def verify_production_entitlements(entitlements: dict) -> None:
    assert entitlements.get("aps-environment") == "production", (
        "Production push notifications are required for automatic iCloud sync"
    )
    assert "iCloud.com.stattie.app" in entitlements.get(
        "com.apple.developer.icloud-container-identifiers", []
    ), "Missing Stattie iCloud container"
    assert "CloudKit" in entitlements.get("com.apple.developer.icloud-services", []), (
        "Missing CloudKit entitlement"
    )
    assert entitlements.get("com.apple.developer.icloud-container-environment") == "Production", (
        "TestFlight must use production iCloud"
    )
    print("Verified production iCloud and push entitlements.")


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 1:
        raise SystemExit("usage: verify_export_entitlements.py <entitlements-dump>")
    entitlements = load_codesign_entitlements(Path(args[0]).read_bytes())
    verify_production_entitlements(entitlements)
    return 0


if __name__ == "__main__":
    sys.exit(main())
