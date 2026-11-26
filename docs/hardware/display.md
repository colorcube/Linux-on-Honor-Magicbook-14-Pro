<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Display: brightness, HDR, colour calibration

## Screen jumps between dark and full brightness (#3)

The Goodix touchpad (`GXT7863`, `27C6:01E0`) exposes two vendor HID collections (usage
pages FF00/FF01) that Windows leaves unbound. Linux turns them into a third input
device, `GXT7863:00 27C6:01E0 UNKNOWN`. That device sends a `KEY_BRIGHTNESSUP`/`DOWN`
press but never the release, so kernel autorepeat fires it at about 30 Hz.

**Fix:** [`fixes/udev/61-honor-fmbp-touchpad.hwdb`](../../fixes/udev/61-honor-fmbp-touchpad.hwdb)
maps the vendor usages `0xff010003`/`0xff010004` to `reserved` inside the kernel. This
works for every desktop. The ghost device also has a mic-mute usage (`0xff010001`) with
the same bug: after resume it made KDE's mic OSD flicker. Since 1.0.3 it is mapped to
`reserved` too, because F7 arrives via huawei-wmi.

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

The OLED panel advertises HDR only in its DisplayID 2.0 block. The kernel reads
the CTA-861 HDR static metadata block (extended tag `0x06`) and nothing else
(`drivers/gpu/drm/drm_edid.c`), so the connector's `HDR_OUTPUT_METADATA` stays
empty and the compositor sees no HDR. Compositors that parse EDID via
`libdisplay-info` (such as GNOME's mutter and Hyprland's Aquamarine) also only
look at the CTA-861 block, so they see nothing either. KDE's KWin works around
it by synthesising the metadata from the base EDID's chromaticities plus the
DisplayID declaration — that's why Plasma shows an HDR switch while the others
don't.

The patched EDID from denis-bb
([issue #16](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/16),
[`fixes/edid/edp-hdr.bin`](../../fixes/edid/)) repeats the HDR information in a CTA-861
extension block. See [fixes/edid/README.md](../../fixes/edid/README.md) for setup
instructions.

Use it with care: the EDID detailed timing can't describe the native modes exactly.
Credit: **denis-bb**.

## Factory colour calibration (#19)

Windows ships per-panel `*_display_factory_calibration_N.xml` files containing 17³ 3D
LUTs, plus ICC profiles. Converting them to `.cube`/ICCv4 for KDE Plasma ≥ 6.7 is an
open research topic. Credit: **BargainSir**.
