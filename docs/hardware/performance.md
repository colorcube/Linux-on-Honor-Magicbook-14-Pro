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

**Fedora package:** `sudo dnf install honor-fmbp-perf` from the
[COPR](https://copr.fedorainfracloud.org/coprs/colorcube/honor-fmbp/). It is optional
and not part of `honor-magicbook-pro-14`. The service starts after installation, or
right away with `sudo systemctl start honor-perf`. Use `honor-perf status|high|balanced`
or Fn+P. On Fedora, `powerprofilesctl` doesn't exist (tuned-ppd), so the profile sync
is skipped; that's harmless.

Measured on a global FMB-P (Core Ultra 9 285H, BIOS 1.13, Fedora 45), full load on AC:

| Setup | Package power | PL1 / PL2 |
|---|---|---|
| without the daemon | 50.1 W (EC clamp) | 65 / 50 W |
| daemon, Smart Mode | 80.0 W | 65 / 80 W |
| daemon, High Performance | 92.7 W | 75 / 115 W |

**Upstream:**
- **Kernel:** Fuwei Xie's RFC v2 series adds `platform_profile` (`\GTUB`/`\STUB`, events
  `0x2a0`/`0x2a1`/`0x2a6`) to huawei-wmi
  ([cover letter](https://lore.kernel.org/r/69C3BBDEF214121E+20261118161311.17252-1-12313607@mail.sustech.edu.cn)).
  It is under review by Ilpo Järvinen, and yhshzh tested it on an FMB-P.
- **thermald:** `imok` and the PL2 AP Policy remain open. Help is welcome.

Credit: **yhshzh** (full analysis, measurements, honor-fmbp-perf), **Fuwei Xie** (kernel series), **tsukasagenesis**
(power-profiles-daemon notes).
