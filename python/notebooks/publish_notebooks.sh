#!/bin/bash
#
# publish_notebooks.sh - Execute notebooks and convert to HTML
#
# Usage:
#   ./publish_notebooks.sh              # Execute and convert
#   ./publish_notebooks.sh --upload     # Execute, convert, and upload
#
# Prerequisites: pip install ustb[dev] jupyter nbconvert jupytext

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HTML_DIR="${SCRIPT_DIR}/html"
mkdir -p "${HTML_DIR}"

echo "=== USTB Python Notebook Publisher ==="

for nb in "${SCRIPT_DIR}"/*.ipynb; do
    name=$(basename "$nb")
    echo "Executing ${name}..."
    jupyter nbconvert --to notebook --execute \
        --ExecutePreprocessor.timeout=600 \
        "$nb" --output "$name"
    echo "Converting ${name} to HTML..."
    jupyter nbconvert --to html "$nb" --output-dir "${HTML_DIR}"
done

echo ""
echo "=== Summary ==="
echo "Notebooks: $(ls ${SCRIPT_DIR}/*.ipynb | wc -l)"
echo "HTML files: $(ls ${HTML_DIR}/*.html | wc -l)"
echo "Output: ${HTML_DIR}"

if [ "$1" = "--upload" ]; then
    REPO="${2:-olemarius90/USTB}"
    cd "${HTML_DIR}" && tar -czf /tmp/python-examples-html.tar.gz .
    gh release upload examples-v1 /tmp/python-examples-html.tar.gz --repo "${REPO}" --clobber
    echo "Uploaded to ${REPO}"
fi
