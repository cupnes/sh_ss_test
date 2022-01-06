#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/memmap.sh
. include/vdp1.sh
. src/vars_map.sh
. src/con.sh
. src/vdp.sh
. src/pad.sh
. src/cd.sh

# 符号付き32ビット除算
# in  : r1 - 被除数
#     : r0 - 除数
# out : r1 - 計算結果の商
# work: r2 - 作業用
#       r3 - 作業用
f_div_reg_by_reg_long_sign() {
	div_reg_by_reg_long_sign r1 r0 r2 r3

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 16進数1桁をASCIIコードへ変換
# in  : r1 - 16進数の値(下位4ビットしか見ない)
# out : r1 - ASCIIコード
# work: r0 - 作業用
f_conv_to_ascii_from_hex() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 下位4ビットを抽出
	sh2_set_reg r0 0f
	sh2_and_to_reg_from_reg r1 r0

	# r1 >= 0x0a ?
	sh2_set_reg r0 0a
	sh2_compare_reg_ge_reg_unsigned r1 r0
	(
		# r1 >= 0x0a の場合

		# HEX_DISP_A + (r1 - 0x0a) をr1へ設定
		## r0 = 0x0a
		sh2_set_reg r0 0a
		## r1 = r1 - r0
		sh2_sub_to_reg_from_reg r1 r0
		## r0 = HEX_DISP_A
		sh2_set_reg r0 $HEX_DISP_A
		## r1 = r1 + r0
		sh2_add_to_reg_from_reg r1 r0
	) >src/f_conv_to_ascii_from_hex.1.o
	(
		# r1 < 0x0a の場合

		# ASCII_0 + r1 をr1へ設定
		sh2_add_to_reg_from_val_byte r1 $ASCII_0

		# r1 >= 0x0a の場合の処理を飛ばす
		local sz_1=$(stat -c '%s' src/f_conv_to_ascii_from_hex.1.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_1 / 2))) 3)
		sh2_nop
	) >src/f_conv_to_ascii_from_hex.2.o
	local sz_2=$(stat -c '%s' src/f_conv_to_ascii_from_hex.2.o)
	sh2_rel_jump_if_true $(two_digits_d $(((sz_2 - 2) / 2)))
	cat src/f_conv_to_ascii_from_hex.2.o	# r1 < 0x0a の場合
	cat src/f_conv_to_ascii_from_hex.1.o	# r1 >= 0x0a の場合

	# 退避したレジスタを復帰しreturn
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定されたアドレスからアドレスへ、指定されたサイズ分コピー
# in  : r1 - コピー先アドレス
#       r2 - コピー元アドレス
#       r3 - コピーするバイト数
# out : r1 - コピー先アドレス + コピーするバイト数
# work: r0 - 作業用
#       r4 - 作業用
f_memcpy() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## r3
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r3
	## r4
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r4

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

	# 退避したレジスタを復帰しreturn
	## r4
	sh2_copy_to_reg_from_ptr_long r4 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r3
	sh2_copy_to_reg_from_ptr_long r3 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された属性値の定形スプライト描画コマンドを指定されたアドレスへ配置する
