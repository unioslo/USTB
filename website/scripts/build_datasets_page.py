#!/usr/bin/env python3
"""
Generate website/datasets.html from examples/dataset_smoke_tests/uff_dataset_registry.m

Real preview PNGs are produced by MATLAB (must match slug algorithm):
  addpath('examples/dataset_smoke_tests');
  export_dataset_previews_to_website();

Then regenerate this page (HTML only, no Pillow):
  python3 website/scripts/build_datasets_page.py --html-only

Optional: generate gray placeholder PNGs (requires Pillow):
  python3 website/scripts/build_datasets_page.py --placeholders

Run from repository root.
"""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "examples" / "dataset_smoke_tests" / "uff_dataset_registry.m"
WEBSITE = ROOT / "website"
IMG_DIR = WEBSITE / "assets" / "images" / "datasets"
OUT_HTML = WEBSITE / "datasets.html"

NAV_BLOCK = """        <li><a href="index.html">Home</a></li>
        <li><a href="documentation.html">Documentation</a></li>
        <li><a href="examples.html">Examples</a></li>
        <li><a href="datasets.html">Datasets</a></li>
        <li><a href="publications.html">Publications</a></li>
        <li><a href="team.html">Team</a></li>
        <li><a href="citation.html">Citation</a></li>"""


def parse_registry(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8")
    rows = []
    pat = re.compile(
        r"T\s*=\s*add\(T,\s*'([^']+)'\s*,\s*'[^']*'\s*,\s*'([^']+)'\s*,\s*'([^']*)'\)"
    )
    for m in pat.finditer(text):
        rows.append(
            {"filename": m.group(1), "mode": m.group(2), "note": m.group(3)}
        )
    return rows


def slug(filename: str) -> str:
    """Must match examples/dataset_smoke_tests/website_slug_for_dataset.m"""
    base = filename.replace(".uff", "").replace(".UFF", "")
    h = hashlib.md5(base.encode("utf-8")).hexdigest()[:10]
    safe = re.sub(r"[^a-zA-Z0-9_.-]+", "_", base)[:40]
    return f"{safe}_{h}"


def make_placeholder_png(path: Path, title: str, mode: str) -> None:
    import textwrap

    from PIL import Image, ImageDraw, ImageFont

    path.parent.mkdir(parents=True, exist_ok=True)
    w, h = 400, 260
    img = Image.new("RGB", (w, h), color=(245, 245, 245))
    draw = ImageDraw.Draw(img)
    for i in range(h):
        g = int(220 + (i / h) * 30)
        draw.line([(0, i), (w, i)], fill=(g, g, g + 5))
    try:
        font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13
        )
        font_small = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11
        )
    except OSError:
        font = ImageFont.load_default()
        font_small = font

    wrap = textwrap.wrap(title, width=46)[:5]
    y = 24
    for line in wrap:
        draw.text((20, y), line, fill=(40, 40, 40), font=font)
        y += 18
    draw.text((20, h - 52), f"Mode: {mode}", fill=(120, 30, 30), font=font_small)
    draw.text(
        (20, h - 32),
        "Placeholder — run export_dataset_previews_to_website in MATLAB",
        fill=(100, 100, 100),
        font=font_small,
    )
    img.save(path, "PNG")


def build_html(rows: list[dict]) -> str:
    cards = []
    for r in rows:
        fn = r["filename"]
        mode = r["mode"]
        if mode == "beamformed_only":
            contains_str = "beamformed data"
        else:
            contains_str = "channel data"
        note = r["note"].replace("&", "&amp;").replace("<", "&lt;")
        slug_v = slug(fn)
        rel_img = f"assets/images/datasets/{slug_v}.png"
        url = f"https://zenodo.org/records/20261898/files/{fn}"
        cards.append(
            f"""            <article class="dataset-card">
                <a href="{url}" class="dataset-thumb" target="_blank" rel="noopener">
                    <img src="{rel_img}" alt="Preview for {fn}" loading="lazy" width="400" height="260">
                </a>
                <h3><a href="{url}" target="_blank" rel="noopener">{fn}</a></h3>
                <p class="dataset-meta"><strong>Contains</strong>: {contains_str}</p>
                <p class="dataset-note">{note}</p>
                <p><a href="{url}" target="_blank" rel="noopener">Download (.uff)</a></p>
            </article>"""
        )

    cards_html = "\n\n".join(cards)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Datasets – UltraSound ToolBox</title>
    <link rel="icon" href="assets/images/ustb-logo.png" type="image/png">
    <link href="https://fonts.googleapis.com/css2?family=Gudea:wght@400;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="assets/style.css">
</head>
<body>

<header class="site-header">
    <div class="header-inner">
        <div class="site-branding">
            <a href="index.html"><img src="assets/images/ustb-logo.png" alt="USTB Logo"></a>
            <div>
                <div class="site-title"><a href="index.html">UltraSound ToolBox</a></div>
                <div class="site-description">MATLAB toolbox for processing ultrasonic signals</div>
            </div>
        </div>
    </div>
</header>

<nav class="main-nav">
    <ul>
{NAV_BLOCK}
    </ul>
</nav>

<div class="content-wrap">
    <main class="main-content">
        <div class="page-content">
            <h1>USTB datasets</h1>
            <p>
                Public UFF datasets used in USTB <a href="examples.html">examples</a> and
                <a href="publications.html">publications</a>. Each file can be downloaded directly
                (HDF5-based <code>.uff</code> format). Use <code>tools.download</code> in MATLAB or
                open the link in a browser. Citation requirements for each dataset are stored inside
                the UFF file — use <code>uff.channel_data.print_authorship</code> after loading.
            </p>
            <p class="dataset-regen-note">
                Previews use <code>examples/dataset_catalog_previews/dataset_preview_beamform.m</code>
                — one <code>switch</code> case per file, copied from the referenced example under
                <code>examples/</code> or <code>publications/</code>. PNGs use the same log scaling as
                <code>b_data.plot(..., 60, ''log'')</code>. Regenerate with
                <code>export_dataset_previews_to_website</code> then
                <code>python3 website/scripts/build_datasets_page.py</code>.
            </p>

            <div class="dataset-grid">
{cards_html}
            </div>
        </div>
    </main>
</div>

<footer class="site-footer">
    <p>Theme: <a href="https://themezee.com/themes/wellington/" target="_blank">Wellington</a> by ThemeZee.</p>
</footer>
</body>
</html>
"""


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Build datasets.html from uff_dataset_registry.m. "
        "Default: HTML only. Use --placeholders to regenerate gray PNGs (Pillow)."
    )
    ap.add_argument(
        "--placeholders",
        action="store_true",
        help="Also write gray placeholder PNGs for each entry (requires Pillow)",
    )
    args = ap.parse_args()

    if not REGISTRY.is_file():
        raise SystemExit(f"Missing registry: {REGISTRY}")
    rows = parse_registry(REGISTRY)
    if not rows:
        raise SystemExit("No dataset rows parsed from registry")

    IMG_DIR.mkdir(parents=True, exist_ok=True)

    if args.placeholders:
        for r in rows:
            png = IMG_DIR / f"{slug(r['filename'])}.png"
            make_placeholder_png(png, r["filename"], r["mode"])
        print(f"Wrote placeholder thumbnails under {IMG_DIR}")

    OUT_HTML.write_text(build_html(rows), encoding="utf-8")
    print(f"Wrote {OUT_HTML} ({len(rows)} datasets)")


if __name__ == "__main__":
    main()
