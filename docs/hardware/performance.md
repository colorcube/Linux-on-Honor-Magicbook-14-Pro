<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Performance mode, power limits, fans (#27, #7)

## Fans

The EC controls both fans by itself, and no fan curve is exposed. To show the RPM, use
[`fixes/honor-fmbp-hwmon/`](../../fixes/honor-fmbp-hwmon/) (EC `0x2C`/`0x2E`). At idle
the fans really stop, so `sensors` then shows 0 RPM.

## High Performance Mode (高能模式)

yhshzh analysed this on BIOS 1.16 with a Core Ultra 5 225H (#27). On Windows the mode
needs three layers working together:

1. **EC mode** via the standard HWMI interface (the one `huawei-wmi` uses):
   - `\GTUB` (`0x0E04`) queries the mode.
   - `\STUB` sets it: `0x000F04` for smart, `0x010F04` for performance.

   Fn+P does the same in the EC and reports it through WMI events `0x2a0` (smart),
   `0x2a1` (performance) and `0x2a6` (rejected: on battery or below 20 %).
2. **Intel DPTF DataVault**: `thermald --adaptive` follows the OEM variables and sets
   PL1/TCC/ITMT. thermald 2.5.13 ignores the separate *PL2 AP Policy*, so PL2 stays at
   50 W.
3. **DTT keep-alive**: unless something writes to `/sys/bus/platform/devices/INTC1042:00/imok`,
   the EC clamps package power to **50 W**. thermald doesn't do this yet.

The balanced profile of `power-profiles-daemon` uses EPP 128, which held the 225H to
about 25 W. Honor uses EPP 64 for AC balanced.

**Interim workaround:** yhshzh's [honor-fmbp-perf](https://github.com/yhshzh/honor-fmbp-perf)
is a small daemon and CLI (Python, systemd, GPL-2.0-or-later, gated to the FMB-P). It
works together with `thermald --adaptive` and does the following:
- mode switching via `\GTUB`/`\STUB` (huawei-wmi debugfs)
- PL2 from the DataVault, matched to the CPU SKU
- `imok` keep-alive, only while thermald runs, so the EC failsafe still works
- EPP 64 on AC balanced
- notifications on Fn+P

It was tested on a Chinese unit (BIOS 1.16, Core Ultra 5 225H). It also works with
`fixes/huawei-wmi-dkms` installed. Only the instant "mode rejected" (`0x2a6`) notice
needs the stock driver.

**Status:** The plan is to bring
`platform_profile` (smart/performance through `\STUB`) into `huawei-wmi` and the
`imok`/PL2 handling into thermald. Help is welcome.

Credit: **yhshzh** (full analysis, measurements), **tsukasagenesis**
(power-profiles-daemon notes).
