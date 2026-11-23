<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# BIOS versions and variants

| BIOS | Date | Notes |
|---|---|---|
| 1.13 | 2025-05-08 | Shipping BIOS of many units. DSDT has the NFC0 load bug. Reference for `dsdt/prebuilt/`. |
| 1.14 | ? | Mentioned in denis-bb#4, not analysed. |
| 1.16 | 2026-03-25 | Same DSDT bug, decompiled table identical apart from OEM rev (tsukasagenesis). Package "20260509" is the same 1.16 for FMB-PM (domakira). |
| 1.17 | 2026-10 | "BIOS 20261010 (1.17-2.07)" (mrueg). No changelog, not analysed yet: reports welcome. |

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
