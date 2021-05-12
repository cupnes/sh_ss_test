#!/bin/bash

# set -uex
set -ue

. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/vdp1.sh
. include/memmap.sh
. src/vars_map.sh
. src/funcs_map.sh

VRAM_DRAW_CMD_BASE=05C00060
VRAM_CMD_SIZE_HEX=$(calc16_4 "${SS_VDP1_COMMAND_SIZE}*64")	# 0x0c80
VRAM_CPT_BASE=$(calc16_8 "${SS_VDP1_VRAM_ADDR}+${VRAM_CMD_SIZE_HEX}")	# 0x05c00c80
VRAM_CLT_BASE=05C00F00
INIT_SP=06004000
PROGRAM_ENTRY_ADDR=06004000

# マスの大きさ[px]
# ※ sh2_set_reg()でそのまま設定する
# 　 マイナスで符号拡張しないように0x80未満であること
SQUARE_WIDTH=10	# 16
SQUARE_HEIGHT=10	# 16

# コマンドテーブル設定
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

# キャラクタパターンテーブル設定
setup_vram_character_pattern_table() {
	local sz

	# r1へコピー先のVRAMアドレス設定
	copy_to_reg_from_val_long r1 $VRAM_CPT_BASE

	# r2へコピー元のデータアドレス設定
	copy_to_reg_from_val_long r2 $var_char_pat_tbl_dat

	# r3へテクスチャファイルのバイト数設定
	# ※ バイト数 <= 32767 であること
	local sz_hex=$(four_digits_d $(stat -c '%s' character.lut))
	sh2_set_reg r0 $(echo $sz_hex | cut -c1-2)
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte $(echo $sz_hex | cut -c3-4)
	sh2_copy_to_reg_from_reg r3 r0

	# f_memcpy()を実行する
	copy_to_reg_from_val_long r4 $a_memcpy
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop
}

# カラールックアップテーブル設定
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

main() {
	# スタックポインタ(r15)の初期化
	copy_to_reg_from_val_long r15 $INIT_SP

	# VRAM初期設定
	setup_vram_command_table
	setup_vram_character_pattern_table
	setup_vram_color_lookup_table

	# VDP2のシステムレジスタ設定
	## TVMD
	## - DISP(b15) = 1
	## - BDCLMD(b8) = 1
	## - LSMD(b7-b6) = 0b00
	## - VRESO(b5-b4) = 0b00
	## - HRESO(b2-b0) = 0b000
	copy_to_reg_from_val_long r4 $SS_VDP2_TVMD_ADDR
	sh2_set_reg r0 81
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r4 r0
	## BGON
	sh2_add_to_reg_from_val_byte r4 20
	sh2_set_reg r0 00
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r4 r0
	## PRISA
	sh2_add_to_reg_from_val_byte r4 68
	sh2_add_to_reg_from_val_byte r4 68
	sh2_set_reg r0 06
	sh2_copy_to_ptr_from_reg_word r4 r0

	# VDP1のシステムレジスタ設定
	## TVMR
	## - VBE(b3) = 0
	## - TVM(b2-b0) = 0b000
	copy_to_reg_from_val_long r3 $SS_VDP1_TVMR_ADDR
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r3 r0
	## FBCR(TVMRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_copy_to_ptr_from_reg_word r3 r0
	## PTMR(FBCRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	## PTM(b1-b0) = 0b10
	sh2_set_reg r0 02
	sh2_copy_to_ptr_from_reg_word r3 r0
	## EWDR(PTMRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r3 r0
	## EWLR(EWDRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_set_reg r0 00
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r3 r0
	## EWRR(EWLRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_set_reg r0 50
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte df
	sh2_copy_to_ptr_from_reg_word r3 r0

	# EDSRのアドレスをスタックへ積んでおく
	copy_to_reg_from_val_long r1 $SS_VDP1_EDSR_ADDR
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1

	# メインループ
	(
		# 描画終了を待つ
		(
			# r1へEDSRのアドレスを取得
			sh2_copy_to_reg_from_ptr_long r1 r15
			# r1の指す先(EDSRの内容)をr0へ取得
			sh2_copy_to_reg_from_ptr_word r0 r1
			sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
		) >src/main.2.o
		cat src/main.2.o
		local sz_2=$(stat -c '%s' src/main.2.o)
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_2) / 2)))
		sh2_nop
		## 論理積結果がゼロのとき、
		## 即ちTビットがセットされたとき、
		## 待つ処理を繰り返す

		# VRAM更新処理

		# r1へ次にコマンドを配置するVRAMアドレスを設定
		copy_to_reg_from_val_long r1 $VRAM_DRAW_CMD_BASE

		# 矩形スプライト
		copy_to_reg_from_val_long r2 $var_character_x
		sh2_copy_to_reg_from_ptr_long r2 r2
		sh2_set_reg r0 $SQUARE_WIDTH
		sh2_multiply_reg_by_reg_unsigned_word r2 r0
		sh2_copy_to_reg_from_macl r2
		copy_to_reg_from_val_long r3 $var_character_y
		sh2_copy_to_reg_from_ptr_long r3 r3
		sh2_set_reg r0 $SQUARE_HEIGHT
		sh2_multiply_reg_by_reg_unsigned_word r3 r0
		sh2_copy_to_reg_from_macl r3
		copy_to_reg_from_val_long r4 $a_put_vdp1_command_scaled_sprite_draw_to_addr
		sh2_abs_call_to_reg_after_next_inst r4
		sh2_nop

		# r1のアドレス先へ描画終了コマンドを配置
		sh2_set_reg r0 80
		sh2_shift_left_logical_8 r0
		sh2_copy_to_ptr_from_reg_word r1 r0

		# ゲームパッドの入力状態更新
		copy_to_reg_from_val_long r1 $a_update_gamepad_input_status
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# 入力に応じてキャラクタの座標更新
		copy_to_reg_from_val_long r1 $a_update_character_coordinates
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop
	) >src/main.1.o
	cat src/main.1.o
	local sz_1=$(stat -c '%s' src/main.1.o)
	sh2_rel_jump_after_next_inst $(two_comp_3_d $(((4 + sz_1) / 2)))
	sh2_nop
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
	dd if=/dev/zero bs=1 count=$pad_sz

	# 関数領域
	cat src/funcs.o
	file_sz=$(stat -c '%s' src/funcs.o)
	area_sz=$(echo "ibase=16;$MAIN_BASE - $FUNCS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	dd if=/dev/zero bs=1 count=$pad_sz

	# メインプログラム領域
	main
}

make_bin
