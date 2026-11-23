<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Keyboard, LEDs, audio

## Internal keyboard (#1)

Before kernel 6.19 the keyboard only worked with the boot parameter `i8042.dumbkbd=1`.
Without it, `atkbd` gets no answer to its probe. The atkbd quirk
[`2aaf33c6e1e8`](https://github.com/torvalds/linux/commit/2aaf33c6e1e82561d7dce2345298a985a2483266)
fixes this, so since **6.19** no parameter is needed and the Caps-Lock LED works too.

If you still have `i8042.dumbkbd=1` on a current kernel, remove it.

Credit: **Cryolitia** (deepin / AOSC OS) bisected this and wrote the patch upstream;
**denis-bb** tested it.

## Caps-Lock and mic-mute LEDs (#9)

Both work on kernel ≥ 7.0 without `i8042.dumbkbd` (the mic-mute LED is
`platform::micmute`). Confirmed by **denis-bb** and **tsukasagenesis**.

## Fn keys (#4)

See [`fixes/huawei-wmi-dkms/`](../../fixes/huawei-wmi-dkms/). The EC also sends the
meaningless PS/2 scancodes `e078` and `f8` with some Fn keys.
[`fixes/udev/61-honor-fmbp-keyboard.hwdb`](../../fixes/udev/61-honor-fmbp-keyboard.hwdb)
silences them.

Desktops have no default action for `KEY_CAMERA_ACCESS_TOGGLE` (F8), `KEY_PROG1`
(Fn+P) or `KEY_REFRESH_RATE_TOGGLE` (Fn+R). Bind them yourself if you want an action.

## Audio (#2)

Up to kernel 6.x some setups needed `snd-intel-dspcfg.dsp_driver=3
snd-hda-intel.model=generic`. On kernel ≥ 7.0 (Fedora 44, Ubuntu 26.04) audio works
out of the box with SOF. Remove those parameters if you still have them. Reported by
**kxygk** and **colorcube**.

## ACPICA crash on stock boot (#11)

The stock DSDT used to trigger a kernel NULL-pointer dereference (hangs in `parted`, at
power-off). This is fixed in ACPICA and the kernel since **6.19 / 6.18.3**
([`9d6c58dae8f6`](https://github.com/torvalds/linux/commit/9d6c58dae8f6590c746ac5d0012ffe14a77539f0),
CVE-2025-71118). That's why standard installer images boot now. You still need the DSDT
override for full functionality. Credit: **Cryolitia**.
