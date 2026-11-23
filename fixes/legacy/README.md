<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Legacy workarounds

Superseded fixes, kept for reference and for setups where the current fix can't be used.

| Directory / file | Replaced by | Why |
|---|---|---|
| [`touchscreen-acpi-call/`](touchscreen-acpi-call/) (kv9898, Obstacleee, DemoxDev, tsukasagenesis) | DSDT PowerResource in [`../../dsdt/`](../../dsdt/) | `acpi_call` doesn't build on kernel 7.3; the service used hard-coded `inputNN` paths |
| [`99-ignore-touchpad-device.rules`](99-ignore-touchpad-device.rules) (jean bzh) | [`../udev/61-honor-fmbp-touchpad.hwdb`](../udev/61-honor-fmbp-touchpad.hwdb) | inhibiting the whole ghost device also drops its mic-mute key |
| [`libfprint-identity-fallback/`](libfprint-identity-fallback/) (tsukasagenesis) | [`../libfprint/`](../libfprint/) (MR !666) | the fallback can't tell enrolled fingers apart |
