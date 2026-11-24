# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 René Fritz and the Linux-on-Honor-Magicbook-14-Pro contributors
# Fedora packages for the HONOR MagicBook Pro 14 2025 (FMB-P) fixes.
# https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro

%global hwmon_ver    1.0
%global kbdlight_ver 1.1
%global wmi_ver      7.3.1

Name:           honor-fmbp
Version:        1.0.6
Release:        1%{?dist}
Summary:        Linux support for the HONOR MagicBook Pro 14 2025 (FMB-P)
License:        GPL-2.0-or-later AND GPL-2.0-only AND CC-BY-4.0 AND LicenseRef-OEM-firmware-derived
URL:            https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros

%description
Fixes, drivers and configuration for the HONOR MagicBook Pro 14 2025 (FMB-P):
corrected DSDT, udev/hwdb quirks, Fn-key, fan and keyboard-backlight drivers
and a charge-limit service. Install the metapackage honor-magicbook-pro-14.

# --------------------------------------------------------------------------
%package -n honor-magicbook-pro-14
Summary:        Metapackage: everything for the HONOR MagicBook Pro 14 2025 (FMB-P)
Requires:       %{name}-dsdt = %{version}-%{release}
Requires:       %{name}-udev = %{version}-%{release}
Requires:       %{name}-battery = %{version}-%{release}
Requires:       %{name}-tools = %{version}-%{release}
Requires:       %{name}-hwmon-dkms = %{version}-%{release}
Requires:       %{name}-kbdlight-dkms = %{version}-%{release}
Requires:       huawei-wmi-fmbp-dkms = %{version}-%{release}
Recommends:     libfprint >= 1.94.100-1.1.honor

%description -n honor-magicbook-pro-14
Pulls in all fixes for the HONOR MagicBook Pro 14 2025 (FMB-P). The patched
libfprint for the FPC 10a5:9924 fingerprint sensor is recommended.

%package dsdt
Summary:        Corrected ACPI DSDT for the HONOR MagicBook Pro 14 (FMB-P)
License:        LicenseRef-OEM-firmware-derived AND GPL-2.0-only
Requires:       dracut
Requires:       coreutils

%description dsdt
Corrected DSDT (NFC0 load-abort fix, touchscreen PowerResource) loaded as an
early-initramfs ACPI table override via dracut. Selects the global or Chinese
table from the firmware at install time. Secure Boot must be disabled.

%package udev
Summary:        udev/hwdb quirks for the HONOR MagicBook Pro 14 (FMB-P)
Requires:       systemd-udev

%description udev
Stops the touchpad's ghost brightness keys, silences meaningless EC
scancodes (e078, f8) and inhibits the touchscreen's bogus second HID
interface.

%package battery
Summary:        Charge-limit service for the HONOR MagicBook Pro 14 (FMB-P)
%{?systemd_requires}

%description battery
Applies the charge threshold from /etc/default/honor-fmbp-battery at boot.
The EC only enforces the presets 40 70, 70 90 and 95 100.

%package tools
Summary:        Diagnostic tools for the HONOR MagicBook Pro 14 (FMB-P)

%description tools
honor-fmbp-diag (status report for bug reports), honor-fmbp-battery-probe
and honor-fmbp-touchscreen-toggle.

%package hwmon-dkms
Summary:        Fan RPM hwmon driver for the HONOR MagicBook Pro 14 (FMB-P) (DKMS)
License:        GPL-2.0-only
Requires:       dkms
Requires(post): %{name}-tools = %{version}-%{release}
Requires(preun): %{name}-tools = %{version}-%{release}
Requires:       kernel-devel-matched

%description hwmon-dkms
Exposes the two EC fan tachometers as a hwmon device (sensors).

%package kbdlight-dkms
Summary:        Keyboard backlight driver for the HONOR MagicBook Pro 14 (FMB-P) (DKMS)
License:        GPL-2.0-only
Requires:       dkms
Requires(post): %{name}-tools = %{version}-%{release}
Requires(preun): %{name}-tools = %{version}-%{release}
Requires:       kernel-devel-matched

