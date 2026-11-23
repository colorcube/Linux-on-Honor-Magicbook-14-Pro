<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Contributing

Every contribution is welcome: test reports, fixes, documentation, packages.

## Test reports

Test reports are the most valuable contribution, especially for:

- **Chinese units** (`dsdt.chinese.aml` is untested on hardware)
- **BIOS 1.16 / 1.17**
- **distributions other than Fedora** (Arch, Ubuntu, openSUSE, …)

Open an issue with the "Test report" template. Include the output of
`sudo tools/honor-fmbp-diag` and say what worked and what didn't. Results go into
[docs/testing.md](docs/testing.md) with your name.

## Fixes and code

- Keep one topic per PR. Each fix lives in its own directory under `fixes/` with a
  README covering the problem, the cause, the fix, how to verify it, and credits.
- Prefer kernel- or firmware-level fixes (DSDT, hwdb, driver) over desktop
  workarounds, and upstream over out-of-tree.
- Gate everything to the FMB-P (DMI) and make it removable with
  `install.sh --uninstall`.
- Add an SPDX header to every file: code GPL-2.0-or-later, docs CC-BY-4.0
  ([REUSE](https://reuse.software)). `reuse lint` must pass.
- **Name your sources.** If you build on someone else's findings, link them and add
  them to [CONTRIBUTORS.md](CONTRIBUTORS.md). Use `Co-authored-by:` trailers in commits.
- Never commit raw ACPI dumps (`acpidump -b`). The `MSDM` table holds the Windows
  product key.

## Packages

Fedora packages (COPR) are being built from `packaging/fedora/`. If you want packages
for another distribution and can test them, open an issue and we'll set them up
together.
