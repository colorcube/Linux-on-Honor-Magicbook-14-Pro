<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Battery charge thresholds

Issues [#10](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/10) and
[#17](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/17).

## How it works

The in-tree `huawei-wmi` driver writes the thresholds through the WMI method `\SBTT`
(EC registers `0x80`/`0x81`). **The EC only enforces a (start, stop) pair if it matches
one of the Honor PC Manager presets.** On a preset pair the EC arms itself: its charge
mode, EC `0x85`, becomes the preset index. Any other pair, such as `60 80`, is stored
but ignored, and the laptop charges to 100 %.

| start | stop | PC Manager name | EC charge mode |
|---|---|---|---|
| 40 | 70 | "70%" (longest battery life) | 1 |
| 70 | 90 | "90%" (balanced) | 2 |
| 95 | 100 | "100%" | 3 |
| 0 | 100 | no limit | 0 |

Verified on **BIOS 1.13** (colorcube, see [docs/testing.md](../../docs/testing.md)) and
**BIOS 1.16** (tsukasagenesis, yhshzh). On 1.13, `60 80` and `50 80` leave the mode at 0,
while `70 90` → 2 and `40 70` → 1.

```sh
echo "70 90" | sudo tee /sys/devices/platform/huawei-wmi/charge_control_thresholds
```

No driver patch is needed. KDE's "limit charging" setting and GNOME extensions write to
the same place, so choose one of the preset values there too.

### Check that the EC armed the limit

This works without `ec_sys`, which Fedora doesn't ship. The query below is a read-only
WMI call (`\GBCM`). In the second block, byte 1 is the charge mode: anything other
than 0 means armed.

```sh
sudo mount -t debugfs none /sys/kernel/debug 2>/dev/null
echo 0x1603 | sudo tee /sys/kernel/debug/huawei-wmi/arg >/dev/null
sudo cat /sys/kernel/debug/huawei-wmi/call
# [{0x00,...},{0x00,0x02,0x00,0x46,0x5a,...}]  -> mode 2, start 0x46=70, stop 0x5a=90
```

## Persist across reboots

The EC keeps the pair across reboots. Re-applying it at boot is cheap insurance:

```sh
sudo install -Dm644 honor-fmbp-battery.default /etc/default/honor-fmbp-battery   # edit BATTERY_THRESHOLD
sudo install -Dm644 honor-fmbp-battery.service /etc/systemd/system/honor-fmbp-battery.service
sudo systemctl enable --now honor-fmbp-battery.service
sudo install -Dm644 99-honor-fmbp-battery.rules /etc/udev/rules.d/99-honor-fmbp-battery.rules
```

The udev rule starts the service again when huawei-wmi binds, in case the driver
probes after the service ran at boot (fix by mrueg).

GNOME's "Battery Health Charging" extension can be set to the presets with
[`gnome-battery-health-charging.dconf`](gnome-battery-health-charging.dconf).

## Notes from the deep-dive (for the curious)

- `\SBCM` (WMI `0x1503`) sets mode + thresholds in one call. Payload bytes
  2–5 are `mode, 0x48, start, stop` — byte 3 **must be the magic `0x48`**
  (decoded in [Huawei-WMI#55](https://github.com/aymanbagabas/Huawei-WMI/issues/55));
  modes: 1=home, 2=office, 3=travel, 4=smart-charge. With the key it can arm
  *custom* pairs into an active drain-to-ceiling mode, but the EC cancels
  that state under heavy load, so it would need periodic re-arming — the
  preset-pair route is strictly better.
- `\SBAD`/`\GBAD` (WMI `0x1203`/`0x1303`) is **battery calibration
  discharge** (forces the machine to run from battery on AC until turned
  off), *not* a protection switch. Don't leave it on.
- EC bytes `0x85`/`0x86`/`0x87` are EC-owned status (charge mode / SBCM key
  echo / arm state); host writes to them get reverted within seconds.
- The EC RAM is memory-mapped at `0xFE0B0000` (banks `ECF0`–`ECF9` in the
  DSDT), readable via `/dev/mem` — handy for diffing EC state.


## Credits

- **n7n8**: found the PC Manager preset byte pairs in EC `0x80`/`0x81` (#17).
- **tsukasagenesis**: worked out that only preset pairs arm the EC (#10, PR #21).
- **yhshzh**: confirmed the mode values on a Chinese unit with BIOS 1.16.
- **sermart1234**: decoded `\SBCM` ([Huawei-WMI#55](https://github.com/aymanbagabas/Huawei-WMI/issues/55)).
- **mpi3d**, **larax2do**: smart-charging regression notes (same thread).
- **nikube**: WMI/PC Manager interface details (#10).
- **kv9898**: pointed to `matebook-applet` as a GUI.
- **fan-nature**: the Windows-side limitation with PC Manager (#25).
- **drphilth**: the service, defaults file and GNOME dconf defaults.
- **colorcube**: verified the preset behaviour on BIOS 1.13.
