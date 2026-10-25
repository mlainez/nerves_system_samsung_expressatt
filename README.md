# Samsung Galaxy Express SGH-I437 Nerves system

This development system targets samsung-expressatt/MSM8960 with nerves_system_br
1.35.3 and the official armv7 hard-float glibc toolchain 15.3.0.

It has been run on a development phone with USB IEx/SSH, Wi-Fi scanning and
WPA2 association, USB charging, native firmware upload, validation and revert.
Factory reset has not been tested on hardware. This is not a stock-to-Nerves
installer or a finished general-purpose BSP.

## Using

Use the versions in `.tool-versions`: Elixir 1.20.4, OTP 29.0.2 and fwup 1.16.0,
plus nerves_bootstrap. Generate an application with `mix nerves.new`, then add
this system to its target-specific dependencies:

```elixir
{:nerves_system_samsung_expressatt,
 github: "mlainez/nerves_system_samsung_expressatt",
 tag: "v0.1.0",
 runtime: false,
 targets: :samsung_expressatt}
```

Set `MIX_TARGET=samsung_expressatt` for `mix deps.get` and `mix firmware`.
Tagged releases carry a prebuilt system artifact that Nerves downloads from
this repository's GitHub releases. Any other commit builds the system locally
with the standard Nerves Linux build prerequisites:

```sh
git clone https://github.com/mlainez/nerves_system_samsung_expressatt.git
cd nerves_system_samsung_expressatt
mix deps.get
mix nerves.system.lint nerves_defconfig
```

The application must provide supervised board startup to select the USB-host
charging mode, load the WCNSS modules and wait for the memory clock driver's
READY state before validation. VintageNet owns Wi-Fi credentials and
networking. Those application services are separate from this system package.

## Kernel

Kernel base: Linux 7.2.9, commit `5fce161649b4d779d1b76d9fcd52dc77779774b8`,
with the board patches in `linux-patches/`. linux.config and
linux-nerves.fragment provide gzip squashfs, f2fs, ext4 for the stock
partitions, fixed device-mapper root slices, standard g_ether and the hardware
watchdog.

CONFIG_EXPRESSATT_CPU1_CLOCK restores CPU1's fixed 384 MHz PLL8 clock before
userspace on this board, retaining its clock references until reboot. CPU hotplug,
idle, suspend and frequency transitions are excluded because they need a separate
clock lifecycle. CONFIG_EXPRESSATT_MEMORY_CLOCK acquires and retains the board's
MEM/DIG regulator references, verifies active memory-bus floors, and restores the
shared-cache clock through the vendor mux sequence. Its asynchronous handoff
publishes READY only after verified postconditions; the application waits for
that state before allowing StartupGuard validation. Failure retains resources
until reboot and prevents validation.

## Firmware

The system ships no WCNSS firmware. The RIVA Wi-Fi image is a Qualcomm/Samsung
file that may not be redistributed, and the NV calibration is unique to each
phone. Both are already on the phone, on stock partitions this system never
writes: `system` (mmcblk0p14) holds `/etc/firmware/wcnss.*` and `persist`
(mmcblk0p16) holds the raw `WCNSS_qcom_wlan_nv.bin`.

erlinit runs `/usr/sbin/expressatt-bringup` before Erlang starts. It mounts
each partition read-only with `noload` only long enough to copy the files into
`/run/firmware`, projects the raw calibration into the layout wcn36xx expects
(the first 28456 bytes with the firmware configuration defaults inserted at
offset 27084, as stock vos_nv_open does), unmounts again and points
`firmware_class.path` at `/run/firmware`. The script logs to the kernel ring
buffer (`dmesg | grep expressatt-bringup`) and always exits 0, so a phone with
unusable firmware still boots without Wi-Fi. The shipped regulatory database
stays in `/lib/firmware`.

The kernel patches target the firmware the stock SYSTEM partition carries, API
1.2.2.15 with packed MDT program headers. The firmware set in public
vendor-blob repositories for this phone is a different, unsigned build and is
not used.

## Storage and boot

All offsets are 512-byte sectors inside the existing USERDATA partition
(/dev/mmcblk0p15). The Android GPT/PIT stays untouched; no whole eMMC or
boot-chain writes occur. The nested MBR layout is:

| Region | Start | Count |
|---|---:|---:|
| Redundant environment 0/1 | 2048/2304 | 256 each |
| ext2 boot A/B | 4096/135168 | 131072 each |
| gzip squashfs root A/B | 266240/790528 | 524288 each |
| Fixed f2fs application | 1314816 | 9392128 |
| Reserved tail | 10706944 | 32768 |

lk2nd reads extlinux from the first nested MBR partition. Firmware upgrade and
revert tasks switch the paired boot/root MBR entries, as in the Fairphone 2 and
3 systems. The application extent and reserved tail never move. The initramfs
accepts only the A and B layouts, maps stable nerves_root_a/b and nerves_app
devices, and records the selected slot's environment UUID under /dev/.nerves.
Validation compares that boot-time record with current metadata; extlinux
carries no custom slot or UUID arguments. The MBR is the boot selector, while
environment metadata describes firmware versions and pending operations.

StartupGuard and nerves_heart provide normal Nerves userspace validation and
recovery. There is no automatic recovery from a kernel that never reaches
userspace. MBR and environment updates are separate writes; an interrupted
operation may require reflashing with Odin. No power-cut safety is claimed.

## Networking

Standard nerves_pack/VintageNetDirect USB networking, credential-free
VintageNetWiFi and public-key SSH use a unique board hostname. A supervised
board service in the application selects USB-host charging and loads the radio
modules; VintageNet owns link configuration and scanning.

The wcn36xx association serializer selects legacy STA/BSS messages for exact
firmware 1.2.2.15. Its BSS wire payload ends after the persona and spectrum fields,
excluding the two trailing transmit-power fields. This follows the stock
driver's 105-byte STA and 459-byte BSS payloads; firmware 1.2.2.24 and other
revisions retain their existing wire representation.

The installed ops.fw uses the fixed `validate-running` helper to compare the
initramfs slot/UUID record against metadata, so FwupOps needs `--unsafe`:

```elixir
config :nerves_runtime, fwup_extra_options: ["--unsafe"]
```

## Installation and recovery

The boot path uses the original Samsung bootloader and an Express-specific
lk2nd build in BOOT. That loader's source and binaries are not part of this
repository, and no installer is published here. Back up the original firmware
and device-specific partitions (at least `efs`, `persist`, `modemst1`,
`modemst2` and `fsg`) before preparing a device. Do not flash this system's
`boot.img` to physical BOOT: it is a nested ext2 image for fwup inside
USERDATA. The original bootloader chain and Android partition table must
remain intact; Heimdall or Odin can restore stock partitions.
