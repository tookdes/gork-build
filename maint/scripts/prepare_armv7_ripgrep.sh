#!/usr/bin/env bash
set -euo pipefail

# Upstream 1.0.45 release builds bundle ripgrep, but its build scripts only
# auto-download x86_64/aarch64 Linux assets. Supply the official static armv7
# musl hard-float binary explicitly so both xai-grok-tools and xai-grok-shell
# can embed it without falling back to a host binary.
RG_VER="15.0.0"
RG_TRIPLE="armv7-unknown-linux-musleabihf"
RG_SHA256="e6fdbe890704c49d694538357f1819202163cab27e75c1ec5da8bf7c83eebaf0"
ROOT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/gork-rg-${RG_VER}-${RG_TRIPLE}"
ARCHIVE="${ROOT}/ripgrep-${RG_VER}-${RG_TRIPLE}.tar.gz"
DIR="${ROOT}/ripgrep-${RG_VER}-${RG_TRIPLE}"
BIN="${DIR}/rg"

mkdir -p "${ROOT}"
if [[ ! -f "${ARCHIVE}" ]]; then
  curl -fsSL --retry 5 --retry-delay 2 \
    -o "${ARCHIVE}" \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VER}/ripgrep-${RG_VER}-${RG_TRIPLE}.tar.gz"
fi

printf '%s  %s\n' "${RG_SHA256}" "${ARCHIVE}" | sha256sum -c - >&2

rm -rf "${DIR}"
tar -xzf "${ARCHIVE}" -C "${ROOT}"
test -f "${BIN}"
chmod +x "${BIN}"

# Fail closed: the embedded helper must itself be ARM and static.
file "${BIN}" >&2
readelf -h "${BIN}" | grep -Eq 'Machine:[[:space:]]+ARM'
if readelf -l "${BIN}" | grep -q 'Requesting program interpreter'; then
  echo "bundled armv7 ripgrep is dynamically linked (PT_INTERP present)" >&2
  exit 1
fi
if readelf -d "${BIN}" 2>/dev/null | grep -q '(NEEDED)'; then
  echo "bundled armv7 ripgrep has dynamic NEEDED entries" >&2
  exit 1
fi

printf '%s\n' "${BIN}"