%description kbdlight-dkms
Registers the keyboard backlight as LED huawei::kbd_backlight.

%package -n huawei-wmi-fmbp-dkms
Summary:        huawei-wmi with the HONOR MagicBook Pro 14 (FMB-P) hotkey map (DKMS)
License:        GPL-2.0-only
Requires:       dkms
Requires(post): %{name}-tools = %{version}-%{release}
Requires(preun): %{name}-tools = %{version}-%{release}
Requires:       kernel-devel-matched

%description -n huawei-wmi-fmbp-dkms
The kernel's huawei-wmi driver plus the FMB-P hotkey codes (touchpad toggle,
camera, Fn+P, Fn+R, keyboard backlight). Overrides the in-tree module.

# --------------------------------------------------------------------------
%prep
%autosetup -n Linux-on-Honor-Magicbook-14-Pro-%{version}

%build
# nothing to build: DKMS builds the modules on the target, the DSDT is prebuilt

%install
# dsdt
install -Dm644 dsdt/prebuilt/dsdt.global.aml  %{buildroot}%{_datadir}/%{name}/dsdt/dsdt.global.aml
install -Dm644 dsdt/prebuilt/dsdt.chinese.aml %{buildroot}%{_datadir}/%{name}/dsdt/dsdt.chinese.aml
install -Dm644 dsdt/prebuilt/fix.global.patch %{buildroot}%{_datadir}/%{name}/dsdt/fix.global.patch
install -Dm755 dsdt/honor-fmbp-dsdt-select    %{buildroot}%{_sbindir}/honor-fmbp-dsdt-select
install -Dm644 dsdt/initramfs/dracut-10-honor-fmbp-dsdt.conf %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/10-honor-fmbp-dsdt.conf
install -d %{buildroot}%{_prefix}/lib/%{name}/acpi
touch %{buildroot}%{_prefix}/lib/%{name}/acpi/dsdt.aml
# udev
install -Dm644 fixes/udev/61-honor-fmbp-keyboard.hwdb  %{buildroot}%{_udevhwdbdir}/61-honor-fmbp-keyboard.hwdb
install -Dm644 fixes/udev/61-honor-fmbp-touchpad.hwdb  %{buildroot}%{_udevhwdbdir}/61-honor-fmbp-touchpad.hwdb
install -Dm644 fixes/udev/99-honor-fmbp-touchscreen.rules        %{buildroot}%{_udevrulesdir}/99-honor-fmbp-touchscreen.rules
install -Dm644 fixes/udev/99-honor-fmbp-touchscreen-toggle.rules %{buildroot}%{_udevrulesdir}/99-honor-fmbp-touchscreen-toggle.rules
# battery
install -Dm644 fixes/battery/honor-fmbp-battery.service %{buildroot}%{_unitdir}/honor-fmbp-battery.service
install -Dm644 fixes/battery/honor-fmbp-battery.default %{buildroot}%{_sysconfdir}/default/honor-fmbp-battery
install -d %{buildroot}%{_presetdir}
echo "enable honor-fmbp-battery.service" > %{buildroot}%{_presetdir}/50-honor-fmbp-battery.preset
# tools
install -Dm755 tools/honor-fmbp-diag               %{buildroot}%{_bindir}/honor-fmbp-diag
install -Dm755 tools/honor-fmbp-battery-probe      %{buildroot}%{_sbindir}/honor-fmbp-battery-probe
install -Dm755 tools/honor-fmbp-touchscreen-toggle %{buildroot}%{_bindir}/honor-fmbp-touchscreen-toggle
install -Dm755 packaging/fedora/honor-fmbp/honor-fmbp-dkms %{buildroot}%{_libexecdir}/honor-fmbp/honor-fmbp-dkms
# dkms sources
for m in honor-fmbp-hwmon:%{hwmon_ver} honor-fmbp-kbdlight:%{kbdlight_ver} huawei-wmi-dkms:%{wmi_ver}; do
    dir=${m%%:*}; ver=${m##*:}
    name=$(sed -n 's/^PACKAGE_NAME="\(.*\)"/\1/p' fixes/$dir/dkms.conf)
    test "$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' fixes/$dir/dkms.conf)" = "$ver"
    install -d %{buildroot}%{_usrsrc}/$name-$ver
    install -m644 fixes/$dir/*.c fixes/$dir/Makefile fixes/$dir/dkms.conf %{buildroot}%{_usrsrc}/$name-$ver/
done
install -Dm644 fixes/honor-fmbp-hwmon/honor-fmbp-hwmon.conf       %{buildroot}%{_modulesloaddir}/honor-fmbp-hwmon.conf
install -Dm644 fixes/honor-fmbp-kbdlight/honor-fmbp-kbdlight.conf %{buildroot}%{_modulesloaddir}/honor-fmbp-kbdlight.conf

# --------------------------------------------------------------------------
%post dsdt
%{_sbindir}/honor-fmbp-dsdt-select || :
if grep -qsE '^[[:space:]]*acpi[[:space:]]+.*\.aml' /etc/grub.d/40_custom /boot/grub2/custom.cfg; then
    echo "honor-fmbp-dsdt: WARNING: a GRUB 'acpi ... .aml' line loads another DSDT and overrides this one." >&2
    echo "honor-fmbp-dsdt: remove it from /etc/grub.d/40_custom (or custom.cfg) and run grub2-mkconfig." >&2
fi

%postun dsdt
if [ "$1" -eq 0 ] && command -v dracut >/dev/null; then
    dracut --force --regenerate-all >/dev/null 2>&1 || :
fi

%post udev
systemd-hwdb update >/dev/null 2>&1 || :
udevadm control --reload >/dev/null 2>&1 || :
udevadm trigger -s input >/dev/null 2>&1 || :

%postun udev
systemd-hwdb update >/dev/null 2>&1 || :
udevadm control --reload >/dev/null 2>&1 || :

%post battery
%systemd_post honor-fmbp-battery.service

%preun battery
%systemd_preun honor-fmbp-battery.service

%postun battery
%systemd_postun_with_restart honor-fmbp-battery.service

# honor-fmbp-dkms only rebuilds when the sources changed (Fedora's DKMS regenerates all
# initramfs images after every install); the DKMS version is stable across updates,
# so modules are only removed on erase
%define dkms_post() %{_libexecdir}/honor-fmbp/honor-fmbp-dkms install %1 %2 || :
%define dkms_preun() if [ "$1" -eq 0 ]; then %{_libexecdir}/honor-fmbp/honor-fmbp-dkms remove %1 %2 || :; fi

%post hwmon-dkms
%dkms_post honor-fmbp-hwmon %{hwmon_ver}
modprobe honor-fmbp-hwmon >/dev/null 2>&1 || :
%preun hwmon-dkms
%dkms_preun honor-fmbp-hwmon %{hwmon_ver}

%post kbdlight-dkms
%dkms_post honor-fmbp-kbdlight %{kbdlight_ver}
modprobe honor-fmbp-kbdlight >/dev/null 2>&1 || :
%preun kbdlight-dkms
%dkms_preun honor-fmbp-kbdlight %{kbdlight_ver}

%post -n huawei-wmi-fmbp-dkms
%dkms_post huawei-wmi-fmbp %{wmi_ver}
%preun -n huawei-wmi-fmbp-dkms
%dkms_preun huawei-wmi-fmbp %{wmi_ver}

# --------------------------------------------------------------------------
%files -n honor-magicbook-pro-14
%license LICENSE
%doc README.md CONTRIBUTORS.md docs/testing.md

%files dsdt
%license LICENSES/LicenseRef-OEM-firmware-derived.txt LICENSES/GPL-2.0-only.txt
%doc dsdt/README.md docs/dsdt-root-cause.md
%{_datadir}/%{name}/
%{_sbindir}/honor-fmbp-dsdt-select
%{_prefix}/lib/dracut/dracut.conf.d/10-honor-fmbp-dsdt.conf
%dir %{_prefix}/lib/%{name}
%dir %{_prefix}/lib/%{name}/acpi
%ghost %{_prefix}/lib/%{name}/acpi/dsdt.aml

%files udev
%license LICENSES/GPL-2.0-or-later.txt LICENSES/GPL-2.0-only.txt
%doc fixes/udev/README.md
%{_udevhwdbdir}/61-honor-fmbp-keyboard.hwdb
%{_udevhwdbdir}/61-honor-fmbp-touchpad.hwdb
%{_udevrulesdir}/99-honor-fmbp-touchscreen.rules
%{_udevrulesdir}/99-honor-fmbp-touchscreen-toggle.rules

%files battery
%license LICENSES/GPL-2.0-only.txt
%doc fixes/battery/README.md
%{_unitdir}/honor-fmbp-battery.service
%{_presetdir}/50-honor-fmbp-battery.preset
%config(noreplace) %{_sysconfdir}/default/honor-fmbp-battery

%files tools
%license LICENSES/GPL-2.0-or-later.txt LICENSES/GPL-2.0-only.txt
%{_bindir}/honor-fmbp-diag
%{_bindir}/honor-fmbp-touchscreen-toggle
%{_sbindir}/honor-fmbp-battery-probe
%dir %{_libexecdir}/honor-fmbp
%{_libexecdir}/honor-fmbp/honor-fmbp-dkms

%files hwmon-dkms
%license LICENSES/GPL-2.0-only.txt
%{_usrsrc}/honor-fmbp-hwmon-%{hwmon_ver}/
%{_modulesloaddir}/honor-fmbp-hwmon.conf

%files kbdlight-dkms
%license LICENSES/GPL-2.0-only.txt
%{_usrsrc}/honor-fmbp-kbdlight-%{kbdlight_ver}/
%{_modulesloaddir}/honor-fmbp-kbdlight.conf

%files -n huawei-wmi-fmbp-dkms
%license LICENSES/GPL-2.0-only.txt
%{_usrsrc}/huawei-wmi-fmbp-%{wmi_ver}/

%changelog
* Tue Nov 24 2026 René Fritz <13253123+colorcube@users.noreply.github.com> - 1.0.6-1
- kbdlight: report Fn+Space level changes made by the EC to the desktop
  (brightness_hw_changed), so the OSD and slider follow (#38)

* Tue Nov 24 2026 René Fritz <13253123+colorcube@users.noreply.github.com> - 1.0.5-1
- huawei-wmi: ignore the keyboard-backlight notifications 0x2b1-0x2b4 (the EC
  cycles the level itself; as key presses the desktop stepped a second time) and
  the EC notifications 0x2e7/0x2e8
- Fedora 45 builds

* Tue Nov 24 2026 René Fritz <13253123+colorcube@users.noreply.github.com> - 1.0.4-1
- Faster updates: DKMS modules are only rebuilt when their sources changed, and the
  initramfs is only regenerated when the selected DSDT changed
- Long steps (DKMS build, initramfs rebuild) are announced on the terminal

* Tue Nov 24 2026 René Fritz <13253123+colorcube@users.noreply.github.com> - 1.0.3-1
- udev: also map the touchpad ghost device's mic-mute usage (0xff010001) to reserved;
  it got stuck after resume and toggled the microphone (F7 comes via huawei-wmi)

* Tue Nov 24 2026 René Fritz <13253123+colorcube@users.noreply.github.com> - 1.0.2-1
- .copr/Makefile: accept the absolute spec path COPR passes (1.0.1 failed to build)

* Tue Nov 24 2026 René Fritz <13253123+colorcube@users.noreply.github.com> - 1.0.1-1
- honor-fmbp-diag also lists the packaged dracut config and the selected DSDT
- Built automatically by COPR from the git tag (.copr/Makefile)

* Mon Nov 23 2026 René Fritz <13253123+colorcube@users.noreply.github.com> - 1.0.0-1
- Initial package
