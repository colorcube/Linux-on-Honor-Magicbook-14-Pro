#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# SPDX-FileCopyrightText: 2026 Philip Walsh (drphilth) <packages@drphilth.com>
# Source: https://github.com/drphilth/honor-magicbook-pro-14-ubuntu (dsdt/inject-touchscreen-power.py)
# Root cause of the touchscreen power bug: kv9898, Obstacleee, tsukasagenesis, codethinki
# (see https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/5)
# inject-touchscreen-power.py <dsdt.dsl>
# Touchscreen power fix, modeled on the FIRMWARE'S OWN pattern for the sibling I2C4/I2C5
# panels (PowerResource PTPL in SSDT7) that the OEM "forgot" to add to the active I2C2
# FTSC1000 node. Adds a self-contained PowerResource (PWRR) whose _ON drives power (GPIO
# 108, desc 0x0014040C) + reset (GPIO 130, 0x00140482) via SPMV(mode)+SGOV(value), referenced
# by _PR0 AND _PR3 methods (gated on the device _STA, like the firmware). Linux turns the
# resource _ON when it powers the device to D0 at i2c_hid probe (verified path:
# i2c_device_probe -> dev_pm_domain_attach(POWER_ON) -> acpi_dev_pm_full_power ->
# acpi_device_set_power(D0) -> PWRR._ON). NO _PSC (see block note). Targets ONLY the FTSC1000.
import sys, re

path = sys.argv[1]
src = open(path).read()

m = re.search(r'_HID = "FTSC1000"', src)
if not m:
    sys.exit("inject: FTSC1000 not found")
# first `Name (_HID, "XXXX0000")` after the FTSC1000 marker = our panel device member
m2 = re.search(r'(?m)^([ \t]*)Name \(_HID, "XXXX0000"\)', src[m.end():])
if not m2:
    sys.exit("inject: anchor 'Name (_HID, \"XXXX0000\")' not found after FTSC1000")
ind = m2.group(1)
block = (
    # Self-contained PowerResource — modeled on the firmware's own PTPL (SSDT7, for the
    # sibling I2C4/I2C5 panels). STAT lives INSIDE PWRR so _STA is self-contained: an
    # earlier attempt kept STAT at the device scope (to feed a _PSC), which made PWRR._STA
    # resolve to the wrong object -> acpi_power_get_state() -> acpi_bus_init_power() failed
    # -> the kernel cleared power_manageable and never called _ON. No _PSC (the firmware
    # has none); Linux infers D3 from PWRR._STA=0 at boot, then powers to D0 on probe.
    f'{ind}PowerResource (PWRR, 0x00, 0x0000)\n'
    f'{ind}{{\n'
    f'{ind}    Name (STAT, Zero)\n'
    f'{ind}    Method (_STA, 0, NotSerialized) {{ Return (STAT) }}\n'
    f'{ind}    Method (_ON, 0, NotSerialized)\n'
    f'{ind}    {{\n'
    # SPMV (GPIO-output mode) then SGOV (drive high): our pads, unlike the firmware's
    # I2C4/I2C5 variant, are not pre-configured to output mode, so SGOV alone won't drive.
    f'{ind}        \\_SB.SPMV (0x0014040C, Zero)\n'
    f'{ind}        \\_SB.SGOV (0x0014040C, One)\n'
    f'{ind}        Sleep (0x02)\n'
    f'{ind}        \\_SB.SPMV (0x00140482, Zero)\n'
    f'{ind}        \\_SB.SGOV (0x00140482, One)\n'
    f'{ind}        Sleep (0x64)\n'
    f'{ind}        STAT = One\n'
    f'{ind}    }}\n'
    f'{ind}    Method (_OFF, 0, NotSerialized)\n'
    f'{ind}    {{\n'
    f'{ind}        \\_SB.SGOV (0x00140482, Zero)\n'
    f'{ind}        Sleep (0x03)\n'
    f'{ind}        \\_SB.SGOV (0x0014040C, Zero)\n'
    f'{ind}        STAT = Zero\n'
    f'{ind}    }}\n'
    f'{ind}}}\n'
    # TD_P MUST (a) come AFTER the PowerResource and (b) use the ABSOLUTE path: the stock
    # DSDT has an unrelated Method(PWRR) at \_SB scope (power-button notify helper), and a
    # bare `PWRR` element declared before the PowerResource resolved to THAT via parent-scope
    # search at table load. The kernel then registered \_SB.PWRR as a power resource, its
    # _STA eval failed -> acpi_bus_init_power() errored -> power_manageable=0 -> _ON never
    # ran. (Diagnosed via dyndbg boot: "\_SB_.PWRR: New power resource" with no state line.)
    f'{ind}Name (TD_P, Package (0x01) {{ \\_SB.PC00.I2C2.TPL1.PWRR }})\n'
    # _PR0 and _PR3 as methods gated on the device _STA (the firmware's pattern): the
    # panel is powered in D0 AND D3hot, fully off only in D3cold. Return empty if absent.
    f'{ind}Method (_PR0, 0, NotSerialized)\n'
    f'{ind}{{\n'
    f'{ind}    If ((_STA () == 0x0F)) {{ Return (TD_P) }}\n'
    f'{ind}    Return (Package (0x00) {{}})\n'
    f'{ind}}}\n'
    f'{ind}Method (_PR3, 0, NotSerialized)\n'
    f'{ind}{{\n'
    f'{ind}    If ((_STA () == 0x0F)) {{ Return (TD_P) }}\n'
    f'{ind}    Return (Package (0x00) {{}})\n'
    f'{ind}}}\n'
    f'{ind}Method (_PS0, 0, NotSerialized) {{ }}\n'
    f'{ind}Method (_PS3, 0, NotSerialized) {{ }}\n'
)
at = m.end() + m2.start()
open(path, 'w').write(src[:at] + block + src[at:])
print("inject: added self-contained PWRR PowerResource + _PR0/_PR3/_PS0/_PS3 (firmware PTPL pattern) to the FTSC1000 device")
