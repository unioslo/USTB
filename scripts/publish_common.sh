#!/usr/bin/env bash
# publish_common.sh — shared helpers for publish_examples.sh / publish_publications.sh / publish_datasets.sh
#
# shellcheck shell=bash
# Intended to be *sourced* from the repo root scripts (same directory):

publish_common_matlab_extra() {
    MATLAB_BATCH_EXTRA=()
    _windows_env=0
    if [ -n "${WINDIR:-}" ] || [ -n "${SYSTEMROOT:-}" ]; then
        _windows_env=1
    fi
    case "${OSTYPE:-}" in
        msys*|cygwin*|mingw*)
            _windows_env=1
            ;;
    esac
    if [ "$_windows_env" -eq 0 ]; then
        case "$(uname -s 2>/dev/null)" in
            Linux|Darwin)
                MATLAB_BATCH_EXTRA=(-nodisplay)
                ;;
        esac
    fi
}

# Git Bash: /c/... → MATLAB needs C:/... (cygpath -m or drive-letter fallback).
publish_repo_path_for_matlab() {
    local p="$1"
    if [ "${_windows_env:-0}" -ne 1 ]; then
        printf '%s' "$p"
        return
    fi
    if command -v cygpath >/dev/null 2>&1; then
        if out=$(cygpath -m "$p" 2>/dev/null) && [ -n "$out" ]; then
            printf '%s' "$out"
            return
        fi
    fi
    case "$p" in
        /[a-zA-Z]/?*)
            local drive rest
            drive=$(printf '%s' "${p:1:1}" | tr '[:lower:]' '[:upper:]')
            rest="${p:3}"
            printf '%s:/%s' "$drive" "$rest"
            ;;
        *)
            printf '%s' "$p"
            ;;
    esac
}

publish_require_matlab() {
    if ! command -v matlab &>/dev/null; then
        echo "Error: MATLAB not found on PATH" >&2
        exit 1
    fi
}
