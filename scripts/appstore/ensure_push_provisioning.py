#!/usr/bin/env python3
"""Enable Push Notifications on the App ID and regenerate the CI profile.

Runs in the GitHub TestFlight environment. Prints capability/profile names only;
never prints API keys, JWTs, or provisioning-profile contents.
"""

from __future__ import annotations

import base64
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

API_BASE = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = os.environ.get("STATTIE_BUNDLE_ID", "com.stattie.app")
PROFILE_NAME = os.environ.get("STATTIE_PROFILE_NAME", "AppStore com.stattie.app CI")
PUSH_CAPABILITY = "PUSH_NOTIFICATIONS"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def der_ecdsa_to_raw(der: bytes) -> bytes:
    if not der or der[0] != 0x30:
        raise ValueError("OpenSSL did not return a DER ECDSA signature.")

    def parse_len(buf: bytes, index: int) -> tuple[int, int]:
        first = buf[index]
        if first < 0x80:
            return first, index + 1
        count = first & 0x7F
        value = int.from_bytes(buf[index + 1 : index + 1 + count], "big")
        return value, index + 1 + count

    _, index = parse_len(der, 1)
    if der[index] != 0x02:
        raise ValueError("ECDSA signature is missing r.")
    r_len, index = parse_len(der, index + 1)
    r = der[index : index + r_len]
    index += r_len
    if der[index] != 0x02:
        raise ValueError("ECDSA signature is missing s.")
    s_len, index = parse_len(der, index + 1)
    s = der[index : index + s_len]
    r = r.lstrip(b"\x00") or b"\x00"
    s = s.lstrip(b"\x00") or b"\x00"
    return r.rjust(32, b"\x00") + s.rjust(32, b"\x00")


def normalize_p8(raw: str) -> str:
    text = raw.strip().replace("\r\n", "\n")
    if "BEGIN PRIVATE KEY" in text:
        return text if text.endswith("\n") else text + "\n"
    body = "".join(text.split())
    lines = [body[i : i + 64] for i in range(0, len(body), 64)]
    return "-----BEGIN PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END PRIVATE KEY-----\n"


def make_token(issuer: str, key_id: str, p8_pem: str) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {
        "iss": issuer,
        "iat": now,
        "exp": now + 20 * 60,
        "aud": "appstoreconnect-v1",
    }
    signing_input = (
        f"{b64url(json.dumps(header, separators=(',', ':')).encode())}."
        f"{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    )
    with tempfile.NamedTemporaryFile("w", delete=False) as key_file:
        key_file.write(p8_pem)
        key_path = key_file.name
    try:
        os.chmod(key_path, 0o600)
        der = subprocess.check_output(
            ["openssl", "dgst", "-sha256", "-sign", key_path],
            input=signing_input.encode(),
        )
    finally:
        os.remove(key_path)
    return f"{signing_input}.{b64url(der_ecdsa_to_raw(der))}"


def api_error_message(body: str) -> str:
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return body.strip() or "empty App Store Connect error body"
    errors = payload.get("errors") or []
    parts = []
    for error in errors:
        title = error.get("title") or "Error"
        detail = error.get("detail") or ""
        code = error.get("code") or ""
        parts.append(": ".join(item for item in (code, title, detail) if item))
    return "; ".join(parts) or body.strip()


class AppStoreConnect:
    def __init__(self, token: str) -> None:
        self.token = token

    def request(self, method: str, path: str, payload: dict[str, Any] | None = None) -> Any:
        data = None if payload is None else json.dumps(payload).encode()
        url = path if path.startswith("https://") else f"{API_BASE}{path}"
        request = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", "replace")
            message = api_error_message(body)
            if error.code == 403:
                raise SystemExit(
                    "The App Store Connect API key cannot update identifiers or profiles. "
                    f"Enable Push Notifications on {BUNDLE_ID} and regenerate "
                    f"{PROFILE_NAME!r} in the Developer portal. Apple said: {message}"
                ) from error
            raise SystemExit(f"App Store Connect {method} {path} failed ({error.code}): {message}") from error

    def get(self, path: str) -> Any:
        return self.request("GET", path)

    def post(self, path: str, payload: dict[str, Any]) -> Any:
        return self.request("POST", path, payload)

    def delete(self, path: str) -> Any:
        return self.request("DELETE", path)


def extract_profile_plist(profile_content_b64: str) -> dict[str, Any]:
    cms = base64.b64decode(profile_content_b64)
    start = cms.find(b"<?xml")
    end = cms.find(b"</plist>")
    if start != -1 and end != -1:
        return plistlib.loads(cms[start : end + len(b"</plist>")])

    with tempfile.NamedTemporaryFile(suffix=".mobileprovision", delete=False) as handle:
        handle.write(cms)
        path = handle.name
    try:
        decoded = subprocess.check_output(["security", "cms", "-D", "-i", path])
        return plistlib.loads(decoded)
    finally:
        os.remove(path)


def profile_has_production_push(profile: dict[str, Any]) -> bool:
    attributes = profile.get("attributes") or {}
    content = attributes.get("profileContent")
    state = attributes.get("profileState")
    if not content or state != "ACTIVE":
        return False
    try:
        entitlements = extract_profile_plist(content).get("Entitlements") or {}
    except Exception:
        return False
    return entitlements.get("aps-environment") == "production"


def required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"{name} is required.")
    return value


