#!/bin/bash
set -euo pipefail
TARGET_READELF=${TARGET_READELF:-"$HOST_DIR/bin/armv7-nerves-linux-gnueabihf-readelf"}
staging="$BUILD_DIR/expressatt-initramfs"
boot="$BUILD_DIR/expressatt-boot"
rm -rf "$staging" "$boot"
mkdir -p "$staging"/{bin,sbin,usr/bin,usr/sbin,lib,etc,proc,sys,dev,run,newroot} "$boot/extlinux"
install -m 0755 "$NERVES_DEFCONFIG_DIR/initramfs/init" "$staging/init"
install -m 0755 "$NERVES_DEFCONFIG_DIR/initramfs/read-layout" "$staging/sbin/read-layout"
install -m 0644 "$NERVES_DEFCONFIG_DIR/rootfs_overlay/etc/fw_env.config" "$staging/etc/fw_env.config"
if [ ! -e "$staging/dev/console" ]; then
    mknod -m 0600 "$staging/dev/console" c 5 1
fi
declare -A copied=()
copy_binary() {
    local input=$1 destination=$2 resolved needed library interpreter
    resolved=$(realpath -e "$input")
    case "$resolved" in "$TARGET_DIR"/*) ;; *) echo "ELF outside target: $input" >&2; exit 1 ;; esac
    install -D -m 0755 "$resolved" "$staging$destination"
    [ -z "${copied[$resolved]:-}" ] || return 0
    copied[$resolved]=yes
    while IFS= read -r needed; do
        library=
        for candidate in "$TARGET_DIR/lib/$needed" "$TARGET_DIR/usr/lib/$needed"; do
            if [ -f "$candidate" ]; then library=$candidate; break; fi
        done
        [ -n "$library" ] || { echo "Missing ELF dependency $needed" >&2; exit 1; }
        copy_binary "$library" "/lib/$needed"
    done < <("$TARGET_READELF" -d "$resolved" | sed -n 's/.*(NEEDED).*\[\(.*\)\].*/\1/p')
    interpreter=$("$TARGET_READELF" -l "$resolved" | sed -n 's/.*Requesting program interpreter: \(.*\)\].*/\1/p')
    if [ -n "$interpreter" ]; then copy_binary "$TARGET_DIR$interpreter" "$interpreter"; fi
}
copy_binary "$TARGET_DIR/bin/busybox" /bin/busybox
dmsetup=
for candidate in "$TARGET_DIR/sbin/dmsetup" "$TARGET_DIR/usr/sbin/dmsetup"; do
    if [ -f "$candidate" ]; then dmsetup=$candidate; break; fi
done
[ -n "$dmsetup" ] || { echo "dmsetup missing" >&2; exit 1; }
copy_binary "$dmsetup" /sbin/dmsetup
copy_binary "$TARGET_DIR/usr/sbin/fw_printenv" /sbin/fw_printenv
for applet in sh mount cat sleep ln sync reboot switch_root hexdump mkdir; do ln -sf busybox "$staging/bin/$applet"; done
(cd "$staging" && find . -print0 | sort -z | cpio --null -o -H newc --owner 0:0) | gzip -n > "$BINARIES_DIR/initramfs.gz"
install -m 0644 "$BINARIES_DIR/zImage" "$boot/zImage"
install -m 0644 "$BINARIES_DIR/qcom-msm8960-samsung-expressatt.dtb" "$boot/qcom-msm8960-samsung-expressatt.dtb"
install -m 0644 "$BINARIES_DIR/initramfs.gz" "$boot/initramfs.gz"
install -m 0644 "$NERVES_DEFCONFIG_DIR/extlinux/extlinux.conf" "$boot/extlinux/extlinux.conf"
"$HOST_DIR/bin/genext2fs" -B 1024 -b 65536 -d "$boot" "$BINARIES_DIR/boot.img"
