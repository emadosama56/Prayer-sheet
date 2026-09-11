#!/usr/bin/env python3
"""Copies the Google Sign-In URL scheme out of GoogleService-Info.plist.

    python3 tool/ios_google_url_scheme.py

Signing in with Google hands control to Safari and then back to the app, and
iOS only knows which app to return to if the scheme is declared in Info.plist.
The value is REVERSED_CLIENT_ID, which lives in the Firebase config — so it is
read from there rather than copied by hand, and stays right if the config is
ever replaced.

Does nothing (and says so) when the config is absent, so an iOS build without
Firebase still succeeds.
"""

import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "ios" / "Runner" / "GoogleService-Info.plist"
INFO = ROOT / "ios" / "Runner" / "Info.plist"


def main() -> int:
    if not CONFIG.exists():
        print(f"no {CONFIG.name}; leaving Info.plist alone")
        return 0

    with CONFIG.open("rb") as handle:
        config = plistlib.load(handle)

    scheme = config.get("REVERSED_CLIENT_ID")
    if not scheme:
        print("REVERSED_CLIENT_ID is missing: is Google sign-in enabled?")
        return 1

    with INFO.open("rb") as handle:
        info = plistlib.load(handle)

    types = info.setdefault("CFBundleURLTypes", [])
    for entry in types:
        if scheme in entry.get("CFBundleURLSchemes", []):
            print("URL scheme already present")
            return 0

    types.append({"CFBundleTypeRole": "Editor", "CFBundleURLSchemes": [scheme]})
    with INFO.open("wb") as handle:
        plistlib.dump(info, handle)

    print(f"added URL scheme {scheme}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
