#!/bin/bash
# One-shot installer for the FMB-P fixes in this repo (fresh-install friendly).
#
#   sudo ./install.sh                  # install everything (asks once)
#   sudo ./install.sh --only battery,driver
#   sudo ./install.sh --status        # show what's installed / armed
#   sudo ./install.sh --uninstall     # remove everything (keeps backups)
#
# Modules: dsdt driver fan battery touchscreen keyboard
#   dsdt        patched DSDT override (the foundation — see fixes/dsdt/)
#   driver      huawei-wmi DKMS with the Fn-key patch
#   fan         honor-fmbp-hwmon DKMS (fan RPM in `sensors`)
#   battery     charge threshold service (preset pair 70/90; see fixes/battery/)
#   touchscreen power-on workaround service + sleep hook + inhibit rules
#   keyboard    hwdb entry silencing the e078 atkbd spam
# (fingerprint is manual-only: see fixes/fingerprint/)
#
# Tested on CachyOS (Arch family). dracut (Fedora) and initramfs-tools
# (Debian/Ubuntu) branches are best-effort — review before trusting.

set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
FIX="$REPO_DIR/fixes"
DENIS_BB_COMMIT=7bf8b7b6041b625cc125e1980d7363327b56d598
DENIS_BB_RAW="https://raw.githubusercontent.com/denis-bb/honor-fmb-p-dsdt/$DENIS_BB_COMMIT"
ALL_MODULES="dsdt driver fan battery touchscreen keyboard"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- detection

detect_platform() {
    local product family
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
    family=$(cat /sys/class/dmi/id/product_family 2>/dev/null || true)
    if [[ $product != FMB-P && $family != *MagicBook* ]]; then
        [[ $FORCE = 1 ]] || die "this doesn't look like an Honor MagicBook FMB-P (product='$product'). Use --force to override."
        warn "DMI mismatch (product='$product') — continuing because of --force"
    fi

    if command -v pacman >/dev/null;      then PKG=pacman
    elif command -v dnf >/dev/null;       then PKG=dnf
    elif command -v apt-get >/dev/null;   then PKG=apt
    else die "no supported package manager found (pacman/dnf/apt)"; fi

    if command -v mkinitcpio >/dev/null;        then INITRAMFS=mkinitcpio
    elif command -v dracut >/dev/null;          then INITRAMFS=dracut
    elif command -v update-initramfs >/dev/null; then INITRAMFS=initramfs-tools
    else INITRAMFS=none; fi

    [[ $PKG = pacman ]] || warn "only the Arch-family path is verified on real hardware; $PKG/$INITRAMFS support is best-effort"
}

secure_boot_on() {
    local var
    var=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -1) || return 1
    [[ -n $var ]] && [[ $(od -An -tu1 -j4 -N1 "$var" 2>/dev/null | tr -d ' ') = 1 ]]
}

# ------------------------------------------------------------- dependencies

