# ACPI `_DSM` / device-init notes (FMB-P, BIOS 1.16)

Why this file exists: every device we still drive with an out-of-tree shim
(touchscreen, fan/EC, fingerprint) was traced back to its ACPI definition to
answer *"what does Windows do that we don't, and is anything missing?"*. The
short answer: **nothing is hidden.** Windows reads the same DSDT/SSDTs; it just
(a) runs a more permissive AML interpreter, (b) takes the `_OSI("Windows …")`
code path, and (c) ships vendor drivers that carry the per-device knowledge.
Our fixes are the Linux equivalents of those vendor drivers.

Tables were taken live from `/sys/firmware/acpi/tables/` and decompiled with
`iasl -d DSDT`. Line numbers below are from that disassembly (BIOS 1.16) and
will drift between firmware revisions — match on the method/name, not the line.

---

## The OS gate everything hangs off: `OSYS`

`_SB` sets a variable `OSYS` from whichever `_OSI("Windows …")` string answers
true, then branches on it in **~50 places**:

```asl
OSYS = 0x03E8                         // default ("no known Windows")
If (_OSI ("Windows 2015")) { OSYS = 0x07DF }   // + 8 earlier versions
...
If ((OSYS < 0x07DC)) { ...legacy init... }     // 0x07DC == "Windows 2012"
```

Linux's ACPICA spoofs the Windows strings, so `OSYS` ends up high (`0x07DF`) on
Linux too — i.e. Linux takes the *modern-Windows* branch. That matters below:
the modern branch frequently means *"the OS/vendor driver will do it"*, and on
Linux there is no vendor driver to pick up the slack.

---

## 1. Touchscreen — `\_SB.PC00.I2C2.TPL1` (`_HID "FTSC1000"`)

This device **does** have a `_DSM`, but it only hands out *resources* — it never
powers the panel. Power-up was delegated to the OS/vendor driver via the `OSYS`
gate, which is the gap our script fills.

### The `_DSM` (dispatch only)

```asl
Name (_S0W, 0x04)                       // can wake from S0 (S0ix)
Method (_DSM, 4, Serialized)
{
    If ((Arg0 == HIDG)) { Return (HIDD (Arg0, Arg1, Arg2, Arg3, HID2)) }  // HID-over-I2C
    If ((Arg0 == TP7G)) { Return (TP7D (Arg0, Arg1, Arg2, Arg3, SBFB, SBFG)) } // touch GPIO/I2C res
    Return (Buffer (One){ 0x00 })
}
```

Two UUIDs, both standard plumbing — **neither toggles power**:

| Key | UUID | What `_DSM` does |
|-----|------|------------------|
| `HIDG` | `3cdff6f7-4267-4555-ad05-b30a3d8938de` (HID-over-I2C) | Fn 0 → returns support bitmap `0x03`; Fn 1 → returns `HID2` = the **HID descriptor register address** (set to `1` in `_INI`). |
| `TP7G` | `ef87eb82-f951-46da-84ec-14871ac6f84b` | Fn 0 → `0x03`; Fn 1 → `ConcatenateResTemplate(SBFB, SBFG)` = the I²C-bus + GpioInt resources, concatenated. |

```asl
Method (HIDD, 5, Serialized) {            // shared HID-over-I2C handler
    If ((Arg0 == HIDG)) {
        If ((Arg2 == Zero) && (Arg1 == One)) { Return (Buffer(One){0x03}) } // funcs 0,1 supported
        If ((Arg2 == One)) { Return (Arg4) }   // Arg4 == HID2 == descriptor reg addr
    }
    Return (Buffer(One){0x00})
}
Method (TP7D, 6, Serialized) {            // hands back I2C+GPIO resources
    If ((Arg0 == TP7G)) {
        If ((Arg2 == Zero) && (Arg1 == One)) { Return (Buffer(One){0x03}) }
        If ((Arg2 == One)) { Return (ConcatenateResTemplate (Arg4, Arg5)) } // SBFB + SBFG
    }
    Return (Buffer(One){0x00})
}
```

### Where power *actually* should happen — `_INI`, and why it doesn't on Linux

```asl
Method (_INI, 0, NotSerialized)
{
    TPGI = T1GI
    If (CondRefOf (\_SB)) {
        If ((OSYS < 0x07DC)) { SRXO (TPGI, One) }   // <-- GPIO power/rx enable, LEGACY-Windows ONLY
        INT1 = GNUM (TPGI)
        INT2 = INUM (TPGI)
        ... SHPO (TPGI, …)                          // pad host-ownership
    }
    If ((TPLT == One)) { _HID = "FTSC1000"; HID2 = One; BADR = 0x38 }
}
Method (_STA, …) { If ((TPLT == One)) { Return (0x0F) } Return (Zero) }  // present iff TPLT==1
```

**The smoking gun:** `SRXO(TPGI, One)` — the call that drives the panel's GPIO
rail — is gated behind `OSYS < 0x07DC`. On modern Windows (and on Linux, which
spoofs modern Windows) that branch is **skipped**, on the assumption that the
precise-touch/vendor driver will power the controller itself. Windows' driver
does. Linux's generic `i2c_hid_acpi` does **not** drive vendor GPIOs, so the
controller stays unpowered and never ACKs on I²C.

→ **Our fix** (`fixes/touchscreen/`) is precisely the missing vendor step: drive
the GPIO lines high and call the panel's `_ON`, then bind `i2c_hid_acpi`. Also
note `_HID` is literally `"XXXX0000"` until `_INI` sets it to `"FTSC1000"` when
`TPLT==1` — so the device is invisible until init runs, another reason a clean
DSDT + correct init order matters. Upstream-clean would be a real
`PowerResource`/`_PS0` on the node (it has none) so `i2c_hid` powers it itself.

