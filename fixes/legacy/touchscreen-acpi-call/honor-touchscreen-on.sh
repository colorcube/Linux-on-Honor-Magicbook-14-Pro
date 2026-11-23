#!/bin/bash
# Honor MagicBook 14 Pro (FMB-P): the BIOS wires the touchscreen's power
# resource (PTPL) to the wrong I2C scope, so the FocalTech FTSC1000 panel
# is never powered/reset. Drive its power-enable (GPIO 108 / GPP_A_12) and
# reset (GPIO 130 / GPP_E_2) lines high, call the misplaced _ON method,
# then bind the i2c-hid driver.
# Ref: https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/5

modprobe acpi_call 2>/dev/null || true

gpioset -c gpiochip0 108=1 130=1 &
GPIOPID=$!
sleep 0.5

if [ -w /proc/acpi/call ]; then
    echo '\_SB.PC00.I2C5.PTPL._ON' > /proc/acpi/call || true
fi
sleep 0.5

if [ ! -e /sys/bus/i2c/drivers/i2c_hid_acpi/i2c-FTSC1000:00 ]; then
    echo i2c-FTSC1000:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/bind 2>/dev/null || true
fi
sleep 0.5
kill $GPIOPID 2>/dev/null

# The bogus secondary keyboard interface is inhibited by
# /etc/udev/rules.d/99-ignore-touchpad-device.rules
exit 0
