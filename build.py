#!/usr/bin/env python3
"""Build the .muxupd packages in dist/ from the folders in packages/.

A .muxupd is a zip whose paths are relative to the device's root (/).
muOS's Archive Manager extracts it over / and then runs opt/update.sh.
"""
import os
import time
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
PACKAGES = {
    "headphone-jack-fix": "Headphone-Jack-Fix-RG35XXH.muxupd",
    "bluetooth-watchdog": "Bluetooth-Watchdog-RG35XXH.muxupd",
}


def build(src, out):
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for base, dirs, files in os.walk(src):
            dirs.sort()
            rel = os.path.relpath(base, src).replace(os.sep, "/")
            if rel != ".":
                zi = zipfile.ZipInfo(rel + "/", time.localtime()[:6])
                zi.external_attr = (0o40755 << 16) | 0x10
                z.writestr(zi, b"")
            for name in sorted(files):
                path = os.path.join(base, name)
                arc = os.path.relpath(path, src).replace(os.sep, "/")
                zi = zipfile.ZipInfo(arc, time.localtime()[:6])
                zi.compress_type = zipfile.ZIP_DEFLATED
                mode = 0o100755 if name.endswith(".sh") else 0o100644
                zi.external_attr = mode << 16
                with open(path, "rb") as f:
                    data = f.read()
                if name.endswith(".sh"):
                    data = data.replace(b"\r\n", b"\n")  # never ship CRLF scripts
                z.writestr(zi, data)


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
    for folder, name in PACKAGES.items():
        out = os.path.join(ROOT, "dist", name)
        build(os.path.join(ROOT, "packages", folder), out)
        print("built", os.path.relpath(out, ROOT))
