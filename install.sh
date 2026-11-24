#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 tsukasagenesis (original installer, PR #21)
# SPDX-FileCopyrightText: 2026 René Fritz and the Linux-on-Honor-Magicbook-14-Pro contributors
#
# Installer for the HONOR MagicBook Pro 14 2025 (FMB-P) fixes in this repository.
#
#   sudo ./install.sh                      # install all modules (asks once)
#   sudo ./install.sh --only udev,battery  # selected modules
#   ./install.sh --status                  # show what is installed / active
#   sudo ./install.sh --uninstall          # remove everything this script installed
#
# Modules (default: all):
#   dsdt     corrected DSDT as early-initramfs override (NFC0 load fix + touchscreen power)
#   udev     hwdb/udev quirks: touchpad ghost keys, e078/f8 scancodes, touchscreen ghost
#   wmi      huawei-wmi DKMS with the FMB-P Fn-key map
#   hwmon    fan RPM driver (DKMS)
#   kbdlight keyboard backlight driver (DKMS)
#   battery  charge-limit service (/etc/default/honor-fmbp-battery, preset pairs only)
# The fingerprint reader is separate: see fixes/libfprint/.
#
# Options:
#   --dsdt-source auto|own|prebuilt   auto (default): build from this machine's firmware
#                 table if it is unmodified, otherwise use the prebuilt table for the SKU
#   --yes          don't ask        --skip-deps   don't install packages
#   --force        skip the DMI check (for testing only)
#
# Tested: Fedora 44 (dracut). Arch (mkinitcpio) and Debian/Ubuntu (initramfs-tools)
# paths are best-effort; please report results.

set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
FIX=$REPO/fixes
LIB=/usr/lib/honor-fmbp
STATE=/var/lib/honor-fmbp
BACKUP=$STATE/backup
ALL_MODULES="dsdt udev wmi hwmon kbdlight battery"
THR=/sys/devices/platform/huawei-wmi/charge_control_thresholds

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

backup() { # move a file we replace or retire into $BACKUP (never next to the original)
    local f=$1
    [[ -e $f ]] || return 0
    install -d "$BACKUP$(dirname "$f")"
    mv "$f" "$BACKUP$f.$(date +%Y%m%d%H%M%S)"
    log "  moved $f to $BACKUP"
}

# ------------------------------------------------------------------ detection

detect_platform() {
    local vendor product
    vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
    if [[ $vendor != HONOR || $product != FMB-P ]]; then
        [[ $FORCE = 1 ]] || die "not an HONOR FMB-P (DMI: '$vendor' / '$product'). Use --force to override."
        warn "DMI mismatch ('$vendor' / '$product'), continuing because of --force"
    fi
    if   command -v dnf >/dev/null;     then PKG=dnf
    elif command -v pacman >/dev/null;  then PKG=pacman
    elif command -v apt-get >/dev/null; then PKG=apt
    else PKG=none; fi
    if   command -v dracut >/dev/null && [[ ! -d /etc/initramfs-tools ]]; then INITRAMFS=dracut
    elif command -v mkinitcpio >/dev/null;       then INITRAMFS=mkinitcpio
    elif command -v update-initramfs >/dev/null; then INITRAMFS=initramfs-tools
    else INITRAMFS=none; fi
    [[ $PKG = dnf ]] || warn "only Fedora is verified on hardware; $PKG/$INITRAMFS is best-effort"
}

secure_boot_on() {
    local v; v=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -1)
    [[ -n $v && $(od -An -tu1 -j4 -N1 "$v" | tr -d ' ') = 1 ]]
}

# is the DSDT in /sys already an override (initrd table upgrade or GRUB 'acpi')?
dsdt_overridden() {
    local klog; klog=$(journalctl -k -b -q 2>/dev/null || dmesg 2>/dev/null || true)
    grep -q 'Table Upgrade: override \[DSDT' <<<"$klog" && return 0
    od -An -c /sys/firmware/acpi/tables/DSDT 2>/dev/null | tr -d ' \n' | grep -q 'TD_P' && return 0   # our table
    ! od -An -c /sys/firmware/acpi/tables/DSDT 2>/dev/null | tr -d ' \n' | grep -q 'NFC0'               # denis-bb table
}
dsdt_sku()  {
    local hex; hex=$(od -An -v -tx1 /sys/firmware/acpi/tables/DSDT 2>/dev/null | tr -s ' \n' ' ')
    if   grep -q '0c 18 90 e0 67' <<<"$hex"; then echo global
    elif grep -q '0c 18 90 e1 67' <<<"$hex"; then echo chinese
    else echo unknown; fi
}