def find_bundle(client: AppStoreConnect) -> dict[str, Any]:
    identifier = urllib.parse.quote(BUNDLE_ID, safe="")
    payload = client.get(f"/v1/bundleIds?filter[identifier]={identifier}&limit=200")
    matches = [
        item
        for item in payload.get("data") or []
        if (item.get("attributes") or {}).get("identifier") == BUNDLE_ID
    ]
    if not matches:
        raise SystemExit(f"No App Store Connect bundle ID found for {BUNDLE_ID}.")
    return matches[0]


def capability_types(client: AppStoreConnect, bundle_id: str) -> set[str]:
    # This related-resource endpoint rejects `limit`.
    payload = client.get(f"/v1/bundleIds/{bundle_id}/bundleIdCapabilities")
    types: set[str] = set()
    for item in payload.get("data") or []:
        capability = (item.get("attributes") or {}).get("capabilityType")
        if capability:
            types.add(capability)
    next_path = (payload.get("links") or {}).get("next") or ""
    while next_path:
        payload = client.get(next_path)
        for item in payload.get("data") or []:
            capability = (item.get("attributes") or {}).get("capabilityType")
            if capability:
                types.add(capability)
        next_path = (payload.get("links") or {}).get("next") or ""
    return types


def enable_push(client: AppStoreConnect, bundle_id: str) -> None:
    existing = capability_types(client, bundle_id)
    if PUSH_CAPABILITY in existing:
        print(f"{BUNDLE_ID} already has Push Notifications.")
        return
    print(f"Enabling Push Notifications on {BUNDLE_ID}.")
    try:
        client.post(
            "/v1/bundleIdCapabilities",
            {
                "data": {
                    "type": "bundleIdCapabilities",
                    "attributes": {"capabilityType": PUSH_CAPABILITY},
                    "relationships": {
                        "bundleId": {"data": {"type": "bundleIds", "id": bundle_id}}
                    },
                }
            },
        )
    except SystemExit as error:
        if "already" in str(error).lower() or "exists" in str(error).lower():
            print("Push Notifications was already enabled.")
            return
        raise
    print("Push Notifications is enabled.")


