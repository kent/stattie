#!/usr/bin/env python3
"""Unit tests for App Store Connect URL choices in ensure_push_provisioning."""

from __future__ import annotations

import json
import unittest
from io import BytesIO
from unittest import mock
from urllib.error import HTTPError

from ensure_push_provisioning import AppStoreConnect, capability_types


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


class RequestRetryTests(unittest.TestCase):
    def test_retries_post_after_apple_500(self) -> None:
        error = HTTPError(
            "https://api.appstoreconnect.apple.com/v1/profiles",
            500,
            "server error",
            hdrs=None,
            fp=BytesIO(json.dumps({"errors": [{"title": "An unexpected error occurred."}]}).encode()),
        )
        success = mock.MagicMock()
        success.read.return_value = json.dumps({"data": {"id": "profile-1"}}).encode()
        success.__enter__.return_value = success
        success.__exit__.return_value = False

        with (
            mock.patch(
                "ensure_push_provisioning.urllib.request.urlopen",
                side_effect=[error, success],
            ) as urlopen,
            mock.patch("ensure_push_provisioning.time.sleep") as slept,
        ):
            result = AppStoreConnect("token").post("/v1/profiles", {"data": {}})

        self.assertEqual(result["data"]["id"], "profile-1")
        self.assertEqual(urlopen.call_count, 2)
        slept.assert_called_once()


if __name__ == "__main__":
    unittest.main()