install_deps() {
    log "Installing dependencies ($PKG)"
    case $PKG in
    pacman)
        pacman -S --needed --noconfirm dkms acpica cpio patch curl libgpiod
        # headers for every installed kernel, the Arch way
        local pb
        for pb in /usr/lib/modules/*/pkgbase; do
            [[ -f $pb ]] && pacman -S --needed --noconfirm "$(cat "$pb")-headers"
        done
        # acpi_call for the touchscreen workaround
        pacman -S --needed --noconfirm acpi_call-dkms 2>/dev/null \
            || pacman -S --needed --noconfirm acpi_call 2>/dev/null \
            || warn "couldn't install acpi_call — touchscreen fix needs it"
        ;;
    dnf)
        dnf install -y dkms kernel-devel acpica-tools cpio patch curl libgpiod-utils git make gcc
        # acpi_call isn't packaged in Fedora — build it via DKMS from git
        if ! grep -q acpi_call <<<"$(dkms status 2>/dev/null || true)"; then
            log "Building acpi_call from source (not packaged in Fedora)"
            rm -rf /usr/src/acpi_call-1.2.2
            git clone --depth 1 https://github.com/nix-community/acpi_call /usr/src/acpi_call-1.2.2 \
                && dkms install acpi_call/1.2.2 \
                || warn "acpi_call build failed — touchscreen fix needs it"
        fi
        ;;
    apt)
        apt-get update
        apt-get install -y dkms "linux-headers-$(uname -r)" acpica-tools cpio patch curl gpiod acpi-call-dkms
        ;;
    esac
}

# ---------------------------------------------------------------- dsdt

dsdt_install() {
    if secure_boot_on; then
        die "Secure Boot is enabled: kernel lockdown ignores ACPI table overrides (and the DKMS modules are unsigned). Disable Secure Boot first."
    fi
    local wd aml
    wd=$(mktemp -d)

    log "Dumping your ACPI tables"
    ( cd "$wd" && acpidump -b )
    [[ -f $wd/dsdt.dat ]] || die "acpidump produced no dsdt.dat"

    if ! grep -q NFC0 "$wd/dsdt.dat"; then
        log "DSDT has no NFC0 device — already patched or BIOS is fixed. Skipping."
        rm -rf "$wd"; return 0
    fi

    log "Decompiling DSDT (this can take a moment)"
    ( cd "$wd" && iasl -e ssdt*.dat -d dsdt.dat >/dev/null 2>&1 ) || true
    if [[ ! -s $wd/dsdt.dsl ]]; then
        # some SSDTs duplicate HS03._UPC and break -e resolution; retry without them
        local keep=() f
        for f in "$wd"/ssdt*.dat; do grep -q HS03 "$f" || keep+=("$f"); done
        ( cd "$wd" && rm -f dsdt.dsl && iasl -e "${keep[@]}" -d dsdt.dat >/dev/null 2>&1 ) || true
    fi
    [[ -s $wd/dsdt.dsl ]] || die "could not decompile your DSDT — do it manually per fixes/dsdt/README.md"

    log "Fetching denis-bb patch (pinned $DENIS_BB_COMMIT)"
    curl -fsSL "$DENIS_BB_RAW/dsdt.global.patch" -o "$wd/dsdt.global.patch" \
        || die "could not download the DSDT patch (network?)"

    log "Applying patch to YOUR decompiled DSDT"
    if patch --dry-run --forward "$wd/dsdt.dsl" "$wd/dsdt.global.patch" >/dev/null 2>&1; then
        patch --forward "$wd/dsdt.dsl" "$wd/dsdt.global.patch" >/dev/null
    else
        # fallback: if our decompile textually matches denis-bb's original
        # (ignoring the iasl header comment), their pre-patched dsl is safe
        warn "patch didn't apply to your decompile — comparing against denis-bb's original"
        curl -fsSL "$DENIS_BB_RAW/original/dsdt.global.dsl" -o "$wd/theirs-orig.dsl" || die "download failed"
        if diff -q <(sed -n '/^DefinitionBlock/,$p' "$wd/dsdt.dsl") \
                   <(sed -n '/^DefinitionBlock/,$p' "$wd/theirs-orig.dsl") >/dev/null; then
            curl -fsSL "$DENIS_BB_RAW/patched/dsdt.global.dsl" -o "$wd/dsdt.dsl" || die "download failed"
        else
            die "your DSDT differs from the known original (new BIOS?). Patch it manually per fixes/dsdt/README.md and do NOT force this."
        fi
    fi

    grep -q 'Device (NFC0)' "$wd/dsdt.dsl" && die "NFC0 still present after patching — aborting"

    log "Compiling patched DSDT"
    ( cd "$wd" && iasl -ve -p dsdt-patched dsdt.dsl >/dev/null ) \
        || die "patched DSDT does not compile cleanly — aborting (nothing was installed)"
    aml=$wd/dsdt-patched.aml
    [[ -s $aml ]] || die "no compiled AML produced"

    log "Installing override to /etc/acpi-override"
    install -d /etc/acpi-override/backup /etc/acpi-override/kernel/firmware/acpi
    cp "$wd"/dsdt.dat "/etc/acpi-override/backup/dsdt-original-$(date +%Y%m%d).dat"
    install -m644 "$aml" /etc/acpi-override/dsdt.aml
    cp /etc/acpi-override/dsdt.aml /etc/acpi-override/kernel/firmware/acpi/dsdt.aml
    ( cd /etc/acpi-override && find kernel | cpio -H newc -o --quiet > acpi-override.cpio )

    case $INITRAMFS in
    mkinitcpio)
        install -Dm755 "$FIX/dsdt/10-acpi-override" /etc/initcpio/post/10-acpi-override
        log "Regenerating initramfs (LTS images stay stock ACPI = rescue entries)"
        if command -v limine-mkinitcpio >/dev/null; then limine-mkinitcpio; else mkinitcpio -P; fi
        ;;
    dracut)
        local img="/boot/initramfs-$(uname -r).img"
        [[ -f $img && ! -f $img.stock-acpi ]] && cp "$img" "$img.stock-acpi" \
            && log "Rescue copy kept at $img.stock-acpi (boot it by editing the initrd line)"
        printf 'acpi_override="yes"\nacpi_table_dir="/etc/acpi-override"\n' \
            > /etc/dracut.conf.d/99-fmbp-acpi-override.conf
        dracut -f
        ;;
    initramfs-tools)
        install -m644 /etc/acpi-override/acpi-override.cpio /boot/fmbp-acpi-override.cpio
        if ! grep -q GRUB_EARLY_INITRD_LINUX_CUSTOM /etc/default/grub; then
            echo 'GRUB_EARLY_INITRD_LINUX_CUSTOM="fmbp-acpi-override.cpio"' >> /etc/default/grub
        else
            sed -i 's/^GRUB_EARLY_INITRD_LINUX_CUSTOM=.*/GRUB_EARLY_INITRD_LINUX_CUSTOM="fmbp-acpi-override.cpio"/' /etc/default/grub
        fi
        update-grub
        warn "rescue path: at the GRUB prompt, edit the entry and delete fmbp-acpi-override.cpio from the initrd line"
        ;;
    *)  warn "unknown initramfs system — override built in /etc/acpi-override but NOT wired into boot" ;;
    esac
    rm -rf "$wd"
    log "DSDT override installed — takes effect after reboot"
}

