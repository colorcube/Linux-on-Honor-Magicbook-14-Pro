<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Contributors

This repository collects the work of many people. Some contributed code here directly.
Many more found the causes, wrote patches elsewhere, tested and reported in issues,
forks and upstream projects. **Thank you all!**

If you are missing from this list, or something is attributed incorrectly, or you do
**not** want your work included here, please open an issue or PR. We'll fix it right
away.

## Code and fixes in this repository

| Who | What | Where |
|---|---|---|
| [@drphilth](https://github.com/drphilth) (Philip Walsh) | DSDT root-cause analysis, minimal DSDT patch and build pipeline, touchscreen PowerResource, Chinese-SKU derivation, keyboard backlight driver, udev rules, battery service, Ubuntu packages | `dsdt/`, `fixes/honor-fmbp-kbdlight/`, `fixes/udev/`, `fixes/battery/`, `docs/dsdt-root-cause.md`, [honor-magicbook-pro-14-ubuntu](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu) |
| [@denis-bb](https://github.com/denis-bb) | first public DSDT fix and stock disassemblies, HDR EDID, many tests | [honor-fmb-p-dsdt](https://github.com/denis-bb/honor-fmb-p-dsdt), #1 #9 #14 #16 |
| [@tsukasagenesis](https://github.com/tsukasagenesis) | installer, fan RPM driver, Fn-key map, libfprint fallback, battery preset mechanism, S3 analysis, ACPI notes | PR #21, `install.sh`, `fixes/honor-fmbp-hwmon/`, `fixes/huawei-wmi-dkms/`, `docs/acpi-dsm-notes.md` |
| [@nikube](https://github.com/nikube) | root cause and hwdb fix for the touchpad ghost brightness keys, libfprint USB-reset finding, status overview | `fixes/udev/61-honor-fmbp-touchpad.hwdb`, #3 #10 #21 |
| [@codethinki](https://github.com/codethinki) | DSDT-only touchscreen fix, libfprint MR !666 | denis-bb PR #10, `fixes/libfprint/` |
| [@egormanga](https://github.com/egormanga) (Egor Vorontsov) | FMB-P key assignments in Huawei-WMI | [Huawei-WMI#93](https://github.com/aymanbagabas/Huawei-WMI/pull/93) |
| [@colorcube](https://github.com/colorcube) (René Fritz) | maintainer, issues, testing on BIOS 1.13 / Fedora, `f8` scancode, diag tools | everything else |

## Upstream fixes

| Who | What |
|---|---|
| [@Cryolitia](https://github.com/Cryolitia) (deepin / AOSC OS) | atkbd keyboard quirk (6.19) and ACPICA NULL-deref fix (6.19 / 6.18.3), #1 #11 |
| Zeno-sole (lichenggang, UnionTech) | libfprint MR !611, FPC `10a5:9924` id |
| [@aymanbagabas](https://github.com/aymanbagabas) (Ayman Bagabas) | the `huawei-wmi` driver |
| sermart1234, mpi3d, larax2do | `\SBCM` decode and smart-charging notes in [Huawei-WMI#55](https://github.com/aymanbagabas/Huawei-WMI/issues/55) |

## Research, analysis and solutions in issues

| Who | Topic |
|---|---|
| [@kv9898](https://github.com/kv9898) (Dianyi Yang) | touchscreen root cause (misplaced `PTPL` power resource), matebook-applet hint (#5, #10) |
| [@Obstacleee](https://github.com/Obstacleee) (Lucas Delon) | touchscreen GPIO lines 108/130 (#20) |
| [@DemoxDev](https://github.com/DemoxDev) | dynamic touchscreen inhibit, fingerprint and DSDT tests (#5, #6, #11) |
| [@NOREIED](https://github.com/NOREIED) | Chinese-SKU touchscreen DSDT |
| [@Terrydaktal](https://github.com/Terrydaktal) | first working libfprint patch for `10a5:9924` |
| [@Atom-Py](https://github.com/Atom-Py) (Vladislav) | power-button EC/FADT analysis (#8) |
| [@n7n8](https://github.com/n7n8) | EC charge-threshold preset bytes (#17) |
| [@yhshzh](https://github.com/yhshzh) | battery mode verification (Chinese, BIOS 1.16), performance mode / DPTF / 50 W clamp analysis, [honor-fmbp-perf](https://github.com/yhshzh/honor-fmbp-perf) daemon (#10, #27) |
| [@sujoshua](https://github.com/sujoshua) (joshua) | touchpad BetterLife/Goodix hypothesis (#3) |
| [@Osama-A-Abbas](https://github.com/Osama-A-Abbas) (Osama Abbas) | GNOME-layer brightness analysis (#3) |
| jean bzh (Fedora forum) | found the touchpad ghost device and wrote the first udev rule |
| Foued (Fedora forum) | fan control observations |
| [@kxygk](https://github.com/kxygk) (George Kontsevich) | Ubuntu installation, live USB / ISO remastering, Chinese units (#13, #14, #15) |
| [@ishtarov](https://github.com/ishtarov) (Igor Shtarov) | Ubuntu ISO rebuild (#13) |
| [@westi77](https://github.com/westi77) (Bulat) | EgisTec `1c7a:05aa` fingerprint guide |
| [@DoMaLo](https://github.com/DoMaLo) (Dmitriy Gushchin) | EgisTec `1c7a:05aa` fingerprint script |
| [@feraxhp](https://github.com/feraxhp) | FPC `10a5:a920` fingerprint fork |
| [@mrueg](https://github.com/mrueg) (Manuel Rüger) | libfprint upstream tracking, BIOS 1.16/1.17 binary analysis (1.17 fixes NFC0) (#22) |
| [@BargainSir](https://github.com/BargainSir) | factory colour calibration data (#19) |
| [@domakira](https://github.com/domakira) (Akhil Domichen) | BIOS 1.16 (#18, #22) |
| [@mikoff](https://github.com/mikoff) | BIOS 20260509 (#22) |
| [@Nodzone](https://github.com/Nodzone) | Chinese unit with global DSDT (#15) |
| [@Ibim243](https://github.com/Ibim243) | Wi-Fi warm-reboot crash report (#26) |
| [@fan-nature](https://github.com/fan-nature) | Windows-side charge-limit limitation (#25) |
| [@EvernightFedora](https://github.com/EvernightFedora) | Evernight Vista (Fedora-based) with the DSDT in the kernel, COPR packages (#23, #24) |
| [@inko32](https://github.com/inko32), [@lcrhf1999](https://github.com/lcrhf1999), [@purevtegsh](https://github.com/purevtegsh), [@feraxhp](https://github.com/feraxhp), [@naveenjohnsonv](https://github.com/naveenjohnsonv) | testing and reports |

## Using AI assistants

Several contributions say they were developed or written with an LLM and then
validated on real hardware. The restructuring of this repository in November 2026 was
done with Claude (Anthropic), and every change was tested on the maintainer's machine.