# ------------------------------------------------------------------ deps

install_deps() {
    local mods=" $MODULES " pk=()
    [[ $mods = *" dsdt "* ]] && pk+=(acpica-tools python3 perl cpio)
    [[ $mods =~ \ (wmi|hwmon|kbdlight)\  ]] && pk+=(dkms)
    [[ ${#pk[@]} -gt 0 ]] || return 0
    log "Installing dependencies ($PKG): ${pk[*]}"
    case $PKG in
    dnf)    dnf install -y "${pk[@]}" "kernel-devel-$(uname -r)" ;;
    pacman) pacman -S --needed --noconfirm "${pk[@]/acpica-tools/acpica}" linux-headers ;;
    apt)    apt-get install -y "${pk[@]}" "linux-headers-$(uname -r)" ;;
    *)      warn "unknown package manager — install ${pk[*]} and kernel headers yourself" ;;
    esac
}

regen_initramfs() {
    case $INITRAMFS in
    dracut)          dracut --force --regenerate-all ;;
    mkinitcpio)      if command -v limine-mkinitcpio >/dev/null; then limine-mkinitcpio; else mkinitcpio -P; fi ;;
    initramfs-tools) update-initramfs -u -k all ;;
    *)               warn "unknown initramfs generator: the DSDT is installed in $LIB/acpi but NOT wired into boot" ;;
    esac
}

# ------------------------------------------------------------------ dsdt

retire_old_dsdt_setups() {
    # GRUB-loaded tables (acpi /dsdt.aml) override ours and load the old table for every entry
    local f
    for f in /etc/grub.d/40_custom /boot/grub2/custom.cfg /boot/grub/custom.cfg; do
        [[ -f $f ]] && grep -q -E '^[[:space:]]*acpi[[:space:]]+.*\.aml' "$f" || continue
        warn "found a GRUB 'acpi' DSDT line in $f — disabling it (backup in $BACKUP)"
        install -d "$BACKUP$(dirname "$f")"; cp -a "$f" "$BACKUP$f.$(date +%Y%m%d%H%M%S)"
        sed -i -E 's/^([[:space:]]*acpi[[:space:]]+.*\.aml)/# disabled by honor-fmbp install.sh: \1/' "$f"
        GRUB_CHANGED=1
    done
    # earlier installer versions (PR #21)
    backup /etc/dracut.conf.d/99-fmbp-acpi-override.conf
    [[ -d /etc/acpi-override ]] && { install -d "$BACKUP/etc"; mv /etc/acpi-override "$BACKUP/etc/acpi-override.$(date +%Y%m%d%H%M%S)"; }
    backup /boot/fmbp-acpi-override.cpio
    sed -i '/^GRUB_EARLY_INITRD_LINUX_CUSTOM="fmbp-acpi-override.cpio"/d' /etc/default/grub 2>/dev/null || true
    # acpi_call touchscreen workarounds are obsolete with the DSDT power resource
    local u
    for u in honor-touchscreen-fix.service honor-touchscreen.service; do
        if systemctl list-unit-files "$u" >/dev/null 2>&1 && systemctl is-enabled "$u" >/dev/null 2>&1; then
            warn "disabling obsolete $u (touchscreen is powered by the DSDT now)"
            systemctl disable --now "$u" || true
        fi
    done
}

update_grub() {
    [[ ${GRUB_CHANGED:-0} = 1 ]] || return 0
    if   [[ -f /boot/grub2/grub.cfg ]] && command -v grub2-mkconfig >/dev/null; then grub2-mkconfig -o /boot/grub2/grub.cfg
    elif command -v update-grub >/dev/null; then update-grub
    elif [[ -f /boot/grub/grub.cfg ]] && command -v grub-mkconfig >/dev/null; then grub-mkconfig -o /boot/grub/grub.cfg
    else warn "regenerate your GRUB config yourself"; fi
}

