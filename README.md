# Linux on Honor Magicbook 14 Pro

This repository contains a record of all the steps required to get the Honor Magicbook 14 Pro laptop working with Linux.

While issues (and solutions) can be discussed and tracked in this repository, its purpose is not to provide code, but rather to organize things and provide the necessary information needed to run Linux on this device.


## Status

Since october 2025 it is possible to run Linux as a daily driver by appliying some tweaks.

The main problem is that the BIOS (v1.13) contains faulty ACPI tables (DSDT). 
These tables provide information about the computer's hardware so that Linux can find and use the hardware components. 
This works if the ACPI tables are correct and Linux has drivers for the hardware. Since the current tables are not correct, Linux cannot find all of the hardware.

Fortunately there's a patch for this and other problems.

### What works (with tweaks)

- :heavy_check_mark: Native screen resolution
- :heavy_check_mark: Graphics hardware
- :heavy_check_mark: Wifi
- :heavy_check_mark: USB-C (screen, ethernet, hid, etc…)
- :heavy_check_mark: Keyboard (dumb mode)
- :heavy_check_mark: Fn Keys (some)
- :heavy_check_mark: Touchpad
- :heavy_check_mark: Audio
- :heavy_check_mark: Webcam
- :heavy_check_mark: Fan control
- :heavy_check_mark: Suspend/Resume

### What doesn't work

- :x: Fingerprint Reader, See [#6](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/6)
- :x: Touchscreen, See [#5](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/5)
- :x: Fn Keys (some), See  [#4](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/4)
- :x: Keyboard (no dumb mode), See: [#1](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/1)
- :x: Fan speed, See: [#7](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/7)

### Tested Linux Distributions

#### Fedora 43

Kernel 6.18.0-0
KDE 6.5.1

## Quickstart

### 1. Keyboard and Sound

Add following boot parameter to the kernel commandline to fix keyboard and sound:

```
i8042.dumbkbd=1 snd-intel-dspcfg.dsp_driver=1
```

See: [#1](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/1) [#2](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/2)

How to set boot parameter: [google](https://www.google.com/search?q=How+do+I+add+a+linux+kernel+boot+parameter)

### 2. Touchpad

Look here for instructions to install a patched DSDT to make the touchpad work:

https://github.com/denis-bb/honor-fmb-p-dsdt

### 3. Screen brightness

Disable a weird device which causes the screen to go dark and to full brightness:

Add a udev rule to disable the device by adding following file: ```/etc/udev/rules.d/99-ignore-touchpad-device.rules``` with this content:

```
SUBSYSTEM=="input", ATTRS{name}=="GXT7863:00 27C6:01E0 UNKNOWN", RUN+="/bin/sh -c 'echo 1 > /sys$env{DEVPATH}/../inhibited'"
```

And reboot.

See: [#3](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues/3)

## Problems and how to solve them

Have a look at the [Github issues](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues).


## Machine Infos

Specs: [honor.com](https://www.honor.com/global/laptops/honor-magicbook-pro-14/spec/)

Manufacturer: HONOR<br>
Product Name: FMB-P<br>
Version: M1030<br>
SKU Number: C100<br>
Family: HONOR MagicBook

### Latest Bios

BIOS version 1.13 (release date 05/08/2025)

### Hardware

Hardware detected by hw-probe: https://linux-hardware.org/?probe=1657e7ed5c

Have a look at the [Github issues](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues) for information and discussion of specific hardware devices.

## Resources

- [A discussion about this machine which got things going](https://discussion.fedoraproject.org/t/fedora42-workstation-work-badly-in-honor-magicbook-14-pro)
