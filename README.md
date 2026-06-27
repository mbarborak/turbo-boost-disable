# Turbo Boost Disable for macOS

Disable Intel Turbo Boost on macOS Tahoe (and earlier) to reduce heat, fan noise, and battery drain.

Works by loading a minimal kernel extension that sets bit 38 of MSR `0x1A0` (`IA32_MISC_ENABLE`) on all CPU cores.

## Requirements

- Intel Mac (tested on i7-9750H)
- macOS with Xcode Command Line Tools installed
- SIP partially disabled (see below)

## SIP Configuration

You must allow unsigned kext loading. Boot into Recovery Mode:

1. Shut down your Mac
2. Hold **Cmd+R** while powering on (Intel) to boot into Recovery Mode
3. Open **Terminal** from the Utilities menu
4. Run:
   ```
   csrutil enable --without kext
   ```
5. Reboot

This keeps most SIP protections intact but allows loading unsigned kernel extensions.

To restore full SIP later:
```
csrutil enable
```

## Build

```
make
```

## Usage

```bash
# Check current state
sudo ./turbo-boost.sh status

# Disable Turbo Boost
sudo ./turbo-boost.sh disable

# Re-enable Turbo Boost
sudo ./turbo-boost.sh enable

# Show CPU info
sudo ./turbo-boost.sh info
```

### Install to /Library/Extensions

To load the kext automatically or persist across sessions:

```bash
make install    # copies kext, sets permissions, loads it
make uninstall  # unloads and removes
```

### Manual kext control

```bash
make load       # load from local build directory
make unload     # unload
```

## Verification

After disabling Turbo Boost:

```bash
# Check thermal level
sysctl machdep.xcpm.cpu_thermal_level

# Monitor CPU frequency (should not exceed base clock)
sudo powermetrics -s cpu_power -n 1
```

## How It Works

The kext writes to the `IA32_MISC_ENABLE` MSR (Model-Specific Register) on each CPU core using `mp_rendezvous_no_intrs` to ensure all cores are updated atomically. Bit 38 is the Turbo Boost disable bit defined by Intel.

- **Loading** the kext sets bit 38 → Turbo Boost off
- **Unloading** the kext clears bit 38 → Turbo Boost on

No background processes run. The MSR state persists until the kext is unloaded or the machine reboots (at which point Turbo Boost returns to its default enabled state).

## Troubleshooting

**"kext not found"** — Run `make` first to build the kext.

**"Failed to load kext"** — Check that SIP is configured to allow kext loading (`csrutil status`).

**Kext won't load on Apple Silicon** — This utility only works on Intel Macs. Apple Silicon does not use Intel MSRs.
