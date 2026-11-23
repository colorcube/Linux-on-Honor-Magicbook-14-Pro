# Fedora libfprint spec with one patch for the HONOR MagicBook Pro 14 (FMB-P)
# fingerprint sensor 10a5:9924. Based on Fedora rpms/libfprint (f44).
# https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro

Name:           libfprint

Version:        1.94.100
Release:        1.1.honor%{?dist}
Summary:        Toolkit for fingerprint scanner

# Automatically converted from old format: LGPLv2+ - review is highly recommended.
# Most of the code is LGPL-2.1-or-later
# libfprint/nbis is NIST-PD
License:        LGPL-2.1-or-later AND NIST-PD
URL:            http://www.freedesktop.org/wiki/Software/fprint/libfprint
Source0:        https://gitlab.freedesktop.org/libfprint/libfprint/-/archive/v%{version}/libfprint-v%{version}.tar.gz
# HONOR MagicBook Pro 14 (FMB-P): FPC 10a5:9924 support, upstream MR !666
# https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/666
# (codethinki; device id from !611 by Zeno-sole; USB reset finding by nikube)
Patch0:         fpcmoc-10a5-9924.patch

BuildRequires:  meson
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  git
BuildRequires:  openssl-devel
BuildRequires:  pkgconfig(glib-2.0) >= 2.50
BuildRequires:  pkgconfig(gio-2.0) >= 2.44.0
BuildRequires:  pkgconfig(gusb) >= 0.3.0
BuildRequires:  pkgconfig(nss)
BuildRequires:  pkgconfig(pixman-1)
BuildRequires:  gtk-doc
BuildRequires:  libgudev-devel
# For the udev.pc to install the rules
BuildRequires:  systemd
BuildRequires:  gobject-introspection-devel
# For internal CI tests; umockdev 0.13.2 has an important locking fix
BuildRequires:  python3-cairo python3-gobject cairo-devel
BuildRequires:  umockdev >= 0.13.2

%description
libfprint offers support for consumer fingerprint reader devices.

%package        devel
Summary:        Development files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description    devel
The %{name}-devel package contains libraries and header files for
developing applications that use %{name}.

%package        tests
Summary:        Tests for the %{name} package
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description tests
The %{name}-tests package contains tests that can be used to verify
the functionality of the installed %{name} package.

%prep
%autosetup -S git -n libfprint-v%{version}

%build
# Include the virtual image driver for integration tests
%meson -Ddrivers=all
%meson_build

%install
%meson_install

%ldconfig_scriptlets

# TODO: The test can't run with the recent pygobject3.52.
# So, skip the test until the issue of pygobject is fixed.

%files
%license COPYING
%doc NEWS THANKS AUTHORS README.md
%{_libdir}/*.so.*
%{_libdir}/girepository-1.0/*.typelib
%{_udevhwdbdir}/60-autosuspend-libfprint-2.hwdb
%{_udevrulesdir}/70-libfprint-2.rules
%{_datadir}/metainfo/org.freedesktop.libfprint.metainfo.xml

%files devel
%doc HACKING.md
%{_includedir}/*
%{_libdir}/*.so
%{_libdir}/pkgconfig/%{name}-2.pc
%{_datadir}/gir-1.0/*.gir
%{_datadir}/gtk-doc/html/libfprint-2/

%files tests
%{_libexecdir}/installed-tests/libfprint-2/
%{_datadir}/installed-tests/libfprint-2/

%changelog
* Mon Nov 23 2026 René Fritz <13253123+colorcube@users.noreply.github.com> - 1.94.100-1.1.honor
- Add FPC 10a5:9924 support (libfprint MR !666) for the HONOR MagicBook Pro 14 (FMB-P)

* Tue Aug 11 2026 Kate Hsuan <hpa@redhat.com> - 1.94.100-1
- Update to the upstream version 1.94.100 (rhbz#2506519)
- (older entries: see Fedora rpms/libfprint)
