#!/usr/bin/env bash
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
TOKEN=""
SERVER="tnmn.click"
PROTO="http"
PORT="3000"
NAME=""
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"

# ── Args ───────────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 --token TOKEN [--server HOST] [--proto http|tcp|udp] [--port PORT] [--name SUBDOMAIN]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --token)   TOKEN="$2";  shift 2 ;;
    --server)  SERVER="$2"; shift 2 ;;
    --proto)   PROTO="$2";  shift 2 ;;
    --port)    PORT="$2";   shift 2 ;;
    --name)    NAME="$2";   shift 2 ;;
    *)         usage ;;
  esac
done

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: --token is required"
  usage
fi

# ── Detect OS / Arch ────────────────────────────────────────────────────────────
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux)  ASSET="tnmn-linux-${ARCH}" ;;
  darwin) ASSET="tnmn-darwin-${ARCH}" ;;
  *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

REPO="ngucungcode/tnmn-client"
LATEST_URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"
CHECKSUMS_URL="https://github.com/${REPO}/releases/latest/download/checksums.txt"

echo "[1/4] Detecting platform: $OS / $ARCH"
echo "[2/4] Downloading binary..."
TMPBIN=$(mktemp)
curl -fSL "$LATEST_URL" -o "$TMPBIN"

echo "[3/4] Verifying checksum..."
CHECKSUMS=$(curl -fSL "$CHECKSUMS_URL" || echo "")
EXPECTED_HASH=$(echo "$CHECKSUMS" | grep " $ASSET$" | awk '{print $1}')
if [[ -n "$EXPECTED_HASH" ]]; then
  ACTUAL_HASH=$(sha256sum "$TMPBIN" | awk '{print $1}')
  if [[ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]]; then
    echo "ERROR: checksum mismatch!"
    echo "  expected: $EXPECTED_HASH"
    echo "  actual:   $ACTUAL_HASH"
    rm -f "$TMPBIN"
    exit 1
  fi
  echo "      Checksum OK"
else
  echo "      Skipping checksum (not found)"
fi

echo "[4/4] Installing to ${INSTALL_DIR}/tnmn..."
mkdir -p "$INSTALL_DIR"
mv "$TMPBIN" "${INSTALL_DIR}/tnmn"
chmod +x "${INSTALL_DIR}/tnmn"

echo ""
echo "[OK] Installed: ${INSTALL_DIR}/tnmn"

if [[ -n "$NAME" ]]; then
  echo ""
  echo "Logging in..."
  "${INSTALL_DIR}/tnmn" login --token "$TOKEN" --server "$SERVER" || true
  echo ""
  echo "Starting tunnel..."
  "${INSTALL_DIR}/tnmn" "$PROTO" "$PORT" --name "$NAME"
else
  echo ""
  echo "Setup done. To connect:"
  echo "  tnmn login --token <TOKEN> --server $SERVER"
  echo "  tnmn $PROTO $PORT --name <SUBDOMAIN>"
fi
