#!/usr/bin/env bash
# setup-runtime.sh — Download a pinned vulnerable JDK into ./runtimes/ for
#                    local reproduction.
#
# IMPORTANT: Replace VENDOR, VERSION, and URL with the exact vulnerable build
#            from your chosen vendor (Adoptium, Amazon Corretto, Azul, etc.)
#            after verifying against the CVE advisory.
#
# Usage:
#   ./scripts/setup-runtime.sh
#   VENDOR=corretto VERSION=21.0.13.9.1 ./scripts/setup-runtime.sh
#
# Exit codes:
#   0 — success
#   1 — download or extraction failure
#   2 — unsupported OS or architecture
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — override via environment variables
# ---------------------------------------------------------------------------
VENDOR="${VENDOR:-temurin}"
VERSION="${VERSION:-21.0.13+9}"          # ← Replace with actual vulnerable tag
ARCH="${ARCH:-x64}"
OS_NAME="${OS_NAME:-linux}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$SCRIPT_DIR/../runtimes"
mkdir -p "$DEST_DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info() { printf '\033[36m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# OS / arch detection
# ---------------------------------------------------------------------------
OS_TYPE=$(uname -s)
MACHINE=$(uname -m)

case "$OS_TYPE" in
  Linux)  OS_NAME="linux" ;;
  Darwin) OS_NAME="mac"   ;;
  *)      die "Unsupported OS: $OS_TYPE. Download a JDK manually." ;;
esac

case "$MACHINE" in
  x86_64)          ARCH="x64"   ;;
  aarch64|arm64)   ARCH="aarch64" ; warn "ARM64 not affected by CVE-2026-114938." ;;
  *)               die "Unsupported architecture: $MACHINE." ;;
esac

# ---------------------------------------------------------------------------
# Encode '+' as '_' in the archive name (Adoptium convention)
# ---------------------------------------------------------------------------
VERSION_SAFE="${VERSION//+/_}"

# ---------------------------------------------------------------------------
# Build download URL
# Example for Adoptium / Eclipse Temurin:
# https://github.com/adoptium/temurin21-binaries/releases/download/
#   jdk-21.0.13%2B9/OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz
# ---------------------------------------------------------------------------
FEATURE=$(echo "$VERSION" | grep -oE '^[0-9]+')
ARCHIVE_NAME="OpenJDK${FEATURE}U-jdk_${ARCH}_${OS_NAME}_hotspot_${VERSION_SAFE}.tar.gz"
URL="https://github.com/adoptium/temurin${FEATURE}-binaries/releases/download/jdk-${VERSION//+/%2B}/${ARCHIVE_NAME}"

ARCHIVE="$DEST_DIR/$ARCHIVE_NAME"

info "Vendor  : $VENDOR"
info "Version : $VERSION"
info "Arch    : $ARCH"
info "OS      : $OS_NAME"
info "Dest    : $DEST_DIR"
echo

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
if [ -f "$ARCHIVE" ]; then
    info "Archive already present: $ARCHIVE"
    info "Delete it to force a fresh download."
else
    info "Downloading: $URL"
    warn "If this URL 404s, replace VENDOR/VERSION in this script with the"
    warn "exact vulnerable build from the advisory or vendor release page."
    echo
    curl -fL --retry 3 --progress-bar -o "$ARCHIVE" "$URL" || \
        die "Download failed. Check the URL and your network connection."
fi

# ---------------------------------------------------------------------------
# Verify (checksum — optional but recommended)
# ---------------------------------------------------------------------------
# Uncomment and add the expected SHA-256 for the pinned build:
# EXPECTED_SHA256="<sha256 from vendor release page>"
# ACTUAL_SHA256=$(sha256sum "$ARCHIVE" | awk '{print $1}')
# if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
#     die "SHA-256 mismatch! Expected $EXPECTED_SHA256, got $ACTUAL_SHA256."
# fi
# info "SHA-256 verified."

# ---------------------------------------------------------------------------
# Extract
# ---------------------------------------------------------------------------
info "Extracting to $DEST_DIR..."
tar -xzf "$ARCHIVE" -C "$DEST_DIR"

# Find the extracted directory (Adoptium uses jdk-VERSION as the top-level dir)
JDK_DIR=$(find "$DEST_DIR" -maxdepth 1 -type d -name "jdk*" | head -1)

if [ -z "$JDK_DIR" ]; then
    die "Could not locate extracted JDK directory under $DEST_DIR"
fi

echo
info "JDK extracted to: $JDK_DIR"
echo
info "Export these before running the PoC:"
echo
echo "    export JAVA_HOME=\"$JDK_DIR\""
echo "    export PATH=\"\$JAVA_HOME/bin:\$PATH\""
echo
info "Then run: ./scripts/run-poc.sh"
