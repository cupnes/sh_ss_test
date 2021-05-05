#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh
. include/memmap.sh

# 指定されたアドレスからアドレスへ、指定されたサイズ分コピー
# in  : r1  - コピー先アドレス
#       r2  - コピー元アドレス
#       r3  - コピーするバイト数
# work: r0  - 作業用
#       r4  - 作業用
# ※ in,work全てのレジスタがこの関数内で何らかの書き換えが行われる
f_memcpy() {
	# r2のアドレスからr1のアドレスへr3バイト分のデータをロード
	## r3 > 0 ?
	sh2_xor_to_reg_from_reg r0 r0	# 2
	sh2_compare_reg_gt_reg_signed r3 r0	# 2
	## falseだったら以降の処理を飛ばす
	(
		# r3 > 0

		# [r1] = [r2]
		sh2_copy_to_reg_from_ptr_byte r4 r2
		sh2_copy_to_ptr_from_reg_byte r1 r4

		# r1 += 1, r2 += 1
		sh2_add_to_reg_from_val_byte r1 01
		sh2_add_to_reg_from_val_byte r2 01

		# r3 += -1
		sh2_add_to_reg_from_val_byte r3 $(two_comp_d 1)
	) >src/f_memcpy.1.o
	local sz_1=$(stat -c '%s' src/f_memcpy.1.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_1 + 2 + 2) / 2)))	# 2
	sh2_nop	# 2
	cat src/f_memcpy.1.o	# sz_1
	sh2_rel_jump_after_next_inst $(two_comp_3_d $(((2 + 2 + sz_1 + 2 + 2 + 2 + 2) / 2)))	# 2
	sh2_nop	# 2

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された属性値の矩形スプライト描画コマンド(不動点指定)を
# 指定されたアドレスへ配置する
# in  : r1  - 配置先アドレス
# work: r0  - 作業用
# ※ in,workは共にこの関数で書き換えられる
# ※ r1は最後に書き込みを行った次のアドレスが指定された状態で帰る
f_put_vdp1_command_scaled_sprite_draw_to_addr() {
	# CMDCTRL
	# 0b0000 0101 0000 0001
	# - JP(b14-b12) = 0b000
	# - ZP(b11-b8) = 0b0101 (左上)
	# - Dir(b5-b4) = 0b00
	# 0x0501 -> [r1]
	sh2_set_reg r0 05
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte 01
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDLINK
	# 0x0000 -> [r1]
	sh2_xor_to_reg_from_reg r0 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDPMOD
	# 0b0000 1000 1000 1000
	# - MON(b15) = 0 (VDP2の機能を使わない)
	# - HSS(b12) = 0 (ハイスピードシュリンク無効)
	# - Pclp(b11) = 1 (クリッピングが必要かどうかの座標計算無効)
	# - Clip(b10) = 0 (ユーザクリッピング座標に従わない)
	# - Cmod(b9) = 0 (Clip=0なので無効)
	# - Mesh(b8) = 0 (メッシュ無効)
	# - ECD(b7) = 1 (エンドコード無効)
	# - SPD(b6) = 0 (透明ピクセル有効)
	# - カラーモード(b5-b3) = 0b001 (ルックアップテーブルモード)
	# - 色演算(b2-b0) = 0b000 (色演算は全て無効)
	# 0x0888 -> [r1]
	sh2_set_reg r0 08
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte 88
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDCOLR
	# カラールックアップテーブルのアドレスを8で割った値を指定する
	# 0x0f00 / 8 = 0x01e0
	# 0x01e0 -> [r1]
	sh2_set_reg r0 01
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte e0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDSRCA
	# キャラクタパターンテーブルのアドレスを8で割った値を設定する
	# 0x0c80 / 8 = 0x0190
	# 0x0190 -> [r1]
	sh2_set_reg r0 01
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte 90
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDSIZE
	# キャラクタパターンテーブルに定義したキャラクタの幅と高さを設定する
	# 幅は8で割った値を設定する
	# - 幅/8(b13-b8) = (/ 16 8.0)2.0 = 0x02
	# - 高さ(b7-b0) = 16 = 0x10
	# 0x0210 -> [r1]
	sh2_set_reg r0 02
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte 10
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDXA
	# 不動点X座標
	# 0x0000 -> [r1]
	sh2_xor_to_reg_from_reg r0 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDYA
	# 不動点Y座標
	# 0x0000 -> [r1]
	sh2_xor_to_reg_from_reg r0 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDXB
	# 表示幅
	# 16 = 0x10
	# 0x0010 -> [r1]
	sh2_set_reg r0 10
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDYB
	# 表示高さ
	# 16 = 0x10
	# 0x0010 -> [r1]
	sh2_set_reg r0 10
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# don't care
	# 2 * 4 = 8バイト分
	# r1 += 8
	sh2_add_to_reg_from_val_byte r1 08

	# CMDGRDA, dummy
	# 0x00000000 -> [r1]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_long r1 r0
	# r1 += 4
	sh2_add_to_reg_from_val_byte r1 04

	# return
	sh2_return_after_next_inst
	sh2_nop
}

funcs() {
	local fsz

	map_file=src/funcs_map.sh
	rm -f $map_file

	# 指定されたアドレスからアドレスへ、指定されたサイズ分コピー
	a_memcpy=$FUNCS_BASE
	echo -e "a_memcpy=$a_memcpy" >>$map_file
	f_memcpy >src/f_memcpy.o
	cat src/f_memcpy.o

	# 指定された属性値の矩形スプライト描画コマンド(不動点指定)を
	# 指定されたアドレスへ配置する
	fsz=$(to16 $(stat -c '%s' src/f_memcpy.o))
	a_put_vdp1_command_scaled_sprite_draw_to_addr=$(calc16_8 "${a_memcpy}+${fsz}")
	echo -e "a_put_vdp1_command_scaled_sprite_draw_to_addr=$a_put_vdp1_command_scaled_sprite_draw_to_addr" >>$map_file
	f_put_vdp1_command_scaled_sprite_draw_to_addr >src/f_put_vdp1_command_scaled_sprite_draw_to_addr.o
	cat src/f_put_vdp1_command_scaled_sprite_draw_to_addr.o
}

funcs
