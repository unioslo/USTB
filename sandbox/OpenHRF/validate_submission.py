"""Validate every converted .hdf5 against the zea spec (single process).

Uses the OpenH-RF evaluator's `validate_zea_spec.py` to run zea's own
`File.validate` + `File.validate_spec` on each acquisition and confirm
`/data/raw_data` is present and `zea_version >= 0.1.0a3`.

Usage::

    python validate_submission.py [output_dir]
"""

import os
import sys
from pathlib import Path

os.environ.setdefault("KERAS_BACKEND", "jax")

# Locate the OpenH-RF evaluator's validate_zea_spec.py. Set OPENHRF_REPO to your
# local OpenH-RF clone; we search both the current (openh-rf-shared) and older
# (openh-rf-submission-eval/scripts) layouts.
_OPENHRF = Path(os.environ.get("OPENHRF_REPO", r"C:\Repositories\OpenH-RF"))
for _cand in (_OPENHRF / "skills" / "openh-rf-shared",
              _OPENHRF / "skills" / "openh-rf-submission-eval" / "scripts"):
    if (_cand / "validate_zea_spec.py").exists():
        sys.path.insert(0, str(_cand))
        break
from validate_zea_spec import validate  # noqa: E402

root = Path(sys.argv[1] if len(sys.argv) > 1 else r"C:\Data\USTB_data\openh_rf_submission")
files = sorted(root.rglob("*.hdf5"))
n_ok = 0
fails = []
for p in files:
    r = validate(p)
    ok = r["compliant"]
    n_ok += ok
    flag = "OK " if ok else "FAIL"
    print(f"  [{flag}] {p.parent.name}/{p.name}  zea={r['file_zea_version']} raw={r['has_raw_data']}")
    if not ok:
        fails.append((str(p), r["errors"]))
print(f"\n{n_ok}/{len(files)} compliant")
for f, e in fails:
    print("FAIL", f, e)
