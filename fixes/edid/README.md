<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# HDR EDID override for the FMB-P internal panel

The patched EDID from [issue #16](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/16)
adds a CTA-861 extension alongside the original DisplayID 2.0 block, advertising PQ,
static HDR metadata type 1, BT.2020, and additional detailed timings.

## Enable

Install `honor-fmbp-edid` or copy `edp-hdr.bin` to
`/usr/lib/firmware/edid/honor-fmbp/edp-hdr.bin`. Confirm that your internal panel
matches the hardware described in issue #16 before enabling it.

### GRUB

Installing `honor-fmbp-edid` on a standard GRUB setup (`/boot/grub/grub.cfg`)
configures the override for `eDP-1` automatically, regenerates GRUB, and rebuilds the
initramfs. Reboot once it finishes.

If configuring GRUB manually, add `drm.edid_firmware=eDP-1:edid/honor-fmbp/edp-hdr.bin`
to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, regenerate GRUB, and include
the firmware file in your initramfs.

### systemd-boot and others

1. Check your internal panel connector under `/sys/class/drm/` (for example
   `card*-eDP-1`) and add the kernel parameter to your boot entry (preserving any
   existing connector mappings):

   ```text
   drm.edid_firmware=eDP-1:edid/honor-fmbp/edp-hdr.bin
   ```

   - **systemd-boot:** append it to the `options` line in `/boot/loader/entries/*.conf`.
   - **UKI:** add it to your embedded command line before rebuilding.
   - **BLS (`grubby`):** update the entry with `grubby`.

2. **dracut:** include the firmware in the initramfs and rebuild:

   ```bash
   echo 'install_items+=" /usr/lib/firmware/edid/honor-fmbp/edp-hdr.bin "' | sudo tee /etc/dracut.conf.d/honor-fmbp-edid.conf
   sudo dracut --force --regenerate-all
   ```

## Verify

After rebooting, confirm the patched EDID is active:

```bash
edid-decode /sys/class/drm/card*-eDP-1/edid
```

## Rollback

- **GRUB (packaged):** uninstall `honor-fmbp-edid` and reboot after GRUB and the
  initramfs finish rebuilding.
- **Manual / systemd-boot and others:** remove `drm.edid_firmware=...` from your boot
  entry (and `/etc/dracut.conf.d/honor-fmbp-edid.conf` if created), rebuild your boot
  images if needed, then remove the package or firmware file and reboot.
