<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Arch packaging

> For end-user installation and usage, see [docs/install/arch.md](../../docs/install/arch.md).

This directory contains PKGBUILDs and helper scripts for Arch Linux:

| Package | Content |
|---|---|
| `honor-magicbook-pro-14` | Prebuilt DSDT + mkinitcpio hook, udev/hwdb quirks, 3 DKMS drivers, diagnostic tools, charge-limit service |
| `honor-fmbp-edid` | Optional HDR EDID firmware for the internal panel (auto-configures standard GRUB) |
| `honor-fmbp-libfprint` | Optional drop-in replacement for Arch's `libfprint` with `10a5:9924` support (MR !666) |

The interactive `./packaging/arch/install.sh` wraps these recipes (plus external Arch
recipes for `1c7a:05aa` and `10a5:a920`). For local checkout builds, it passes
`--skipchecksums` on the locally generated main/EDID tarballs; fingerprint source
verification and standalone PKGBUILD checks remain unchanged.

## Build individual packages locally

With `base-devel` installed, run from the repository root as a regular user:

```bash
bash packaging/arch/make-sources.sh 1.0.9 packaging/arch/out
export SRCDEST="$PWD/packaging/arch/out"
(cd packaging/arch/honor-magicbook-pro-14 && makepkg -si)
```

- Run the same `makepkg -si` command in `honor-fmbp-edid` or `honor-fmbp-libfprint` as
  needed (or `makepkg -s` to build without installing).
- Building `honor-fmbp-libfprint` runs the upstream test suite and may require trusting
  the upstream PGP signing key (verify the fingerprint against the `PKGBUILD`). If the
  pinned upstream tag already includes the `10a5:9924` USB reset fix, the build skips
  the patch and prompts you to update the recipe.

## Release and AUR

Standalone PKGBUILDs download the checksummed tarballs produced by `make-sources.sh`
(distinct from the Fedora COPR source archive):

1. Generate deterministic release assets (independent of checkout mtimes and the
   `packaging/arch/` files):
   ```bash
   bash packaging/arch/make-sources.sh <version> packaging/arch/out
   b2sum packaging/arch/out/*
   ```
2. Update `b2sums` in the affected `PKGBUILD`s and refresh `.SRCINFO` with
   `makepkg --printsrcinfo > .SRCINFO`.
3. Confirm redistribution rights for firmware-derived assets before publishing, attach
   the generated assets to the GitHub release, then publish each `PKGBUILD`, `.SRCINFO`,
   and `.install` file to AUR.
4. Once a release is published, always bump the version/asset name if any source
   manifest input changes.
