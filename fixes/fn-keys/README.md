# Fn keys — patched `huawei-wmi`

Resolves issue #4.

## What works after this
Maps the FMB-P-specific WMI hotkey codes that the in-tree `huawei-wmi` driver
doesn't know, so the previously-dead Fn keys emit proper keycodes:

| WMI code | key |
|----------|-----|
| `0x283` / `0x2a3` | touchpad toggle on/off (F-row) |
| `0x288` | camera access toggle |
| `0x2a0` / `0x2a1` / `0x2a6` | performance-mode switch (Fn+P) |
| `0x2a7` | refresh-rate toggle (Fn+R) |
| `0x2b1`–`0x2b4` | keyboard-backlight level keys |
| `0x2e0` / `0x2e1` | camera module enable/disable |
| `0x2e5` / `0x2e6` | EC auto-backlight notifications (ignored) |

The keymap additions are based on the work in
[aymanbagabas/Huawei-WMI#93](https://github.com/aymanbagabas/Huawei-WMI/pull/93)
adapted to the in-kernel driver.

`61-honor-fmbp-keyboard.hwdb` additionally silences a meaningless `e078` atkbd
scancode the EC emits alongside hotkey presses (stops the
`atkbd: Unknown key pressed` dmesg spam).

## Install (DKMS against the in-tree module)
```sh
# Fetch the matching in-tree driver source for your kernel, apply the patch,
# and build it as a DKMS module that overrides the stock huawei-wmi.
curl -L "https://git.kernel.org/.../drivers/platform/x86/huawei-wmi.c?h=v<your-kver>" -o huawei-wmi.c
patch huawei-wmi.c < huawei-wmi-fmbp.patch
# package as DKMS (BUILT_MODULE_NAME=huawei-wmi, DEST=/updates/dkms) and install.

# hwdb:
sudo install -Dm644 61-honor-fmbp-keyboard.hwdb /etc/udev/hwdb.d/61-honor-fmbp-keyboard.hwdb
sudo systemd-hwdb update && sudo udevadm trigger
```

Ideally these mappings land upstream in `huawei-wmi` so no out-of-tree module is
needed; the patch here is provided for people who want them working today.
