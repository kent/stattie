"""Prepare Stattie's signing profile inside the protected TestFlight runner.

Only the existing CI certificate is reused. No profiles or certificates are
revoked, and credentials/profile contents are never written to logs.
"""

import base64
import datetime as dt
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

BUNDLE_ID = "com.stattie.app"
TEAM_ID = "PS5W7BFTQ2"
CONTAINER_ID = "iCloud.com.stattie.app"
PROFILE_NAME = "AppStore com.stattie.app CI"
CLOUD_PROFILE_NAME = PROFILE_NAME + " iCloud"
API_ORIGIN = "https://api.appstoreconnect.apple.com"


def encoded(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=")


def api_token():
    now = int(time.time())
    header = {"alg": "ES256", "kid": os.environ["APPSTORE_API_KEY_ID"], "typ": "JWT"}
    claims = {"iss": os.environ["APPSTORE_ISSUER_ID"], "iat": now, "exp": now + 600,
              "aud": "appstoreconnect-v1"}
    signing_input = b".".join(encoded(json.dumps(value).encode()) for value in (header, claims))
    # Ruby's bundled OpenSSL signs in memory; the private key stays in the
    # protected runner environment, never argv or a temporary key file.
    signer = '''require "openssl"
key = OpenSSL::PKey.read(ENV.fetch("APPSTORE_API_PRIVATE_KEY"))
der = key.sign(OpenSSL::Digest::SHA256.new, STDIN.read)
integers = OpenSSL::ASN1.decode(der).value
STDOUT.binmode
STDOUT.write([integers.map { |v| v.value.to_s(16).rjust(64, "0") }.join].pack("H*"))
'''
    result = subprocess.run(["ruby", "-e", signer], input=signing_input, capture_output=True)
    if result.returncode or len(result.stdout) != 64:
        raise RuntimeError("Could not sign the App Store Connect API token")
    return (signing_input + b"." + encoded(result.stdout)).decode()


class NoRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        raise RuntimeError("Refusing to forward Apple API authorization through a redirect")


class AppleAPI:
    def __init__(self, token):
        self.token = token

    def request(self, path, data=None):
        url = path if path.startswith("https://") else API_ORIGIN + path
        if urllib.parse.urlsplit(url).netloc != urllib.parse.urlsplit(API_ORIGIN).netloc:
            raise RuntimeError("Refusing an unexpected Apple API origin")
        request = urllib.request.Request(
            url, data=None if data is None else json.dumps({"data": data}).encode(),
            headers={"Authorization": "Bearer " + self.token, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.build_opener(NoRedirects()).open(request, timeout=45) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            # Report only Apple's error codes/titles, not response bodies that
            # may contain profile material or authorization details.
            payload = json.loads(error.read())
            reasons = "; ".join(f"{item.get('code')}: {item.get('title')}"
                                for item in payload.get("errors", []))
            raise RuntimeError(f"Apple API returned HTTP {error.code}: {reasons}") from None

    def records(self, path):
        records = []
        while path:
            response = self.request(path)
            records.extend(response["data"])
            path = response.get("links", {}).get("next")
        return records


def decode_profile(profile):
    raw = base64.b64decode(profile["attributes"]["profileContent"], validate=True)
    result = subprocess.run(["security", "cms", "-D"], input=raw, capture_output=True)
    if result.returncode:
        raise RuntimeError("Apple returned an unreadable provisioning profile")
    return plistlib.loads(result.stdout)


def certificate_ids(profile):
    return {item["id"] for item in profile["relationships"]["certificates"]["data"]}


def supports_icloud(profile, decoded):
    entitlements = decoded.get("Entitlements", {})
    environments = entitlements.get("com.apple.developer.icloud-container-environment", [])
    if isinstance(environments, str):
        environments = [environments]
    expiration = decoded.get("ExpirationDate", dt.datetime.min).replace(tzinfo=dt.timezone.utc)
    return (
        profile["attributes"]["profileState"] == "ACTIVE"
        and expiration > dt.datetime.now(dt.timezone.utc)
        and entitlements.get("application-identifier") == f"{TEAM_ID}.{BUNDLE_ID}"
        and entitlements.get("aps-environment") == "production"
        and CONTAINER_ID in entitlements.get("com.apple.developer.icloud-container-identifiers", [])
        and "CloudKit" in entitlements.get("com.apple.developer.icloud-services", [])
        and "Production" in environments
    )


def prepare_profile(api, decode=decode_profile):
    bundles = api.records("/v1/bundleIds?" + urllib.parse.urlencode({"filter[identifier]": BUNDLE_ID}))
    if len(bundles) != 1 or bundles[0]["attributes"]["identifier"] != BUNDLE_ID:
        raise RuntimeError("Could not uniquely resolve the Stattie bundle ID")
    bundle_id = bundles[0]["id"]
    query = urllib.parse.urlencode({"filter[profileType]": "IOS_APP_STORE",
                                  "include": "bundleId,certificates", "limit": 200})
    profiles = [profile for profile in api.records("/v1/profiles?" + query)
                if profile["relationships"]["bundleId"]["data"]["id"] == bundle_id]
    sources = [profile for profile in profiles if profile["attributes"]["name"] == PROFILE_NAME]
    if not sources:
        raise RuntimeError("The existing Stattie CI profile is required to identify its signing certificate")
    source = max(sources, key=lambda profile: profile["attributes"]["createdDate"])
    certificates = certificate_ids(source)
    if len(certificates) != 1:
        raise RuntimeError("The existing CI profile must identify one distribution certificate")

    # Reuse a compatible CI profile without changing the Apple account.
    for profile in profiles:
        name = profile["attributes"]["name"]
        if (name == PROFILE_NAME or name.startswith(CLOUD_PROFILE_NAME)) and certificate_ids(profile) == certificates:
            decoded = decode(profile)
            if supports_icloud(profile, decoded):
                return profile, decoded

    capabilities = api.records(f"/v1/bundleIds/{bundle_id}/bundleIdCapabilities")
    if not any(item["attributes"]["capabilityType"] == "PUSH_NOTIFICATIONS" for item in capabilities):
        api.request("/v1/bundleIdCapabilities", {
            "type": "bundleIdCapabilities", "attributes": {"capabilityType": "PUSH_NOTIFICATIONS"},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_id}}},
        })
        print("Enabled Push Notifications for the Stattie app ID.")

    # Keep the old profile for other workflows; create a separate compatible one.
    name = CLOUD_PROFILE_NAME
    if any(profile["attributes"]["name"] == name for profile in profiles):
        name += " " + str(int(time.time()))
    created = api.request("/v1/profiles", {
        "type": "profiles", "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle_id}},
            "certificates": {"data": [{"type": "certificates", "id": value} for value in sorted(certificates)]},
        },
    })["data"]
    decoded = decode(created)
    if not supports_icloud(created, decoded):
        raise RuntimeError("The regenerated profile still lacks production iCloud/push support")
    print("Created an iCloud-capable profile using the existing CI certificate.")
    return created, decoded


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise RuntimeError("Signing profile preparation runs only in protected GitHub Actions")
    profile, decoded = prepare_profile(AppleAPI(api_token()))
    profile_uuid = str(uuid.UUID(decoded["UUID"]))
    content = base64.b64decode(profile["attributes"]["profileContent"], validate=True)
    for directory in ("Library/Developer/Xcode/UserData/Provisioning Profiles",
                      "Library/MobileDevice/Provisioning Profiles"):
        destination = Path.home() / directory
        destination.mkdir(parents=True, exist_ok=True)
        installed = destination / f"{profile_uuid}.mobileprovision"
        installed.write_bytes(content)
        installed.chmod(0o600)
    options = plistlib.loads(Path("ci/ExportOptions.plist").read_bytes())
    options["provisioningProfiles"][BUNDLE_ID] = profile_uuid
    options_path = Path(os.environ["RUNNER_TEMP"]) / "StattieExportOptions.plist"
    options_path.write_bytes(plistlib.dumps(options))
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"profile_uuid={profile_uuid}\nexport_options={options_path}\n")
    print("Verified and installed the production iCloud signing profile.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, KeyError, ValueError) as error:
        raise SystemExit(str(error)) from None
