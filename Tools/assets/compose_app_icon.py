#!/usr/bin/env python3
"""Install tvOS brand assets (app icons, App Store poster, top shelf) from artwork."""

from __future__ import annotations

import json
import sys
import urllib.request
import zipfile
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS_DIR = Path(__file__).resolve().parent
BRAND_ASSETS = (
    ROOT
    / "Apps/Stratix/Stratix/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
)
HOME_ICON_STACK = BRAND_ASSETS / "App Icon.imagestack"
APP_STORE_ICON_STACK = BRAND_ASSETS / "App Icon - App Store.imagestack"
TOP_SHELF_IMAGESET = BRAND_ASSETS / "Top Shelf Image.imageset"
TOP_SHELF_WIDE_IMAGESET = BRAND_ASSETS / "Top Shelf Image Wide.imageset"

DEFAULT_LOGO_PATH = Path("/Users/sibwase/Downloads/logo.pxd")
DEFAULT_POSTER_PATH = Path("/Users/sibwase/Downloads/poster.png")
TOP_SHELF_CACHE_PATH = ASSETS_DIR / "topshelf_source.png"
LOGO_CACHE_PATH = ASSETS_DIR / "logo_source.png"

PXD_PREVIEW_CANDIDATES = (
    "QuickLook/Thumbnail.webp",
    "QuickLook/Preview.webp",
)

ICON_ASPECT = 5 / 3
TOP_SHELF_ASPECT = 1920 / 720
TOP_SHELF_WIDE_ASPECT = 2320 / 720

HOME_ICON_LAYERS = (
    ("Back.imagestacklayer/Content.imageset", "Stratix_Logo_Artboard 1 copy 2"),
    ("Middle.imagestacklayer/Content.imageset", "Stratix_Logo_Artboard 1"),
    ("Front.imagestacklayer/Content.imageset", "Stratix_Logo_Artboard 1 copy"),
)
APP_STORE_ICON_LAYERS = (
    ("Back.imagestacklayer/Content.imageset", "Stratix_Poster_Back"),
    ("Middle.imagestacklayer/Content.imageset", "Stratix_Poster_Middle"),
    ("Front.imagestacklayer/Content.imageset", "Stratix_Poster_Front"),
)


def save_lossless_png(image: Image.Image, output: Path) -> None:
    if image.mode not in ("RGB", "RGBA"):
        image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
    image.save(output, format="PNG", compress_level=1, optimize=False)


def load_pxd_image(path: Path) -> Image.Image:
    """Extract the QuickLook preview from a Pixelmator Pro .pxd archive."""
    with zipfile.ZipFile(path) as archive:
        for member in PXD_PREVIEW_CANDIDATES:
            if member not in archive.namelist():
                continue
            payload = archive.read(member)
            image = Image.open(BytesIO(payload)).convert("RGBA")
            save_lossless_png(image, LOGO_CACHE_PATH)
            print(
                f"Loaded logo from {path} via {member} ({image.size[0]}x{image.size[1]}). "
                "Export a PNG from Pixelmator for higher icon resolution."
            )
            return image.convert("RGB")

    raise ValueError(f"No QuickLook preview found in {path}")


def load_logo_image(source: Path | str | None = None) -> Image.Image:
    if isinstance(source, str) and not source.startswith(("http://", "https://")):
        source = Path(source)

    if isinstance(source, Path) and source.exists():
        if source.suffix.lower() == ".pxd":
            return load_pxd_image(source)
        image = Image.open(source).convert("RGBA")
        save_lossless_png(image, LOGO_CACHE_PATH)
        return image.convert("RGB")

    if DEFAULT_LOGO_PATH.exists():
        return load_pxd_image(DEFAULT_LOGO_PATH)

    if LOGO_CACHE_PATH.exists():
        return Image.open(LOGO_CACHE_PATH).convert("RGB")

    legacy_logo_cache = ASSETS_DIR / "logo_source.webp"
    if legacy_logo_cache.exists():
        return Image.open(legacy_logo_cache).convert("RGB")

    raise FileNotFoundError(
        "Logo source not found. Provide logo.pxd or ensure logo_source.webp exists."
    )


def load_top_shelf_image(source: Path | str | None = None) -> Image.Image:
    if isinstance(source, str) and not source.startswith(("http://", "https://")):
        source = Path(source)

    if isinstance(source, Path) and source.exists():
        image = Image.open(source).convert("RGBA")
        save_lossless_png(image, TOP_SHELF_CACHE_PATH)
        print(f"Loaded top shelf from {source} ({image.size[0]}x{image.size[1]})")
        return image.convert("RGB")

    if DEFAULT_POSTER_PATH.exists():
        image = Image.open(DEFAULT_POSTER_PATH).convert("RGBA")
        save_lossless_png(image, TOP_SHELF_CACHE_PATH)
        print(
            f"Loaded top shelf from {DEFAULT_POSTER_PATH} "
            f"({image.size[0]}x{image.size[1]})"
        )
        return image.convert("RGB")

    if TOP_SHELF_CACHE_PATH.exists():
        return Image.open(TOP_SHELF_CACHE_PATH).convert("RGB")

    legacy_topshelf_cache = ASSETS_DIR / "topshelf_source.jpg"
    if legacy_topshelf_cache.exists():
        return Image.open(legacy_topshelf_cache).convert("RGB")

    raise FileNotFoundError(
        "Top shelf source not found. Provide poster.png or topshelf_source.png."
    )


