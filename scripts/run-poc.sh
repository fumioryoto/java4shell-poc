#!/usr/bin/env bash
# run-poc.sh — Compile and run the bounded CVE-2026-114938 PoC.
#
# Requires JAVA_HOME to point to a JDK build in the vulnerable range.
# Run ./scripts/setup-runtime.sh and export JAVA_HOME first.
#
# Usage:
#   ./scripts/run-poc.sh                                        # vulnerable run
#   JAVA_TOOL_OPTIONS=-XX:-UseBASE64Intrinsics ./scripts/run-poc.sh  # mitigated
#
# Exit codes mirror the PoC:
#   0 — NOT VULNERABLE (or intrinsic disabled / non-AVX-512 CPU)
#   1 — VULNERABLE (canary corruption observed)
#   2 — prerequisites not met
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info() { printf '\033[36m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
if [ -z "${JAVA_HOME:-}" ]; then
    # Attempt to infer from PATH as a fallback
    if command -v java >/dev/null 2>&1; then
        JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
        warn "JAVA_HOME not set. Inferred: $JAVA_HOME"
        warn "For a pinned vulnerable build, run ./scripts/setup-runtime.sh"
        warn "and export JAVA_HOME before running this script."
    else
        die "JAVA_HOME is not set and 'java' was not found on PATH."
    fi
fi

JAVA="$JAVA_HOME/bin/java"
JAVAC="$JAVA_HOME/bin/javac"

[ -x "$JAVA" ]  || die "'java' not found at $JAVA"
[ -x "$JAVAC" ] || die "'javac' not found at $JAVAC"

# ---------------------------------------------------------------------------
# Version info
# ---------------------------------------------------------------------------
info "JAVA_HOME = $JAVA_HOME"
"$JAVA" -version 2>&1 | sed 's/^/    /'
echo

if [ -n "${JAVA_TOOL_OPTIONS:-}" ]; then
    info "JAVA_TOOL_OPTIONS = $JAVA_TOOL_OPTIONS"
    echo
fi

# ---------------------------------------------------------------------------
# Compile
# ---------------------------------------------------------------------------
BUILD_DIR="$REPO_ROOT/build/classes"
SRC_DIR="$REPO_ROOT/src/main/java/com/example/java4shell"

mkdir -p "$BUILD_DIR"

info "Compiling..."
"$JAVAC" -encoding UTF-8 -d "$BUILD_DIR" \
  "$SRC_DIR/Base64Trigger.java" \
  "$SRC_DIR/Main.java"
info "Compiled to $BUILD_DIR"
echo

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
# Note: on a vulnerable JVM this may produce an hs_err_pid*.log in the working
# directory if the heap corruption is severe enough to crash the JVM. Those
# files are listed in .gitignore so they will not be committed accidentally.
exec "$JAVA" \
  ${JAVA_TOOL_OPTIONS:-} \
  -cp "$BUILD_DIR" \
  com.example.java4shell.Main
