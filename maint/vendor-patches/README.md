# Vendor crate patches (armv7 / musl / ancient kernels)

These patches are **not** part of the upstream product tree series under
`maint/patches/`. They modify third-party crates in
`$CARGO_HOME/registry/src` after Cargo has fetched them.

## When to apply

Run after dependency download and **before** `cargo build` when targeting:

- `armv7-unknown-linux-musleabihf` / `armv7-unknown-linux-gnueabihf`
- Ancient Linux kernels (e.g. 3.4 / CyanogenMod) where `/proc/sys/kernel/random/entropy_avail`
  stays below 256 and AWS-LC would otherwise block forever on `RNDGETENTCNT`

```bash
# from the gork-build recipe repo root (after checkout + cargo fetch)
./maint/scripts/apply_vendor_patches.sh
```

The script is idempotent: it greps for a marker string and skips crates that
are already patched.

## Patches

| Patch | Crate | Purpose |
|-------|-------|---------|
| `aws-lc-sys-0.39.1-skip-rndgetentcnt.patch` | aws-lc-sys 0.39.1 | Skip `RNDGETENTCNT` entropy wait in `ensure_dev_urandom_is_initialized` |
| `nono-0.53.0-arm-sys-openat.patch` | nono 0.53.0 | Define `SYS_OPENAT` / `SYS_OPENAT2` for `target_arch = "arm"` |
| `sqlite-vec-0.1.7-alpha.2-musl-uint-typedefs.patch` | sqlite-vec 0.1.7-alpha.2 | Disable BSD `u_int*_t` typedefs that break musl |

## Regenerating

Unpack the matching `.crate` from `~/.cargo/registry/cache/`, copy the
patched file from a working registry checkout (or re-apply the edit), then:

```bash
diff -u pristine/... patched/... | sed '1s|.*|--- a/...|;2s|.*|+++ b/...|' \
  > maint/vendor-patches/<name>.patch
```

Patches must apply with `patch -p1` from the crate root.
