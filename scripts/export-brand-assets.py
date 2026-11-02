#!/usr/bin/env python3
"""Export the approved NepType artwork to native platform icon sizes on macOS."""
from pathlib import Path
import json
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "branding/assets"
MASTER = ASSETS / "neptype-icon-master.png"


def resize(size, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sips", "-z", str(size), str(size), str(MASTER), "--out", str(destination)],
                   check=True, stdout=subprocess.DEVNULL)


def main():
    resize(1024, ASSETS / "neptype-icon-1024.png")
    resize(128, ASSETS / "neptype-mark.png")
    catalog = ROOT / "platforms/ios/NepTypeMobile/Assets.xcassets"
    shutil.copyfile(ASSETS / "neptype-icon-1024.png", catalog / "AppIcon.appiconset/AppIcon.png")
    logo = catalog / "NepTypeMark.imageset"
    logo.mkdir(parents=True, exist_ok=True)
    images = []
    for scale in (1, 2, 3):
        filename = f"neptype-mark@{scale}x.png"
        resize(32 * scale, logo / filename)
        images.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})
    (logo / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    resize(256, ROOT / "platforms/android/app/src/main/res/drawable-nodpi/neptype_mark.png")
    resize(128, ROOT / "platforms/linux/assets/neptype-mark.png")
    resize(128, ROOT / "landing-page/assets/neptype-icon.png")
    with tempfile.TemporaryDirectory(prefix="neptype-icons-") as temporary:
        temp = Path(temporary)
        iconset = temp / "NepType.iconset"
        iconset.mkdir()
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                suffix = "@2x" if scale == 2 else ""
                resize(size * scale, iconset / f"icon_{size}x{size}{suffix}.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ASSETS / "NepType.icns")], check=True)
        # Windows Vista and later accept PNG-encoded images in ICO resources.
        png = temp / "windows-256.png"
        resize(256, png)
        data = png.read_bytes()
        ico = struct.pack("<HHH", 0, 1, 1) + struct.pack("<BBBBHHII", 0, 0, 0, 0, 1, 32, len(data), 22) + data
        (ROOT / "platforms/windows/neptype.ico").write_bytes(ico)
    print("Exported approved NepType branding for macOS, iOS, Android, Linux, and the landing page.")


if __name__ == "__main__":
    main()
