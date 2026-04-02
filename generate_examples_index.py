#!/usr/bin/env python3
"""Generate an index.html that links to all published USTB example HTML files.

Usage:
    python generate_examples_index.py [html_root]

    html_root: folder containing the published HTML (default: examples_html/)

The script walks html_root, finds every .html file, organises them by folder,
and writes an index.html at the root of html_root.
"""

import os
import sys
from pathlib import Path
from collections import defaultdict

HTML_TEMPLATE = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>USTB Examples</title>
<style>
  :root {{
    --bg: #fdfdfd; --fg: #1a1a2e; --accent: #0f3460; --link: #1a73e8;
    --card-bg: #fff; --border: #e0e0e0; --code-bg: #f5f5f5;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg: #1a1a2e; --fg: #e0e0e0; --accent: #64b5f6; --link: #90caf9;
      --card-bg: #16213e; --border: #2a2a4a; --code-bg: #0f3460;
    }}
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: var(--bg); color: var(--fg);
    max-width: 960px; margin: 0 auto; padding: 2rem 1rem;
    line-height: 1.6;
  }}
  h1 {{ color: var(--accent); margin-bottom: .25rem; font-size: 2rem; }}
  .subtitle {{ color: var(--fg); opacity: .7; margin-bottom: 2rem; }}
  h2 {{
    color: var(--accent); margin: 1.5rem 0 .5rem;
    padding-bottom: .25rem; border-bottom: 2px solid var(--border);
    font-size: 1.15rem;
  }}
  ul {{ list-style: none; padding-left: 0; }}
  li {{ padding: .25rem 0; }}
  a {{ color: var(--link); text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  code {{ background: var(--code-bg); padding: .1em .35em; border-radius: 3px; font-size: .9em; }}
  .stats {{ margin-bottom: 1.5rem; font-size: .9rem; opacity: .8; }}
</style>
</head>
<body>
<h1>USTB Examples</h1>
<p class="subtitle">UltraSound ToolBox &mdash; published example gallery</p>
<p class="stats">{total} examples across {n_folders} categories</p>
{sections}
</body>
</html>
"""

FOLDER_LABELS = {
    "acoustical_radiation_force_imaging": "Acoustical Radiation Force Imaging",
    "advanced_beamforming": "Advanced Beamforming",
    "alpinion": "Alpinion",
    "field_II": "Field II Simulations",
    "FLUST": "FLUST (Flow Simulator)",
    "fresnel": "Fresnel Simulations",
    "kWave": "k-Wave Simulations",
    "picmus": "PICMUS Challenge",
    "REFoCUS": "REFoCUS",
    "uff": "UFF File Format",
    "UiO_course_IN4015_Ultrasound_Imaging": "UiO Course IN4015",
    "verasonics": "Verasonics",
}


def label_for(folder: str) -> str:
    top = folder.split(os.sep)[0] if os.sep in folder else folder
    top = folder.split("/")[0] if "/" in folder else top
    base = FOLDER_LABELS.get(top, top.replace("_", " ").title())
    rest = folder.replace(top, "", 1).strip(os.sep).strip("/")
    if rest:
        rest_nice = rest.replace("_", " ").replace(os.sep, " / ").replace("/", " / ")
        return f"{base} / {rest_nice}"
    return base


def main():
    html_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("examples_html")
    if not html_root.is_dir():
        print(f"Error: {html_root} does not exist or is not a directory.")
        sys.exit(1)

    by_folder = defaultdict(list)
    for html_file in sorted(html_root.rglob("*.html")):
        if html_file.name == "index.html":
            continue
        rel = html_file.relative_to(html_root)
        folder = str(rel.parent) if str(rel.parent) != "." else "(root)"
        by_folder[folder].append(rel)

    sections = []
    total = 0
    for folder in sorted(by_folder.keys()):
        files = by_folder[folder]
        total += len(files)
        nice_label = label_for(folder) if folder != "(root)" else "General"
        items = []
        for f in sorted(files):
            name = f.stem.replace("_", " ")
            items.append(f'  <li><a href="{f.as_posix()}">{name}</a> <code>{f.name}</code></li>')
        sections.append(f'<h2>{nice_label}</h2>\n<ul>\n' + "\n".join(items) + "\n</ul>")

    page = HTML_TEMPLATE.format(
        total=total,
        n_folders=len(by_folder),
        sections="\n".join(sections),
    )

    out = html_root / "index.html"
    out.write_text(page, encoding="utf-8")
    print(f"Wrote {out}  ({total} examples in {len(by_folder)} folders)")


if __name__ == "__main__":
    main()
