#!/bin/bash

# set -uex
set -ue

. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/vdp1.sh
. include/memmap.sh
. include/charcode.sh
. src/vars_map.sh
. src/funcs_map.sh
. src/vdp.sh
. src/con.sh

VRAM_CMD_SIZE_HEX=$(calc16_4 "${SS_VDP1_COMMAND_SIZE}*64")	# 0x0c80
VRAM_CPT_BASE=$(calc16_8 "${SS_VDP1_VRAM_ADDR}+${VRAM_CMD_SIZE_HEX}")	# 0x05c00c80
INIT_SP=06004000
PROGRAM_ENTRY_ADDR=06004000

# 出力する座標
OUTPUT_X1=10
OUTPUT_Y1=10
OUTPUT_X2=10
OUTPUT_Y2=20

# コマンドテーブル設定
# work: r0* - put_file_to_addr,copy_to_reg_from_val_long,この中の作業用
#     : r1* - put_file_to_addrの作業用
#     : r2* - put_file_to_addrの作業用
# ※ *が付いているレジスタはこの関数で書き換えられる
setup_vram_command_table() {
	# 05c00000
	local com_adr=$SS_VDP1_VRAM_ADDR
	vdp1_command_system_clipping_coordinates >src/system_clipping_coordinates.o
	put_file_to_addr src/system_clipping_coordinates.o $com_adr

	# 05c00020
	com_adr=$(calc16 "$com_adr+20")
	vdp1_command_user_clipping_coordinates >src/user_clipping_coordinates.o
	put_file_to_addr src/user_clipping_coordinates.o $com_adr

	# 05c00040
	com_adr=$(calc16 "$com_adr+20")
	vdp1_command_local_coordinates >src/local_coordinates.o
	put_file_to_addr src/local_coordinates.o $com_adr

	# r1へ次にコマンドを配置するVRAMアドレスを設定
	copy_to_reg_from_val_long r1 $VRAM_DRAW_CMD_BASE

	# r1のアドレス先へ描画終了コマンドを配置
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
}

# カラールックアップテーブル設定
# work: r0* - copy_to_reg_from_val_longの作業用
#     : r1* - この中の作業用
# ※ *が付いているレジスタはこの関数で書き換えられる
setup_vram_color_lookup_table() {
	# 配置先アドレスをr1へ設定
	copy_to_reg_from_val_long r1 $VRAM_CLT_BASE

	# | 0 | 透明 | 0x0000 |
	sh2_xor_to_reg_from_reg r0 r0
	sh2_copy_to_ptr_from_reg_word r1 r0

	# | 1 | 白   | 0xffff |
	sh2_add_to_reg_from_val_byte r1 02
	sh2_set_reg r0 ff
	sh2_copy_to_ptr_from_reg_word r1 r0

	# | 2 | 透明 | 0x0000 |
	# | : |  :   |   :    |
	# | f | 透明 | 0x0000 |
	sh2_xor_to_reg_from_reg r0 r0
	local _i
	for _i in $(seq 2 15); do
		sh2_add_to_reg_from_val_byte r1 02
		sh2_copy_to_ptr_from_reg_word r1 r0
	done
}

# メイン関数
# work: r0*  - copy_to_reg_from_val_long,setup_vram_command_table,
#              setup_vram_color_lookup_table,この中の作業用
#     : r1*  - setup_vram_command_table,setup_vram_color_lookup_table,
#              この中の作業用
#     : r2*  - setup_vram_command_table,この中の作業用
#     : r3*  - vdp_initの作業用
#     : r4*  - vdp_initの作業用
# ※ *が付いているレジスタはこの関数で書き換えられる
main() {
	# スタックポインタ(r15)の初期化
	copy_to_reg_from_val_long r15 $INIT_SP

	# VRAM初期設定
	setup_vram_command_table
	setup_vram_color_lookup_table

	# VDP1/2の初期化
	vdp_init

	# 関数のアドレスをr2へ設定
	copy_to_reg_from_val_long r2 $a_putchar

	# 'A'-'Z'を1文字ずつ出力
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_A
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_B
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_C
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_D
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_E
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_F
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_G
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_H
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_I
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_J
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_K
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_L
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_M
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_N
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_O
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_P
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_Q
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_R
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_S
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_T
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_U
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_V
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_W
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_X
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_Y
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r1 $CHARCODE_Z

	# 描画終了コマンドを配置
	copy_to_reg_from_val_long r1 $var_next_vdpcom_addr
	sh2_copy_to_reg_from_ptr_long r1 r1
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r1 r0

	# 無限ループ
	infinite_loop
}

make_bin() {
	local file_sz
	local area_sz
	local pad_sz

	# メインプログラム領域へジャンプ(32バイト)
	(
		copy_to_reg_from_val_long r1 $MAIN_BASE
		sh2_abs_jump_to_reg_after_next_inst r1
		sh2_nop
		sh2_nop	# jmp_main.oのサイズを4の倍数にするためのパディング
	) >src/jmp_main.o
	cat src/jmp_main.o

	# 変数領域
	cat src/vars.o
	file_sz=$(stat -c '%s' src/vars.o)
	area_sz=$(echo "ibase=16;$FUNCS_BASE - $VARS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	if [ $pad_sz -lt 0 ]; then
		echo 'Error: variable area overflow.' 1>&2
		exit 1
	fi
	cat <<EOF 1>&2
[variable area (unit: byte)]
- size : $area_sz
- used : $file_sz
- avail: $pad_sz
EOF
	dd if=/dev/zero bs=1 count=$pad_sz

	# 関数領域
	cat src/funcs.o
	file_sz=$(stat -c '%s' src/funcs.o)
	area_sz=$(echo "ibase=16;$MAIN_BASE - $FUNCS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	if [ $pad_sz -lt 0 ]; then
		echo 'Error: function area overflow.' 1>&2
		exit 1
	fi
	cat <<EOF 1>&2
[function area (unit: byte)]
- size : $area_sz
- used : $file_sz
- avail: $pad_sz
EOF
	dd if=/dev/zero bs=1 count=$pad_sz

	# メインプログラム領域
	main
}

make_bin
