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

## 2. Install the fixes

```bash
git clone https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro.git
cd Linux-on-Honor-Magicbook-14-Pro
sudo ./install.sh
sudo reboot
./install.sh --status
```

What `install.sh` does on Fedora:

- **dsdt:**
  - If the firmware table is unmodified, it builds the corrected DSDT from it.
  - If an override is already active, it uses `dsdt/prebuilt/dsdt.<sku>.aml`.
  - It installs the table to `/usr/lib/honor-fmbp/acpi/` and adds
    `/etc/dracut.conf.d/10-honor-fmbp-dsdt.conf`, then rebuilds all initramfs images.
  - It disables an old GRUB `acpi /dsdt.aml` line and old touchscreen/acpi_call
    services, with backups in `/var/lib/honor-fmbp/backup/`.
- **udev, wmi, hwmon, kbdlight, battery:** see [fixes/](../../fixes/).

After the reboot, `journalctl -k -b | grep "Table Upgrade"` should show
`override [DSDT-HONOR-ARL]`. The touchscreen, the keyboard backlight (KDE: battery &
brightness applet) and `sensors` should then work.

**Rescue:** if the system doesn't boot, choose Fedora's `0-rescue` entry. Its
initramfs predates the override. Then run `sudo ./install.sh --uninstall --only dsdt`.

## 3. Fingerprint (FPC `10a5:9924`)

Until the COPR is available, build the patched libfprint yourself:

```bash
sudo dnf install rpm-build rpmdevtools 'dnf-command(builddep)'
sudo dnf builddep packaging/fedora/libfprint/libfprint.spec
mkdir -p ~/rpmbuild/SOURCES && cp packaging/fedora/libfprint/*.patch ~/rpmbuild/SOURCES/
spectool -g -R packaging/fedora/libfprint/libfprint.spec
rpmbuild -bb packaging/fedora/libfprint/libfprint.spec
sudo dnf install ~/rpmbuild/RPMS/x86_64/libfprint-1.94.100-1.1.honor.fc44.x86_64.rpm
sudo systemctl restart fprintd
```

Then enroll in *System Settings → Users → Fingerprint* (KDE) or with `fprintd-enroll`.
To go back to Fedora's package, run `sudo dnf distro-sync libfprint`.

## 4. Charge limit

Edit `BATTERY_THRESHOLD` in `/etc/default/honor-fmbp-battery`. Only `40 70`, `70 90`
and `95 100` work. Then run `sudo systemctl restart honor-fmbp-battery`. In KDE's
energy settings, pick the same values.

## Uninstall

```bash
sudo ./install.sh --uninstall && sudo reboot
```
