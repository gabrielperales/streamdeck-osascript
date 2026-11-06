#!/usr/bin/env python3
"""Checks manifest.json rules that the Stream Deck app enforces on install
but `streamdeck validate` does not catch.

- Every image the manifest references exists as .png (with an @2x variant) or .svg.
- A manifest with `Category` also has `CategoryIcon`. Without it the app refuses
  to install the plugin ("category icon not defined").

Usage: python3 Tests/check_manifest.py path/to/com.example.sdPlugin
"""

import json
import os
import sys


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    plugin_dir = sys.argv[1]
    with open(os.path.join(plugin_dir, "manifest.json")) as f:
        manifest = json.load(f)

    errors = []
    if "Category" in manifest and "CategoryIcon" not in manifest:
        errors.append("Category is set but CategoryIcon is missing (the Stream Deck app rejects the plugin)")

    images = {"Icon": manifest.get("Icon"), "CategoryIcon": manifest.get("CategoryIcon")}
    for i, action in enumerate(manifest.get("Actions", [])):
        images[f"Actions[{i}].Icon"] = action.get("Icon")
        for j, state in enumerate(action.get("States", [])):
            images[f"Actions[{i}].States[{j}].Image"] = state.get("Image")

    for field, path in images.items():
        if not path:
            continue
        base = os.path.join(plugin_dir, path)
        if os.path.isfile(base + ".svg"):
            continue
        missing = [p for p in (base + ".png", base + "@2x.png") if not os.path.isfile(p)]
        if missing:
            errors.append(f"{field} '{path}': missing {', '.join(os.path.basename(p) for p in missing)}")

    for error in errors:
        print("error  " + error)
    if errors:
        sys.exit(f"{len(errors)} manifest problem(s)")
    print("manifest icons ok")


if __name__ == "__main__":
    main()
