# Battery charge thresholds

Relates to issues #10 / #17.

## The actual mechanism (second correction, 2026-07-02 — verified on hardware)

Two earlier versions of this page were wrong (first "thresholds just work",
then "arm SBAD+SBCM"). The real behaviour, established by experiment on
FMB-P BIOS 1.16:

**The EC validates the (start, stop) threshold *pair* against Honor PC
Manager's presets.** Write a recognized pair into EC regs `0x80`/`0x81`
(what `huawei-wmi`'s normal `\SBTT` path does) and the EC **arms itself** —
it sets its internal charge-mode bytes (EC `0x85` = 2, `0x87` = 2) and
enforces the limit passively. Write anything else (e.g. `60 80`) and the EC
stores the values but never arms, silently charging to 100%. That is the
whole mystery behind "thresholds visible but not enforced".

Recognized pairs (PC Manager presets, from issue #17 and testing):

| start | stop | PC Manager name |
|-------|------|-----------------|
| 40 | 70 | "70%" |
| 70 | 90 | "90%" |
| 95 | 100 | "100%" |
| 0 | 100 | no limit (disarm) |

So the fix is simply:

```sh
echo "70 90" | sudo tee /sys/devices/platform/huawei-wmi/charge_control_thresholds
```

**No driver patch, no WMI arming needed.** Verify the EC armed itself
(needs `modprobe ec_sys`): EC byte `0x85` must be non-zero —

```sh
sudo xxd -s 0x84 -l 4 /sys/kernel/debug/ec/ec0/io   # xx CHMD 48 xx, CHMD != 00
```

Enforcement is robust: confirmed to hold under full CPU+GPU load, and the
EC actively drains back to the ceiling if the battery is above it when the
limit is set.

## Notes from the deep-dive (for the curious)

- `\SBCM` (WMI `0x1503`) sets mode + thresholds in one call. Payload bytes
  2–5 are `mode, 0x48, start, stop` — byte 3 **must be the magic `0x48`**
  (decoded in [Huawei-WMI#55](https://github.com/aymanbagabas/Huawei-WMI/issues/55));
  modes: 1=home, 2=office, 3=travel, 4=smart-charge. With the key it can arm
  *custom* pairs into an active drain-to-ceiling mode, but the EC cancels
  that state under heavy load, so it would need periodic re-arming — the
  preset-pair route is strictly better.
- `\SBAD`/`\GBAD` (WMI `0x1203`/`0x1303`) is **battery calibration
  discharge** (forces the machine to run from battery on AC until turned
  off), *not* a protection switch. Don't leave it on.
- EC bytes `0x85`/`0x86`/`0x87` are EC-owned status (charge mode / SBCM key
  echo / arm state); host writes to them get reverted within seconds.
- The EC RAM is memory-mapped at `0xFE0B0000` (banks `ECF0`–`ECF9` in the
  DSDT), readable via `/dev/mem` — handy for diffing EC state.

## Persist across reboots

The EC keeps the pair across reboots, but re-applying at boot is free
insurance. `honor-battery-thresholds.sh` writes the pair (default `70 90`,
edit to taste — **use a recognized pair**):

```sh
sudo install -Dm755 honor-battery-thresholds.sh /usr/local/sbin/honor-battery-thresholds.sh
sudo install -Dm644 honor-battery-thresholds.service /etc/systemd/system/honor-battery-thresholds.service
sudo systemctl enable honor-battery-thresholds.service
```
