#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# SPDX-FileCopyrightText: 2026 Philip Walsh (drphilth) <packages@drphilth.com>
# SPDX-FileCopyrightText: 2026 René Fritz and the Linux-on-Honor-Magicbook-14-Pro contributors
#
# build.sh — build the corrected DSDT for the HONOR MagicBook Pro 14 2025 (FMB-P).
#
# Based on drphilth's pipeline (https://github.com/drphilth/honor-magicbook-pro-14-ubuntu,
# dsdt/build.sh); the original NFC0 load-abort fix is by denis-bb
# (https://github.com/denis-bb/honor-fmb-p-dsdt). Mechanism: ../docs/dsdt-root-cause.md
#
# Usage:
#   sudo dsdt/build.sh                      # use THIS machine's firmware DSDT (must be stock)
#   dsdt/build.sh --table path/to/DSDT      # a raw stock table (acpidump -b / sysfs copy)
#   dsdt/build.sh --dsl path/to/stock.dsl   # a stock disassembly (e.g. denis-bb original/)
#   options: --out DIR (default dsdt/out)  --no-touchscreen  --no-chinese
#
# Output (in --out):
#   dsdt.<sku>.aml        corrected table for the detected SKU (global|chinese)
#   dsdt.chinese.aml      derived Chinese-SKU table (only when input is global)
#   fix.patch             source diff stock -> patched (review this!)
#
# The input MUST be the unmodified firmware table. If an override
# is already active, /sys shows the overridden table — then pass --table/--dsl, or boot
# once without the override and rerun.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/out"
IASL=${IASL:-iasl}
IN_TABLE="" IN_DSL="" TOUCHSCREEN=1 CHINESE=1

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo ">> $*"; }

while [ $# -gt 0 ]; do
    case $1 in
        --table) IN_TABLE=$2; shift 2 ;;
        --dsl)   IN_DSL=$2; shift 2 ;;
        --out)   OUT=$2; shift 2 ;;
        --no-touchscreen) TOUCHSCREEN=0; shift ;;
        --no-chinese) CHINESE=0; shift ;;
        -h|--help) sed -n '2,/^set -e/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option $1" ;;
    esac
done

command -v "$IASL" >/dev/null || die "iasl not found (Fedora: dnf install acpica-tools)"
command -v python3 >/dev/null || die "python3 not found"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

# ---------------------------------------------------------------- [1] input -> stock.dsl
if [ -n "$IN_DSL" ]; then
    cp "$IN_DSL" "$WORK/stock.dsl"
else
    [ -n "$IN_TABLE" ] || IN_TABLE=/sys/firmware/acpi/tables/DSDT
    [ -r "$IN_TABLE" ] || die "cannot read $IN_TABLE (run with sudo, or pass --table/--dsl)"
    cp "$IN_TABLE" "$WORK/stock.dat"
    log "[1] disassemble stock DSDT"
    "$IASL" -d -p "$WORK/stock" "$WORK/stock.dat" >/dev/null 2>&1 || die "iasl -d failed"
fi
# firmware OEM revision (0x02 on BIOS 1.13/1.16); the override must carry a higher one
REV=$(sed -n 's/^DefinitionBlock ("", "DSDT", 2, "HONOR", "ARL", \(0x[0-9A-Fa-f]*\))$/\1/p' "$WORK/stock.dsl" | head -1)
[ -n "$REV" ] || die "input is not an FMB-P DSDT (expected OEM HONOR / table ARL)"
# refuse tables that are already corrected (ours: injected TD_P; denis-bb: NFC0 removed),
# e.g. /sys/firmware/acpi/tables/DSDT while an override is active
if grep -q 'Name (TD_P, Package' "$WORK/stock.dsl" || ! grep -q 'Device (NFC0)' "$WORK/stock.dsl"; then
    die "input is an already patched DSDT (an override is active?).
       Pass the stock table with --table/--dsl, or boot once without the override."
fi
NEW_REV=$(printf '0x%08X' $((REV + 1)))

if   grep -q 'OperationRegion (GNVS, SystemMemory, 0x67E09018' "$WORK/stock.dsl"; then SKU=global
elif grep -q 'OperationRegion (GNVS, SystemMemory, 0x67E19018' "$WORK/stock.dsl"; then SKU=chinese
else die "unknown BIOS SKU (GNVS base not recognised) — please report this with tools/honor-fmbp-diag"; fi
log "input SKU: $SKU"
cp "$WORK/stock.dsl" "$WORK/patched.dsl"
P=$WORK/patched.dsl

