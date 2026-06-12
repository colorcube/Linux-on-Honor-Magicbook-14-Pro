# Battery charge thresholds

Relates to issues #10 / #17.

## Finding
On this unit (BIOS 1.16, with the DSDT override applied) the charge thresholds
exposed by `huawei-wmi` **are honoured by the EC**:

```sh
echo "60 80" | sudo tee /sys/devices/platform/huawei-wmi/charge_control_thresholds
# or per-attribute:
#   /sys/class/power_supply/BAT0/charge_control_start_threshold
#   /sys/class/power_supply/BAT0/charge_control_end_threshold
```

Writing thresholds flips EC registers `0x80`/`0x81` (start/stop %) and enable
flags `0x85`/`0x87` (confirmed by diffing EC RAM), and charging stops at the set
ceiling. Earlier "thresholds ignored" reports may predate the DSDT fix that gets
the EC working correctly.

## Persist across reboots
`honor-battery-thresholds.service` re-applies the limits at boot (defaults to
60–80; edit the value to taste):
```sh
sudo install -Dm644 honor-battery-thresholds.service /etc/systemd/system/honor-battery-thresholds.service
sudo systemctl enable honor-battery-thresholds.service
```
(`matebook-applet` also works as a GUI alternative, per issue #10.)
