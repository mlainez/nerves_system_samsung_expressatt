# Samsung Galaxy Express SGH-I437 Nerves system

This development system targets samsung-expressatt/MSM8960. It derives from
official nerves_system_bbb, using nerves_system_br 1.35.0 and the official armv7
hard-float glibc toolchain 15.3.0. The existing version number and BeagleBone
changelog are inherited from that template; there is no ExpressATT binary release.

The development phone has booted persistent Nerves with USB IEx/SSH, Wi-Fi
scanning and WPA2 association, USB charging, native firmware upload, validation
and revert. These results are recorded in the local port backlog; publishing
source does not repeat hardware acceptance. Factory-reset acceptance remains
open. This is not a stock-to-Nerves installer or a finished general-purpose BSP.

## Build dependencies

Use the versions in `.tool-versions`: Elixir 1.20.4, OTP 29.0.2 and fwup 1.16.0,
plus nerves_bootstrap and the standard Nerves Linux build prerequisites.
The Buildroot firmware extractor also needs Bash, Python 3.10+, e2fsprogs
(`debugfs`), GNU coreutils and verified original SYSTEM/PERSIST backups.
Heimdall and Fastboot are needed for the existing device recovery workflow.

Clone the system and prepare the private firmware described below:

```sh
git clone https://github.com/mlainez/nerves_system_samsung_expressatt.git
cd nerves_system_samsung_expressatt
mix deps.get
mix nerves.system.lint nerves_defconfig
```

Generate an application with `mix nerves.new`, then add this system to its
target-specific dependencies (replace the example path with your clone):

```elixir
{:nerves_system_samsung_expressatt,
 path: "../nerves_system_samsung_expressatt", runtime: false}
```

In the application, set `MIX_TARGET=samsung_expressatt` for `mix deps.get` and
`mix firmware`. There are no downloadable system artifacts; the system builds
locally. The application must provide supervised board startup to select the
verified USB-host charging mode, load the WCNSS modules and wait for the memory
clock driver's READY state before validation. VintageNet owns Wi-Fi credentials
and networking. Those application services are separate from this system package.

Kernel base: Linux 7.2.9, commit `5fce161649b4d779d1b76d9fcd52dc77779774b8`.
The hardware patches omit SCM diagnostic/SDI experiments. linux.config and
linux-nerves.fragment provide gzip squashfs, f2fs, fixed device-mapper root
slices, standard g_ether and the hardware watchdog.

CONFIG_EXPRESSATT_CPU1_CLOCK restores CPU1's fixed 384 MHz PLL8 clock before
userspace on this board, retaining its clock references until reboot. CPU hotplug,
idle, suspend and frequency transitions are excluded because they need a separate
clock lifecycle. CONFIG_EXPRESSATT_MEMORY_CLOCK acquires and retains the board's
MEM/DIG regulator references, verifies active memory-bus floors, and restores the
shared-cache clock through the reviewed vendor mux sequence. Its asynchronous
handoff publishes READY only after verified postconditions; the application waits
for that state before allowing StartupGuard validation. Failure retains resources
until reboot and prevents validation. Host tests do not establish charging or
cold-boot behavior on another phone.

## Private firmware