---

## 2. Fingerprint — there is **no `_DSM`** (it's a pure USB device)

The DSDT *does* contain a fingerprint node, but it's the wrong bus:

```asl
Scope (_SB.PC00.SPI1) {
  Device (FPNT) {
    Method (_HID, 0, …) {                 // SPI sensor menu, selected by EC byte FPTT
      If ((FPTT == One))  { Return ("FPC1011") }
      If ((FPTT == 0x02)) { Return ("FPC1020") }
      If ((FPTT == 0x03)) { Return ("VFSI6101") }
      If ((FPTT == 0x04)) { Return ("VFSI7500") }
      If ((FPTT == 0x05)) { Return ("EGIS0300") }
      If ((FPTT == 0x06)) { Return ("FPC1021") }
      Return ("DUMY0000")
    }
    Method (_INI, …) { SHPO (GFPI, One); SHPO (GFPS, One) }   // SPI/GPIO setup
    Method (_STA, …) { If ((FPTT != Zero) && (SPIP == One)) { Return (0x0F) } Return (Zero) }
  }
}
```

`FPNT` is a generic **SPI** fingerprint slot for other SKUs. On this unit
`FPTT == 0` (the EC reports no SPI sensor) → `_HID` resolves to `"DUMY0000"` and
`_STA` returns 0 (absent). The actual reader is **USB**:

```
/sys/bus/usb/devices/3-6 → idVendor=10a5 idProduct=9924   (FPC match-on-chip)
```

A USB device enumerates entirely from its own descriptors — **no ACPI, no
`_DSM`, no `_PS0` involved at all.** So there was never anything to "miss" in
firmware; the only place to fix it is the USB driver.

→ **Our fix** (`fixes/fingerprint/`) is a `libfprint`/`fpcmoc` patch: register
`10A5:9924` and trust the on-chip match for this firmware's `0x4` identity
token. Windows simply ships FPC's signed USB driver, which already knows the id.

---

## 3. Embedded Controller — `\_SB.PC00.LPCB.WTEC` (`_HID "PNP0C09"`) — no `_DSM`

```asl
Device (WTEC) {
    Name (_HID, EisaId ("PNP0C09"))      // Embedded Controller
    Method (_CRS, …) { ... IO 0x62 ; IO 0x66 ... }     // legacy EC command/data ports
    OperationRegion (ECF0, SystemMemory, 0xFE0B0000, 0xFF)   // <-- memory-mapped EC RAM, bank 0
    OperationRegion (ECF1, SystemMemory, 0xFE0B0100, 0xFF)   //     bank 1
    OperationRegion (ECF3, SystemMemory, 0xFE0B0300, 0xFF)   //     ...
    ...
    Field (ECF0, ByteAcc, Lock, Preserve) { EFMV,8, EFSV,8, EFTV,8, ... FPTT,8, ... }
}
```

The EC has **no `_DSM`** — devices don't negotiate with it that way. Two access
paths exist:

- **Legacy 0x62/0x66 IO** (declared in `_CRS`) — what `ec_sys` and the kernel's
  `acpi_ec` expose as the 256-byte EC address space. This is the space we dumped
  and diffed.
- **Memory-mapped banks at `0xFE0B0000 + 0x100·n`** — the same EC RAM the DSDT
  itself reads/writes (e.g. `FPTT`, the SPI-fingerprint selector above, lives in
  bank 0).

There is no firmware method that says "fan1 RPM is here" or "charge stop % is
here" — that mapping is **driver knowledge**, hardcoded in Huawei's Windows EC
driver. We recovered it by diffing EC RAM:

| Field | EC offset (0x62/0x66 space) |
|-------|------------------------------|
| fan1 RPM | `0x2C`/`0x2D` |
| fan2 RPM | `0x2E`/`0x2F` |
| charge start % | `0x80` |
| charge stop % | `0x81` |
| threshold enable flags | `0x85`, `0x87` |

→ **Our fixes**: `fixes/fan/` (`honor-fmbp-hwmon` reads `0x2C–0x2F`) and
`fixes/battery/` (thresholds via `huawei-wmi`, which flips `0x80/0x81/0x85/0x87`).

---

## Conclusion

- **Touchscreen** — has a `_DSM`, but it only returns descriptors/resources; the
  power step (`SRXO`) is `OSYS`-gated to legacy Windows and otherwise left to the
  vendor driver. No `PowerResource`/`_PS0` on the node → Linux can't auto-power
  it. *(Our GPIO `_ON` script = the missing vendor power-up.)*
- **Fingerprint** — pure USB (`10a5:9924`); the ACPI `FPNT` node is an inactive
  SPI slot. No `_DSM` is involved at all. *(Our libfprint patch = the missing
  USB driver.)*
- **EC** — no `_DSM`; register meanings are driver knowledge, recovered by RAM
  diffing. *(Our hwmon module + WMI thresholds = the missing EC driver.)*

So: no second firmware "base", nothing hidden. Windows wins out-of-the-box on a
lenient AML interpreter, the `_OSI` Windows branch, and a stack of signed vendor
drivers — and we've reproduced each of those through the proper Linux mechanism.
The clean long-term fixes are upstream: a real touchscreen `PowerResource`,
`huawei-wmi` keymap + thresholds, and the `fpcmoc` id/`0x4` handling.

*Decompiled and annotated with the help of an LLM, cross-checked against the
live `/sys/firmware/acpi/tables` dump on real hardware.*
