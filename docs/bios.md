<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# BIOS versions and variants

| BIOS | Date | Notes |
|---|---|---|
| 1.13 | 2025-05-08 | Shipping BIOS of many units. DSDT has the NFC0 load bug. Reference for `dsdt/prebuilt/`. |
| 1.14 | ? | Mentioned in denis-bb#4, not analysed. |
| 1.16 | 2026-03-25 | Same DSDT bug as 1.13 (tsukasagenesis). Microcode 0x116 → 0x11A, new 16 GB Micron LPDDR5X part, `OneKeyCheck` recovery variable widened to 32 bit and controllable via WMI, new EC commands (dual-battery test mode, sensor id), no more Intel ME update in the package. Package "20260509" is the same 1.16 (domakira). |
| 1.17 | 2026-10 | "BIOS 20261010 (1.17-2.07)". **Fixes the NFC0 load abort**: the `GNUM` call moved from table-load time into `NFC0._CRS`. That is the only ACPI change. Also a new 8 GB Micron LPDDR5X part and a rebuilt EC firmware. The touchscreen power resource is still missing. Verified from the firmware capsule, not yet tested on hardware. |

BIOS 1.16/1.17 changes: binary analysis by **mrueg** (#22). Verified independently by
extracting the DSDT from the official firmware capsules (`FBARL113/116/117.BIN`):

- The DSDT stored in 1.13 and 1.16 is **byte-identical**.
- 1.17 differs **only** in `NFC0`: the `GNUM` call moved from table load into `_CRS`.
- The stored table is a template. At boot the firmware fills in the header (OEM ID
  `HONOR`, table ID `ARL`, **OEM revision 2**), all NVS base addresses and lengths
  (`GNVS`, `SANB`, `VMNB`, `PNVB`, `OGNS`, `MDBG`), `SS3` (S3 off) and renames `_EDL`. The
  code that does this is unchanged in 1.17, so the OEM revision stays 2 and our
  override (revision 3) still applies.

### What 1.17 means for the fixes

- Touchpad, NVMe, USB-C and battery info should work **without** a DSDT override.
- The touchscreen still needs the override (PowerResource).
- `dsdt/build.sh` recognises the fixed NFC0, skips that step and only injects the
  touchscreen power resource. It sets the override's OEM revision to the firmware's
  revision + 1. The kernel ignores an override whose revision isn't higher.
- The prebuilt tables (from 1.13, OEM revision 3) also apply on 1.17, because the
  firmware still sets OEM revision 2 at boot (see above). Reports from 1.17 owners are
  welcome.

Downloads: Honor support page for your region (e.g. [MY](https://www.honor.com/my/support/laptop/honor-magicbook-pro-14/)).
Honor isn't on LVFS, so `fwupd` won't offer updates.

## Global vs. Chinese units

The two known variants have identical DSDT logic. Only six NVS base addresses differ
(GNVS at `0x67E09018` vs. `0x67E19018`). These addresses are **assigned at boot**, so
the difference may come from the memory configuration (RAM size) rather than the
region. That would explain why a Chinese unit needed the "global" table (#15). Please
report your variant together with the RAM size (`honor-fmbp-diag` shows both). If your
addresses match neither variant, the package doesn't select a table. In that case,
build one from your own firmware with `dsdt/build.sh`.

Fingerprint sensors differ between units, too: see [`fixes/libfprint/`](../fixes/libfprint/).

## Other models

- **MagicBook Pro 14 2026** (ZQC-P, Core Ultra 5 338H, touchpad `TXNW3643`) and
  **MagicBook 14 2026** (non-Pro): different firmware. The fixes here are DMI-gated
  to `FMB-P` and won't apply. See denis-bb#6 and #1 (lcrhf1999).
- A possible third FMB-P BIOS variant (`TPD0` unresolved): denis-bb#8.

Credit: **domakira**, **mikoff**, **mrueg** (BIOS releases), **kxygk**, **Nodzone**
(Chinese units).