`firmware/` is ignored and non-redistributable. Use the
[Buildroot board extractor](https://github.com/Spin42/buildroot-android/blob/samsung-expressatt/buildroot-external/board/samsung-expressatt/scripts/prepare_firmware.sh)
for the five original SYSTEM WCNSS files and stock-layout, same-phone NV
projection. In a checkout of buildroot-android's `samsung-expressatt` branch, run:

```sh
buildroot-external/board/samsung-expressatt/scripts/prepare_firmware.sh \
  /absolute/path/to/verified-backups /absolute/path/to/nerves_system_samsung_expressatt/firmware
```

The backups directory must contain `system.img`, `persist.img` and their
`SHA256SUMS`. The projector currently accepts only the original development
phone's verified NV identity. Another SGH-I437 needs a reviewed calibration
identity/schema; never reuse a different phone's calibration.

Create the manifest consumed by the system package inside `firmware/`:

```sh
sha256sum wcnss.mdt wcnss.b00 wcnss.b01 wcnss.b02 wcnss.b04 \
  wlan/prima/WCNSS_qcom_wlan_nv.bin > SHA256SUMS
sha256sum --check SHA256SUMS
```

The package verifies this manifest before installing. No PERSIST write or
build-time Wi-Fi credentials are needed. Firmware images and system archives
contain private calibration and must remain local. Public CI checks source only.

## Storage and boot

All offsets are512-byte sectors inside existing USERDATA (/dev/mmcblk0p15).
The Android GPT/PIT stays untouched; no whole eMMC or boot-chain writes occur.
The current MBR layout (local port decision-7) is:

| Region | Start | Count |
|---|---:|---:|
| Redundant environment0/1 |2048/2304|256each|
| ext2 bootA/B |4096/135168|131072each|
| gzip squashfs rootA/B |266240/790528|524288each|
| Fixed f2fs application |1314816|9392128|
| Reserved tail |10706944|32768|

Ordinary lk2nd reads extlinux from the first nested MBR partition. Firmware
upgrade and revert tasks switch the paired boot/root MBR entries, as in the FP2
and FP3 systems. The application extent and reserved tail never move. Initramfs
validates the two permitted MBR layouts, maps stable nerves_root_a/b and nerves_app
devices, and records the selected slot's redundant-environment UUID under /dev/.nerves.
Validation compares that boot-time proof with current metadata; extlinux carries
no custom slot or UUID arguments. The MBR is the boot selector, while environment
metadata describes firmware versions and pending operations.

The explicit migrate.b task accepts only the old layout with validated running A
and writes new B boot/root before switching metadata and MBR. It preserves old A
and application data. Normal upgrades require the new expressatt-mbr-v1 layout.
Old A remains a legacy recovery slot until a later upgrade replaces it; its old
ops archive does not implement the new layout's maintenance operations.

StartupGuard and nerves_heart retain normal Nerves userspace validation/recovery.
There is no custom lk2nd attempted-UUID protocol or promise of automatic recovery
from a kernel that never reaches userspace. MBR/environment updates are separate
writes; interrupted operations may require the proven Odin/rescue recovery path.
No blanket power-cut safety is claimed.

## Networking and startup

Standard nerves_pack/VintageNetDirect USB networking, credential-free
VintageNetWiFi and generated public-key SSH use a unique board hostname.
Buildroot10.0.42.x/Dropbear/ACM policy does not carry over. A supervised board
service selects proven USB-host charging and loads radio modules; VintageNet
owns link configuration and scanning.

The wcn36xx association serializer selects legacy STA/BSS messages for exact
firmware 1.2.2.15. Its BSS wire payload ends after the persona and spectrum fields,
excluding the two trailing transmit-power fields. This follows the original
stock driver's 105-byte STA and 459-byte BSS payloads; firmware 1.2.2.24 and other
revisions retain their existing wire representation. Source and binary evidence
is recorded in the port's PORT-71-association-wire-review evidence. Host serializer
tests establish compatibility of the projection. WPA2 association and native
SSH over Wi-Fi were also verified on the development phone.

The installed trusted ops.fw uses a fixed validate-running helper to compare
initramfs slot/UUID proof against metadata. FwupOps needs --unsafe for this local
requirement; firmware upload policy is unchanged. Host file-image tests, the
system linter, real IEx/USB/Wi-Fi, native upload, validation and revert have been
exercised in the local port. Factory reset remains an open hardware acceptance check.

## Installation and recovery

The proven boot path uses the original Samsung bootloader and an Express-specific
lk2nd build in BOOT. That loader's source and binaries are not part of this
repository. Device installation currently depends on the original porting kit's
guard, serial/product checks, verified BOOT/USERDATA backups and immutable
working Buildroot/lk2nd rollback artifacts. Back up the original firmware and
device-specific partitions before preparing a device. Do not flash this system's
`boot.img` to physical BOOT: it is a nested ext2 image for fwup inside USERDATA.

No one-command installer is published here. Interrupted metadata/MBR operations
can require Odin and the proven rescue path. The original bootloader chain and
Android partition table must remain intact.
