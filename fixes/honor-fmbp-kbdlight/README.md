<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Keyboard backlight: `honor-fmbp-kbdlight`

The in-tree `huawei-wmi` driver doesn't expose the keyboard backlight, and the
firmware's WMI keyboard-light methods do nothing on this model. This small DMI-gated
module drives the EC field `KBBL` (offset `0x41`) directly:

- `0x04` = off, `0x02` = low, `0x03` = high (reactive: turns off after inactivity)
- `0x01` = latch the current level (steady, no timeout)

It registers the standard LED `huawei::kbd_backlight`. UPower, GNOME and KDE pick it up
automatically: in KDE it appears as a slider in the battery & brightness applet. Fn+Space
cycles through the levels. The EC does that itself; since 1.0.6 the driver polls `KBBL`
(every 300 ms, module parameter `poll_ms`, 0 = off) and reports such changes via
`brightness_hw_changed`, so the desktop shows an OSD and the slider follows (#38).

| Fn+Space | WMI event | EC `KBBL` |
|---|---|---|
| off | `0x2b1` | `0x04` |
| 50 % | `0x2b2` | `0x02` |
| 100 % | `0x2b3` | `0x03` |

In the default **reactive** mode the EC turns the backlight off after some inactivity
and back on with the next key press. That doesn't change `KBBL`, so the desktop keeps
showing the configured level, and Fn+Space continues from there (as on Windows). If you
don't want the timeout, switch to **steady** mode:

```sh
echo steady | sudo tee /sys/class/leds/huawei::kbd_backlight/mode
``` The `mode` attribute switches between reactive and steady.

```sh
sudo cp -r . /usr/src/honor-fmbp-kbdlight-1.1
sudo dkms install honor-fmbp-kbdlight/1.1
sudo install -m644 honor-fmbp-kbdlight.conf /etc/modules-load.d/   # no modalias -> load explicitly
```

Tested: Fedora 44, kernel 7.3 (0/50/100 % via Fn+Space and the KDE slider).

Credit: **drphilth** (reverse engineering, driver), from
[honor-magicbook-pro-14-ubuntu](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu).