# (カラーモード=ルックアップテーブルモード、主に文字表示用)
# in  : r1 - 配置先アドレス
#     : r2 - X座標
#     : r3 - Y座標
#     : r4 - キャラクタアドレス/8(下位2ビットは0)
#     : r5 - ビット31-16：CMDLINK
#            ビット02-00：ジャンプ形式(JP)
# out : r1 - 最後に書き込みを行った次のアドレス
# work: r0 - 作業用
f_put_vdp1_command_normal_sprite_draw_to_addr() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# CMDCTRL
	# 0b0(r5 & 0x00000003) 0000 0000 0000
	# - JP(b14-b12) = r5 & 0x00000003
	# - Dir(b5-b4) = 0b00
	# (r5 & 0x00000003) << 12 -> [r1]
	sh2_copy_to_reg_from_reg r0 r5
	sh2_and_to_r0_from_val_byte 03
	sh2_shift_left_logical_8 r0
	sh2_shift_left_logical_2 r0
	sh2_shift_left_logical_2 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDLINK
	# r5 >> 16 -> [r1]
	sh2_copy_to_reg_from_reg r0 r5
	sh2_shift_right_logical_16 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDPMOD
	# 0b0000 1000 1000 1000
	# - MON(b15) = 0 (VDP2の機能を使わない)
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
	sh2_set_reg r0 $(echo $VRAM_CLT_BASE_CMDCOLR | cut -c1-2)
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte $(echo $VRAM_CLT_BASE_CMDCOLR | cut -c3-4)
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDSRCA
	# キャラクタパターンテーブルのアドレスを8で割った値を設定する
	# r4 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r4
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
	# r2 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r2
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDYA
	# 不動点Y座標
	# r3 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r3
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# don't care
	# 2 * 6 = 12バイト分
	# r1 += 12 (0x0c)
	sh2_add_to_reg_from_val_byte r1 0c

	# CMDGRDA, dummy
	# 0x00000000 -> [r1]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_long r1 r0
	# r1 += 4
	sh2_add_to_reg_from_val_byte r1 04

	# 退避したレジスタを復帰しreturn
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された属性値の定形スプライト描画コマンドを指定されたアドレスへ配置する
# (カラーモード=RGB、フルスクリーン(320x224)での画像表示用)
# in  : r1 - 配置先アドレス
#     : r2 - X座標
#     : r3 - Y座標
#     : r4 - CPTアドレス/8(下位2ビットは0)
#     : r5 - ビット31-16：CMDLINK
#            ビット02-00：ジャンプ形式(JP)
# out : r1 - 最後に書き込みを行った次のアドレス
# work: r0 - 作業用
f_put_vdp1_command_normal_sprite_draw_rgb_to_addr() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# CMDCTRL
	# 0b0(r5 & 0x00000003) 0000 0000 0000
	# - JP(b14-b12) = r5 & 0x00000003
	# - Dir(b5-b4) = 0b00
	# (r5 & 0x00000003) << 12 -> [r1]
	sh2_copy_to_reg_from_reg r0 r5
	sh2_and_to_r0_from_val_byte 03
	sh2_shift_left_logical_8 r0
	sh2_shift_left_logical_2 r0
	sh2_shift_left_logical_2 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDLINK
	# r5 >> 16 -> [r1]
	sh2_copy_to_reg_from_reg r0 r5
	sh2_shift_right_logical_16 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDPMOD
	# - MON(b15) = 0 (VDP2の機能を使わない)
	# - Pclp(b11) = 1 (クリッピングが必要かどうかの座標計算無効)
	# - Clip(b10) = 0 (ユーザクリッピング座標に従わない)
	# - Cmod(b9) = 0 (Clip=0なので無効)
	# - Mesh(b8) = 0 (メッシュ無効)
	# - ECD(b7) = 1 (エンドコード無効)
	# - SPD(b6) = 0 (透明ピクセル有効)
	# - カラーモード(b5-b3) = 0b101 (RGBモード)
	# - 色演算(b2-b0) = 0b000 (色演算は全て無効)
	# 0b0000 1000 1010 1000
	# 0x08a8 -> [r1]
	sh2_set_reg r0 08
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte a8
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDCOLR
	# 0x0000 -> [r1]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDSRCA
	# キャラクタパターンテーブルのアドレスを8で割った値を設定する
	# r4 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r4
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDSIZE
	# キャラクタパターンテーブルに定義したキャラクタの幅と高さを設定する
	# 幅は8で割った値を設定する
	# - 幅/8(b13-b8) = (/ 320 8.0)40.0 = 0x28
	# - 高さ(b7-b0) = 224 = 0xe0
	# 0x28e0 -> [r1]
	sh2_set_reg r0 28
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte e0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDXA
	# 不動点X座標
	# r2 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r2
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDYA
	# 不動点Y座標
	# r3 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r3
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# don't care
	# 2 * 6 = 12バイト分
	# r1 += 12 (0x0c)
	sh2_add_to_reg_from_val_byte r1 0c

	# CMDGRDA, dummy
	# 0x00000000 -> [r1]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_long r1 r0
	# r1 += 4
	sh2_add_to_reg_from_val_byte r1 04

	# 退避したレジスタを復帰しreturn
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された属性値の矩形スプライト描画コマンド(不動点指定)を
# 指定されたアドレスへ配置する
# in  : r1* - 配置先アドレス
#     : r2  - 不動点X座標
#     : r3  - 不動点Y座標
#     : r4  - キャラクタアドレス/8(下位2ビットは0)
# work: r0* - 作業用
# ※ *が付いているレジスタはこの関数で書き換えられる
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
	# r4 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r4
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
	# r2 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r2
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDYA
	# 不動点Y座標
	# r3 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r3
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

	# 符号付き32ビット除算
	a_div_reg_by_reg_long_sign=$FUNCS_BASE
	echo -e "a_div_reg_by_reg_long_sign=$a_div_reg_by_reg_long_sign" >>$map_file
	f_div_reg_by_reg_long_sign >src/f_div_reg_by_reg_long_sign.o
	cat src/f_div_reg_by_reg_long_sign.o

	# 16進数1桁をASCIIコードへ変換
	fsz=$(to16 $(stat -c '%s' src/f_div_reg_by_reg_long_sign.o))
	a_conv_to_ascii_from_hex=$(calc16_8 "${a_div_reg_by_reg_long_sign}+${fsz}")
	echo -e "a_conv_to_ascii_from_hex=$a_conv_to_ascii_from_hex" >>$map_file
	f_conv_to_ascii_from_hex >src/f_conv_to_ascii_from_hex.o
	cat src/f_conv_to_ascii_from_hex.o

	# 指定されたアドレスからアドレスへ、指定されたサイズ分コピー
	fsz=$(to16 $(stat -c '%s' src/f_conv_to_ascii_from_hex.o))
	a_memcpy=$(calc16_8 "${a_conv_to_ascii_from_hex}+${fsz}")
	echo -e "a_memcpy=$a_memcpy" >>$map_file
	f_memcpy >src/f_memcpy.o
	cat src/f_memcpy.o

	# 指定された属性値の定形スプライト描画コマンドを
	# 指定されたアドレスへ配置する
	# (カラーモード=ルックアップテーブルモード、主に文字表示用)
	fsz=$(to16 $(stat -c '%s' src/f_memcpy.o))
	a_put_vdp1_command_normal_sprite_draw_to_addr=$(calc16_8 "${a_memcpy}+${fsz}")
	echo -e "a_put_vdp1_command_normal_sprite_draw_to_addr=$a_put_vdp1_command_normal_sprite_draw_to_addr" >>$map_file
	f_put_vdp1_command_normal_sprite_draw_to_addr >src/f_put_vdp1_command_normal_sprite_draw_to_addr.o
	cat src/f_put_vdp1_command_normal_sprite_draw_to_addr.o

	# 指定された属性値の定形スプライト描画コマンドを
	# 指定されたアドレスへ配置する
	# (カラーモード=RGB、フルスクリーン(320x224)での画像表示用)
	fsz=$(to16 $(stat -c '%s' src/f_put_vdp1_command_normal_sprite_draw_to_addr.o))
	a_put_vdp1_command_normal_sprite_draw_rgb_to_addr=$(calc16_8 "${a_put_vdp1_command_normal_sprite_draw_to_addr}+${fsz}")
	echo -e "a_put_vdp1_command_normal_sprite_draw_rgb_to_addr=$a_put_vdp1_command_normal_sprite_draw_rgb_to_addr" >>$map_file
	f_put_vdp1_command_normal_sprite_draw_rgb_to_addr >src/f_put_vdp1_command_normal_sprite_draw_rgb_to_addr.o
	cat src/f_put_vdp1_command_normal_sprite_draw_rgb_to_addr.o

	# 指定された属性値の矩形スプライト描画コマンド(不動点指定)を
	# 指定されたアドレスへ配置する
	fsz=$(to16 $(stat -c '%s' src/f_put_vdp1_command_normal_sprite_draw_rgb_to_addr.o))
	a_put_vdp1_command_scaled_sprite_draw_to_addr=$(calc16_8 "${a_put_vdp1_command_normal_sprite_draw_rgb_to_addr}+${fsz}")
	echo -e "a_put_vdp1_command_scaled_sprite_draw_to_addr=$a_put_vdp1_command_scaled_sprite_draw_to_addr" >>$map_file
	f_put_vdp1_command_scaled_sprite_draw_to_addr >src/f_put_vdp1_command_scaled_sprite_draw_to_addr.o
	cat src/f_put_vdp1_command_scaled_sprite_draw_to_addr.o

	# 指定されたアドレスのVDPCOMを指定されたジャンプ形式とCMDLINKへ変更する
	fsz=$(to16 $(stat -c '%s' src/f_put_vdp1_command_scaled_sprite_draw_to_addr.o))
	a_update_vdp1_command_jump_mode=$(calc16_8 "${a_put_vdp1_command_scaled_sprite_draw_to_addr}+${fsz}")
	echo -e "a_update_vdp1_command_jump_mode=$a_update_vdp1_command_jump_mode" >>$map_file
	f_update_vdp1_command_jump_mode >src/f_update_vdp1_command_jump_mode.o
	cat src/f_update_vdp1_command_jump_mode.o

	# ゲームパッドの入力状態更新
	fsz=$(to16 $(stat -c '%s' src/f_update_vdp1_command_jump_mode.o))
	a_update_gamepad_input_status=$(calc16_8 "${a_update_vdp1_command_jump_mode}+${fsz}")
	echo -e "a_update_gamepad_input_status=$a_update_gamepad_input_status" >>$map_file
	f_update_gamepad_input_status >src/f_update_gamepad_input_status.o
	cat src/f_update_gamepad_input_status.o

	# con領域のCPとVDPCOMをクリアする
	fsz=$(to16 $(stat -c '%s' src/f_update_gamepad_input_status.o))
	a_clear_con_cp_vdpcom=$(calc16_8 "${a_update_gamepad_input_status}+${fsz}")
	echo -e "a_clear_con_cp_vdpcom=$a_clear_con_cp_vdpcom" >>$map_file
	f_clear_con_cp_vdpcom >src/f_clear_con_cp_vdpcom.o
	cat src/f_clear_con_cp_vdpcom.o

	# 指定された文字(ASCII)を指定された座標に出力(コンソール以外用)
	fsz=$(to16 $(stat -c '%s' src/f_clear_con_cp_vdpcom.o))
	a_putchar_xy=$(calc16_8 "${a_clear_con_cp_vdpcom}+${fsz}")
	echo -e "a_putchar_xy=$a_putchar_xy" >>$map_file
	f_putchar_xy >src/f_putchar_xy.o
	cat src/f_putchar_xy.o

	# 指定された文字(ASCII)を指定された座標に出力(コンソール用)
	fsz=$(to16 $(stat -c '%s' src/f_putchar_xy.o))
	a_putchar_xy_con_printable=$(calc16_8 "${a_putchar_xy}+${fsz}")
	echo -e "a_putchar_xy_con_printable=$a_putchar_xy_con_printable" >>$map_file
	f_putchar_xy_con_printable >src/f_putchar_xy_con_printable.o
	cat src/f_putchar_xy_con_printable.o

	# 指定された文字列を指定された座標に出力
	fsz=$(to16 $(stat -c '%s' src/f_putchar_xy_con_printable.o))
	a_putstr_xy=$(calc16_8 "${a_putchar_xy_con_printable}+${fsz}")
	echo -e "a_putstr_xy=$a_putstr_xy" >>$map_file
	f_putstr_xy >src/f_putstr_xy.o
	cat src/f_putstr_xy.o

	# r1の値を指定された座標に出力
	fsz=$(to16 $(stat -c '%s' src/f_putstr_xy.o))
	a_putreg_xy=$(calc16_8 "${a_putstr_xy}+${fsz}")
	echo -e "a_putreg_xy=$a_putreg_xy" >>$map_file
	f_putreg_xy >src/f_putreg_xy.o
	cat src/f_putreg_xy.o

	# コンソールの初期化
	fsz=$(to16 $(stat -c '%s' src/f_putreg_xy.o))
	a_con_init=$(calc16_8 "${a_putreg_xy}+${fsz}")
	echo -e "a_con_init=$a_con_init" >>$map_file
	f_con_init >src/f_con_init.o
	cat src/f_con_init.o

	# カーソルを1文字分進める
	fsz=$(to16 $(stat -c '%s' src/f_con_init.o))
	a_forward_cursor=$(calc16_8 "${a_con_init}+${fsz}")
	echo -e "a_forward_cursor=$a_forward_cursor" >>$map_file
	f_forward_cursor >src/f_forward_cursor.o
	cat src/f_forward_cursor.o

	# カーソルの改行処理
	fsz=$(to16 $(stat -c '%s' src/f_forward_cursor.o))
	a_line_feed_cursor=$(calc16_8 "${a_forward_cursor}+${fsz}")
	echo -e "a_line_feed_cursor=$a_line_feed_cursor" >>$map_file
	f_line_feed_cursor >src/f_line_feed_cursor.o
	cat src/f_line_feed_cursor.o

	# バックスペース処理
	fsz=$(to16 $(stat -c '%s' src/f_line_feed_cursor.o))
	a_backspace_cursor=$(calc16_8 "${a_line_feed_cursor}+${fsz}")
	echo -e "a_backspace_cursor=$a_backspace_cursor" >>$map_file
	f_backspace_cursor >src/f_backspace_cursor.o
	cat src/f_backspace_cursor.o

	# 1文字出力しカーソル座標を1文字分進める
	fsz=$(to16 $(stat -c '%s' src/f_backspace_cursor.o))
	a_putchar=$(calc16_8 "${a_backspace_cursor}+${fsz}")
	echo -e "a_putchar=$a_putchar" >>$map_file
	f_putchar >src/f_putchar.o
	cat src/f_putchar.o

	# コントロールパッドから1文字の入力を取得する
	fsz=$(to16 $(stat -c '%s' src/f_putchar.o))
	a_getchar_from_pad=$(calc16_8 "${a_putchar}+${fsz}")
	echo -e "a_getchar_from_pad=$a_getchar_from_pad" >>$map_file
	f_getchar_from_pad >src/f_getchar_from_pad.o
	cat src/f_getchar_from_pad.o

	# CR1〜CR4を指定された座標にダンプする
	fsz=$(to16 $(stat -c '%s' src/f_getchar_from_pad.o))
	a_dump_cr1234_xy=$(calc16_8 "${a_getchar_from_pad}+${fsz}")
	echo -e "a_dump_cr1234_xy=$a_dump_cr1234_xy" >>$map_file
	f_dump_cr1234_xy >src/f_dump_cr1234_xy.o
	cat src/f_dump_cr1234_xy.o

	# CDコマンドを実行する
	fsz=$(to16 $(stat -c '%s' src/f_dump_cr1234_xy.o))
	a_cd_exec_command=$(calc16_8 "${a_dump_cr1234_xy}+${fsz}")
	echo -e "a_cd_exec_command=$a_cd_exec_command" >>$map_file
	f_cd_exec_command >src/f_cd_exec_command.o
	cat src/f_cd_exec_command.o

	# 指定されたFADの画像(320x224)をVDP1 RAMのother領域へロードし表示する
	fsz=$(to16 $(stat -c '%s' src/f_cd_exec_command.o))
	a_load_img_from_cd_and_view=$(calc16_8 "${a_cd_exec_command}+${fsz}")
	echo -e "a_load_img_from_cd_and_view=$a_load_img_from_cd_and_view" >>$map_file
	f_load_img_from_cd_and_view >src/f_load_img_from_cd_and_view.o
	cat src/f_load_img_from_cd_and_view.o
}

funcs
