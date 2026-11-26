<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Arch Linux

## 1. Install

Run the following as a regular user:

```bash
sudo pacman -S --needed base-devel git linux-headers
git clone --depth 1 https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro.git
cd Linux-on-Honor-Magicbook-14-Pro
./packaging/arch/install.sh
```

> Match the headers package to your kernel (`linux-headers` for `linux`,
> `linux-lts-headers` for `linux-lts`, or the matching `*-headers` package for any
> other kernel) so DKMS can compile the drivers.

The interactive installer builds local packages with `makepkg` and installs your
selections in a single `pacman -U` transaction. Each option defaults to yes and can be
declined independently:

| Package | Content |
|---|---|
| `honor-magicbook-pro-14` | Prebuilt DSDT + mkinitcpio hook, udev/hwdb quirks, 3 DKMS drivers (`hwmon`, `kbdlight`, `huawei-wmi`), `honor-fmbp-diag`, charge-limit service |
| `honor-fmbp-edid` (optional) | Patched HDR EDID firmware for the internal OLED panel (auto-configures standard GRUB) |
| Fingerprint driver (optional) | Auto-detected by USB ID (`honor-fmbp-libfprint` for `10a5:9924`, or external recipes for `1c7a:05aa` / `10a5:a920`) + `fprintd` |

## 2. Verify

Before rebooting, confirm that DKMS built all three modules:

```bash
dkms status
```

> Keep a fallback/rescue boot entry that skips `acpi_override` (`-S acpi_override` in
> that mkinitcpio preset) or a separate working boot image before rebooting.

Reboot, then verify that the DSDT override and hardware fixes are active:

```bash
journalctl -k -b | grep "Table Upgrade"
honor-fmbp-diag
```

## 3. Optional features

### Charge limit

Enable the service, then set `BATTERY_THRESHOLD` in `/etc/default/honor-fmbp-battery`
(supported presets: `40 70`, `70 90`, `95 100`) and restart it:

```bash
sudo systemctl enable --now honor-fmbp-battery.service
```

See [fixes/battery/README.md](../../fixes/battery/README.md) for details.

### HDR

#### GRUB

On a standard GRUB setup (`/boot/grub/grub.cfg`), installing `honor-fmbp-edid`
configures the EDID override automatically and regenerates GRUB. Reboot, then enable
HDR in your compositor.

#### systemd-boot and others

For **systemd-boot**, Limine, rEFInd, UKIs, or a non-standard GRUB path, check your
internal connector under `/sys/class/drm/` (usually `eDP-1`) and add the kernel
parameter to your boot entry:

```text
drm.edid_firmware=eDP-1:edid/honor-fmbp/edp-hdr.bin
```

- **systemd-boot:** append it to the `options` line in `/boot/loader/entries/*.conf`.
- **UKI:** add it to your embedded kernel command line and rebuild the UKI.
- **dracut:** add `install_items+=" /usr/lib/firmware/edid/honor-fmbp/edp-hdr.bin "` in
  `/etc/dracut.conf.d/` and run `sudo dracut --force --regenerate-all`.

After rebooting, verify with `edid-decode /sys/class/drm/card*-eDP-1/edid`.

### Fingerprint

As described in [fixes/libfprint/README.md](../../fixes/libfprint/README.md), the FMB-P
ships with different fingerprint sensors depending on the unit. During installation,
`./packaging/arch/install.sh` detects your sensor's USB ID automatically and builds the
matching package along with `fprintd`:

| USB ID | Package | Recipe |
|---|---|---|
| `10a5:9924` | `honor-fmbp-libfprint` | Built-in (`packaging/arch/honor-fmbp-libfprint`, libfprint MR !666) |
| `1c7a:05aa` | `honor-fmbp-libfprint-sdcp` | External ([drphilth/honor-fmbp-libfprint-sdcp](https://github.com/drphilth/honor-fmbp-libfprint-sdcp)) |
| `10a5:a920` | `libfprint-fpc1022` | External ([feraxtx/libfprint-10a5-a920](https://github.com/feraxtx/libfprint-10a5-a920)) |

If no supported sensor is detected, fingerprint setup is skipped. Building `10a5:9924`
may require importing the upstream PGP signing key (verify the fingerprint against the
PKGBUILD first).

After installation, enroll and verify your fingerprint:

```bash
fprintd-enroll
fprintd-verify
```

## 4. Uninstall

### Remove packages

Remove the main package (and `honor-fmbp-edid` if installed):

```bash
sudo pacman -Rns honor-magicbook-pro-14
sudo pacman -Rns honor-fmbp-edid
```

Pacman automatically disables `honor-fmbp-battery.service`, removes package-owned
boot configs, regenerates standard GRUB, and rebuilds the initramfs.

If you installed a fingerprint driver:

- **`1c7a:05aa` (`honor-fmbp-libfprint-sdcp`):** remove it directly (stock `libfprint`
  remains installed):
  ```bash
  sudo pacman -Rns honor-fmbp-libfprint-sdcp
  ```
- **`10a5:9924` (`honor-fmbp-libfprint`) or `10a5:a920` (`libfprint-fpc1022`):**
  restore Arch's stock `libfprint` (accept the conflict prompt), then restart `fprintd`:
  ```bash
  sudo pacman -S extra/libfprint
  sudo systemctl restart fprintd
  ```

### Reset battery charge limit (if enabled)

The hardware controller remembers the last charge limit even after uninstall and reboot.
Before rebooting, reset it to unrestricted charging:

```bash
echo '0 100' | sudo tee /sys/devices/platform/huawei-wmi/charge_control_thresholds
```

Reboot once finished (`sudo reboot`).

## 5. Advanced

### DSDT overrides and local builds

On a standard mkinitcpio setup, `honor-magicbook-pro-14` detects your FMB-P variant
(global or Chinese) from the firmware table, stages the matching prebuilt AML at
`/usr/lib/initcpio/acpi_override/dsdt-prebuilt.aml`, and enables mkinitcpio's native
`acpi_override` hook via `/etc/mkinitcpio.conf.d/50-honor-fmbp.conf` (including for
UKIs).

- **Custom mkinitcpio presets** using `-c`, `ALL_config`, or `<preset>_config` may skip
  the drop-in: add `acpi_override` to `HOOKS` in that preset's config and rebuild.
- **dracut:** configure the override per the
  [Arch Wiki](https://wiki.archlinux.org/title/DSDT#Using_the_AML_with_dracut) and
  rebuild manually.

To build a DSDT from your own firmware instead of using the prebuilt table, boot once
**without** any DSDT override so `/sys/firmware/acpi/tables/DSDT` contains the stock
table. Install `acpica`, `python`, and `perl`, then run (`--no-chinese` builds only the
variant detected on this machine):

```bash
work=$(mktemp -d)
sudo /usr/share/honor-fmbp/dsdt/build.sh --no-chinese --out "$work" &&
    sudo install -Dm644 "$work"/dsdt.*.aml /etc/initcpio/acpi_override/honor-fmbp.aml &&
    sudo honor-fmbp-dsdt-select --mkinitcpio --remove
sudo mkinitcpio -P
```

While `/etc/initcpio/acpi_override/honor-fmbp.aml` exists, package upgrades preserve it
and keep the prebuilt copy removed. Rebuild it after a BIOS update. To keep using it
after removing `honor-magicbook-pro-14`, add `acpi_override` to `HOOKS` in
`/etc/mkinitcpio.conf`.

To return to prebuilt mode, move the local file aside and rebuild (remove
`acpi_override` from `/etc/mkinitcpio.conf` if you added it manually):

```bash
sudo mv /etc/initcpio/acpi_override/honor-fmbp.aml /etc/initcpio/acpi_override/honor-fmbp.aml.local-backup &&
    sudo honor-fmbp-dsdt-select --mkinitcpio
sudo mkinitcpio -P
```

### Manual packaging

- **Build individual PKGBUILDs manually:** see
  [packaging/arch/README.md](../../packaging/arch/README.md).
- **Without packages (best-effort):** run `sudo ./install.sh` from the repository root
  (do not combine it with the packages above).
