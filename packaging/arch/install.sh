#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 the Linux-on-Honor-Magicbook-14-Pro contributors
#
# Build and install the Arch packages for the HONOR MagicBook Pro 14 2025 (FMB-P).
#
#   ./packaging/arch/install.sh
#
# The script runs as a regular user: makepkg builds the packages, then a single
# pacman transaction installs them. It asks which optional packages to install,
# detects the fingerprint reader and picks the matching libfprint recipe.
#
# Requirements: base-devel, git, pacman, sudo, an interactive terminal, and the
# kernel headers matching every kernel the DKMS modules should support.
set -euo pipefail

arch_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

fail() { printf '%s\n' "$*" >&2; exit 1; }

# Ask a yes/no question. An empty answer counts as yes.
confirm() {
    local answer
    while true; do
        read -r -p "$1 [Y/n] " answer || fail 'Installation cancelled (end of input).'
        case "${answer,,}" in
            ''|y|yes) return 0 ;;
            n|no) return 1 ;;
            *) printf '%s\n' 'Enter y or n.' >&2 ;;
        esac
    done
}

# USB IDs of the fingerprint readers this installer has a recipe for.
# 10a5:9924 is the FMB-P reader; the other two come from external recipes.
supported_fingerprint_ids='10a5:9924 1c7a:05aa 10a5:a920'

# USB vendors whose devices are the fingerprint sensors of this product line.
# A device from one of them that is not in the supported list is reported to the
# user as a reader we have no recipe for yet. Readers from other vendors stay
# invisible here; "lsusb | grep -i -E '10a5|1c7a'" shows what is attached.
fingerprint_vendors='10a5 1c7a'

