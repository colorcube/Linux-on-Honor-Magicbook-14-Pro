<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Fedora

Verified on Fedora 44 (KDE), kernel 7.3, BIOS 1.13 global.

## 1. Before you start

- **Disable Secure Boot** in the firmware (F2; Honor may ask you to set a supervisor
  password first).
- Kernel ≥ 6.19 boots the stock firmware (keyboard works, no ACPICA crash). The touchpad
  stays dead until the DSDT fix is installed, so keep a USB mouse handy for a fresh
  install.
- Remove old workarounds from the kernel command line if present: `i8042.dumbkbd=1`,
  `snd-intel-dspcfg.dsp_driver=3`, `snd-hda-intel.model=generic`.

## 2. Install (COPR packages, recommended)

```bash
sudo dnf copr enable colorcube/honor-fmbp
sudo dnf install honor-magicbook-pro-14
sudo reboot
honor-fmbp-diag
```

**The first installation takes a few minutes. Don't abort it.** DKMS builds three
kernel modules, and Fedora's DKMS then rebuilds the initramfs of *every* installed kernel
after each module (about 20-30 s per kernel). The DSDT package rebuilds them once more.
In a terminal, the packages announce these steps as they happen. Updates skip all of
this unless a driver's sources or the DSDT actually changed.

The metapackage `honor-magicbook-pro-14` pulls in:

| Package | Content |
|---|---|
| `honor-fmbp-dsdt` | corrected DSDT (global/Chinese chosen automatically), dracut override |
| `honor-fmbp-udev` | hwdb/udev quirks (touchpad ghost keys, scancodes, touchscreen ghost) |
| `honor-fmbp-battery` | charge-limit service (`/etc/default/honor-fmbp-battery`, default `70 90`) |
| `honor-fmbp-tools` | `honor-fmbp-diag`, `honor-fmbp-touchscreen-toggle`, `honor-fmbp-battery-probe` |
| `honor-fmbp-hwmon-dkms`, `honor-fmbp-kbdlight-dkms`, `huawei-wmi-fmbp-dkms` | drivers (DKMS, rebuilt on kernel updates) |
| `libfprint` (recommended) | Fedora's libfprint plus MR !666 for the FPC `10a5:9924` sensor |

After the reboot, `journalctl -k -b | grep "Table Upgrade"` should show
`override [DSDT-HONOR-ARL]`.

The COPR has repo priority 90, so its `libfprint` wins over Fedora's. If Fedora updates
libfprint, the COPR build is rebuilt. Until then you stay on the patched version. If
you'd rather keep Fedora's libfprint (for example because you have a different sensor),
exclude it from the COPR:

```bash
sudo dnf config-manager setopt copr:copr.fedorainfracloud.org:colorcube:honor-fmbp.excludepkgs=libfprint
sudo dnf distro-sync libfprint
```

**Rescue:** if the system doesn't boot, choose Fedora's `0-rescue` entry and run
`sudo dnf remove honor-fmbp-dsdt`.

**Uninstall:** `sudo dnf remove 'honor-fmbp-*' huawei-wmi-fmbp-dkms honor-magicbook-pro-14 && sudo dnf distro-sync libfprint`.

## 3. Alternative: `install.sh` (without packages)

Use this if you don't want the COPR. Don't combine it with the packages.

```bash
git clone https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro.git
cd Linux-on-Honor-Magicbook-14-Pro
sudo ./install.sh
sudo reboot
./install.sh --status
```

- If the firmware table is unmodified, `install.sh` builds the DSDT from it.
- It disables old GRUB `acpi` lines and acpi_call services, with backups in
  `/var/lib/honor-fmbp/backup/`.
- It does not cover the fingerprint reader. For that, build
  `packaging/fedora/libfprint/libfprint.spec` with `rpmbuild` (see
  [fixes/libfprint/](../../fixes/libfprint/)).

## 4. Charge limit

Edit `BATTERY_THRESHOLD` in `/etc/default/honor-fmbp-battery`. Only `40 70`, `70 90`
and `95 100` work. Then run `sudo systemctl restart honor-fmbp-battery`. In KDE's
energy settings, pick the same values.
