#!/usr/bin/env python3
"""Unit tests for App Store Connect URL choices in ensure_push_provisioning."""

from __future__ import annotations

import unittest

from ensure_push_provisioning import capability_types


class FakeClient:
    def __init__(self, payload: dict) -> None:
        self.path = ""
        self.payload = payload

    def get(self, path: str) -> dict:
        self.path = path
        return self.payload


class CapabilityTypesTests(unittest.TestCase):
    def test_omits_limit_on_related_capabilities(self) -> None:
        client = FakeClient(
            {
                "data": [
                    {"attributes": {"capabilityType": "PUSH_NOTIFICATIONS"}},
                    {"attributes": {"capabilityType": "ICLOUD"}},
                ]
            }
        )
        types = capability_types(client, "82A759L64D")
        self.assertEqual(client.path, "/v1/bundleIds/82A759L64D/bundleIdCapabilities")
        self.assertNotIn("limit", client.path)
        self.assertEqual(types, {"PUSH_NOTIFICATIONS", "ICLOUD"})


if __name__ == "__main__":
    unittest.main()