# Print the USB IDs of the supported fingerprint readers, one per line.
fingerprint_ids() {
    local device vendor product id
    for device in "${1:-/sys/bus/usb/devices}"/*; do
        [[ -r $device/idVendor && -r $device/idProduct ]] || continue
        read -r vendor < "$device/idVendor" && read -r product < "$device/idProduct" || continue
        id="${vendor,,}:${product,,}"
        case " $supported_fingerprint_ids " in
            *" $id "*) printf '%s\n' "$id" ;;
        esac
    done | sort -u
}

# Print the USB IDs of the detected readers that have no recipe yet, one per line.
unsupported_fingerprint_ids() {
    local device vendor product id
    for device in "${1:-/sys/bus/usb/devices}"/*; do
        [[ -r $device/idVendor && -r $device/idProduct ]] || continue
        read -r vendor < "$device/idVendor" && read -r product < "$device/idProduct" || continue
        id="${vendor,,}:${product,,}"
        case " $fingerprint_vendors " in
            *" ${vendor,,} "*) ;;
            *) continue ;;
        esac
        case " $supported_fingerprint_ids " in
            *" $id "*) continue ;;
        esac
        printf '%s\n' "$id"
    done | sort -u
}

# Print the ID of the reader to install, or nothing when the user skips it.
select_fingerprint() {
    local -a ids=()
    local choice
    mapfile -t ids < <(fingerprint_ids "${1:-}")
    case ${#ids[@]} in
        0)
            # A reader we know but have no recipe for: name it and point to the
            # issue tracker instead of failing the whole installation.
            local -a unknown=()
            mapfile -t unknown < <(unsupported_fingerprint_ids "${1:-}")
            if (( ${#unknown[@]} )); then
                printf '%s\n' \
                    "Detected fingerprint reader ${unknown[*]}, which this installer has no recipe for yet." \
                    'Skipping fingerprint support for now. If your reader should work,' \
                    'please open an issue and mention the USB ID above:' \
                    '  https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/issues' >&2
            else
                printf '%s\n' \
                    'No fingerprint reader detected; skipping fingerprint support.' >&2
            fi
            ;;
        1) printf '%s\n' "${ids[0]}" ;;
        *)
            printf '%s\n' 'Multiple supported readers detected. Select one library:' >&2
            select choice in "${ids[@]}" Skip; do
                case "$choice" in
                    Skip) return 0 ;;
                    '') printf '%s\n' 'Select a listed option.' >&2 ;;
                    *) printf '%s\n' "$choice"; return 0 ;;
                esac
            done
            fail 'Installation cancelled (end of input).'
            ;;
    esac
}

# Build one package recipe and add the resulting archive to the install list.
build_package() {
    local name=$1 recipe=$2 output=$work/output/$1 archive
    shift 2
    mkdir -p -- "$output"

    # PKGDEST keeps the archives inside the build tree; --syncdeps installs the
    # build dependencies of the recipe as the regular user.
    (cd -- "$recipe" && PKGDEST="$output" makepkg --syncdeps "$@")

    local -a archives=("$output/$name"-[0-9]*.pkg.tar.*)
    for archive in "${archives[@]}"; do
        # Skip detached signatures: pacman does not take them as an input.
        [[ -f $archive && $archive != *.sig ]] || continue
        packages+=("$archive")
        return 0
    done
    fail "No package archive produced for $name."
}

main() {
    local work version name fingerprint repo='' recipe='' maintainer=''
    local -a local_packages=() packages=()

    if [[ ${1-} == --help || ${1-} == -h ]]; then
        printf '%s\n' \
            'Usage: ./packaging/arch/install.sh' \
            '' \
            'Interactive script to install the necessary hardware support packages' \
            'for the HONOR MagicBook Pro 14 2025 (FMB-P), so that it works' \
            'properly on Arch Linux.'
        return 0
    fi

    # ---------------------------------------------------------------- checks

    (( $# == 0 )) || fail 'See --help for usage.'
    (( EUID != 0 )) || fail 'Run this script as a regular user, without sudo.'
    [[ -t 0 ]] || fail 'Run this script in an interactive terminal.'

    local cmd
    for cmd in makepkg pacman sudo; do
        command -v "$cmd" >/dev/null || fail "Required command not found: $cmd"
    done

    # ------------------------------------------------------- package selection

    printf '\n==> HONOR MagicBook Pro 14 (FMB-P) Arch Linux Installer\n\n'

    if confirm 'Install the main hardware support package (DSDT, DKMS drivers, udev, battery)?'; then
        local_packages+=(honor-magicbook-pro-14)
    fi

    printf '\n'
    printf 'Details: https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro/blob/main/fixes/edid/README.md\n'
    if confirm 'Install the optional HDR EDID package (honor-fmbp-edid)?'; then
        local_packages+=(honor-fmbp-edid)
    fi

    printf '\n'
    fingerprint=$(select_fingerprint)
    case "$fingerprint" in
        10a5:9924)
            name=honor-fmbp-libfprint
            maintainer='this project and the libfprint MR !666 contributors'
            printf 'Detected fingerprint sensor %s -> %s (maintained by %s)\n' \
                "$fingerprint" "$name" "$maintainer"
            printf 'Source: https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/666\n'
            ;;
        1c7a:05aa)
            name=honor-fmbp-libfprint-sdcp
            repo=https://github.com/drphilth/honor-fmbp-libfprint-sdcp
            recipe=arch
            maintainer=drphilth
            ;;
        10a5:a920)
            name=libfprint-fpc1022
            repo=https://github.com/feraxtx/libfprint-10a5-a920
            recipe=packaging/arch
            maintainer=feraxtx
            ;;
    esac

    if [[ -n $fingerprint ]]; then
        if [[ -n $repo ]]; then
            printf 'Detected fingerprint sensor %s -> %s (maintained by %s)\n' \
                "$fingerprint" "$name" "$maintainer"
            printf 'External Arch recipe: %s/tree/HEAD/%s\n' "$repo" "$recipe"
        fi
        if ! confirm "Install $name and fprintd?"; then
            fingerprint=''
        elif [[ -z $repo ]]; then
            local_packages+=("$name")
        fi
    fi

    if (( ${#local_packages[@]} == 0 )) && [[ -z $fingerprint ]]; then
        printf '\nNo packages selected. Nothing to do.\n'
        return 0
    fi

    # Only one libfprint flavour can be active at a time: the SDCP library comes
    # first in the ld.so search order, so keeping it alongside another sensor
    # variant would shadow the selected driver.
    if [[ -n $fingerprint ]]; then
        local installed
        for installed in honor-fmbp-libfprint-sdcp honor-fmbp-libfprint libfprint-fpc1022; do
            [[ $installed != "$name" ]] || continue
            if pacman -Q "$installed" >/dev/null 2>&1; then
                fail "Remove the previous fingerprint package ($installed) before switching drivers."
            fi
        done
    fi

    # ------------------------------------------------------------------ build

    printf '\n==> Building selected packages...\n'

    work=$(mktemp -d)
    trap 'rm -rf -- '"$(printf '%q' "$work")" EXIT

    # The recipes download a release tarball; make-sources.sh prepares it.
    export SRCDEST="$work/sources"
    mkdir -p -- "$SRCDEST"

    if (( ${#local_packages[@]} > 0 )); then
        version=$(awk '$1 == "pkgver" { print $3; exit }' \
            "$arch_dir/honor-magicbook-pro-14/.SRCINFO")
        bash "$arch_dir/make-sources.sh" "$version" "$SRCDEST"

        # Build from a copy so the recipe directories stay untouched.
        local package
        for package in "${local_packages[@]}"; do
            cp -a -- "$arch_dir/$package" "$work/$package"
            case "$package" in
                honor-magicbook-pro-14|honor-fmbp-edid)
                    printf '\n==> Building %s (local checkout; skipping release checksum)\n' "$package"
                    build_package "$package" "$work/$package" --skipchecksums
                    ;;
                *)
                    printf '\n==> Building %s\n' "$package"
                    build_package "$package" "$work/$package"
                    ;;
            esac
        done
    fi

    if [[ -n $fingerprint && -n $repo ]]; then
        command -v git >/dev/null || fail 'Install git to build the external fingerprint package.'
        git clone --depth=1 -- "$repo.git" "$work/external"
        printf '\n==> Building %s (external recipe at commit %s)\n' \
            "$name" "$(git -C "$work/external" rev-parse --short HEAD)"
        build_package "$name" "$work/external/$recipe"
    fi

    # ---------------------------------------------------------------- install

    printf '\n==> Installing packages...\n'

    # One transaction for all archives: pacman resolves the conflicts between
    # the fingerprint packages and the stock library in a single step.
    sudo pacman -U -- "${packages[@]}"
    if [[ -n $fingerprint ]]; then
        sudo pacman -S --needed fprintd
    fi

    # ---------------------------------------------------------------- summary

    printf '\n==> Installation complete!\n'
    printf '\nNext steps:\n'
    printf '  1. Check DKMS module status:   dkms status\n'
    printf '  2. Reboot your system:         sudo reboot\n'
    printf '  3. Verify after reboot:        honor-fmbp-diag\n'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
