<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Legacy: libfprint identity fallback (PR #21)

Superseded by [`../../libfprint/`](../../libfprint/) (upstream MR !666). This patch accepts the
sensor's opaque `identity_type 0x4` token as a match. That token only appears because of
the USB reset that MR !666 removes. With the fallback, identify can't tell enrolled fingers
apart. Kept for reference. Author: tsukasagenesis.
