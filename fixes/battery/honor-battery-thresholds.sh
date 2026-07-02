#!/bin/sh
# Honor FMB-P: restore battery charge thresholds at boot.
#
# The EC only enforces thresholds when the (start, stop) pair matches an
# Honor PC Manager preset: 40/70, 70/90 or 95/100 (0/100 = no limit).
# On a recognized pair the EC arms itself (EC 0x85/0x87 go non-zero) and
# stops charging at the ceiling; any other pair is stored but IGNORED.
#
# Change the pair below if you prefer 40/70 (max battery longevity) or
# 95/100 (max runtime) — but only use recognized pairs.

echo "70 90" > /sys/devices/platform/huawei-wmi/charge_control_thresholds