dsdt_uninstall() {
    rm -f /etc/initcpio/post/10-acpi-override /etc/dracut.conf.d/99-fmbp-acpi-override.conf /boot/fmbp-acpi-override.cpio
    sed -i '/^GRUB_EARLY_INITRD_LINUX_CUSTOM="fmbp-acpi-override.cpio"/d' /etc/default/grub 2>/dev/null || true
    case $INITRAMFS in
    mkinitcpio)      if command -v limine-mkinitcpio >/dev/null; then limine-mkinitcpio; else mkinitcpio -P; fi ;;
    dracut)          dracut -f ;;
    initramfs-tools) update-grub ;;
    esac
    log "DSDT override unwired (files kept in /etc/acpi-override, incl. backups)"
}

# ---------------------------------------------------------------- dkms bits

dkms_module_install() { # $1 srcdir  $2 name  $3 version
    rm -rf "/usr/src/$2-$3"
    cp -r "$1" "/usr/src/$2-$3"
    rm -f "/usr/src/$2-$3/README.md"
    local st; st=$(dkms status 2>/dev/null || true)
    grep -q "^$2/$3.*installed" <<<"$st" || dkms install "$2/$3"
}

driver_install() {
    log "Installing patched huawei-wmi (Fn keys)"
    dkms_module_install "$FIX/huawei-wmi-dkms" huawei-wmi-fmbp 1.0
    modprobe -r huawei_wmi 2>/dev/null || true
    modprobe huawei-wmi || warn "module load failed — will load on next boot"
}
driver_uninstall() {
    dkms remove huawei-wmi-fmbp/1.0 --all 2>/dev/null || true
    rm -rf /usr/src/huawei-wmi-fmbp-1.0
}