def list_named_profiles(client: AppStoreConnect) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    name = urllib.parse.quote(PROFILE_NAME, safe="")
    payload = client.get(
        "/v1/profiles"
        f"?filter[name]={name}"
        "&filter[profileType]=IOS_APP_STORE"
        "&include=certificates"
        "&fields[profiles]=name,profileState,profileType,profileContent"
        "&fields[certificates]=name,certificateType,displayName"
        "&limit=200"
    )
    profiles = []
    for item in payload.get("data") or []:
        if (item.get("attributes") or {}).get("name") == PROFILE_NAME:
            profiles.append(item)
    return profiles, payload.get("included") or []


def certificate_ids_for(profile: dict[str, Any], included: list[dict[str, Any]]) -> list[str]:
    rel = ((profile.get("relationships") or {}).get("certificates") or {}).get("data") or []
    ids = [item["id"] for item in rel if item.get("id")]
    if ids:
        return ids
    return [
        item["id"]
        for item in included
        if item.get("type") == "certificates" and item.get("id")
    ]


def distribution_certificate_ids(client: AppStoreConnect) -> list[str]:
    for certificate_type in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
        payload = client.get(
            f"/v1/certificates?filter[certificateType]={certificate_type}&limit=200"
        )
        ids = [item["id"] for item in payload.get("data") or [] if item.get("id")]
        if ids:
            return list(dict.fromkeys(ids))
    raise SystemExit("No Apple Distribution certificates were found for a new App Store profile.")


def delete_profile(client: AppStoreConnect, profile_id: str) -> None:
    client.delete(f"/v1/profiles/{profile_id}")


def create_profile(client: AppStoreConnect, bundle_id: str, certificate_ids: list[str]) -> dict[str, Any]:
    return client.post(
        "/v1/profiles",
        {
            "data": {
                "type": "profiles",
                "attributes": {
                    "name": PROFILE_NAME,
                    "profileType": "IOS_APP_STORE",
                },
                "relationships": {
                    "bundleId": {"data": {"type": "bundleIds", "id": bundle_id}},
                    "certificates": {
                        "data": [
                            {"type": "certificates", "id": certificate_id}
                            for certificate_id in certificate_ids
                        ]
                    },
                },
            }
        },
    )


def ensure_profile(client: AppStoreConnect, bundle_id: str) -> None:
    profiles, included = list_named_profiles(client)
    usable = [item for item in profiles if profile_has_production_push(item)]
    if usable:
        print(f"{PROFILE_NAME} already includes production push.")
        return

    certificate_ids: list[str] = []
    for profile in profiles:
        certificate_ids.extend(certificate_ids_for(profile, included))
    certificate_ids = list(dict.fromkeys(certificate_ids))
    if not certificate_ids:
        certificate_ids = distribution_certificate_ids(client)

    for profile in profiles:
        print(f"Removing stale profile {PROFILE_NAME}.")
        delete_profile(client, profile["id"])
    if profiles:
        time.sleep(2)

    print(f"Creating {PROFILE_NAME} with Push Notifications.")
    created = create_profile(client, bundle_id, certificate_ids)
    profile = created.get("data") or {}
    last_state = (profile.get("attributes") or {}).get("profileState")
    for _ in range(5):
        time.sleep(2)
        profiles, _ = list_named_profiles(client)
        if any(profile_has_production_push(item) for item in profiles):
            print(f"{PROFILE_NAME} now includes production push.")
            return
        if profiles:
            last_state = (profiles[0].get("attributes") or {}).get("profileState")
    raise SystemExit(
        f"Recreated {PROFILE_NAME}, but it still lacks production aps-environment "
        f"(state={last_state or 'unknown'})."
    )


def main() -> int:
    issuer = required_env("APPSTORE_ISSUER_ID")
    key_id = required_env("APPSTORE_API_KEY_ID")
    private_key = normalize_p8(required_env("APPSTORE_API_PRIVATE_KEY"))
    client = AppStoreConnect(make_token(issuer, key_id, private_key))
    bundle = find_bundle(client)
    bundle_id = bundle["id"]
    enable_push(client, bundle_id)
    ensure_profile(client, bundle_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