dsdt_install() {
    secure_boot_on && die "Secure Boot is on: kernel lockdown may ignore ACPI table overrides. Disable it first (see dsdt/README.md)."
    local sku src=$DSDT_SOURCE out
    sku=$(dsdt_sku)
    [[ $sku != unknown ]] || die "unknown BIOS SKU — please report with tools/honor-fmbp-diag"
    if [[ $src = auto ]]; then
        dsdt_overridden && src=prebuilt || src=own
    fi
    install -d "$LIB/acpi" "$STATE"
    case $src in
    own)
        dsdt_overridden && die "the DSDT in /sys is already an override; use --dsdt-source prebuilt (or boot once without it)"
        log "Building the DSDT from this machine's firmware ($sku)"
        out=$(mktemp -d)
        "$REPO/dsdt/build.sh" --out "$out" --no-chinese
        install -m644 "$out/fix.patch" "$STATE/dsdt-fix.patch"
        install -m644 "$out/dsdt.$sku.aml" "$LIB/acpi/dsdt.aml"
        rm -rf "$out" ;;
    prebuilt)
        log "Using the prebuilt $sku DSDT (an override is active, so the stock table isn't readable)"
        install -m644 "$REPO/dsdt/prebuilt/dsdt.$sku.aml" "$LIB/acpi/dsdt.aml" ;;
    *) die "unknown --dsdt-source '$src'" ;;
    esac
    echo "$sku $src $(date +%F)" > "$STATE/dsdt.info"

    retire_old_dsdt_setups
    case $INITRAMFS in
    dracut)
        install -Dm644 "$REPO/dsdt/initramfs/dracut-10-honor-fmbp-dsdt.conf" /etc/dracut.conf.d/10-honor-fmbp-dsdt.conf ;;
    mkinitcpio)
        local w; w=$(mktemp -d); install -d "$w/kernel/firmware/acpi"
        cp "$LIB/acpi/dsdt.aml" "$w/kernel/firmware/acpi/"
        ( cd "$w" && find kernel | LC_ALL=C sort | cpio -o -H newc -R 0:0 --quiet ) > "$LIB/acpi-override.cpio"
        rm -rf "$w"
        install -Dm755 "$REPO/dsdt/initramfs/mkinitcpio-10-acpi-override" /etc/initcpio/post/10-acpi-override ;;
    initramfs-tools)
        install -Dm755 "$REPO/dsdt/initramfs/initramfs-tools-honor-fmbp-dsdt" /etc/initramfs-tools/hooks/honor-fmbp-dsdt ;;
    esac
    log "Regenerating initramfs"
    regen_initramfs
    update_grub
    log "DSDT installed ($sku, $src) — active after reboot. Check: journalctl -k -b | grep 'Table Upgrade'"
    log "Rescue: boot an entry whose initramfs predates this (e.g. Fedora's '0-rescue' entry) or run --uninstall."
}

dsdt_uninstall() {
    rm -f /etc/dracut.conf.d/10-honor-fmbp-dsdt.conf /etc/initcpio/post/10-acpi-override \
          /etc/initramfs-tools/hooks/honor-fmbp-dsdt "$LIB/acpi-override.cpio" "$STATE/dsdt.info"
    rm -rf "$LIB/acpi"
    regen_initramfs
    log "DSDT override removed (GRUB lines disabled by the installer stay disabled; backups in $BACKUP)"
}

dsdt_status() {
    if [[ -f $LIB/acpi/dsdt.aml ]]; then
        local active="not active yet (reboot)"
        local klog; klog=$(journalctl -k -b -q 2>/dev/null || dmesg 2>/dev/null || true)
        grep -q 'Table Upgrade: override \[DSDT' <<<"$klog" && active="active"
        echo "installed ($(cat "$STATE/dsdt.info" 2>/dev/null)), $active"
    else echo "-"; fi
}

# ------------------------------------------------------------------ udev

