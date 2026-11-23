# Fixes & findings — Honor MagicBook (Pro) 14 (FMB-P)

Tested on a global FMB-P, **BIOS 1.16**, Core Ultra 9 285H (Arrow Lake-H),
CachyOS, kernel 7.0 (and LTS 6.18). The patched DSDT
([denis-bb/honor-fmb-p-dsdt](https://github.com/denis-bb/honor-fmb-p-dsdt))
is assumed to be applied first — it's the prerequisite for most of the below.

| Area | Status | Folder / notes |
|------|--------|----------------|
| Touchscreen (FTSC1000) | ✅ working | [`touchscreen/`](touchscreen/) — GPIO power + `acpi_call` + service (issue #5/#20) |
| Fn keys | ✅ working | [`fn-keys/`](fn-keys/) — patched `huawei-wmi` + hwdb (issue #4) |
| Fan RPM readout | ✅ working | [`fan/`](fan/) — `honor-fmbp-hwmon` hwmon module (issue #7) |
| Fingerprint (FPC 10a5:9924) | ✅ working | [`fingerprint/`](fingerprint/) — `libfprint` fpcmoc patch (issue #6) |
| Battery charge thresholds | ✅ working | [`battery/`](battery/) — honoured by EC; persist service (issue #10/#17) |
| Caps-Lock LED | ✅ working | kernel ≥ 7.0, no tweak needed (issue #9) |
| Mic-mute key LED | ✅ working | `platform::micmute` LED toggles correctly (issue #9) |
| Performance profiles | ✅ working | `power-profiles-daemon` switches CPU EPP (Performance/Balanced/Power-Saver); KDE selector works. Firmware DPTF `platform_profile` is absent ("placeholder"), but Fn+P still switches the EC platform mode. |
| Suspend (s2idle) | ✅ working | only supported suspend; see S3 finding below |
| Hibernate / suspend-then-hibernate | ✅ working | S4 hibernate works (e.g. encrypted swapfile + `resume=`); use it for low standby drain since S3 is unavailable |

For *why* each shimmed device needs a shim — the annotated ACPI `_DSM` /
device-init traces (touchscreen, fingerprint, EC) and the `_OSI`/`OSYS`
Windows-gating that explains the "works on Windows out of the box" gap — see
[`acpi-dsm-notes.md`](acpi-dsm-notes.md).

## Findings (hardware/firmware limits — not fixable in Linux)

- **No S3 deep sleep.** The DSDT contains a valid `\_S3` package but it's gated
  behind `Name (SS3, Zero)` which the firmware never sets, so only s2idle is
  offered. Forcing it (override `SS3 = One`) *does* register S3, but entering it
  **hard-freezes** the machine (no resume). This is expected: Intel removed S3
  from 11th-gen onward, and Arrow Lake-H implements only S0ix / Modern Standby —
  **Windows has no S3 on this platform either.** Use hibernate for long idle.
- **No IR camera / face unlock.** The 2025 FMB-P ships a plain 1080p RGB webcam;
  the glossy strip by the lens only looks like it houses IR emitters. (Windows
  Hello face is a 2026-model feature.) Fingerprint is the biometric option.

---

*These fixes and notes were developed and documented with the help of an LLM,
then validated on real hardware. Treat the out-of-tree modules/patches as
"works for me today" starting points; upstreaming the relevant bits (huawei-wmi
keymap, libfprint id + 0x4 identity handling, a proper touchscreen DSDT power
resource) is the better long-term path.*
