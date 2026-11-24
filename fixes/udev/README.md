<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# udev / hwdb quirks

| File | Fixes | Credit |
|---|---|---|
| `61-honor-fmbp-touchpad.hwdb` | The touchpad's vendor HID collection sends a stuck `KEY_BRIGHTNESSUP`/`DOWN`, so the screen jumps between dark and full brightness (#3). Maps usages `0xff010003`/`0xff010004` (brightness) and `0xff010001` (mic-mute, stuck after resume) to `reserved`. The real F7 mic-mute key arrives via huawei-wmi. | nikube (root cause, fix), jean bzh, sujoshua, Osama-A-Abbas |
| `61-honor-fmbp-keyboard.hwdb` | The EC sends meaningless atkbd scancodes `e078` and `f8` with Fn hotkeys, which floods the log with "Unknown key pressed". | tsukasagenesis, drphilth, colorcube |
| `99-honor-fmbp-touchscreen.rules` | Inhibits the touchscreen's bogus second HID interface `FTSC1000:00 2808:5662 UNKNOWN` (phantom mic-mute, flickering mic LED). Matches by name, not by `inputNN`. | kv9898, DemoxDev, drphilth |
| `99-honor-fmbp-touchscreen-toggle.rules` | Optional: lets group `input` toggle the touchscreen without root via [`../../tools/honor-fmbp-touchscreen-toggle`](../../tools/honor-fmbp-touchscreen-toggle). | drphilth |

Install (`install.sh --only udev` does the first three):

```sh
sudo install -m644 61-*.hwdb /etc/udev/hwdb.d/
sudo install -m644 99-honor-fmbp-touchscreen.rules /etc/udev/rules.d/
sudo systemd-hwdb update && sudo udevadm trigger -s input
```

Check: `journalctl -k -b | grep -c "Unknown key"` should be 0, and screen brightness
stays constant while you use the touchpad.
