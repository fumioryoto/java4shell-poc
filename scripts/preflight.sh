#!/usr/bin/env bash
# preflight.sh — Verify CPU and runtime prerequisites for CVE-2026-114938.
#
# Exit codes:
#   0 — all prerequisites met
#   2 — CPU is missing one or more required AVX-512 VBMI flags
#   3 — Java not found on PATH
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() { printf '    \033[32m[ok]\033[0m %s\n' "$*"; }
fail() { printf '    \033[31m[MISSING]\033[0m %s\n' "$*"; }
info() { printf '\033[36m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. CPU flags
# ---------------------------------------------------------------------------
info "Checking CPU flags for AVX-512 VBMI (required by the vulnerable code path)..."
echo

REQUIRED_FLAGS=(avx512f avx512bw avx512vbmi bmi2)
CPU_FLAGS_FILE=/proc/cpuinfo

if [ ! -f "$CPU_FLAGS_FILE" ]; then
    warn "/proc/cpuinfo not found. This check only works on Linux."
    warn "macOS / BSD: use 'sysctl -a | grep AVX512' manually."
    warn "ARM64 is not affected by this vulnerability."
    exit 2
fi

FLAGS_LINE=$(grep -m1 '^flags' "$CPU_FLAGS_FILE" | tr ' ' '\n' | sort)

MISSING=0
for FLAG in "${REQUIRED_FLAGS[@]}"; do
    if grep -qx "$FLAG" <<< "$FLAGS_LINE"; then
        pass "$FLAG"
    else
        fail "$FLAG"
        MISSING=1
    fi
done

echo
if [ "$MISSING" -ne 0 ]; then
    warn "One or more required CPU flags are absent."
    warn "This host CANNOT trigger the vulnerable AVX-512 VBMI code path."
    warn "The PoC will report NOT VULNERABLE by design."
    warn "To reproduce, use an Intel Ice Lake / Sapphire Rapids / Emerald Rapids"
    warn "/ Granite Rapids or AMD Zen 4+ machine."
    exit 2
fi

info "All required CPU flags present."
echo

# ---------------------------------------------------------------------------
# 2. Architecture check
# ---------------------------------------------------------------------------
ARCH=$(uname -m)
info "Architecture: $ARCH"
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    warn "ARM64 detected. This vulnerability does not affect ARM64."
    exit 2
fi

# ---------------------------------------------------------------------------
# 3. Java
# ---------------------------------------------------------------------------
info "Checking Java..."
if ! command -v java >/dev/null 2>&1; then
    warn "'java' not found on PATH."
    warn "Run ./scripts/setup-runtime.sh to download a pinned vulnerable JDK,"
    warn "then set JAVA_HOME and re-run this script."
    exit 3
fi

JAVA_VERSION_OUTPUT=$(java -version 2>&1)
printf '    %s\n' "$JAVA_VERSION_OUTPUT"
echo

# Extract feature version
FEATURE=$(java -XshowSettings:property -version 2>&1 | grep 'java.version' | head -1 | \
          grep -oE '[0-9]+' | head -1)
info "JDK feature version detected: $FEATURE"

case "$FEATURE" in
  17)
    info "Payload to use: 129-byte trigger ('A'*128 + '=')"
    info "Vulnerable range: 17.0.6 – 17.0.21"
    ;;
  21|25|27)
    info "Payload to use: 65-byte trigger ('A'*64 + '=')"
    ;;
  *)
    warn "JDK $FEATURE may not be tested. Check the README's affected-versions table."
    ;;
esac

echo
info "Preflight complete. Run './scripts/run-poc.sh' to execute the PoC."
