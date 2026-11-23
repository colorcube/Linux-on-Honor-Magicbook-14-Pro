# Fan speed readout — `honor-fmbp-hwmon`

Resolves issue #7 (fan RPM reporting).

## What it does
A small hwmon kernel module that exposes the two fan tachometers the EC keeps
in its RAM, so `sensors` shows real RPMs (e.g. `fan1: 2291 RPM`, `fan2: 1989 RPM`).

The fan **control** is still handled autonomously by the EC — this only adds
read-only RPM reporting, which was previously missing entirely.

## How the registers were found
Dumping the EC RAM (`modprobe ec_sys`, read `/sys/kernel/debug/ec/ec0/io`) at
idle vs. under a CPU stress load and diffing revealed two little-endian 16-bit
words that scale with fan speed:

| EC offset | meaning            |
|-----------|--------------------|
| `0x2C/0x2D` | fan 1 RPM (LE)   |
| `0x2E/0x2F` | fan 2 RPM (LE)   |

(For reference, other useful EC offsets found the same way: `0x10–0x1A` =
temperatures in °C, `0x80/0x81` = battery charge start/stop thresholds,
`0x85/0x87` = threshold enable flags, `0x0A` = performance-mode flag.)

## Install (DKMS — survives kernel updates)
```sh
sudo cp -r . /usr/src/honor-fmbp-hwmon-1.0
sudo dkms add honor-fmbp-hwmon/1.0
sudo dkms install honor-fmbp-hwmon/1.0
echo honor-fmbp-hwmon | sudo tee /etc/modules-load.d/honor-fmbp-hwmon.conf
sudo modprobe honor-fmbp-hwmon
sensors honor_fmbp-isa-0000
```

The module is DMI-gated to `HONOR / FMB-P`, so it won't load on other machines.
