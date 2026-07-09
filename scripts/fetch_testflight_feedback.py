#!/usr/bin/env python3
"""
fetch_testflight_feedback.py
Fetches TestFlight beta feedback (screenshots + crashes) from the App Store Connect API
and saves them to a local folder for analysis.

Usage:
    python3 scripts/fetch_testflight_feedback.py

Environment variables (or pass via .env):
    ASC_KEY_ID       — API Key ID (e.g. "D383SF739")
    ASC_ISSUER_ID    — Issuer ID (UUID from App Store Connect)
    ASC_KEY_PATH     — Path to your .p8 private key file
    ASC_BUNDLE_ID    — (optional) filter to a specific app bundle ID
    OUTPUT_DIR       — (optional) where to save output, default: testflight-feedback/
"""

import os
import sys
import json
import time
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime, timezone


# ── Optional: load a .env file from the project root ──────────────────────────
def load_dotenv(path=".env"):
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    except FileNotFoundError:
        pass


load_dotenv()

# ── Config ─────────────────────────────────────────────────────────────────────
KEY_ID = os.environ.get("ASC_KEY_ID", "")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "")
KEY_PATH = os.environ.get("ASC_KEY_PATH", "")
BUNDLE_ID = os.environ.get("ASC_BUNDLE_ID", "")  # optional filter
OUTPUT_DIR = Path(os.environ.get("OUTPUT_DIR", "testflight-feedback"))

BASE_URL = "https://api.appstoreconnect.apple.com/v1"


# ── JWT generation (no third-party deps) ──────────────────────────────────────
def _b64url(data: bytes) -> str:
    import base64

    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def generate_jwt() -> str:
    """Build a signed JWT for App Store Connect API auth."""
    try:
        from cryptography.hazmat.primitives import serialization, hashes
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.hazmat.backends import default_backend
    except ImportError:
        sys.exit(
            "Missing dependency: pip install cryptography\n"
            "Or: pip3 install cryptography"
        )

    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,  # 20 minutes, Apple's max
        "aud": "appstoreconnect-v1",
    }

    header_b64 = _b64url(json.dumps(header, separators=(",", ":")).encode())
    payload_b64 = _b64url(json.dumps(payload, separators=(",", ":")).encode())
    signing_input = f"{header_b64}.{payload_b64}".encode()

    key_text = Path(KEY_PATH).read_bytes()
    private_key = serialization.load_pem_private_key(
        key_text, password=None, backend=default_backend()
    )
    signature = private_key.sign(signing_input, ec.ECDSA(hashes.SHA256()))

    # DER → raw (r || s)  for JWT ES256
    from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

    r, s = decode_dss_signature(signature)
    raw_sig = r.to_bytes(32, "big") + s.to_bytes(32, "big")

    return f"{header_b64}.{payload_b64}.{_b64url(raw_sig)}"


# ── HTTP helpers ───────────────────────────────────────────────────────────────
def api_get(token: str, path: str, params: dict = None, allow_failure: bool = False) -> dict | None:
    url = f"{BASE_URL}{path}"
    if params:
        qs = "&".join(f"{k}={v}" for k, v in params.items())
        url = f"{url}?{qs}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        if allow_failure:
            return None
        sys.exit(f"API error {e.code} on {path}:\n{body}")


def download_file(url: str, dest: Path, token: str):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        dest.write_bytes(resp.read())


# ── Fetch helpers ──────────────────────────────────────────────────────────────
def get_apps(token: str) -> list:
    data = api_get(token, "/apps", {"limit": "50"})
    apps = data.get("data", [])
    if BUNDLE_ID:
        apps = [a for a in apps if a["attributes"]["bundleId"] == BUNDLE_ID]
    return apps


def get_builds(token: str, app_id: str) -> list:
    """Return all builds for the app (newest first, limit 20)."""
    data = api_get(
        token, f"/builds", {"filter[app]": app_id, "limit": "20", "sort": "-uploadedDate"}
    )
    return data.get("data", [])


def fetch_beta_feedback(token: str, app_id: str, app_dir: Path):
    """Download screenshot feedback submitted by testers."""
    print("  → Fetching screenshot feedback …")
    params = {"filter[app]": app_id, "limit": "100", "include": "screenshot,tester"}
    data = api_get(token, "/betaFeedbacks", params)
    items = data.get("data", [])

    if not items:
        print("     (no screenshot feedback found)")
        return

    fb_dir = app_dir / "feedback"
    fb_dir.mkdir(parents=True, exist_ok=True)

    # Build a map of included resources keyed by id
    included = {i["id"]: i for i in data.get("included", [])}

    summary = []
    for item in items:
        attr = item["attributes"]
        fb_id = item["id"]
        timestamp = attr.get("timestamp", "")
        comment = attr.get("comment", "")
        device = attr.get("deviceModel", "")
        os_ver = attr.get("osVersion", "")
        app_ver = attr.get("appVersion", "")
        locale = attr.get("locale", "")

        # Tester info
        tester_ref = item.get("relationships", {}).get("tester", {}).get("data", {})
        tester = included.get(tester_ref.get("id", ""), {})
        tester_email = tester.get("attributes", {}).get("email", "unknown")

        # Screenshot
        shot_ref = item.get("relationships", {}).get("screenshot", {}).get("data", {})
        shot_obj = included.get(shot_ref.get("id", ""), {})
        shot_url = shot_obj.get("attributes", {}).get("imageUrl", "")

        entry = {
            "id": fb_id,
            "timestamp": timestamp,
            "tester": tester_email,
            "comment": comment,
            "device": device,
            "os_version": os_ver,
            "app_version": app_ver,
            "locale": locale,
            "screenshot": "",
        }

        if shot_url:
            img_path = fb_dir / f"{fb_id}.jpg"
            try:
                download_file(shot_url, img_path, token)
                entry["screenshot"] = str(img_path.relative_to(app_dir.parent))
                print(f"     Saved screenshot: {img_path.name}")
            except Exception as exc:
                print(f"     ⚠ Could not download screenshot for {fb_id}: {exc}")

        summary.append(entry)

    out_file = fb_dir / "feedback_summary.json"
    out_file.write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"     Saved {len(summary)} feedback item(s) → {out_file}")


