# Touchscreen (FocalTech FTSC1000) — working fix

Resolves issue #5 / #20.

## Root cause
The BIOS attaches the touchscreen's power resource (`PTPL`) to the wrong I2C
scope, so the FocalTech `FTSC1000` panel on `\_SB.PC00.I2C2.TPL1` is never
powered or taken out of reset. Linux enumerates the ACPI device but
`i2c_hid_acpi` can't talk to it (`i2ctransfer` to `0x38` returns `Remote I/O
error`). The panel's Power-Enable and Reset lines are GPIOs that stay low.

## Fix
Drive the two GPIO lines high, call the (misplaced) `_ON` power method, then
bind the HID driver. A bogus secondary HID keyboard interface
(`FTSC1000:00 2808:5662 UNKNOWN`) that the firmware also exposes is inhibited to
stop phantom key events / mic-LED flicker.

GPIO mapping on the Intel `INTC105E` controller (gpiochip0):
- line **108** (`GPP_A_12`) = touch power-enable → drive high
- line **130** (`GPP_E_2`)  = touch reset → drive high (release reset)

## Install
```sh
# dependencies
sudo pacman -S --needed acpi_call-dkms libgpiod   # Arch/CachyOS
# (Fedora: acpi_call-dkms from rpmfusion/copr; Debian: acpi-call-dkms + gpiod)

sudo install -Dm755 honor-touchscreen-on.sh /usr/local/sbin/honor-touchscreen-on.sh
sudo install -Dm644 honor-touchscreen.service /etc/systemd/system/honor-touchscreen.service
sudo install -Dm755 honor-touchscreen.sleep-hook /usr/lib/systemd/system-sleep/honor-touchscreen
echo acpi_call | sudo tee /etc/modules-load.d/acpi_call.conf
sudo systemctl daemon-reload
sudo systemctl enable --now honor-touchscreen.service
```

Add this udev rule (append to `99-ignore-touchpad-device.rules`) so the bogus
HID interface is inhibited automatically:
```
SUBSYSTEM=="input", ATTRS{name}=="FTSC1000:00 2808:5662 UNKNOWN", RUN+="/bin/sh -c 'echo 1 > /sys$env{DEVPATH}/../inhibited'"
```

## Notes
- The GPIO line numbers come from `gpioinfo` and may differ if your firmware
  enumerates the controller differently — verify with `gpioinfo gpiochip0`
  (look for the two `output` lines around 108/130).
- A cleaner long-term fix would patch the DSDT to attach the power resource to
  the correct scope and/or add `_PS0`/`_PS3`; this script-based approach avoids
  shipping another DSDT override.