def center_aspect_crop(image: Image.Image, aspect: float) -> Image.Image:
    """Center-crop source art to the target aspect ratio."""
    width, height = image.size
    source_aspect = width / height

    if source_aspect > aspect:
        crop_width = int(round(height * aspect))
        crop_height = height
    else:
        crop_width = width
        crop_height = int(round(width / aspect))

    left = (width - crop_width) // 2
    top = (height - crop_height) // 2
    return image.crop((left, top, left + crop_width, top + crop_height))


def fit_to_target(image: Image.Image, width: int, height: int) -> Image.Image:
    """Crop-aware resize: copy pixels when sizes already match, downscale when possible."""
    if image.size == (width, height):
        return image

    src_width, src_height = image.size
    if src_width >= width and src_height >= height:
        print(f"Downscaling {src_width}x{src_height} -> {width}x{height}")
        return image.resize((width, height), Image.Resampling.LANCZOS)

    print(
        f"Warning: upscaling {src_width}x{src_height} -> {width}x{height} "
        "(source resolution is below the asset slot)"
    )
    return image.resize((width, height), Image.Resampling.LANCZOS)


def write_imageset_contents(
    imageset_dir: Path,
    basename: str,
    *,
    include_2x: bool = True,
) -> None:
    images = [
        {
            "filename": f"{basename}.png",
            "idiom": "tv",
            "scale": "1x",
        }
    ]
    if include_2x:
        images.append(
            {
                "filename": f"{basename}@2x.png",
                "idiom": "tv",
                "scale": "2x",
            }
        )

    payload = {
        "images": images,
        "info": {"author": "xcode", "version": 1},
    }
    (imageset_dir / "Contents.json").write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )


def compose_stack(
    stack_dir: Path,
    source: Image.Image,
    *,
    base_width: int,
    base_height: int,
    aspect: float,
    layer_specs: tuple[tuple[str, str], ...],
) -> None:
    framed = center_aspect_crop(source, aspect)

    for scale, suffix in ((1, ""), (2, "@2x")):
        width = base_width * scale
        height = base_height * scale
        rendered = fit_to_target(framed, width, height)
        for layer_path, basename in layer_specs:
            directory = stack_dir / layer_path
            output = directory / f"{basename}{suffix}.png"
            save_lossless_png(rendered, output)
            print(f"Wrote {output}")

    for layer_path, basename in layer_specs:
        write_imageset_contents(stack_dir / layer_path, basename)


def compose_imageset(
    imageset_dir: Path,
    source: Image.Image,
    *,
    base_width: int,
    base_height: int,
    aspect: float,
    basename: str,
) -> None:
    framed = center_aspect_crop(source, aspect)

    for scale, suffix in ((1, ""), (2, "@2x")):
        width = base_width * scale
        height = base_height * scale
        rendered = fit_to_target(framed, width, height)
        output = imageset_dir / f"{basename}{suffix}.png"
        save_lossless_png(rendered, output)
        print(f"Wrote {output}")

    write_imageset_contents(imageset_dir, basename)


def compose_top_shelf_assets(source: Image.Image) -> None:
    compose_imageset(
        TOP_SHELF_IMAGESET,
        source,
        base_width=1920,
        base_height=720,
        aspect=TOP_SHELF_ASPECT,
        basename="Stratix_Poster",
    )
    compose_imageset(
        TOP_SHELF_WIDE_IMAGESET,
        source,
        base_width=2320,
        base_height=720,
        aspect=TOP_SHELF_WIDE_ASPECT,
        basename="Stratix_Poster",
    )


def compose_icon_assets(source: Image.Image) -> None:
    compose_stack(
        HOME_ICON_STACK,
        source,
        base_width=400,
        base_height=240,
        aspect=ICON_ASPECT,
        layer_specs=HOME_ICON_LAYERS,
    )
    compose_stack(
        APP_STORE_ICON_STACK,
        source,
        base_width=1280,
        base_height=768,
        aspect=ICON_ASPECT,
        layer_specs=APP_STORE_ICON_LAYERS,
    )


def compose_all_brand_assets(
    logo_source: Path | str | None = None,
    topshelf_source: Path | str | None = None,
) -> None:
    compose_icon_assets(load_logo_image(logo_source))
    compose_top_shelf_assets(load_top_shelf_image(topshelf_source))


def main() -> None:
    flags = {"--topshelf-only", "--icons-only", "--all"}
    topshelf_only = "--topshelf-only" in sys.argv
    icons_only = "--icons-only" in sys.argv
    compose_all = "--all" in sys.argv or (not topshelf_only and not icons_only)
    args = [arg for arg in sys.argv[1:] if arg not in flags]

    source_arg: Path | str | None = args[0] if args else None

    if topshelf_only:
        compose_top_shelf_assets(load_top_shelf_image(source_arg))
    elif icons_only:
        compose_icon_assets(load_logo_image(source_arg))
    else:
        compose_all_brand_assets(
            logo_source=source_arg,
            topshelf_source=None,
        )


if __name__ == "__main__":
    main()