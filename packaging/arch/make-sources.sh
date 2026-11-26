#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 the Linux-on-Honor-Magicbook-14-Pro contributors
#
# Prepare the exact sources used by the Arch recipes, for a local build or a
# release.
#
#   ./packaging/arch/make-sources.sh 1.0.9 /tmp/sources
#
# Two files are written into the output directory:
#
#   honor-fmbp-<version>-arch.tar      the sources of the hardware packages
#   fpcmoc-10a5-9924-<version>.patch   the patch for the libfprint package
#
# The tarball is reproducible: the same sources always produce the same bytes,
# so the checksums in the recipes stay valid. Publish both files as release
# assets and update the recipes with their BLAKE2 checksums.
set -euo pipefail

if (( $# != 2 )) || [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Usage: %s VERSION OUTPUT-DIRECTORY\n' "$0" >&2
    exit 2
fi

version=$1
mkdir -p -- "$2"
out=$(cd -- "$2" && pwd)

# The sources live in the repository root, two levels above this script.
cd -- "$(dirname -- "$0")/../.."

# A stable collation keeps the archive order the same on every machine.
export LC_ALL=C

# Stage inside the output directory, so the final move stays on one filesystem.
stage=$(mktemp -d -- "$out/.arch-sources.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT

# The exact files the recipes unpack and install. The recipes themselves stay
# out of the archive: updating their checksums must not change the tarball.
sources=(
    LICENSES/{CC-BY-4.0,GPL-2.0-only,GPL-2.0-or-later,LicenseRef-OEM-firmware-derived}.txt
    docs/install/arch.md
    dsdt/build.sh dsdt/honor-fmbp-dsdt-select
    dsdt/initramfs/mkinitcpio-honor-fmbp.conf
    dsdt/patches/inject-touchscreen-power.py
    dsdt/prebuilt/dsdt.{chinese,global}.aml dsdt/prebuilt/fix.global.patch
    fixes/battery/{99-honor-fmbp-battery.rules,honor-fmbp-battery.default,honor-fmbp-battery.service}
    fixes/edid/{README.md,edp-hdr.bin,grub-honor-fmbp-edid.cfg,mkinitcpio-honor-fmbp-edid.conf}
    fixes/honor-fmbp-hwmon/{dkms.conf,honor-fmbp-hwmon.c,honor-fmbp-hwmon.conf,Makefile}
    fixes/honor-fmbp-kbdlight/{dkms.conf,honor-fmbp-kbdlight.c,honor-fmbp-kbdlight.conf,Makefile}
    fixes/huawei-wmi-dkms/{dkms.conf,huawei-wmi.c,Makefile}
    fixes/udev/{61-honor-fmbp-keyboard.hwdb,61-honor-fmbp-touchpad.hwdb,99-honor-fmbp-touchscreen.rules,99-honor-fmbp-touchscreen-toggle.rules}
    tools/honor-fmbp-{battery-probe,diag,touchscreen-toggle}
)

archive="honor-fmbp-$version-arch.tar"
patch="fpcmoc-10a5-9924-$version.patch"

# A symlink would pull foreign content into the archive and change its
# checksum, so only regular files are allowed here.
for source in "${sources[@]}"; do
    if [[ ! -f $source || -L $source ]]; then
        printf 'Expected a regular source file: %s\n' "$source" >&2
        exit 1
    fi
done

# Reproducible tarball: no timestamps, no owner names, fixed modes, no hard
# links. TAR_OPTIONS is dropped so the environment cannot change the result.
# The recipes set the modes again when they install the files.
env -u TAR_OPTIONS tar \
    --format=ustar \
    --mtime='@0' \
    --owner=0 --group=0 --numeric-owner \
    --mode=0644 \
    --hard-dereference \
    --transform="s,^,honor-fmbp-$version/," \
    -cf "$stage/$archive" \
    -- "${sources[@]}"

# The libfprint patch is a release asset of its own: it patches the upstream
# libfprint sources.
install -m644 fixes/libfprint/fpcmoc-10a5-9924.patch "$stage/$patch"

mv -- "$stage/$archive" "$stage/$patch" "$out/"