fan_install() {
    log "Installing fan hwmon module"
    dkms_module_install "$FIX/fan" honor-fmbp-hwmon 1.0
    echo honor-fmbp-hwmon > /etc/modules-load.d/honor-fmbp-hwmon.conf
    modprobe honor-fmbp-hwmon 2>/dev/null || warn "fan module load failed — will load on next boot"
}
fan_uninstall() {
    modprobe -r honor-fmbp-hwmon 2>/dev/null || true
    dkms remove honor-fmbp-hwmon/1.0 --all 2>/dev/null || true
    rm -rf /usr/src/honor-fmbp-hwmon-1.0 /etc/modules-load.d/honor-fmbp-hwmon.conf
}

# ---------------------------------------------------------------- the rest

battery_armed() {
    # The EC arms itself (EC reg 0x85 = preset index 1/2/3) only for the
    # PC Manager preset pairs 40/70, 70/90, 95/100 — anything else is
    # stored but silently ignored. Returns 0 if enforcement is armed.
    modprobe ec_sys 2>/dev/null || return 2
    [[ -r /sys/kernel/debug/ec/ec0/io ]] || return 2
    local chmd
    chmd=$(dd if=/sys/kernel/debug/ec/ec0/io bs=1 skip=$((0x85)) count=1 2>/dev/null | od -An -tu1 | tr -d ' ')
    [[ -n $chmd && $chmd -ne 0 ]]
}

battery_install() {
    log "Installing battery threshold service (70-90 preset, edit the script to taste)"
    install -Dm755 "$FIX/battery/honor-battery-thresholds.sh" /usr/local/sbin/honor-battery-thresholds.sh
    install -Dm644 "$FIX/battery/honor-battery-thresholds.service" /etc/systemd/system/honor-battery-thresholds.service
    systemctl daemon-reload
    systemctl enable --now honor-battery-thresholds.service
    sleep 2
    case $(battery_armed; echo $?) in
    0) log "EC armed the limit (preset pair recognized) — enforcement active" ;;
    1) warn "EC did NOT arm: the configured pair is not a PC Manager preset (only 40/70, 70/90, 95/100 are enforced)" ;;
    *) : ;; # ec_sys unavailable — can't verify, stay quiet
    esac
}
battery_uninstall() {
    systemctl disable --now honor-battery-thresholds.service 2>/dev/null || true
    rm -f /etc/systemd/system/honor-battery-thresholds.service /usr/local/sbin/honor-battery-thresholds.sh
    systemctl daemon-reload
}

touchscreen_install() {
    log "Installing touchscreen power-on workaround"
    modinfo acpi_call >/dev/null 2>&1 || warn "acpi_call module not found — the workaround will not work until it's installed"
    echo acpi_call > /etc/modules-load.d/acpi_call.conf
    install -Dm755 "$FIX/touchscreen/honor-touchscreen-on.sh" /usr/local/sbin/honor-touchscreen-on.sh
    install -Dm644 "$FIX/touchscreen/honor-touchscreen.service" /etc/systemd/system/honor-touchscreen.service
    install -Dm755 "$FIX/touchscreen/honor-touchscreen.sleep-hook" /usr/lib/systemd/system-sleep/honor-touchscreen
    install -Dm644 "$FIX/touchscreen/99-ignore-touchpad-device.rules" /etc/udev/rules.d/99-ignore-touchpad-device.rules
    udevadm control --reload
    systemctl daemon-reload
    systemctl enable --now honor-touchscreen.service || warn "touchscreen service failed (needs acpi_call + the DSDT fix)"
}
touchscreen_uninstall() {
    systemctl disable --now honor-touchscreen.service 2>/dev/null || true
    rm -f /etc/systemd/system/honor-touchscreen.service /usr/local/sbin/honor-touchscreen-on.sh \
          /usr/lib/systemd/system-sleep/honor-touchscreen /etc/udev/rules.d/99-ignore-touchpad-device.rules \
          /etc/modules-load.d/acpi_call.conf
    udevadm control --reload; systemctl daemon-reload
}

