<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# DSDT fix

The FMB-P firmware DSDT (BIOS 1.13 and 1.16, global and Chinese) has two defects:

1. **Load abort.** `Device (NFC0)` runs `GNUM (0x0014080A)` at table-load time. On
   Linux that faults and aborts the rest of the table load, which orphans much of the
   ACPI namespace. The result is a broken touchpad, missing battery and thermal
   information, no USB-C SSDT and, depending on the kernel, no NVMe at all.
2. **Touchscreen never powered.** The FocalTech `FTSC1000` panel on `I2C2` has no power
   resource. The firmware only defines one (`PTPL`) for the disabled sibling panels on
   `I2C4`/`I2C5`, so the panel stays in reset and `i2c_hid_acpi` gets `-ENXIO`.

The fix removes the single faulting call, injects a `PowerResource` that drives the
panel's power-enable GPIO (108, `GPP_A_12`) and reset GPIO (130, `GPP_E_2`), and bumps
the OEM revision so the kernel accepts the override. You can review every change in
[`prebuilt/fix.global.patch`](prebuilt/fix.global.patch). The full analysis is in
[`../docs/dsdt-root-cause.md`](../docs/dsdt-root-cause.md).

## Build from your own firmware (recommended)

```bash
sudo dnf install acpica-tools        # iasl
sudo dsdt/build.sh                   # reads /sys/firmware/acpi/tables/DSDT
```

The script refuses to build if the table in `/sys` is already overridden (OEM rev ≠ 2).
In that case, either boot once without the override or pass a stock table or
disassembly:

```bash
dsdt/build.sh --table /path/to/DSDT.dat      # raw table from `acpidump -b`
dsdt/build.sh --dsl   /path/to/stock.dsl     # e.g. denis-bb's original/dsdt.global.dsl
```

On BIOS 1.13 global, the table built from the firmware is identical to drphilth's
hardware-tested table (verified 2026-11-23, see [docs/testing.md](../docs/testing.md)).

**BIOS 1.17** fixes the NFC0 load abort (#22). `build.sh` detects this and then only
injects the touchscreen power resource. It always sets the OEM revision to the
firmware's revision + 1.

The script detects the BIOS SKU (global/Chinese) from the GNVS address. It aborts if a
future BIOS changes the patched code. When the input is global, it also derives the
Chinese table. That table is byte-identical to one built straight from denis-bb's
Chinese stock disassembly.

> **Never commit raw ACPI dumps.** `acpidump -b` also writes the `MSDM` table, which
> holds your Windows product key.

## Prebuilt tables (fallback)

[`prebuilt/`](prebuilt/) holds tables built by `build.sh` from the stock BIOS 1.13
disassembly that denis-bb published. They are meant for live USB/ISO use or machines
without `iasl`. They are minimally patched derivatives of HONOR's firmware and are
redistributed to owners of this hardware as an interoperability fix.

| File | SKU | Tested on hardware |
|---|---|---|
| `dsdt.global.aml` | global | ✅ BIOS 1.13, Fedora 44, kernel 7.3.4 (see [docs/testing.md](../docs/testing.md)) |
| `dsdt.chinese.aml` | Chinese | **untested**, reports welcome |

## Installing the override

`tools/install.sh --only dsdt` does this for you. To do it by hand on dracut systems
(Fedora):

```bash
sudo install -Dm644 dsdt/out/dsdt.global.aml /usr/lib/honor-fmbp/acpi/dsdt.aml
echo 'acpi_override="yes"
acpi_table_dir="/usr/lib/honor-fmbp/acpi"' | sudo tee /etc/dracut.conf.d/10-honor-fmbp-dsdt.conf
sudo dracut --force --regenerate-all
```

After a reboot, `journalctl -k | grep "Table Upgrade"` should show
`override [DSDT-HONOR-ARL]`.

**Secure Boot:** disable it. Kernel lockdown is supposed to block initrd ACPI
overrides. Kernel 7.0 applies them anyway because of a boot-ordering quirk, but you
can't rely on that.

**Rescue:** keep a boot entry without the override (for example an older initramfs, or
`rd.break` plus removing the dracut config). Without the override the system still
boots on Fedora with kernel ≥ 6.19, but the touchpad and touchscreen don't work.

## Credits

- **denis-bb**: first public FMB-P DSDT fix and the stock disassemblies
  ([honor-fmb-p-dsdt](https://github.com/denis-bb/honor-fmb-p-dsdt)).
- **drphilth** (Philip Walsh): root-cause analysis, minimal patch, touchscreen
  PowerResource, Chinese-SKU derivation, build pipeline
  ([honor-magicbook-pro-14-ubuntu](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu)).
- **kv9898**, **Obstacleee**, **tsukasagenesis**, **codethinki**: touchscreen power
  analysis (GPIO lines, misplaced `PTPL`, DSDT-only fix in denis-bb PR #10).
- **NOREIED**: Chinese-SKU touchscreen DSDT.
- **Cryolitia**: kernel-side ACPICA fix that makes stock boots survive (6.19+).
