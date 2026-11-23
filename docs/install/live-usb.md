<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Installing from a live USB

Since kernel **6.19** the stock firmware no longer crashes the kernel, and the internal
keyboard works. Current installers (Fedora ≥ 44, Ubuntu ≥ 26.04) therefore usually boot
without tricks. Without the DSDT override, though, the **touchpad doesn't work** (bring
a USB mouse), and on some kernels the NVMe isn't visible.

If the installer doesn't see the NVMe or you need the touchpad, load the corrected
table during installation:

- **Simplest (denis-bb):** don't "flash" the ISO. Unpack it with an archiver onto a
  FAT-formatted USB stick and copy `dsdt/prebuilt/dsdt.global.aml` next to it. In the
  GRUB menu press `c`, then:
  ```
  acpi /dsdt.aml
  ```
  Press Esc and boot the installer entry.
- **Ventoy (kxygk):** put the ISO and `dsdt.aml` on a Ventoy stick. In the GRUB editor
  (`e`), add `acpi (hd0,msdos1)/dsdt.aml` as the first line. Find the device with `ls`
  or Tab completion.
- **Remastered ISO:** drphilth's
  [`iso/build-install-iso.sh`](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu/tree/main/iso)
  (Ubuntu) bakes the table into the installer. kxygk described the manual `xorriso`
  route in #13.

After the installation, boot the new system the same way once (GRUB `acpi` line), then
run `install.sh`. From then on the table is loaded from the initramfs.

Chinese units: use `dsdt.chinese.aml`. If it doesn't work, try the global one and
report the result (#15).

Credit: **kxygk**, **ishtarov**, **denis-bb**, **drphilth**, **EvernightFedora**
(Evernight Vista ISOs with the DSDT built in).
