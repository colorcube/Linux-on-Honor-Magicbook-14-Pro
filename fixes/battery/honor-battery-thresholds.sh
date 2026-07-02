#!/bin/sh
# Honor FMB-P: restore battery charge thresholds (60-80) and arm the EC's
# stop-charge logic.
#
# The EC stores thresholds in regs 0x80/0x81 (SCRS/TCRS) but only enforces
# them when BOTH of these are set (the sequence Honor PC Manager uses):
#   1. battery protection ON  - ACPI \SBAD, WMI cmd 0x1203, arg byte2=1
#   2. charge mode 2          - ACPI \SBCM, WMI cmd 0x1503, arms EC reg
#      0x85 (CHMD); with protection off the EC clears CHMD within seconds,
#      and mode 1 is rejected outright.
#
# Payload 0x503C00021503 = SBCM(mode=2, dact=0, start=0x3C/60, end=0x50/80).
#
# With huawei-wmi-battery-sbcm.patch applied, the driver issues SBAD+SBCM
# on every threshold write; the stock huawei-wmi driver only issues \SBTT.

echo "60 80" > /sys/devices/platform/huawei-wmi/charge_control_thresholds

# Fallback for the stock driver (e.g. DKMS build failure on a new kernel,
# or the LTS rescue kernel): arm protection + charge mode via WMI debugfs.
if [ -w /sys/kernel/debug/huawei-wmi/arg ]; then
    printf '0x011203' > /sys/kernel/debug/huawei-wmi/arg
    cat /sys/kernel/debug/huawei-wmi/call > /dev/null
    printf '0x503C00021503' > /sys/kernel/debug/huawei-wmi/arg
    cat /sys/kernel/debug/huawei-wmi/call > /dev/null
fi
