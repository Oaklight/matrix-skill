#!/bin/bash
# Install jq as a local static binary (no root required)
# Usage: bash scripts/install-jq.sh [install-dir]
#
# Default install dir: ~/.local/bin
# After install, ensure the dir is in your PATH.

set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"
JQ_VERSION="1.7.1"

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
  linux)  PLATFORM="linux" ;;
  darwin) PLATFORM="macos" ;;
  *)      echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64|amd64)   ARCH_SUFFIX="amd64" ;;
  aarch64|arm64)   ARCH_SUFFIX="arm64" ;;
  *)               echo "❌ Unsupported arch: $ARCH"; exit 1 ;;
esac

BINARY="jq-${PLATFORM}-${ARCH_SUFFIX}"
GITHUB_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/${BINARY}"

# Mirror options for users in China mainland
# Uncomment one of these if GitHub is slow:
# DOWNLOAD_URL="https://ghfast.top/${GITHUB_URL}"
# DOWNLOAD_URL="https://gh-proxy.com/${GITHUB_URL}"
# DOWNLOAD_URL="https://mirror.ghproxy.com/${GITHUB_URL}"
DOWNLOAD_URL="${DOWNLOAD_URL:-$GITHUB_URL}"

mkdir -p "$INSTALL_DIR"

echo "📦 Downloading jq ${JQ_VERSION} (${PLATFORM}/${ARCH_SUFFIX})..."
echo "   URL: $DOWNLOAD_URL"

if command -v curl &>/dev/null; then
  curl -fSL -o "${INSTALL_DIR}/jq" "$DOWNLOAD_URL"
elif command -v wget &>/dev/null; then
  wget -q -O "${INSTALL_DIR}/jq" "$DOWNLOAD_URL"
else
  echo "❌ Need curl or wget to download"; exit 1
fi

chmod +x "${INSTALL_DIR}/jq"

echo "✅ jq ${JQ_VERSION} installed to ${INSTALL_DIR}/jq"
"${INSTALL_DIR}/jq" --version

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  echo "⚠️  ${INSTALL_DIR} is not in your PATH. Add it:"
  echo "   export PATH=\"${INSTALL_DIR}:\$PATH\""
  echo "   # Or add to ~/.bashrc / ~/.zshrc for persistence"
fi