UDEV_FILES="hwdb.d/61-honor-fmbp-keyboard.hwdb hwdb.d/61-honor-fmbp-touchpad.hwdb rules.d/99-honor-fmbp-touchscreen.rules"
udev_install() {
    log "Installing udev/hwdb quirks"
    local f
    # retire the old whole-device inhibit for the touchpad ghost (replaced by the hwdb)
    for f in /etc/udev/rules.d/99-ignore-touchpad.rules /etc/udev/rules.d/99-ignore-touchpad-device.rules; do backup "$f"; done
    for f in $UDEV_FILES; do install -Dm644 "$FIX/udev/${f#*/}" "/etc/udev/$f"; done
    systemd-hwdb update
    udevadm control --reload
    udevadm trigger -s input || true
}
udev_uninstall() {
    local f; for f in $UDEV_FILES; do rm -f "/etc/udev/$f"; done
    systemd-hwdb update; udevadm control --reload
}
udev_status() { [[ -f /etc/udev/hwdb.d/61-honor-fmbp-touchpad.hwdb ]] && echo installed || echo "-"; }

# ------------------------------------------------------------------ dkms modules

dkms_ver() { sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$FIX/$1/dkms.conf"; }
dkms_name() { sed -n 's/^PACKAGE_NAME="\(.*\)"/\1/p' "$FIX/$1/dkms.conf"; }

dkms_add() { # $1 = dir in fixes/
    local n v; n=$(dkms_name "$1"); v=$(dkms_ver "$1")
    log "Installing $n/$v (DKMS)"
    dkms remove "$n/$v" --all >/dev/null 2>&1 || true
    rm -rf "/usr/src/$n-$v"; cp -r "$FIX/$1" "/usr/src/$n-$v"
    dkms install "$n/$v"
}
dkms_del() {
    local n v; n=$(dkms_name "$1"); v=$(dkms_ver "$1")
    dkms remove "$n/$v" --all 2>/dev/null || true
    rm -rf "/usr/src/$n-$v"
}
dkms_st() { local n st; n=$(dkms_name "$1"); st=$(dkms status "$n" 2>/dev/null || true); grep -m1 installed <<<"$st" || echo "-"; }

wmi_install()      { dkms_add huawei-wmi-dkms; modprobe -r huawei_wmi 2>/dev/null || true; modprobe huawei-wmi || warn "load failed, will load on next boot"; }
wmi_uninstall()    { dkms_del huawei-wmi-dkms; }
wmi_status()       { dkms_st huawei-wmi-dkms; }
hwmon_install()    { dkms_add honor-fmbp-hwmon; install -Dm644 "$FIX/honor-fmbp-hwmon/honor-fmbp-hwmon.conf" /etc/modules-load.d/honor-fmbp-hwmon.conf; modprobe honor-fmbp-hwmon || true; }
hwmon_uninstall()  { modprobe -r honor-fmbp-hwmon 2>/dev/null || true; dkms_del honor-fmbp-hwmon; rm -f /etc/modules-load.d/honor-fmbp-hwmon.conf; }
hwmon_status()     { dkms_st honor-fmbp-hwmon; }
kbdlight_install() { dkms_add honor-fmbp-kbdlight; install -Dm644 "$FIX/honor-fmbp-kbdlight/honor-fmbp-kbdlight.conf" /etc/modules-load.d/honor-fmbp-kbdlight.conf; modprobe honor-fmbp-kbdlight || true; }
kbdlight_uninstall() { modprobe -r honor-fmbp-kbdlight 2>/dev/null || true; dkms_del honor-fmbp-kbdlight; rm -f /etc/modules-load.d/honor-fmbp-kbdlight.conf; }
kbdlight_status()  { dkms_st honor-fmbp-kbdlight; }

# ------------------------------------------------------------------ battery

battery_mode() { # EC charge mode via the read-only WMI query \GBCM: 0 = not armed, 1-3 = preset
    local d=/sys/kernel/debug/huawei-wmi
    mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug 2>/dev/null || return 1
    [[ -w $d/arg ]] || return 1
    printf 0x1603 > $d/arg
    cat $d/call 2>/dev/null | tr -d ' \n' | sed -n 's/.*},{0x[0-9a-f]*,0x\([0-9a-f]*\),.*/\1/p'
}
battery_install() {
    log "Installing battery charge-limit service"
    [[ -f /etc/default/honor-fmbp-battery ]] || install -Dm644 "$FIX/battery/honor-fmbp-battery.default" /etc/default/honor-fmbp-battery
    install -Dm644 "$FIX/battery/honor-fmbp-battery.service" /etc/systemd/system/honor-fmbp-battery.service
    install -Dm644 "$FIX/battery/99-honor-fmbp-battery.rules" /etc/udev/rules.d/99-honor-fmbp-battery.rules
    udevadm control --reload
    systemctl daemon-reload
    systemctl enable honor-fmbp-battery.service
    systemctl restart honor-fmbp-battery.service
    sleep 2
    local m; m=$(battery_mode || true)
    case $m in
    "")     warn "could not read the EC charge mode (huawei-wmi debugfs missing)" ;;
    00|0)   warn "EC did NOT arm the limit: only 40 70, 70 90 and 95 100 are enforced (edit /etc/default/honor-fmbp-battery)" ;;
    *)      log "EC armed the charge limit (mode $m)" ;;
    esac
}
battery_uninstall() {
    systemctl disable --now honor-fmbp-battery.service 2>/dev/null || true
    rm -f /etc/systemd/system/honor-fmbp-battery.service /etc/udev/rules.d/99-honor-fmbp-battery.rules
    systemctl daemon-reload; udevadm control --reload
    [[ -w $THR ]] && echo "0 100" > $THR || true
    log "charge limit removed (kept /etc/default/honor-fmbp-battery)"
}
battery_status() {
    systemctl is-enabled honor-fmbp-battery.service >/dev/null 2>&1 || { echo "-"; return; }
    local m=""; [[ $EUID = 0 ]] && m=$(battery_mode || true)
    echo "enabled, thresholds $(cat $THR 2>/dev/null)${m:+, EC mode $m}"
}

