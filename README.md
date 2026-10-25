# Samsung Galaxy Express SGH-I437 Nerves system

This development system targets samsung-expressatt/MSM8960 with nerves_system_br
1.35.3 and the official armv7 hard-float glibc toolchain 15.3.0. There is no
ExpressATT binary release.

The development phone has booted persistent Nerves with USB IEx/SSH, Wi-Fi
scanning and WPA2 association, USB charging, native firmware upload, validation
and revert. These results are recorded in the local port backlog; publishing
source does not repeat hardware acceptance. Factory-reset acceptance remains
open. This is not a stock-to-Nerves installer or a finished general-purpose BSP.

## Build dependencies

Use the versions in `.tool-versions`: Elixir 1.20.4, OTP 29.0.2 and fwup 1.16.0,
plus nerves_bootstrap and the standard Nerves Linux build prerequisites.
Heimdall and Fastboot are needed for the existing device recovery workflow.

Clone the system:

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
`mix firmware`. Tagged releases carry a prebuilt system artifact that Nerves
downloads from this repository's GitHub releases; any other commit builds the
system locally. The application must provide supervised board startup to select the
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

The kernel patches target the firmware this phone's stock SYSTEM carries, API
1.2.2.15 with packed MDT program headers; see `linux-patches/`. The firmware
set shipped in public vendor-blob repositories for this phone is a different,
unsigned build and is not used.

## Storage and boot

All offsets are 512-byte sectors inside existing USERDATA (/dev/mmcblk0p15).
The Android GPT/PIT stays untouched; no whole eMMC or boot-chain writes occur.
The current MBR layout (local port decision-7) is:

| Region | Start | Count |
|---|---:|---:|
| Redundant environment 0/1 | 2048/2304 | 256 each |
| ext2 boot A/B | 4096/135168 | 131072 each |
| gzip squashfs root A/B | 266240/790528 | 524288 each |
| Fixed f2fs application | 1314816 | 9392128 |
| Reserved tail | 10706944 | 32768 |

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
Buildroot 10.0.42.x/Dropbear/ACM policy does not carry over. A supervised board
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
