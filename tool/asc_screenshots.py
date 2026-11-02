"""Upload the six current iPhone screenshots to the Turkish App Store listing.

Uses the existing App Store Connect API key in ~/.appstoreconnect/private_keys.
The script keeps the two existing screenshots and places the new six first.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import time
from pathlib import Path

import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature


APP_ID = "6810047270"
ISSUER_ID = "4b9c07a9-b262-42a3-9d17-71fa084b9a1e"
KEY_ID = "BKSYBN34QY"
KEY_PATH = Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{KEY_ID}.p8"
SCREENSHOT_DIR = Path(__file__).resolve().parents[1] / "artifacts/app-store-screenshots-69"
BASE = "https://api.appstoreconnect.apple.com/v1"


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token() -> str:
    now = int(time.time())
    head = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}, separators=(",", ":")).encode())
    payload = b64(json.dumps({"iss": ISSUER_ID, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}, separators=(",", ":")).encode())
    signed = f"{head}.{payload}".encode()
    key = serialization.load_pem_private_key(KEY_PATH.read_bytes(), password=None)
    der = key.sign(signed, ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(der)
    return f"{head}.{payload}.{b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


def api(method: str, route: str, *, params=None, body=None):
    response = requests.request(
        method,
        f"{BASE}{route}",
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
        params=params,
        json=body,
        timeout=60,
    )
    if not response.ok:
        raise RuntimeError(f"{method} {route}: {response.status_code} {response.text[:1500]}")
    return response.json() if response.content else {}


def find_set() -> str:
    versions = api("GET", f"/apps/{APP_ID}/appStoreVersions", params={"limit": 200})["data"]
    version = next(v for v in versions if v["attributes"]["platform"] == "IOS" and v["attributes"]["appStoreState"] == "PREPARE_FOR_SUBMISSION")
    localizations = api("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations", params={"limit": 200})["data"]
    localization = next(v for v in localizations if v["attributes"]["locale"] == "tr")
    sets = api("GET", f"/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets", params={"limit": 200})["data"]
    target = next(s for s in sets if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67")
    return target["id"]


def list_screenshots(set_id: str):
    return api("GET", f"/appScreenshotSets/{set_id}/appScreenshots", params={"limit": 200})["data"]


def upload(path: Path, set_id: str) -> str:
    contents = path.read_bytes()
    reservation = api("POST", "/appScreenshots", body={"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": path.name, "fileSize": len(contents)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
    }})["data"]
    for op in reservation["attributes"]["uploadOperations"]:
        chunk = contents[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        response = requests.request(op["method"], op["url"], headers=headers, data=chunk, timeout=120)
        if not response.ok:
            raise RuntimeError(f"Upload {path.name}: {response.status_code} {response.text[:500]}")
    api("PATCH", f"/appScreenshots/{reservation['id']}", body={"data": {
        "type": "appScreenshots", "id": reservation["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(contents).hexdigest()},
    }})
    print(f"Uploaded {path.name}: {reservation['id']}", flush=True)
    return reservation["id"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upload", action="store_true", help="Upload and reorder, otherwise only list")
    args = parser.parse_args()
    set_id = find_set()
    existing = list_screenshots(set_id)
    print(f"Screenshot set: {set_id}")
    print("Existing:", [(x["attributes"]["fileName"], x["id"], x["attributes"].get("assetDeliveryState", {}).get("state")) for x in existing])
    if not args.upload:
        return
    names = ["01-ana-sayfa.png", "02-grup-detayi.png", "03-grup-uyeleri.png", "04-gruplarim.png", "05-siralama.png", "06-katilim-istekleri.png"]
    by_name = {x["attributes"]["fileName"]: x["id"] for x in existing}
    for name in names:
        if name not in by_name:
            by_name[name] = upload(SCREENSHOT_DIR / name, set_id)
    ordered = [by_name[n] for n in names] + [x["id"] for x in existing if x["attributes"]["fileName"] not in names]
    api("PATCH", f"/appScreenshotSets/{set_id}/relationships/appScreenshots", body={
        "data": [{"type": "appScreenshots", "id": item} for item in ordered]
    })
    final = list_screenshots(set_id)
    print("Final order:", [x["attributes"]["fileName"] for x in final])


if __name__ == "__main__":
    main()
