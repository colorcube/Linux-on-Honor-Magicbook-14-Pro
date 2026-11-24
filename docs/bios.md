<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# BIOS versions and variants

| BIOS | Date | Notes |
|---|---|---|
| 1.13 | 2025-05-08 | Shipping BIOS of many units. DSDT has the NFC0 load bug. Reference for `dsdt/prebuilt/`. |
| 1.14 | ? | Mentioned in denis-bb#4, not analysed. |
| 1.16 | 2026-03-25 | Same DSDT bug as 1.13 (tsukasagenesis). Microcode 0x116 → 0x11A, new 16 GB Micron LPDDR5X part, `OneKeyCheck` recovery variable widened to 32 bit and controllable via WMI, new EC commands (dual-battery test mode, sensor id), no more Intel ME update in the package. Package "20260509" is the same 1.16 (domakira). |
| 1.17 | 2026-10 | "BIOS 20261010 (1.17-2.07)". **Fixes the NFC0 load abort**: the `GNUM` call moved from table-load time into `NFC0._CRS`. That is the only ACPI change. Also a new 8 GB Micron LPDDR5X part and a rebuilt EC firmware. The touchscreen power resource is still missing. Not yet tested on hardware: reports welcome. |

BIOS 1.16/1.17 changes: binary analysis by **mrueg** (#22).

### What 1.17 means for the fixes

- Touchpad, NVMe, USB-C and battery info should work **without** a DSDT override.
- The touchscreen still needs the override (PowerResource).
- `dsdt/build.sh` recognises the fixed NFC0, skips that step and only injects the
  touchscreen power resource. It sets the override's OEM revision to the firmware's
  revision + 1. The kernel ignores an override whose revision isn't higher.
- The prebuilt tables (from 1.13, OEM revision 3) only work on 1.17 if Honor didn't
  raise the table's revision to 3 or more. We don't know that yet. If the touchscreen
  doesn't come back on 1.17, build the table from your own firmware with `dsdt/build.sh`.

Downloads: Honor support page for your region (e.g. [MY](https://www.honor.com/my/support/laptop/honor-magicbook-pro-14/)).
Honor isn't on LVFS, so `fwupd` won't offer updates.

## Global vs. Chinese units

The two BIOS SKUs have identical DSDT logic. Only six NVS base addresses differ (GNVS
at `0x67E09018` on global units, `0x67E19018` on Chinese ones). `dsdt/build.sh` and
`tools/honor-fmbp-diag` detect the SKU from the table. Earlier advice said "Chinese
units sometimes need the global DSDT" (#15). That came from denis-bb's tables and
should no longer apply with SKU detection. Please report your results.

Fingerprint sensors differ between units, too: see [`fixes/libfprint/`](../fixes/libfprint/).

## Other models

- **MagicBook Pro 14 2026** (ZQC-P, Core Ultra 5 338H, touchpad `TXNW3643`) and
  **MagicBook 14 2026** (non-Pro): different firmware. The fixes here are DMI-gated
  to `FMB-P` and won't apply. See denis-bb#6 and #1 (lcrhf1999).
- A possible third FMB-P BIOS variant (`TPD0` unresolved): denis-bb#8.

Credit: **domakira**, **mikoff**, **mrueg** (BIOS releases), **kxygk**, **Nodzone**
(Chinese units).
