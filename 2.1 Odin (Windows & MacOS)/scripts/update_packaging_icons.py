#!/usr/bin/env python3
"""Rebuild macOS and Windows packaging icons from the 2.1 icon family."""

from io import BytesIO
from pathlib import Path
import shutil
import struct

from PIL import Image


SCRIPT_DIRECTORY = Path(__file__).resolve().parent
PROJECT_DIRECTORY = SCRIPT_DIRECTORY.parent
ICON_DIRECTORY = PROJECT_DIRECTORY / "icons"
MACOS_DIRECTORY = PROJECT_DIRECTORY / "packaging" / "macos"
WINDOWS_DIRECTORY = PROJECT_DIRECTORY / "packaging" / "windows"
WINDOWS_STORE_ASSET_DIRECTORY = (
    PROJECT_DIRECTORY / "packaging" / "windows-store" / "Assets"
)

ICON_SIZES = (16, 32, 48, 64, 128, 256, 512, 1024)
WINDOWS_ICO_SIZES = (16, 32, 48, 64, 128, 256)


def icon_path(size: int) -> Path:
    return ICON_DIRECTORY / f"{size}x{size}.png"


def load_icon(size: int) -> Image.Image:
    path = icon_path(size)
    icon = Image.open(path)
    if icon.size != (size, size):
        raise ValueError(f"expected {path} to be {size}x{size}, got {icon.size}")
    return icon.convert("RGBA")


def write_windows_ico() -> None:
    frames = [load_icon(size) for size in WINDOWS_ICO_SIZES]
    frames[-1].save(
        WINDOWS_DIRECTORY / "caverace.ico",
        format="ICO",
        append_images=frames[:-1],
        sizes=[(size, size) for size in WINDOWS_ICO_SIZES],
    )


def write_windows_store_asset(name: str, source_size: int, target_size: int) -> None:
    icon = load_icon(source_size)
    icon = icon.resize((target_size, target_size), Image.Resampling.LANCZOS)
    icon.save(WINDOWS_STORE_ASSET_DIRECTORY / name, format="PNG", optimize=True)


def write_macos_icns() -> None:
    # The modern PNG-backed ICNS entries cover classic 1x sizes and Retina
    # representations. Some physical sizes intentionally appear twice because
    # macOS distinguishes their logical point size by the four-byte type code.
    representations = (
        (b"icp4", 16),
        (b"icp5", 32),
        (b"ic07", 128),
        (b"ic08", 256),
        (b"ic09", 512),
        (b"ic10", 1024),
        (b"ic11", 32),
        (b"ic12", 64),
        (b"ic13", 256),
        (b"ic14", 512),
    )
    canonical_icon = load_icon(1024)
    chunks = []
    for type_code, size in representations:
        if size <= 64:
            # Keep compact macOS representations visually consistent with the
            # canonical app icon. The hand-tuned small source files crop the
            # artwork too tightly, making menu-sized icons look unrelated.
            compact_icon = canonical_icon.resize(
                (size, size), Image.Resampling.LANCZOS
            )
            output = BytesIO()
            compact_icon.save(output, format="PNG", optimize=True)
            png = output.getvalue()
        else:
            png = icon_path(size).read_bytes()
        chunks.append(type_code + struct.pack(">I", len(png) + 8) + png)
    body = b"".join(chunks)
    icns = b"icns" + struct.pack(">I", len(body) + 8) + body
    (MACOS_DIRECTORY / "CaveRace.icns").write_bytes(icns)


def main() -> None:
    for size in ICON_SIZES:
        load_icon(size)

    shutil.copyfile(
        icon_path(1024),
        MACOS_DIRECTORY / "CaveRace-AppStore-1024.png",
    )
    write_macos_icns()
    write_windows_ico()

    # Use the closest larger hand-tuned source icon for each Store target.
    write_windows_store_asset("Square44x44Logo.png", 48, 44)
    write_windows_store_asset("StoreLogo.png", 64, 50)
    write_windows_store_asset("Square150x150Logo.png", 256, 150)

    print("Updated macOS, Windows, and Windows Store packaging icons")


if __name__ == "__main__":
    main()
