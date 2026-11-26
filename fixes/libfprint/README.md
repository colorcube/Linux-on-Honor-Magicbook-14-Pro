<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Fingerprint reader

The FMB-P ships with one of several sensors in the power button. Check yours with
`lsusb | grep -i -E '10a5|1c7a'`:

| USB ID | Sensor | Status |
|---|---|---|
| `10a5:9924` | FPC L:2407 (most global units) | patch below, upstream MR [!666](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/666) open |
| `1c7a:05aa` | EgisTec ET171 (Chinese units, some others) | SDCP fork: [drphilth/honor-fmbp-libfprint-sdcp](https://github.com/drphilth/honor-fmbp-libfprint-sdcp); guide: [westi77](https://github.com/westi77/magic_book_pro_14_linux_guide/blob/main/Fingerprint-1c7a.md) |
| `10a5:a920` | FPC (other variant) | fork: [feraxtx/libfprint-10a5-a920](https://github.com/feraxtx/libfprint-10a5-a920) |

## FPC 10a5:9924

[`fpcmoc-10a5-9924.patch`](fpcmoc-10a5-9924.patch) is upstream MR !666. It applies
unchanged to libfprint 1.94.100 (Fedora 44). It does two things:

1. It registers `10a5:9924` in the `fpcmoc` driver and the autosuspend hwdb.
2. It skips `g_usb_device_reset()` when the device is opened. On this sensor the reset
   restarts the firmware, which re-enumerates as a new USB device. The driver's handle
   becomes stale and enrollment fails.

With the reset skipped, the sensor returns proper identities. libfprint therefore
still checks *which* enrolled finger matched, and no "trust the chip" fallback is
needed.

**Fedora:** build the RPM from [`../../packaging/fedora/libfprint/`](../../packaging/fedora/libfprint/).
Later it will also come from the COPR.

**Arch:** see [docs/install/arch.md](../../docs/install/arch.md#fingerprint).

```sh
git clone https://gitlab.freedesktop.org/libfprint/libfprint && cd libfprint
git checkout v1.94.100 && patch -p1 < fpcmoc-10a5-9924.patch
meson setup build && ninja -C build && sudo ninja -C build install
fprintd-enroll && fprintd-verify
```

The earlier approach from PR #21 (a fallback that accepts the chip's opaque
`identity_type 0x4` token) is kept in
[`../legacy/libfprint-identity-fallback/`](../legacy/libfprint-identity-fallback/).
It works, but it can't tell enrolled fingers apart.

## Credits

- **Terrydaktal**: first working Linux patch, reverse-engineered from the Windows driver
  ([libfprint-fpc-10a5-9924](https://github.com/Terrydaktal/libfprint-fpc-10a5-9924)).
- **tsukasagenesis**: fpcmoc patch with identity fallback (PR #21).
- **Zeno-sole** (lichenggang): upstream MR !611, device id.
- **nikube**: found that the USB reset is the real problem.
- **codethinki**: upstream MR !666 (reset skip, no fallback).
- **mrueg**: pointed to the upstream MRs.
- **westi77**, **DoMaLo**, **drphilth**: EgisTec `1c7a:05aa`. **feraxhp**: FPC `10a5:a920`.
- **colorcube**, **DemoxDev**: early sensor research (#6).
