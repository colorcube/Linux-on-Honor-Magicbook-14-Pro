# Test log

Results of testing the fixes in this repository on real hardware. Please add your own
results through an issue or PR, and include the output of `tools/honor-fmbp-diag`.

## Test machines

| ID | Model | BIOS | SKU | CPU | Distro | Tester |
|---|---|---|---|---|---|---|
| A | FMB-P M1030 / C100 | 1.13 (05/08/2025) | global | Core Ultra 9 285H | Fedora 44 KDE | colorcube |

## Results

| Date | Machine | Kernel | Fix | Result | Notes |
|---|---|---|---|---|---|
| 2026-11-23 | A | 7.3.4-200.fc44 | `dsdt/prebuilt/dsdt.global.aml` via dracut (`acpi_override`) | ✅ | `Table Upgrade: override` logged. Touchscreen binds to `i2c_hid_acpi` **without acpi_call** and works after suspend/resume. NVMe, touchpad and Wi-Fi OK. ACPI boot errors dropped from 14 (denis-bb table via GRUB) to 6; the remaining ones are SSDT references to touch devices this variant doesn't have (`I2C3.TPD0`, `I2C4/I2C5.TPL1`). The `TXHC.RHUB.SS01-04` errors are gone. |
| 2026-11-23 | A | 7.3.4-200.fc44 | `fixes/udev/99-honor-fmbp-touchscreen.rules` | ✅ | `FTSC1000:00 2808:5662 UNKNOWN` inhibited by name. |
| 2026-11-23 | A | 7.3.3-200.fc44 | `fixes/legacy/touchscreen-acpi-call` | ❌ | `acpi_call` DKMS doesn't build on 7.3, and the inhibit used a hard-coded `inputNN` path. Superseded by the DSDT fix. |
| 2026-11-23 | A | 7.3.4-200.fc44 | `fixes/udev/61-honor-fmbp-touchpad.hwdb` (replaces the inhibit rule) | ✅ | Brightness stays constant while using the touchpad. The ghost device stays active (`inhibited=0`) but no longer sends brightness keys. Mic-mute (F7) works, no mic-overlay flicker in KDE. |
| 2026-11-23 | A | 7.3.4-200.fc44 | `fixes/honor-fmbp-kbdlight` (DKMS) | ✅ | `huawei::kbd_backlight` appears. Fn+Space and the KDE slider switch between 0/50/100 %. |
| 2026-11-23 | A | 7.3.4-200.fc44 | `fixes/honor-fmbp-hwmon` (DKMS) | ✅ | `sensors`: 2400/2164 RPM under load, 0/0 RPM at idle (fans really stop). Auto-loads at boot via modules-load.d. |
| 2026-11-23 | A | 7.3.4-200.fc44 | `fixes/huawei-wmi-dkms` (v7.3 + FMB-P keymap) | ✅ | Zero WMI "Unknown key" messages (619 per boot before). F3 toggles the touchpad. F8 → `KEY_CAMERA_ACCESS_TOGGLE`, Fn+P → `KEY_PROG1` (0x2a0), Fn+R → `KEY_REFRESH_RATE_TOGGLE`: the events arrive, but KDE binds no default action (no OSD). |
| 2026-11-23 | A | 7.3.4-200.fc44 | — | ⚠️ open | atkbd scancode `0xf8` (translated set 2) still logs "Unknown key" (~11×/boot). Key not identified yet. A kernel WARNING from i915 at boot ("Port A asks to use VBT vswing/preemph tables") is cosmetic and unrelated. |
