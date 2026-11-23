<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Power button (#8)

**This isn't a bug: hold the button firmly for about half a second.** The button
doubles as the fingerprint sensor, so the EC ignores short touches on purpose. A short
tap never reaches the OS, and Windows behaves the same way.

A press held for about 0.5 s makes the EC raise query `0x33`. The DSDT's `_Q33` sends
`Notify(PWRB, 0x80)`, the `PNP0C0C` device emits `KEY_POWER`, and GNOME/KDE show the
power dialog. Holding it for about 10 s forces a hardware power-off.

To watch this happen:

```sh
echo 'file drivers/acpi/ec.c +p' | sudo tee /sys/kernel/debug/dynamic_debug/control
sudo dmesg -w | grep 'Query('      # hold the button ~0.5 s -> Query(0x33)
```

`Query(0xb1)` and `Query(0xb2)` appear periodically. Those are thermal events, not the
button.

Credit: **Atom-Py** traced the EC queries and FADT. **drphilth** found the hold
behaviour and the `_Q33` path. Confirmed by **colorcube**.