# ---------------------------------------------------------------- [2] the fixes
n=$(grep -c 'INT1 = GNUM (0x0014080A)' "$P" || true)
case $n in
1)  log "[2] remove NFC0 load-time GNUM call (aborts the whole DSDT load otherwise)"
    sed -i '/INT1 = GNUM (0x0014080A)/d; /CreateWordField (SBGF, 0x17, INT1)/d' "$P" ;;
0)  # BIOS 1.17 moved the GNUM call into NFC0._CRS (analysis by mrueg, issue #22)
    grep -q 'GNUM (0x0014080A)' "$P" \
        || die "NFC0 GNUM call not found at all — unknown BIOS, please report with tools/honor-fmbp-diag"
    log "[2] NFC0 is already fixed in this BIOS (GNUM no longer runs at table load) — skipping" ;;
*)  die "expected one NFC0 GNUM call, found $n — BIOS changed, re-audit" ;;
esac

if [ "$TOUCHSCREEN" = 1 ]; then
    log "[2b] inject touchscreen PowerResource (FTSC1000 on I2C2)"
    python3 -I "$HERE/patches/inject-touchscreen-power.py" "$P"
fi

log "[3] bump OEM revision $REV -> $NEW_REV"
sed -i "s/^\(DefinitionBlock (\"\", \"DSDT\", 2, \"HONOR\", \"ARL\", \)$REV)/\1$NEW_REV)/" "$P"
grep -q "\"ARL\", $NEW_REV)" "$P" || die "OEM revision bump failed"

log "[4] drop references a standalone DSDT can't resolve (dead code, not behavioural)"
sed -i '/External (.*EFUN\.CRFI/d' "$P"
sed -i '/External (_SB_\.PC0[02]\.XHCI\._PS[03]\.PS[03]X,/d' "$P"
perl -0777 -i -pe 's/[ \t]*If \(CondRefOf \(PS0X\)\)\n[ \t]*\{\n[ \t]*PS0X \(\)\n[ \t]*\}\n//g' "$P"
perl -0777 -i -pe 's/[ \t]*If \(CondRefOf \(PS3X\)\)\n[ \t]*\{\n[ \t]*PS3X \(\)\n[ \t]*\}\n//g' "$P"

# ---------------------------------------------------------------- [3] compile
compile() { # $1 = dsl, $2 = target aml
    local base=${1%.dsl}
    # -on: keep the absolute \_SB.PC00.I2C2.TPL1.PWRR reference (the optimizer would
    # shorten it to a bare PWRR that mis-binds to the stock \_SB.PWRR method).
    if ! "$IASL" -on -p "$base" "$1" > "$base.log" 2>&1; then
        grep -i -E 'error' "$base.log" >&2; die "iasl compile failed for $1"
    fi
    errs=$(grep -o -E '[0-9]+ Errors' "$base.log" | head -1 | cut -d' ' -f1)
    [ "${errs:-0}" = 0 ] || die "iasl reported $errs errors"
    cp "$base.aml" "$2"
}

log "[5] compile $SKU"
compile "$P" "$OUT/dsdt.$SKU.aml"
diff -u "$WORK/stock.dsl" "$P" | sed "s#$WORK/##g" > "$OUT/fix.patch" || true

# ---------------------------------------------------------------- [4] Chinese variant
# Global and Chinese stock DSDTs differ only in six NVS base addresses (+0x00100000).
if [ "$SKU" = global ] && [ "$CHINESE" = 1 ]; then
    log "[6] derive Chinese-SKU variant (UNTESTED on Chinese hardware)"
    C=$WORK/chinese.dsl; cp "$P" "$C"
    for pair in "0x67E09018 0x67E19018" "0x67E13D18 0x67E23D18" "0x67E13F98 0x67E23F98" \
                "0x67E13018 0x67E23018" "0x67E13E98 0x67E23E98" "0x67DEC018 0x67DFC018"; do
        set -- $pair
        n=$(grep -cF "$1" "$C" || true)
        [ "$n" = 1 ] || die "expected one '$1' for the Chinese derivation, found $n — re-audit"
        sed -i "s/$1/$2/" "$C"
    done
    compile "$C" "$OUT/dsdt.chinese.aml"
fi

log "done:"
ls -l "$OUT"/*.aml | awk '{print "   " $NF " (" $5 " bytes)"}'
log "review $OUT/fix.patch, then install with tools/install.sh --only dsdt (or see dsdt/README.md)"
