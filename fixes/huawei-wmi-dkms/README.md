# huawei-wmi DKMS tree (vendored, patched for FMB-P)

This is the stock kernel `drivers/platform/x86/huawei-wmi.c` (GPL-2.0) with
the FMB-P Fn-key patch from this repo already applied, plus
`dkms.conf`/`Makefile` so it can be installed as a DKMS module that overrides
the in-tree driver:

- [`../fn-keys/huawei-wmi-fmbp.patch`](../fn-keys/huawei-wmi-fmbp.patch) —
  FMB-P hotkey codes (issue #4)

(Battery thresholds need **no** driver change — the stock `\SBTT` path works
once a recognized preset pair is used; see [`../battery/`](../battery/).)

It is vendored so `install.sh` works offline and deterministically instead of
fetching kernel sources at run time.

## Manual install

```sh
sudo cp -r . /usr/src/huawei-wmi-fmbp-1.0
sudo dkms install huawei-wmi-fmbp/1.0
sudo modprobe -r huawei_wmi && sudo modprobe huawei-wmi
```

DKMS rebuilds it automatically on kernel updates (needs the matching kernel
headers installed).