keyboard_install() {
    log "Installing keyboard hwdb entry"
    install -Dm644 "$FIX/fn-keys/61-honor-fmbp-keyboard.hwdb" /etc/udev/hwdb.d/61-honor-fmbp-keyboard.hwdb
    systemd-hwdb update && udevadm trigger
}
keyboard_uninstall() {
    rm -f /etc/udev/hwdb.d/61-honor-fmbp-keyboard.hwdb
    systemd-hwdb update && udevadm trigger
}

# ---------------------------------------------------------------- status

status() {
    local ok='\033[1;32m✔\033[0m' no='\033[1;31m✘\033[0m' dkms_out
    dkms_out=$(dkms status 2>/dev/null || true)
    printf "dsdt:        "; [[ -f /etc/acpi-override/acpi-override.cpio ]] && echo -e "$ok override built" || echo -e "$no"
    printf "driver:      "; grep -q huawei-wmi-fmbp <<<"$dkms_out" && echo -e "$ok $(grep huawei-wmi-fmbp <<<"$dkms_out" | head -1)" || echo -e "$no"
    printf "fan:         "; grep -q honor-fmbp-hwmon <<<"$dkms_out" && echo -e "$ok" || echo -e "$no"
    printf "battery:     "
    if systemctl is-enabled honor-battery-thresholds.service >/dev/null 2>&1; then
        local armtxt=""
        case $(battery_armed; echo $?) in
        0) armtxt="(EC armed)" ;;
        1) armtxt="(EC NOT armed — pair is not a preset!)" ;;
        esac
        echo -e "$ok $(cat /sys/devices/platform/huawei-wmi/charge_control_thresholds 2>/dev/null) $armtxt"
    else echo -e "$no"; fi
    printf "touchscreen: "; systemctl is-enabled honor-touchscreen.service >/dev/null 2>&1 && echo -e "$ok" || echo -e "$no"
    printf "keyboard:    "; [[ -f /etc/udev/hwdb.d/61-honor-fmbp-keyboard.hwdb ]] && echo -e "$ok" || echo -e "$no"
    if [[ -r /sys/class/power_supply/BAT0/status ]]; then
        echo "battery now: $(cat /sys/class/power_supply/BAT0/capacity)% $(cat /sys/class/power_supply/BAT0/status)"
    fi
}

# ---------------------------------------------------------------- main

FORCE=0; YES=0; MODULES=$ALL_MODULES; ACTION=install; SKIP_DEPS=0
while [[ $# -gt 0 ]]; do
    case $1 in
    --status)     ACTION=status ;;
    --uninstall)  ACTION=uninstall ;;
    --only)       MODULES=${2//,/ }; shift ;;
    --force)      FORCE=1 ;;
    --yes|-y)     YES=1 ;;
    --skip-deps)  SKIP_DEPS=1 ;;
    -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;
    *) die "unknown option $1 (see --help)" ;;
    esac
    shift
done

[[ $ACTION = status ]] && { status; exit 0; }
[[ $EUID -eq 0 ]] || die "run as root (sudo ./install.sh)"
detect_platform

for m in $MODULES; do
    [[ " $ALL_MODULES " = *" $m "* ]] || die "unknown module '$m' (valid: $ALL_MODULES)"
done

if [[ $ACTION = install ]]; then
    echo "Will install: $MODULES   (distro: $PKG, initramfs: $INITRAMFS)"
    if [[ $YES -ne 1 ]]; then
        read -rp "Continue? [y/N] " a; [[ ${a,,} = y* ]] || exit 1
    fi
    [[ $SKIP_DEPS = 1 ]] || install_deps
    for m in $MODULES; do "${m}_install"; done
    echo
    log "Done. Reboot to activate the DSDT override (everything else is live)."
    log "Check with: ./install.sh --status"
else
    echo "Will REMOVE: $MODULES"
    if [[ $YES -ne 1 ]]; then
        read -rp "Continue? [y/N] " a; [[ ${a,,} = y* ]] || exit 1
    fi
    for m in $MODULES; do "${m}_uninstall"; done
    log "Uninstalled. Reboot to return to stock ACPI."
fi
