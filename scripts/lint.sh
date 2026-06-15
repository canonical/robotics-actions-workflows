#!/usr/bin/env bash
# Run actionlint + shellcheck locally — mirrors what the lint CI job does.
#
# Usage:
#   ./scripts/lint.sh
#
# Dependencies (auto-installed to /tmp if missing):
#   - actionlint  https://github.com/rhysd/actionlint
#   - shellcheck  https://github.com/koalaman/shellcheck
set -euo pipefail

ACTIONLINT_VERSION="1.7.7"
SHELLCHECK_VERSION="0.10.0"

ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

# ── shellcheck ────────────────────────────────────────────────────────────────
if command -v shellcheck &>/dev/null; then
  SHELLCHECK="$(command -v shellcheck)"
else
  SC_ARCH="${ARCH}"
  [[ "${SC_ARCH}" == "x86_64" ]] && SC_ARCH="x86_64"
  [[ "${SC_ARCH}" == "aarch64" ]] && SC_ARCH="aarch64"
  SC_ARCHIVE="shellcheck-v${SHELLCHECK_VERSION}.${OS}.${SC_ARCH}.tar.xz"
  SC_URL="https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/${SC_ARCHIVE}"
  echo "shellcheck not found — downloading v${SHELLCHECK_VERSION} ..."
  curl -sSfL "${SC_URL}" | tar -xJ -C /tmp --strip-components=1 "shellcheck-v${SHELLCHECK_VERSION}/shellcheck"
  SHELLCHECK="/tmp/shellcheck"
fi

# ── actionlint ────────────────────────────────────────────────────────────────
if command -v actionlint &>/dev/null; then
  ACTIONLINT="$(command -v actionlint)"
else
  AL_ARCH="${ARCH}"
  [[ "${AL_ARCH}" == "x86_64" ]] && AL_ARCH="amd64"
  [[ "${AL_ARCH}" == "aarch64" ]] && AL_ARCH="arm64"
  AL_ARCHIVE="actionlint_${ACTIONLINT_VERSION}_${OS}_${AL_ARCH}.tar.gz"
  AL_URL="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${AL_ARCHIVE}"
  echo "actionlint not found — downloading v${ACTIONLINT_VERSION} ..."
  curl -sSfL "${AL_URL}" | tar -xz -C /tmp actionlint
  ACTIONLINT="/tmp/actionlint"
fi

echo "Using actionlint: $("${ACTIONLINT}" --version 2>&1 | head -1)"
echo "Using shellcheck: $("${SHELLCHECK}" --version | head -2 | tail -1)"
echo ""

exec "${ACTIONLINT}" -shellcheck "${SHELLCHECK}" -color "$@"
