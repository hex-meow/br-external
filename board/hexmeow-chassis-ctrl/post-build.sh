#!/bin/sh
export CUR_DIR=$BR2_EXTERNAL_HEX_EMBEDDED_PATH/board/hexmeow-chassis-ctrl
$HOST_DIR/bin/rk-mkimage -C none -A arm -T script -n 'load script' -d $CUR_DIR/boot.cmd $TARGET_DIR/boot/boot.scr
cp $CUR_DIR/design_1_wrapper.bit $TARGET_DIR/boot/design_1_wrapper.bit