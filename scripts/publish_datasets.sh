#!/usr/bin/env bash
#
# publish_datasets.sh — Beamform PNG previews + datasets.html for the website
#
# Produces datasets-html.tar.gz (contents rooted at repo website/ ):
#   datasets.html
#   assets/images/datasets/*.png
#
# GitHub Actions: deploy-website.yml extracts this tarball with -C website
#
# Prerequisites: MATLAB + USTB, Python 3, network (Zenodo / ustb dataset hosts)
#
# Usage:
#   ./publish_datasets.sh
#   ./publish_datasets.sh --upload
#   ./publish_datasets.sh --upload unioslo/USTB

set -e
set -o pipefail 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=publish_common.sh
. "${SCRIPT_DIR}/publish_common.sh"

publish_common_matlab_extra
TARBALL="datasets-html.tar.gz"
WEBSITE="${REPO_ROOT}/website"

publish_require_matlab
echo "MATLAB: $(matlab -batch "disp(version)" 2>/dev/null | tail -1)"

REPO_ROOT_M=$(publish_repo_path_for_matlab "$REPO_ROOT")
echo ""
echo "=== USTB dataset previews + datasets page ==="
echo "Website dir: ${WEBSITE}"
echo "(MATLAB repo path: ${REPO_ROOT_M})"
echo ""

mkdir -p "${WEBSITE}/assets/images/datasets"

echo "Exporting previews (MATLAB, may download many datasets)..."
unset DISPLAY
matlab "${MATLAB_BATCH_EXTRA[@]}" -batch "cd('${REPO_ROOT_M}'); addpath(genpath(pwd)); export_dataset_previews_to_website();" \
    2>&1 | tee publish_datasets_matlab.log

echo ""
echo "Building datasets.html..."
python3 "${REPO_ROOT}/website/scripts/build_datasets_page.py"

if [ ! -f "${WEBSITE}/datasets.html" ]; then
    echo "Error: ${WEBSITE}/datasets.html missing after build" >&2
    exit 1
fi

echo ""
echo "=== Packaging ${TARBALL} ==="
(
    cd "${WEBSITE}"
    tar -czf "${REPO_ROOT}/${TARBALL}" datasets.html assets/images/datasets
)
echo "Tarball: ${TARBALL} ($(du -h "${REPO_ROOT}/${TARBALL}" | cut -f1))"

if [ "${1:-}" = "--upload" ]; then
    echo ""
    echo "=== Uploading to GitHub Release examples-v1 ==="
    REPO="${2:-olemarius90/USTB}"
    gh release upload examples-v1 "${REPO_ROOT}/${TARBALL}" --repo "${REPO}" --clobber
    echo "Uploaded ${TARBALL} to ${REPO} release examples-v1"
fi

echo "Done."
