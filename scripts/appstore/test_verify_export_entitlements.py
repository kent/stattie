#!/usr/bin/env python3
"""Tests for IPA entitlement dump parsing."""

from __future__ import annotations

import plistlib
import tempfile
import unittest
from pathlib import Path

from verify_export_entitlements import load_codesign_entitlements, main, verify_production_entitlements

SAMPLE = {
    "aps-environment": "production",
    "com.apple.developer.icloud-container-identifiers": ["iCloud.com.stattie.app"],
    "com.apple.developer.icloud-services": ["CloudKit"],
    "com.apple.developer.icloud-container-environment": "Production",
}


class EntitlementDumpTests(unittest.TestCase):
    def test_reads_xml_plist(self) -> None:
        raw = plistlib.dumps(SAMPLE, fmt=plistlib.FMT_XML)
        self.assertEqual(load_codesign_entitlements(raw)["aps-environment"], "production")

    def test_skips_codesign_stdout_prefix(self) -> None:
        raw = b"Executable=/tmp/Stattie.app\n" + plistlib.dumps(SAMPLE, fmt=plistlib.FMT_XML)
        self.assertEqual(load_codesign_entitlements(raw)["aps-environment"], "production")

    def test_reads_binary_plist(self) -> None:
        raw = plistlib.dumps(SAMPLE, fmt=plistlib.FMT_BINARY)
        self.assertEqual(load_codesign_entitlements(raw)["aps-environment"], "production")

    def test_rejects_der_blob(self) -> None:
        with self.assertRaises(SystemExit):
            load_codesign_entitlements(b"\x30\x82\x01\x00not-a-plist")

    def test_verify_accepts_production_payload(self) -> None:
        verify_production_entitlements(SAMPLE)

    def test_main_reads_prefixed_xml_file(self) -> None:
        raw = b"Executable=/tmp/Stattie.app\n" + plistlib.dumps(SAMPLE, fmt=plistlib.FMT_XML)
        with tempfile.NamedTemporaryFile(delete=False) as handle:
            handle.write(raw)
            path = handle.name
        self.assertEqual(main([path]), 0)


if __name__ == "__main__":
    unittest.main()
