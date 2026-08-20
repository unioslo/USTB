#!/usr/bin/env bash
#
# publish_examples.sh — Website example gallery (**examples-html.tar.gz** only)
#
# For publications HTML use ./publish_publications.sh.
# For dataset preview PNGs + datasets.html use ./publish_datasets.sh.
#
# Upload all three artifacts to GitHub Release **examples-v1** separately so CI can
# refresh one domain at a time.
#
# Usage:
#   ./publish_examples.sh
#   ./publish_examples.sh --upload [OWNER/REPO]

set -e
set -o pipefail 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=publish_common.sh
. "${SCRIPT_DIR}/publish_common.sh"

publish_common_matlab_extra
OUTPUT_DIR="${REPO_ROOT}/examples_html"
TARBALL="examples-html.tar.gz"
FIELD_II_PATH="/opt/field_ii"

echo "=== USTB Example Publisher (examples only) ==="
echo "Output: ${OUTPUT_DIR}"
echo ""

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

publish_require_matlab
echo "MATLAB: $(matlab -batch "disp(version)" 2>/dev/null | tail -1)"

echo -n "MEX: "
if ls "${REPO_ROOT}/+mex/das_c.mexw64" >/dev/null 2>&1; then
    ls -la "${REPO_ROOT}/+mex/das_c.mexw64" 2>/dev/null | awk '{print $6, $7, $8, $9}'
elif ls "${REPO_ROOT}/+mex/das_c.mexa64" >/dev/null 2>&1; then
    ls -la "${REPO_ROOT}/+mex/das_c.mexa64" 2>/dev/null | awk '{print $6, $7, $8, $9}'
else
    echo "(no das_c mex found)"
fi

FIELD_II_CMD=""
if [ -d "${FIELD_II_PATH}" ]; then
    echo "Field II: ${FIELD_II_PATH}"
    FIELD_II_CMD="addpath('${FIELD_II_PATH}');"
else
    echo "Field II: not found (field_II examples will use fresnel fallback)"
fi

echo ""

REPO_ROOT_M=$(publish_repo_path_for_matlab "$REPO_ROOT")
OUTPUT_DIR_M=$(publish_repo_path_for_matlab "$OUTPUT_DIR")
echo "Publishing examples..."
echo "(MATLAB cwd path: ${REPO_ROOT_M})"
unset DISPLAY
matlab "${MATLAB_BATCH_EXTRA[@]}" -batch "cd('${REPO_ROOT_M}'); addpath(genpath(pwd)); ${FIELD_II_CMD}publish_all_examples('${OUTPUT_DIR_M}', true);" 2>&1 | tee publish_examples.log

echo ""
echo "=== Checking for errors in published HTML ==="
ERROR_COUNT=0
for f in $(find "${OUTPUT_DIR}" -name "*.html"); do
    if grep -q "Error using\|Error in " "$f" 2>/dev/null; then
        NAME=$(echo "$f" | sed "s|${OUTPUT_DIR}/||")
        echo "  ERROR: ${NAME}"
        DIR=$(dirname "$f")
        BASE=$(basename "$f" .html)
        rm -f "$f" "${DIR}/${BASE}"_*.png
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
done
echo "Removed ${ERROR_COUNT} examples with errors"

echo ""
echo "=== Generating examples index ==="
python3 "${SCRIPT_DIR}/generate_examples_index.py" "${OUTPUT_DIR}"

HTML_COUNT=$(find "${OUTPUT_DIR}" -name "*.html" -not -name "index.html" | wc -l)
PNG_COUNT=$(find "${OUTPUT_DIR}" -name "*.png" | wc -l)
echo ""
echo "=== Summary ==="
echo "Examples: ${HTML_COUNT}"
echo "Figures:  ${PNG_COUNT}"
echo "Output:   ${OUTPUT_DIR}"

echo ""
echo "=== Packaging ==="
cd "${OUTPUT_DIR}" && tar -czf "${REPO_ROOT}/${TARBALL}" . && cd "${REPO_ROOT}"
echo "Tarball: ${TARBALL} ($(du -h "${REPO_ROOT}/${TARBALL}" | cut -f1))"

if [ "${1:-}" = "--upload" ]; then
    echo ""
    echo "=== Uploading to GitHub Release examples-v1 ==="
    REPO="${2:-olemarius90/USTB}"
    gh release upload examples-v1 "${REPO_ROOT}/${TARBALL}" --repo "${REPO}" --clobber
    echo "Uploaded ${TARBALL} to ${REPO} release examples-v1"
fi

echo ""
echo "Done!"
