# DSDT override (the foundation for most other fixes)

The FMB-P BIOS DSDT (identical in 1.13 and 1.16) aborts at ACPI load because
of module-level code in `Device (NFC0)`. That single failure takes down
battery reporting, the touchpad, thermal sensors and a USB-C SSDT. The fix is
[denis-bb/honor-fmb-p-dsdt](https://github.com/denis-bb/honor-fmb-p-dsdt):
remove `NFC0`, bump the OEM table revision, and feed the patched DSDT to the
kernel as an ACPI-override initrd.

`../../install.sh` automates this with safeguards: it dumps **your** firmware's
DSDT, applies the denis-bb patch (aborting if it doesn't apply cleanly — e.g.
a future BIOS), verifies it recompiles with zero iasl errors, builds the
uncompressed override cpio, and wires it into your initramfs system:

- **mkinitcpio** (Arch/CachyOS): installs [`10-acpi-override`](10-acpi-override)
  as a post hook. It deliberately skips `-lts` images, so an installed LTS
  kernel stays on stock ACPI as a rescue entry.
- **dracut** (Fedora & co.): drops the table in `/etc/acpi-override/` and
  enables `acpi_override` via `/etc/dracut.conf.d/`; a pre-override backup of
  the current initramfs is kept as `*.stock-acpi.img`.
- **initramfs-tools + GRUB** (Debian/Ubuntu): installs the cpio to `/boot` and
  loads it via `GRUB_EARLY_INITRD_LINUX_CUSTOM`.

**Secure Boot must be disabled** — kernel lockdown ignores ACPI table
overrides from the initrd (and the DKMS modules are unsigned anyway).

If you'd rather do it by hand, follow the denis-bb README; the hook file here
is still useful for the mkinitcpio case.
