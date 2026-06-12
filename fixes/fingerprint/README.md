# Fingerprint reader (FPC `10a5:9924`) — working enroll + verify

Resolves issue #6.

## Summary
The power-button fingerprint sensor is an FPC match-on-chip device,
`10a5:9924` ("FPC L:2407 FW:3334151"). It is **not** in upstream `libfprint`,
but it speaks the same protocol as the already-supported `fpcmoc` family
(`0x9524`, `0x9B24`, `0xC844`, …). Two small changes make it work:

1. **Register the USB id** `10A5:9924` in the `fpcmoc` driver's id table.
2. **Handle this firmware's identify response.** On a match it returns an
   opaque, stable, per-enrollment token with `identity_type == 0x4` instead of
   echoing the bound identity, so libfprint's host-side `fp_print_equal()` check
   fails and every verify returns *no-match*. Since the match is performed on
   the secure element (status `0` + a valid token is only returned for a genuine
   enrolled finger), the driver trusts that decision for the `0x4` form.
   Verified behaviour: enrolled finger matches reliably; different fingers are
   rejected (the chip returns an empty identity for non-matches).

See `fmbp-fpc-9924.patch` (against libfprint 1.94.x). `PKGBUILD.example` shows
how it was packaged on Arch/CachyOS.

## Build
```sh
git clone https://gitlab.freedesktop.org/libfprint/libfprint
cd libfprint && patch -p1 < /path/to/fmbp-fpc-9924.patch
meson setup build -Ddrivers=fpcmoc && ninja -C build
# install, then enroll:  fprintd-enroll -f right-index-finger
```

## Caveats
- Match reliability depends on enrollment quality (consistent, centred, firm
  placement). Enroll a single finger carefully for best results.
- Because the host can't reconstruct the opaque token, multi-finger *identify*
  can't tell which enrolled finger matched (fine for login/verify, which only
  asks "is this finger enrolled?").
- This is a pragmatic driver-level workaround; upstreaming would ideally decode
  the `0x4` identity format properly.
