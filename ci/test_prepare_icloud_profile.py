import copy
import datetime as dt
import unittest
from unittest.mock import patch

from ci import prepare_icloud_profile as signing


def profile(name=signing.PROFILE_NAME, identifier="original", certificate="ci-certificate", bundle="stattie"):
    return {
        "id": identifier,
        "attributes": {"name": name, "createdDate": "2026-08-30", "profileState": "ACTIVE"},
        "relationships": {"bundleId": {"data": {"id": bundle}},
                          "certificates": {"data": [{"id": certificate}]}},
    }


def decoded(push=True):
    return {
        "ExpirationDate": dt.datetime.now() + dt.timedelta(days=30),
        "Entitlements": {
            "application-identifier": signing.TEAM_ID + "." + signing.BUNDLE_ID,
            "aps-environment": "production" if push else None,
            "com.apple.developer.icloud-container-identifiers": [signing.CONTAINER_ID],
            "com.apple.developer.icloud-services": ["CloudKit"],
            "com.apple.developer.icloud-container-environment": ["Development", "Production"],
        },
    }


class FakeAPI:
    def __init__(self, profiles, capabilities=()):
        self.profiles = profiles
        self.capabilities = capabilities
        self.mutations = []

    def records(self, path):
        if path.startswith("/v1/bundleIds?"):
            return [{"id": "stattie", "attributes": {"identifier": signing.BUNDLE_ID}}]
        if path.startswith("/v1/profiles?"):
            return self.profiles
        if path == "/v1/bundleIds/stattie/bundleIdCapabilities":
            return [{"attributes": {"capabilityType": value}} for value in self.capabilities]
        raise AssertionError(path)

    def request(self, path, data):
        self.mutations.append((path, copy.deepcopy(data)))
        return {"data": profile(signing.CLOUD_PROFILE_NAME, identifier="created")}


class SigningProfileTests(unittest.TestCase):
    def setUp(self):
        # Fixture repairs must not look like changes to the real Apple account.
        silence = patch("builtins.print")
        silence.start()
        self.addCleanup(silence.stop)

    def test_reuses_compatible_profile_without_mutating_apple_account(self):
        existing = profile()
        api = FakeAPI([existing])
        selected, _ = signing.prepare_profile(api, decode=lambda _: decoded())
        self.assertEqual(selected, existing)
        self.assertEqual(api.mutations, [])

    def test_repairs_missing_push_and_preserves_existing_certificate(self):
        api = FakeAPI([profile()], capabilities=["ICLOUD"])
        selected, _ = signing.prepare_profile(api, decode=lambda row: decoded(row["id"] != "original"))
        self.assertEqual(selected["id"], "created")
        self.assertEqual([path for path, _ in api.mutations], ["/v1/bundleIdCapabilities", "/v1/profiles"])
        capability = api.mutations[0][1]
        self.assertEqual(capability["attributes"]["capabilityType"], "PUSH_NOTIFICATIONS")
        self.assertEqual(capability["relationships"]["bundleId"]["data"]["id"], "stattie")
        created = api.mutations[1][1]
        self.assertEqual(created["relationships"]["certificates"]["data"],
                         [{"type": "certificates", "id": "ci-certificate"}])
        self.assertEqual(created["attributes"]["profileType"], "IOS_APP_STORE")

    def test_does_not_enable_push_twice(self):
        api = FakeAPI([profile()], capabilities=["ICLOUD", "PUSH_NOTIFICATIONS"])
        signing.prepare_profile(api, decode=lambda row: decoded(row["id"] == "created"))
        self.assertEqual([path for path, _ in api.mutations], ["/v1/profiles"])

    def test_cannot_use_another_distribution_certificate(self):
        other = profile(signing.CLOUD_PROFILE_NAME, "other", certificate="other-certificate")
        api = FakeAPI([profile(), other])
        selected, _ = signing.prepare_profile(api, decode=lambda row: decoded(row["id"] != "original"))
        self.assertEqual(selected["id"], "created")
        self.assertEqual(api.mutations[-1][1]["relationships"]["certificates"]["data"][0]["id"], "ci-certificate")

    def test_cannot_change_another_app(self):
        api = FakeAPI([profile(bundle="another-app")])
        with self.assertRaisesRegex(RuntimeError, "existing Stattie CI profile"):
            signing.prepare_profile(api, decode=lambda _: decoded())
        self.assertEqual(api.mutations, [])

    def test_does_not_guess_a_certificate_without_the_existing_profile(self):
        api = FakeAPI([])
        with self.assertRaises(RuntimeError):
            signing.prepare_profile(api)
        self.assertEqual(api.mutations, [])

    def test_rejects_a_regenerated_profile_without_production_push(self):
        api = FakeAPI([profile()])
        with self.assertRaisesRegex(RuntimeError, "still lacks"):
            signing.prepare_profile(api, decode=lambda _: decoded(False))

    def test_rejects_expired_or_wrong_team_profiles(self):
        values = decoded()
        values["ExpirationDate"] = dt.datetime(2020, 1, 1)
        self.assertFalse(signing.supports_icloud(profile(), values))
        values = decoded()
        values["Entitlements"]["application-identifier"] = "OTHER.com.stattie.app"
        self.assertFalse(signing.supports_icloud(profile(), values))

    def test_rejects_development_cloud_environment(self):
        values = decoded()
        values["Entitlements"]["com.apple.developer.icloud-container-environment"] = ["Development"]
        self.assertFalse(signing.supports_icloud(profile(), values))

    def test_never_sends_authorization_to_another_origin(self):
        with self.assertRaisesRegex(RuntimeError, "unexpected Apple API origin"):
            signing.AppleAPI("synthetic-test-token").request("https://example.com/profiles")


if __name__ == "__main__":
    unittest.main()
