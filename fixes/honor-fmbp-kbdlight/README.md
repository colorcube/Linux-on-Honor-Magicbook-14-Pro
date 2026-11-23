<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Keyboard backlight: `honor-fmbp-kbdlight`

The in-tree `huawei-wmi` driver doesn't expose the keyboard backlight, and the
firmware's WMI keyboard-light methods do nothing on this model. This small DMI-gated
module drives the EC field `KBBL` (offset `0x41`) directly:

- `0x04` = off, `0x02` = low, `0x03` = high (reactive: turns off after inactivity)
- `0x01` = latch the current level (steady, no timeout)

It registers the standard LED `huawei::kbd_backlight`. UPower, GNOME and KDE pick it up
automatically: in KDE it appears as a slider in the battery & brightness applet. Fn+Space
cycles through the levels. The `mode` attribute switches between reactive and steady.

```sh
sudo cp -r . /usr/src/honor-fmbp-kbdlight-1.1
sudo dkms install honor-fmbp-kbdlight/1.1
sudo install -m644 honor-fmbp-kbdlight.conf /etc/modules-load.d/   # no modalias -> load explicitly
```

Tested: Fedora 44, kernel 7.3 (0/50/100 % via Fn+Space and the KDE slider).

Credit: **drphilth** (reverse engineering, driver), from
[honor-magicbook-pro-14-ubuntu](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu).
