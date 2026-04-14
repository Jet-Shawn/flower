#!/usr/bin/env python3
"""
Run Nano Banana Pro from the terminal.

Student flow:
1. Press P in Processing to save a flower image.
2. Run: python3 nano_banana_terminal.py
3. Choose stem or head.
4. Type a prompt and press Enter.

The script uses the newest saved flower PNG for that choice and writes the
Nano Banana result into MemoryGarden/.
"""

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parent
MEMORY_GARDEN_DIR = ROOT / "MemoryGarden"
MODEL = "google/nano-banana-pro"
# Load from .env if present
_env_path = ROOT / ".env"
if _env_path.exists():
    for _line in _env_path.read_text().splitlines():
        _line = _line.strip()
        if _line and not _line.startswith("#") and "=" in _line:
            _k, _v = _line.split("=", 1)
            os.environ.setdefault(_k.strip(), _v.strip())

WORKSHOP_REPLICATE_TOKEN = os.environ.get("REPLICATE_API_TOKEN", "")


def ensure_replicate():
    if importlib.util.find_spec("replicate") is None:
        print("Installing Replicate... (first time only)")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "replicate"])

    import replicate

    return replicate


def find_latest_flower_png(kind: str) -> Path | None:
    if kind == "stem":
        patterns = ["flower-stem-*.png"]
    else:
        patterns = ["flower-head-*.png"]

    candidates = []

    for folder in (MEMORY_GARDEN_DIR, ROOT):
        for pattern in patterns:
            candidates.extend(folder.glob(pattern))

    if not candidates:
        return None

    return max(candidates, key=lambda path: path.stat().st_mtime)


def save_output_file(output, destination: Path) -> None:
    if hasattr(output, "read"):
        destination.write_bytes(output.read())
        return

    if isinstance(output, (list, tuple)) and output:
        save_output_file(output[0], destination)
        return

    urllib.request.urlretrieve(str(output), destination)


def main() -> int:
    choice = input("Use which image? [stem/head]: ").strip().lower()
    if choice in ("s", "stem"):
        choice = "stem"
    elif choice in ("h", "head", "no-stem", "without-stem"):
        choice = "head"
    else:
        print("Please type stem or head.")
        return 1

    image_path = find_latest_flower_png(choice)
    if image_path is None:
        print(f"No {choice} flower PNG found yet.")
        print("Press P in Processing first, then run this script again.")
        return 1

    prompt = input("Prompt: ").strip()
    if not prompt:
        print("No prompt entered.")
        return 1

    replicate = ensure_replicate()
    token = os.environ.get("REPLICATE_API_TOKEN", WORKSHOP_REPLICATE_TOKEN)
    client = replicate.Client(api_token=token)

    print(f"Using image: {image_path.name}")
    print("Running Nano Banana Pro...")

    with image_path.open("rb") as image_file:
        output = client.run(
            MODEL,
            input={
                "prompt": prompt,
                "image_input": [image_file],
                "aspect_ratio": "match_input_image",
                "resolution": "2K",
                "output_format": "png",
            },
        )

    out_name = f"nano-banana-{time.strftime('%Y%m%d-%H%M%S')}.png"
    out_path = MEMORY_GARDEN_DIR / out_name
    save_output_file(output, out_path)

    print(f"Saved {out_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
