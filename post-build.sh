#!/bin/sh
set -eu
mkdir -p "$TARGET_DIR/usr/share/fwup"
"$HOST_DIR/bin/fwup" -c -f "$NERVES_DEFCONFIG_DIR/fwup-ops.conf" -o "$TARGET_DIR/usr/share/fwup/ops.fw"
ln -sf ops.fw "$TARGET_DIR/usr/share/fwup/revert.fw"
cp -R "$NERVES_DEFCONFIG_DIR/fwup_include" "$BINARIES_DIR/"
chmod 0755 "$TARGET_DIR/usr/lib/expressatt/validate-running"
# The kernel belongs to the selected boot image, not the squashfs.
rm -f "$TARGET_DIR/boot/zImage"
