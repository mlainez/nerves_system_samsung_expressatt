#!/bin/sh
set -eu
"$HOST_DIR/bin/fakeroot" -- "$NERVES_DEFCONFIG_DIR/scripts/create-boot-img.sh"
"$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh" "$TARGET_DIR" "$NERVES_DEFCONFIG_DIR/fwup.conf"
