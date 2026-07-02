# Battery charge thresholds

Relates to issues #10 / #17.

## Finding (corrected 2026-07-02)

An earlier version of this page claimed the thresholds written through
`huawei-wmi` were honoured by the EC. **That was wrong** — the EC *stores*
them but does not *enforce* them, and the laptop still charges to 100%.

`huawei-wmi` only issues WMI command `0x1003` (ACPI `\SBTT`), which writes the
start/stop percentages into EC registers `0x80`/`0x81`. Enforcement requires
the sequence Honor PC Manager uses on Windows — **both** steps, in order:

1. **Battery protection ON** — ACPI `\SBAD` = WMI cmd `0x1203`, arg byte 2 =
   `1` (on) / `2` (off). This sets a flag in EC bank 5 (`0xFE0B0502`), outside
   the classic EC address space (invisible to `ec_sys` dumps, which is why it
   was missed). Read back with `\GBAD` = `0x1303` (returns 1=on, 2=off).
2. **Charge mode 2** — ACPI `\SBCM` = WMI cmd `0x1503`, payload bytes 2–5 =
   `mode, dact, start, end`. Mode `2` arms the charge-mode byte `CHMD`
   (EC reg `0x85`) and rewrites the thresholds.

Gotchas found by experiment:

- mode `1` is rejected while on AC; mode `2` is the one that latches;
- a non-zero `dact` byte clears `CHMD`;
- with protection (`SBAD`) off, the EC accepts `SBCM` and then **silently
  clears `CHMD` ~5 seconds later** — it looks armed, then reverts, which makes
  this very easy to misdiagnose.

Once armed, behaviour matches Windows: above the end threshold on AC the EC
actively drains the battery down to the cap and holds it there; charging only
resumes below the start threshold.

## Quick test (stock kernel, no driver changes)

```sh
# battery protection ON  (\SBAD, byte2=1)
printf '0x011203' | sudo tee /sys/kernel/debug/huawei-wmi/arg
sudo cat /sys/kernel/debug/huawei-wmi/call > /dev/null

# charge mode 2, start=60 (0x3C), end=80 (0x50)  (\SBCM)
printf '0x503C00021503' | sudo tee /sys/kernel/debug/huawei-wmi/arg
sudo cat /sys/kernel/debug/huawei-wmi/call > /dev/null
```

Verify: `sudo modprobe ec_sys`, then EC byte `0x85` must read `02` **and stay
`02`** (re-check after 10 s):

```sh
sudo xxd -s 0x84 -l 4 /sys/kernel/debug/ec/ec0/io
```

## Proper fix: driver patch

`huawei-wmi-battery-sbcm.patch` makes `huawei_wmi_battery_set()` issue
`SBAD`(on) + `SBCM`(mode 2) after `SBTT` — or `SBAD`(off) + `SBCM`(mode 0)
when set back to `0/100`. With it, the normal interfaces just work:

```sh
echo "60 80" | sudo tee /sys/devices/platform/huawei-wmi/charge_control_thresholds
# or /sys/class/power_supply/BAT0/charge_control_{start,end}_threshold,
# or KDE's battery-limit UI
```

It composes with the Fn-key keymap patch in [`../fn-keys/`](../fn-keys/)
(different hunks of the same file) — apply both to one DKMS tree.

## Persist across reboots

The EC keeps the thresholds, but the protection/mode flags don't reliably
survive a power cycle. `honor-battery-thresholds.sh` re-applies everything:
it writes the thresholds via sysfs and, if a *stock* driver is loaded (LTS /
rescue kernel, DKMS build failure), also replays the two WMI commands via
debugfs as a fallback. Run it at boot with the service (defaults to 60–80;
edit to taste):

```sh
sudo install -Dm755 honor-battery-thresholds.sh /usr/local/sbin/honor-battery-thresholds.sh
sudo install -Dm644 honor-battery-thresholds.service /etc/systemd/system/honor-battery-thresholds.service
sudo systemctl enable honor-battery-thresholds.service
```
