<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Fixes

Each directory has its own README covering the problem, the fix, how to verify it and
who found it. [`../install.sh`](../install.sh) installs them all (`--only` picks single
modules).

| Directory | What | install.sh module |
|---|---|---|
| [`../dsdt/`](../dsdt/) | corrected DSDT: NFC0 load abort + touchscreen power | `dsdt` |
| [`udev/`](udev/) | touchpad ghost brightness keys, `e078`/`f8` scancodes, touchscreen ghost interface | `udev` |
| [`huawei-wmi-dkms/`](huawei-wmi-dkms/) | Fn-key map for the in-kernel `huawei-wmi` | `wmi` |
| [`honor-fmbp-hwmon/`](honor-fmbp-hwmon/) | fan RPM in `sensors` | `hwmon` |
| [`honor-fmbp-kbdlight/`](honor-fmbp-kbdlight/) | keyboard backlight LED (`huawei::kbd_backlight`) | `kbdlight` |
| [`battery/`](battery/) | charge limit (PC Manager preset pairs only) | `battery` |
| [`libfprint/`](libfprint/) | fingerprint reader FPC `10a5:9924` | separate (RPM / build) |
| [`legacy/`](legacy/) | superseded workarounds, kept for reference | — |
