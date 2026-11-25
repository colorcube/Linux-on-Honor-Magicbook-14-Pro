<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Linux on HONOR MagicBook Pro 14 (2025, FMB-P)

Fixes, drivers and documentation for running Linux on the **HONOR MagicBook Pro 14
2025** (`FMB-P`, Intel Core Ultra "Arrow Lake-H"). This collection brings together the
work of many people from the [issues](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues),
forks and companion projects. See [CONTRIBUTORS.md](CONTRIBUTORS.md).

With the fixes here, **everything except a few cosmetic details works**: touchpad,
touchscreen, keyboard backlight, Fn keys, fan readout, fingerprint reader and charge
limit.

## Status

Tested on BIOS 1.13 (global), Fedora 44, kernel 7.3. Details:
[docs/testing.md](docs/testing.md).

| Component | Stock kernel ≥ 7.0 | With this repo | Details |
|---|---|---|---|
| Boot, NVMe, keyboard | ✅ (keyboard since 6.19) | ✅ | [keyboard](docs/hardware/keyboard.md) |
| Touchpad, USB-C, battery info, thermals | ❌ firmware DSDT aborts loading | ✅ DSDT override | [dsdt/](dsdt/) |
| Touchscreen (FocalTech FTSC1000) | ❌ never powered | ✅ DSDT override + udev | [dsdt/](dsdt/), [fixes/udev/](fixes/udev/) |
| Screen jumps dark/bright (touchpad ghost keys) | ❌ | ✅ hwdb | [fixes/udev/](fixes/udev/) |
| Fn keys (touchpad, camera, Fn+P, Fn+R, backlight) | partly | ✅ DKMS | [fixes/huawei-wmi-dkms/](fixes/huawei-wmi-dkms/) |
| Keyboard backlight | ❌ | ✅ DKMS | [fixes/honor-fmbp-kbdlight/](fixes/honor-fmbp-kbdlight/) |
| Fan RPM in `sensors` | ❌ (the EC controls the fans) | ✅ DKMS | [fixes/honor-fmbp-hwmon/](fixes/honor-fmbp-hwmon/) |
| Fingerprint FPC `10a5:9924` | ❌ | ✅ patched libfprint | [fixes/libfprint/](fixes/libfprint/) |
| Fingerprint EgisTec `1c7a:05aa` | ❌ | external fork | [fixes/libfprint/](fixes/libfprint/) |
| Charge limit | stored but ignored | ✅ preset pairs 40/70, 70/90, 95/100 | [fixes/battery/](fixes/battery/) |
| Caps-Lock and mic-mute LEDs | ✅ | ✅ | [keyboard](docs/hardware/keyboard.md) |
| Wi-Fi, Bluetooth, audio, webcam, lid, suspend (s2idle) | ✅ | ✅ | [docs/hardware/](docs/hardware/) |
| Power button | ✅ hold ~0.5 s | ✅ | [power button](docs/hardware/power-button.md) |
| HDR in GNOME/KDE | ❌ | EDID override (optional) | [display](docs/hardware/display.md) |
| Performance mode (Fn+P, 50 W clamp) | ❌ capped at 50 W | ✅ optional package `honor-fmbp-perf` (80–115 W) | [performance](docs/hardware/performance.md) |
| S3 deep sleep | ❌ hardware is S0ix-only | hibernate works | [sleep](docs/hardware/sleep.md) |
| Wi-Fi fails after warm reboot | open (#26) | — | [wifi](docs/hardware/wifi.md) |
| IR camera / face unlock | — no IR camera in the 2025 model | — | |

## Quickstart (Fedora)

Disable **Secure Boot** in the firmware (F2) first. Then:

```bash
sudo dnf copr enable colorcube/honor-fmbp
sudo dnf install honor-magicbook-pro-14
sudo reboot
honor-fmbp-diag
```

The first installation takes a few minutes: three kernel modules are built with DKMS
and Fedora rebuilds the initramfs for every installed kernel. Don't abort it. Later
updates are fast unless a driver or the DSDT changed.

The packages come from the [COPR](https://copr.fedorainfracloud.org/coprs/colorcube/honor-fmbp/)
(Fedora 44) and include the patched libfprint for the fingerprint reader. Details,
alternatives (`install.sh`) and uninstall instructions are in
[docs/install/fedora.md](docs/install/fedora.md).

**Other distributions:**
- **Ubuntu:** use drphilth's PPA ([honor-magicbook-pro-14-ubuntu](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu)).
- **Fedora-based with Secure Boot:** [Evernight Vista](https://copr.fedorainfracloud.org/coprs/evernightvista/evernight-vista)
  ships a kernel with the DSDT built in.
- **Others:** `install.sh` also supports pacman/mkinitcpio and apt/initramfs-tools on a
  best-effort basis.

We're happy to build packages for other distributions if someone can test them, so
please open an issue.

**Installing from scratch / live USB:** [docs/install/live-usb.md](docs/install/live-usb.md).

## Reporting problems

Please attach the output of `sudo tools/honor-fmbp-diag` and state the BIOS version and
whether your unit is global or Chinese. Check [docs/testing.md](docs/testing.md) first,
and add your own results there.

## Machine

HONOR `FMB-P` (versions M1020/M1030, SKU C100). Specs:
[honor.com](https://www.honor.com/global/laptops/honor-magicbook-pro-14/spec/).
BIOS history: [docs/bios.md](docs/bios.md). Hardware probe:
[linux-hardware.org](https://linux-hardware.org/?probe=1657e7ed5c).

## License

Code is GPL-2.0 (`-or-later`, or `-only` where the source requires it); the libfprint
patch is LGPL-2.1-or-later; documentation is CC-BY-4.0. Prebuilt DSDT tables are
minimally patched derivatives of HONOR's firmware for owners of this hardware. Per-file
details are in [REUSE.toml](REUSE.toml) and the SPDX headers.

## Resources

- [Fedora discussion that got things going](https://discussion.fedoraproject.org/t/fedora42-workstation-work-badly-in-honor-magicbook-14-pro/154790)
- [denis-bb/honor-fmb-p-dsdt](https://github.com/denis-bb/honor-fmb-p-dsdt), the first DSDT fix
- [drphilth/honor-magicbook-pro-14-ubuntu](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu), Ubuntu packages
