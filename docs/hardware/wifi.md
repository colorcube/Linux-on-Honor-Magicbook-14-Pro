<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Wi-Fi, Bluetooth, webcam

Wi-Fi (Intel CNVi `8086:7740`, `iwlwifi`), Bluetooth and the RGB webcam work out of the
box. The 2025 model has no IR camera.

## Open: Wi-Fi missing after every second warm reboot (#26)

Reported by **Ibim243** (Arch, BIOS 1.13, kernels 7.2 and 6.18 LTS, old DSDT override).
On affected boots the firmware crashes during init (`NMI_INTERRUPT_UMAC_FATAL`,
`Failed to run INIT ucode: -5`), and `wlp0s20f3` is missing. A cold boot works almost
every time.

Not reproduced yet with the minimal DSDT from this repository. Please report in #26
whether it happens for you, with `tools/honor-fmbp-diag` output and
`journalctl -k -b | grep iwlwifi`.
