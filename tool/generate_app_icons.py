"""Generate launcher and launch-screen assets from branding masters."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets/branding/app_icon_master.png"
LAUNCH_MASTER = ROOT / "assets/branding/launch_logo_master.png"
IOS = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
IOS_LAUNCH = ROOT / "ios/Runner/Assets.xcassets/LaunchLogo.imageset"
ANDROID = ROOT / "android/app/src/main/res"


def write_icon(image: Image.Image, destination: Path, size: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(
        destination, format="PNG", optimize=True
    )


def write_launch_logo(image: Image.Image, destination: Path, size: int) -> None:
    """Fit the transparent mark inside a square with comfortable safe space."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    artwork_size = round(size * 0.78)
    artwork = image.copy()
    artwork.thumbnail((artwork_size, artwork_size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = ((size - artwork.width) // 2, (size - artwork.height) // 2)
    canvas.alpha_composite(artwork, offset)
    canvas.save(destination, format="PNG", optimize=True)


def main() -> None:
    with Image.open(MASTER) as source:
        image = source.convert("RGB")
        if image.width != image.height or image.width < 1024:
            raise ValueError("App icon master must be square and at least 1024 px.")

        contents = json.loads((IOS / "Contents.json").read_text())
        for entry in contents["images"]:
            filename = entry.get("filename")
            if filename:
                points = float(entry["size"].split("x")[0])
                scale = int(entry["scale"].removesuffix("x"))
                write_icon(image, IOS / filename, round(points * scale))

        # Keep older, currently unreferenced files in this set visually consistent.
        for icon in IOS.glob("Icon-App-*.png"):
            stem = icon.stem.removeprefix("Icon-App-")
            size_part, scale_part = stem.split("@")
            points = float(size_part.split("x")[0])
            scale = int(scale_part.removesuffix("x"))
            write_icon(image, icon, round(points * scale))

        for density, size in {
            "mdpi": 48,
            "hdpi": 72,
            "xhdpi": 96,
            "xxhdpi": 144,
            "xxxhdpi": 192,
        }.items():
            write_icon(image, ANDROID / f"mipmap-{density}/ic_launcher.png", size)

    with Image.open(LAUNCH_MASTER) as source:
        launch_logo = source.convert("RGBA")
        if launch_logo.width != launch_logo.height or launch_logo.width < 1024:
            raise ValueError("Launch logo master must be square and at least 1024 px.")
        for scale, size in ((1, 168), (2, 336), (3, 504)):
            write_launch_logo(
                launch_logo,
                IOS_LAUNCH / f"NamazGrubumLaunchLogo-{size}.png",
                size,
            )


if __name__ == "__main__":
    main()
