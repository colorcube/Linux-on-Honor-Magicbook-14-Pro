# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 René Fritz and the Linux-on-Honor-Magicbook-14-Pro contributors
# Fedora package for yhshzh's honor-fmbp-perf (performance mode daemon for the
# HONOR MagicBook Pro 14 2025, FMB-P). Upstream: https://github.com/yhshzh/honor-fmbp-perf

Name:           honor-fmbp-perf
Version:        0.1.0
Release:        1%{?dist}
Summary:        High Performance Mode daemon for the HONOR MagicBook Pro 14 (FMB-P)
License:        GPL-2.0-or-later
URL:            https://github.com/yhshzh/honor-fmbp-perf
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
BuildArch:      noarch
BuildRequires:  python3
BuildRequires:  systemd-rpm-macros
Requires:       python3
Requires:       thermald
%{?systemd_requires}
Recommends:     libnotify

%description
Interim userspace daemon (honor-perfd) and CLI (honor-perf) for the High Performance
Mode of the HONOR MagicBook Pro 14 2025 (FMB-P), until huawei-wmi gets
platform_profile support and thermald handles imok and the PL2 AP Policy:
switches the EC mode via huawei-wmi (\GTUB/\STUB), syncs PL2 from the Intel DTT
DataVault, sends the DTT imok keep-alive while thermald runs (lifting the 50 W
clamp), sets EPP 64 on AC balanced and notifies on Fn+P. Works with
thermald --adaptive (Fedora's default). Written by yhshzh.

%prep
%autosetup -n %{name}-%{version}

%build
# pure Python, nothing to build

%install
install -Dm755 honor-perfd.py %{buildroot}%{_libexecdir}/honor-perfd
install -Dm755 honor-perf.py  %{buildroot}%{_bindir}/honor-perf
install -Dm644 honor-perf.service %{buildroot}%{_unitdir}/honor-perf.service
sed -i 's#^ExecStart=.*#ExecStart=%{_libexecdir}/honor-perfd#' %{buildroot}%{_unitdir}/honor-perf.service
install -Dm644 honor-perf.default %{buildroot}%{_sysconfdir}/default/honor-perf
install -d %{buildroot}%{_presetdir}
echo "enable honor-perf.service" > %{buildroot}%{_presetdir}/50-honor-perf.preset

%check
%{python3} test_honor_perf.py

%post
%systemd_post honor-perf.service

%preun
%systemd_preun honor-perf.service

%postun
%systemd_postun_with_restart honor-perf.service

%files
%license LICENSE
%doc README.md
%{_libexecdir}/honor-perfd
%{_bindir}/honor-perf
%{_unitdir}/honor-perf.service
%{_presetdir}/50-honor-perf.preset
%config(noreplace) %{_sysconfdir}/default/honor-perf

%changelog
* Wed Nov 25 2026 René Fritz <13253123+colorcube@users.noreply.github.com> - 0.1.0-1
- Initial package of yhshzh's honor-fmbp-perf v0.1.0
