<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Display: brightness, HDR, colour calibration

## Screen jumps between dark and full brightness (#3)

The Goodix touchpad (`GXT7863`, `27C6:01E0`) exposes two vendor HID collections (usage
pages FF00/FF01) that Windows leaves unbound. Linux turns them into a third input
device, `GXT7863:00 27C6:01E0 UNKNOWN`. That device sends a `KEY_BRIGHTNESSUP`/`DOWN`
press but never the release, so kernel autorepeat fires it at about 30 Hz.

**Fix:** [`fixes/udev/61-honor-fmbp-touchpad.hwdb`](../../fixes/udev/61-honor-fmbp-touchpad.hwdb)
maps the two vendor usages `0xff010003`/`0xff010004` to `reserved` inside the kernel.
This works for every desktop, and mic-mute (`0xff010001`) keeps working.

Older workarounds, kept for reference:
- Inhibit the whole device with a udev rule
  ([`fixes/legacy/99-ignore-touchpad-device.rules`](../../fixes/legacy/99-ignore-touchpad-device.rules)).
- On GNOME only, unbind the brightness keys with gsettings (see #3).

Credit:
- **jean bzh** (Fedora forum): found the device and wrote the inhibit rule.
- **sujoshua**: the BetterLife/Goodix hypothesis.
- **Osama-A-Abbas**: the GNOME layer analysis.
- **nikube**: root cause and the hwdb fix.

**Brightness keys:** the firmware sends press and release in the same microsecond on
the ACPI video bus, and some compositors (mutter) ignore that. nikube uses a small
listener service as a workaround. On KDE the keys work.

## HDR (#16)

The OLED panel advertises HDR only in its DisplayID block, which GNOME 49 and KDE don't
read. denis-bb built a patched EDID (`edp-hdr.bin`, attached to #16). Load it like this:

1. Copy `edp-hdr.bin` to `/lib/firmware/edid/` and include it in the initramfs. On
   Fedora, add `install_items+=" /lib/firmware/edid/edp-hdr.bin "` to a dracut conf.
2. Add `drm.edid_firmware=eDP-1:edid/edp-hdr.bin` to the kernel command line.

Use it with care: the EDID detailed timing can't describe the native modes exactly.
Credit: **denis-bb**.

## Factory colour calibration (#19)

Windows ships per-panel `*_display_factory_calibration_N.xml` files containing 17³ 3D
LUTs, plus ICC profiles. Converting them to `.cube`/ICCv4 for KDE Plasma ≥ 6.7 is an
open research topic. Credit: **BargainSir**.