def fetch_crash_diagnostics(token: str, build_id: str, build_label: str, app_dir: Path):
    """Download crash diagnostic signatures and logs for a build."""
    data = api_get(
        token,
        f"/builds/{build_id}/diagnosticSignatures",
        {"limit": "50"},
        allow_failure=True,
    )
    if data is None:
        return 0
    sigs = data.get("data", [])

    if not sigs:
        return 0

    crash_dir = app_dir / "crashes" / build_label
    crash_dir.mkdir(parents=True, exist_ok=True)

    total = 0
    for sig in sigs:
        sig_id = sig["id"]
        sig_attr = sig["attributes"]
        sig_name = sig_attr.get("signature", sig_id)
        weight = sig_attr.get("weight", 0)  # crash count
        diag_type = sig_attr.get("diagnosticType", "")

        # Fetch the log content
        logs_data = api_get(
            token, f"/diagnosticSignatures/{sig_id}/logs", {"limit": "5"},
            allow_failure=True,
        )
        if logs_data is None:
            continue
        logs = logs_data.get("data", [])

        entry = {
            "signature_id": sig_id,
            "signature": sig_name,
            "type": diag_type,
            "crash_count": weight,
            "build": build_label,
            "logs": [],
        }

        for log in logs:
            log_url = log.get("attributes", {}).get("url", "")
            log_id = log.get("id", "")
            if log_url:
                log_path = crash_dir / f"{sig_id}_{log_id}.txt"
                try:
                    download_file(log_url, log_path, token)
                    entry["logs"].append(str(log_path.relative_to(app_dir.parent)))
                except Exception as exc:
                    print(f"     ⚠ Could not download log {log_id}: {exc}")

        safe_name = "".join(c if c.isalnum() or c in "-_." else "_" for c in sig_name)[
            :80
        ]
        out_file = crash_dir / f"{safe_name}.json"
        out_file.write_text(json.dumps(entry, indent=2, ensure_ascii=False))
        total += 1

    return total


# ── Main ───────────────────────────────────────────────────────────────────────
def validate_config():
    missing = [v for v in ("KEY_ID", "ISSUER_ID", "KEY_PATH") if not globals()[v]]
    if missing:
        sys.exit(
            f"Missing required config: {', '.join(missing)}\n"
            "Set them as environment variables or in a .env file:\n"
            "  ASC_KEY_ID=<your key id>\n"
            "  ASC_ISSUER_ID=<your issuer id>\n"
            "  ASC_KEY_PATH=path/to/AuthKey_XXXXXXXX.p8\n"
        )
    if not Path(KEY_PATH).exists():
        sys.exit(f"Key file not found: {KEY_PATH}")


def main():
    validate_config()

    print("🔑  Generating JWT …")
    token = generate_jwt()

    print("📱  Fetching apps …")
    apps = get_apps(token)
    if not apps:
        sys.exit("No apps found. Check your BUNDLE_ID filter or API key permissions.")

    run_ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for app in apps:
        app_id = app["id"]
        bundle_id = app["attributes"]["bundleId"]
        app_name = app["attributes"]["name"]
        print(f"\n📦  {app_name} ({bundle_id})")

        app_dir = OUTPUT_DIR / bundle_id
        app_dir.mkdir(parents=True, exist_ok=True)

        # Note: Beta tester feedback (screenshots + comments) is not available
        # via the App Store Connect API — only through the web UI.

        # Crash diagnostics — latest 5 builds
        print("  → Fetching crash diagnostics …")
        builds = get_builds(token, app_id)[:5]
        total_crashes = 0
        for build in builds:
            b_id = build["id"]
            b_version = build["attributes"].get("version", b_id)
            b_short = build["attributes"].get("buildAudienceType", "")
            label = f"v{b_version}"
            n = fetch_crash_diagnostics(token, b_id, label, app_dir)
            if n:
                print(f"     {label}: {n} crash signature(s)")
                total_crashes += n

        if total_crashes == 0:
            print("     (no crash signatures found for recent builds)")

    # Write a run manifest
    manifest = {
        "fetched_at": run_ts,
        "apps": [
            {
                "id": a["id"],
                "name": a["attributes"]["name"],
                "bundle_id": a["attributes"]["bundleId"],
            }
            for a in apps
        ],
        "output_dir": str(OUTPUT_DIR),
    }
    (OUTPUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(f"\n✅  Done. Output saved to: {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