# ------------------------------------------------------------------ main

status() {
    local m
    for m in $ALL_MODULES; do printf '  %-9s %s\n' "$m" "$("${m}_status")"; done
    [[ $EUID = 0 ]] || echo "  (run with sudo for the EC charge mode)"
}

FORCE=0; YES=0; SKIP_DEPS=0; MODULES=$ALL_MODULES; ACTION=install; DSDT_SOURCE=auto
while [[ $# -gt 0 ]]; do
    case $1 in
    --status)      ACTION=status ;;
    --uninstall)   ACTION=uninstall ;;
    --only)        MODULES=${2//,/ }; shift ;;
    --dsdt-source) DSDT_SOURCE=$2; shift ;;
    --force)       FORCE=1 ;;
    --yes|-y)      YES=1 ;;
    --skip-deps)   SKIP_DEPS=1 ;;
    -h|--help)     sed -n '5,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option $1 (see --help)" ;;
    esac
    shift
done
for m in $MODULES; do [[ " $ALL_MODULES " = *" $m "* ]] || die "unknown module '$m' (valid: $ALL_MODULES)"; done

[[ $ACTION = status ]] && { status; exit 0; }
[[ $EUID -eq 0 ]] || die "run as root (sudo $0)"
detect_platform

if [[ $ACTION = install ]]; then
    echo "Will install: $MODULES   (packages: $PKG, initramfs: $INITRAMFS, dsdt source: $DSDT_SOURCE)"
    if [[ $YES -ne 1 ]]; then read -rp "Continue? [y/N] " a; [[ ${a,,} = y* ]] || exit 1; fi
    [[ $SKIP_DEPS = 1 ]] || install_deps
    for m in $MODULES; do "${m}_install"; done
    echo; log "Done. Reboot if the DSDT was installed. Check with: $0 --status"
else
    echo "Will REMOVE: $MODULES"
    if [[ $YES -ne 1 ]]; then read -rp "Continue? [y/N] " a; [[ ${a,,} = y* ]] || exit 1; fi
    for m in $MODULES; do "${m}_uninstall"; done
    log "Uninstalled. Reboot to return to the stock firmware tables."
fi
