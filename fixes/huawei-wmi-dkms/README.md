<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# huawei-wmi with FMB-P hotkeys (DKMS)

The in-tree `huawei-wmi` driver doesn't know the FMB-P-specific WMI hotkey codes.
Those keys are dead, and every press logs `Unknown key pressed`. On this laptop the
EC's auto-backlight notifications `0x2e5`/`0x2e6` alone produce hundreds of these
messages per boot. Issue [#4](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/4).

[`huawei-wmi.c`](huawei-wmi.c) is the **kernel v7.3** driver with
[`fmbp-keymap.patch`](fmbp-keymap.patch) applied. It installs as a DKMS module that
overrides the in-tree driver. When a new kernel changes the driver, rebuild it like
this:

```sh
curl -o huawei-wmi.c https://raw.githubusercontent.com/torvalds/linux/v7.3/drivers/platform/x86/huawei-wmi.c
patch huawei-wmi.c < fmbp-keymap.patch
```

| WMI code | key |
|---|---|
| `0x283` / `0x2a3` | touchpad toggle on/off (F3) |
| `0x288` | camera access toggle (F8) |
| `0x2a0` / `0x2a1` / `0x2a6` | performance mode (Fn+P): balanced / performance / rejected; see #27 |
| `0x2a7` | refresh-rate toggle (Fn+R) |
| `0x2b1`–`0x2b4` | keyboard-backlight levels |
| `0x2e0` / `0x2e1` | camera module enable/disable |
| `0x2e5` / `0x2e6` | EC auto-backlight notifications (ignored) |

`0x28e` → Print is already in mainline, so you don't need a hwdb entry for it.

Battery thresholds need **no** driver change; see [`../battery/`](../battery/).

## Install

```sh
sudo cp -r . /usr/src/huawei-wmi-fmbp-7.3.1
sudo dkms install huawei-wmi-fmbp/7.3.1
sudo modprobe -r huawei_wmi && sudo modprobe huawei-wmi
```

To check it works, run `journalctl -k -b | grep -c "Unknown key pressed"`. It should
stay at 0.

## Upstream

The goal is to get these mappings into mainline `huawei-wmi` together with a
`platform_profile` provider for Fn+P (`\GTUB`/`\STUB`, see #27). Then this module can
go away.

## Credits

- **egormanga**: FMB-P/MagicBook key assignments in
  [aymanbagabas/Huawei-WMI#93](https://github.com/aymanbagabas/Huawei-WMI/pull/93).
- **tsukasagenesis**: adapted them to the in-kernel driver and added the remaining
  codes (PR #21).
- **Ayman Bagabas** and the kernel contributors: the `huawei-wmi` driver itself (GPL-2.0).
