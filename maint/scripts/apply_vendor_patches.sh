#!/usr/bin/env bash
# Apply gork-build vendor crate patches into $CARGO_HOME/registry/src.
# Run after `cargo fetch` / dependency download and before `cargo build`
# for musl armv7 / ancient-kernel (e.g. Linux 3.4) targets.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="${ROOT}/maint/vendor-patches"
CARGO_HOME="${CARGO_HOME:-${HOME}/.cargo}"
SRC_ROOT="${CARGO_HOME}/registry/src"

if [[ ! -d "$SRC_ROOT" ]]; then
  echo "error: cargo registry src not found: $SRC_ROOT" >&2
  echo "hint: run cargo fetch / download dependencies first" >&2
  exit 1
fi

find_crate_dir() {
  local name="$1"
  # Prefer exact directory match under any registry index hash.
  local matches=()
  while IFS= read -r -d '' d; do
    matches+=("$d")
  done < <(find "$SRC_ROOT" -mindepth 2 -maxdepth 2 -type d -name "$name" -print0 2>/dev/null)

  if [[ ${#matches[@]} -eq 0 ]]; then
    return 1
  fi
  # Prefer the most recently modified copy if multiples exist.
  printf '%s\n' "${matches[@]}" | xargs -d '\n' ls -1dt | head -1
}

apply_one() {
  local crate="$1"
  local patch_file="$2"
  local marker="$3"
  local patch_path="${PATCH_DIR}/${patch_file}"

  if [[ ! -f "$patch_path" ]]; then
    echo "error: missing patch $patch_path" >&2
    exit 1
  fi

  local crate_dir
  if ! crate_dir="$(find_crate_dir "$crate")"; then
    echo "error: crate dir for ${crate} not found under ${SRC_ROOT}" >&2
    echo "hint: cargo fetch the dependency first" >&2
    exit 1
  fi

  if grep -Rql --fixed-strings "$marker" "$crate_dir" 2>/dev/null; then
    echo "ok: ${crate} already patched (marker present) at ${crate_dir}"
    return 0
  fi

  echo "applying ${patch_file} -> ${crate_dir}"
  if ! patch -p1 -d "$crate_dir" --forward --batch <"$patch_path"; then
    echo "error: failed to apply ${patch_file} to ${crate_dir}" >&2
    exit 1
  fi

  if ! grep -Rql --fixed-strings "$marker" "$crate_dir" 2>/dev/null; then
    echo "error: patch applied but marker not found for ${crate}: ${marker}" >&2
    exit 1
  fi
  echo "ok: applied ${patch_file}"
}

apply_one "aws-lc-sys-0.39.1" \
  "aws-lc-sys-0.39.1-skip-rndgetentcnt.patch" \
  "Gork Build / ancient kernels"

apply_one "nono-0.53.0" \
  "nono-0.53.0-arm-sys-openat.patch" \
  "ARM (armv7hf / EABI) — not upstream in nono 0.53.0"

apply_one "sqlite-vec-0.1.7-alpha.2" \
  "sqlite-vec-0.1.7-alpha.2-musl-uint-typedefs.patch" \
  "gork-build: skip BSD u_int*_t typedefs"

echo "all vendor patches applied"
