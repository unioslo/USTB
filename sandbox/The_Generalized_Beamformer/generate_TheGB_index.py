#!/usr/bin/env python3
"""Generate the landing page for The Generalized Beamformer paper examples.

Usage:
    python generate_TheGB_index.py
"""

from pathlib import Path

SCRIPTS = [
    {
        "file": "CPWC_double_adaptive_redone.html",
        "title": "Double Adaptive Beamforming",
        "desc": (
            "Compares five TX/RX beamforming configurations using Capon Minimum "
            "Variance (MV) on the PICMUS numerical phantom: conventional DAS, "
            "MV on RX, MV on TX, double adaptive MV, and reversed order. "
            "Includes gCNR, FWHM resolution analysis, and lateral profiles."
        ),
        "tags": ["Capon MV", "CPWC", "gCNR", "FWHM", "adaptive"],
    },
    {
        "file": "illustrate_virtual_sources.html",
        "title": "Virtual Source Geometry &amp; Scan Types",
        "desc": (
            "Visualises the probe geometry and virtual source positions for "
            "diverging wave (DW), synthetic transmit aperture (STA), and "
            "plane wave (PW) sequences. Also shows linear scan, sector scan, "
            "and their 3-D counterparts."
        ),
        "tags": ["geometry", "virtual source", "DW", "STA", "PW", "scan"],
    },
    {
        "file": "FI_coherence_factor.html",
        "title": "Focused Imaging with Coherence Factor",
        "desc": (
            "Demonstrates focused imaging on a phased-array cardiac dataset "
            "using the Generalized Beamformer with scanline and retrospective "
            "transmit beamforming (RTB), combined with coherence factor weighting."
        ),
        "tags": ["FI", "phased array", "coherence factor", "RTB", "cardiac"],
    },
    {
        "file": "kWave_USTB_generalized_beamformer.html",
        "title": "k-Wave Full-Wave Simulation",
        "desc": (
            "Full-wave acoustic simulation using k-Wave with a selectable transmit "
            "waveform (FI, PW, STAI, DW). Simulates point scatterers, a hyperechoic "
            "cyst, and a gradient bar, then beamforms with USTB."
        ),
        "tags": ["k-Wave", "simulation", "FI", "PW", "STAI", "DW"],
    },
]

HTML = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>The Generalized Beamformer &mdash; USTB Examples</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Source+Serif+4:opsz,wght@8..60,400;8..60,600;8..60,700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  :root {{
    --bg: #fafaf8; --fg: #1c1917; --accent: #1e3a5f;
    --link: #1a5fb4; --card: #fff; --border: #e7e5e4;
    --tag-bg: #e8edf2; --tag-fg: #1e3a5f; --muted: #78716c;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg: #1c1917; --fg: #e7e5e4; --accent: #93c5fd;
      --link: #93c5fd; --card: #292524; --border: #44403c;
      --tag-bg: #1e3a5f; --tag-fg: #bfdbfe; --muted: #a8a29e;
    }}
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: 'Inter', system-ui, sans-serif;
    background: var(--bg); color: var(--fg);
    line-height: 1.65; max-width: 820px;
    margin: 0 auto; padding: 3rem 1.5rem 4rem;
  }}
  h1 {{
    font-family: 'Source Serif 4', Georgia, serif;
    font-size: 2.2rem; font-weight: 700; color: var(--accent);
    margin-bottom: .35rem; letter-spacing: -0.02em;
  }}
  .authors {{ color: var(--muted); margin-bottom: .5rem; font-size: .95rem; }}
  .abstract {{
    margin-bottom: 2.5rem; font-size: .95rem; line-height: 1.7;
    border-left: 3px solid var(--accent); padding-left: 1rem;
    color: var(--muted);
  }}
  .abstract a {{ color: var(--link); text-decoration: none; }}
  .abstract a:hover {{ text-decoration: underline; }}
  h2 {{
    font-family: 'Source Serif 4', Georgia, serif;
    font-size: 1.3rem; font-weight: 600; color: var(--accent);
    margin-bottom: 1.2rem;
  }}
  .card {{
    background: var(--card); border: 1px solid var(--border);
    border-radius: 8px; padding: 1.4rem 1.6rem;
    margin-bottom: 1rem; transition: box-shadow .15s;
  }}
  .card:hover {{ box-shadow: 0 2px 12px rgba(0,0,0,.08); }}
  .card h3 {{ font-size: 1.05rem; margin-bottom: .4rem; }}
  .card h3 a {{ color: var(--link); text-decoration: none; }}
  .card h3 a:hover {{ text-decoration: underline; }}
  .card p {{ font-size: .9rem; color: var(--muted); margin-bottom: .6rem; }}
  .tags {{ display: flex; flex-wrap: wrap; gap: .35rem; }}
  .tag {{
    background: var(--tag-bg); color: var(--tag-fg);
    font-size: .75rem; font-weight: 500; padding: .15rem .55rem;
    border-radius: 4px;
  }}
  footer {{
    margin-top: 3rem; padding-top: 1.5rem;
    border-top: 1px solid var(--border);
    font-size: .82rem; color: var(--muted);
  }}
  footer a {{ color: var(--link); text-decoration: none; }}
</style>
</head>
<body>

<h1>The Generalized Beamformer</h1>
<p class="authors">
  Ole Marius Hoel Rindal, Alfonso Rodriguez-Molares, Anders Vrålstad, Stefano Fiorentini, Andreas Austeng
</p>

<div class="abstract">
  These examples accompany the paper
  <a href="https://www.techrxiv.org/users/684320/articles/1263073-the-generalized-beamformer-in-the-ultrasound-toolbox"
     target="_blank"><em>The Generalized Beamformer in the UltraSound ToolBox</em></a>.
  Each page is a published MATLAB script from the
  <a href="https://github.com/unioslo/USTB" target="_blank">USTB</a>
  repository that demonstrates a key concept or result from the paper.
</div>

<h2>Examples</h2>

{cards}

<footer>
  Generated from the <a href="https://github.com/unioslo/USTB">USTB</a> repository.
  The UltraSound ToolBox is developed at the University of Oslo.
</footer>

</body>
</html>
"""


def make_card(s: dict) -> str:
    tags = "".join(f'<span class="tag">{t}</span>' for t in s["tags"])
    return (
        f'<div class="card">\n'
        f'  <h3><a href="{s["file"]}">{s["title"]}</a></h3>\n'
        f'  <p>{s["desc"]}</p>\n'
        f'  <div class="tags">{tags}</div>\n'
        f'</div>'
    )


def main():
    here = Path(__file__).resolve().parent
    out_dir = here / "webpage"
    out_dir.mkdir(exist_ok=True)

    cards = "\n".join(make_card(s) for s in SCRIPTS)
    page = HTML.format(cards=cards)

    out = out_dir / "index.html"
    out.write_text(page, encoding="utf-8")
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
