<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Suspend, hibernate

- **s2idle (S0ix)** works, including resume. The touchscreen comes back after resume
  with the DSDT fix.
- **S3 deep sleep** isn't available. The `\_S3` package is in the DSDT but gated behind
  `Name (SS3, Zero)`. If you force `SS3 = One`, S3 shows up, but entering it hard-freezes
  the machine. Arrow Lake-H is S0ix-only, and Windows has no S3 on this platform either.
- **Hibernate (S4)** and suspend-then-hibernate work. That's the way to get very low
  standby drain.

Credit: **tsukasagenesis** (S3 investigation on BIOS 1.16).

The MagicBook X14 (AMD) from #12 is a different machine and isn't covered here.
