#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/vdp1.sh
. src/render.sh
. src/debug.sh

VRAM_DRAW_CMD_BASE=05c00060
INIT_SP=06004000
PROGRAM_ENTRY_ADDR=06004000
VARS_BASE=0600401E
FUNCS_BASE=06005000
MAIN_BASE=06010000

map_file=map.sh
rm -f $map_file

debug 'before: vars()'

vars() {
	local vsz

	# 三角関数計算のための係数テーブル
	## N * sinθ を (N * 係数) / 1000 で計算する係数のテーブル
	var_sin_coeff_table=$VARS_BASE
	echo -e "var_sin_coeff_table=$var_sin_coeff_table" >>$map_file
	cat sin_coeff_table.dat
	## N * cosθ を (N * 係数) / 1000 で計算する係数のテーブル
	vsz=$(to16 $(stat -c '%s' sin_coeff_table.dat))
	var_cos_coeff_table=$(calc16_8 "${var_sin_coeff_table}+${vsz}")
	echo -e "var_cos_coeff_table=$var_cos_coeff_table" >>$map_file
	cat cos_coeff_table.dat

	# ゲームパッド入力状態
	## 現在の押下状態
	## (押下時0)
	### → ← ↓ ↑ Start A C B
	vsz=$(to16 $(stat -c '%s' cos_coeff_table.dat))
	var_pad_current_state_1=$(calc16_8 "${var_cos_coeff_table}+${vsz}")
	echo -e "var_pad_current_state_1=$var_pad_current_state_1" >>$map_file
	echo -en '\xff'
	### R X Y Z L (bit2-0: 予約)
	var_pad_current_state_2=$(calc16_8 "$var_pad_current_state_1+1")
	echo -e "var_pad_current_state_2=$var_pad_current_state_2" >>$map_file
	echo -en '\xff'

	# 投影面Z座標
	var_proj_z=$(calc16_8 "$var_pad_current_state_2+1")
	echo -e "var_proj_z=$var_proj_z" >>$map_file
	echo -en '\x00\x64'	# 100

	# 現在のカメラ座標系のY軸旋回角度
	var_rotation_angle_y=$(calc16_8 "$var_proj_z+2")
	echo -e "var_rotation_angle_y=$var_rotation_angle_y" >>$map_file
	echo -en '\x00\x00'	# 0

	# 六面体の8頂点の3次元座標
	## 頂点座標が並ぶ領域のベースアドレス
	var_hexahedron_base=$(calc16_8 "$var_rotation_angle_y+2")
	echo -e "var_hexahedron_base=$var_hexahedron_base" >>$map_file
	## 頂点A(正面左上)
	### X (base+0x00)
	var_hexahedron_ax=$var_hexahedron_base
	ofs_hexahedron_ax=00
	echo -e "var_hexahedron_ax=$var_hexahedron_ax" >>$map_file
	echo -en '\xFF\xDB'	# -37
	### Y (base+0x02)
	var_hexahedron_ay=$(calc16_8 "$var_hexahedron_ax+2")
	ofs_hexahedron_ay=02
	echo -e "var_hexahedron_ay=$var_hexahedron_ay" >>$map_file
	echo -en '\x00\x86'	# 134
	### Z (base+0x04)
	var_hexahedron_az=$(calc16_8 "$var_hexahedron_ay+2")
	ofs_hexahedron_az=04
	echo -e "var_hexahedron_az=$var_hexahedron_az" >>$map_file
	echo -en '\x00\x64'	# 100
	## 頂点B(正面右上)
	### X (base+0x06)
	var_hexahedron_bx=$(calc16_8 "$var_hexahedron_az+2")
	ofs_hexahedron_bx=06
	echo -e "var_hexahedron_bx=$var_hexahedron_bx" >>$map_file
	echo -en '\x00\x25'	# 37
	### Y (base+0x08)
	var_hexahedron_by=$(calc16_8 "$var_hexahedron_bx+2")
	ofs_hexahedron_by=08
	echo -e "var_hexahedron_by=$var_hexahedron_by" >>$map_file
	echo -en '\x00\x86'	# 134
	### Z (base+0x0a)
	var_hexahedron_bz=$(calc16_8 "$var_hexahedron_by+2")
	ofs_hexahedron_bz=0a
	echo -e "var_hexahedron_bz=$var_hexahedron_bz" >>$map_file
	echo -en '\x00\x64'	# 100
	## 頂点C(正面右下)
	### X (base+0x0c)
	var_hexahedron_cx=$(calc16_8 "$var_hexahedron_bz+2")
	ofs_hexahedron_cx=0c
	echo -e "var_hexahedron_cx=$var_hexahedron_cx" >>$map_file
	echo -en '\x00\x25'	# 37
	### Y (base+0x0e)
	var_hexahedron_cy=$(calc16_8 "$var_hexahedron_cx+2")
	ofs_hexahedron_cy=0e
	echo -e "var_hexahedron_cy=$var_hexahedron_cy" >>$map_file
	echo -en '\x00\x00'	# 0
	### Z (base+0x10)
	var_hexahedron_cz=$(calc16_8 "$var_hexahedron_cy+2")
	ofs_hexahedron_cz=10
	echo -e "var_hexahedron_cz=$var_hexahedron_cz" >>$map_file
	echo -en '\x00\x64'	# 100
	## 頂点D(正面左下)
	### X (base+0x12)
	var_hexahedron_dx=$(calc16_8 "$var_hexahedron_cz+2")
	ofs_hexahedron_dx=12
	echo -e "var_hexahedron_dx=$var_hexahedron_dx" >>$map_file
	echo -en '\xFF\xDB'	# -37
	### Y (base+0x14)
	var_hexahedron_dy=$(calc16_8 "$var_hexahedron_dx+2")
	ofs_hexahedron_dy=14
	echo -e "var_hexahedron_dy=$var_hexahedron_dy" >>$map_file
	echo -en '\x00\x00'	# 0
	### Z (base+0x16)
	var_hexahedron_dz=$(calc16_8 "$var_hexahedron_dy+2")
	ofs_hexahedron_dz=16
	echo -e "var_hexahedron_dz=$var_hexahedron_dz" >>$map_file
	echo -en '\x00\x64'	# 100
	## 頂点E(背面左上)
	### X (base+0x18)
	var_hexahedron_ex=$(calc16_8 "$var_hexahedron_dz+2")
	ofs_hexahedron_ex=18
	echo -e "var_hexahedron_ex=$var_hexahedron_ex" >>$map_file
	echo -en '\xFF\xDB'	# -37
	### Y (base+0x1a)
	var_hexahedron_ey=$(calc16_8 "$var_hexahedron_ex+2")
	ofs_hexahedron_ey=1a
	echo -e "var_hexahedron_ey=$var_hexahedron_ey" >>$map_file
	echo -en '\x00\x86'	# 134
	### Z (base+0x1c)
	var_hexahedron_ez=$(calc16_8 "$var_hexahedron_ey+2")
	ofs_hexahedron_ez=1c
	echo -e "var_hexahedron_ez=$var_hexahedron_ez" >>$map_file
	echo -en '\x00\x77'	# 119
	## 頂点F(背面右上)
	### X (base+0x1e)
	var_hexahedron_fx=$(calc16_8 "$var_hexahedron_ez+2")
	ofs_hexahedron_fx=1e
	echo -e "var_hexahedron_fx=$var_hexahedron_fx" >>$map_file
	echo -en '\x00\x25'	# 37
	### Y (base+0x20)
	var_hexahedron_fy=$(calc16_8 "$var_hexahedron_fx+2")
	ofs_hexahedron_fy=20
	echo -e "var_hexahedron_fy=$var_hexahedron_fy" >>$map_file
	echo -en '\x00\x86'	# 134
	### Z (base+0x22)
	var_hexahedron_fz=$(calc16_8 "$var_hexahedron_fy+2")
	ofs_hexahedron_fz=22
	echo -e "var_hexahedron_fz=$var_hexahedron_fz" >>$map_file
	echo -en '\x00\x77'	# 119
	## 頂点G(背面右下)
	### X (base+0x24)
	var_hexahedron_gx=$(calc16_8 "$var_hexahedron_fz+2")
	ofs_hexahedron_gx=24
	echo -e "var_hexahedron_gx=$var_hexahedron_gx" >>$map_file
	echo -en '\x00\x25'	# 37
	### Y (base+0x26)
	var_hexahedron_gy=$(calc16_8 "$var_hexahedron_gx+2")
	ofs_hexahedron_gy=26
	echo -e "var_hexahedron_gy=$var_hexahedron_gy" >>$map_file
	echo -en '\x00\x00'	# 0
	### Z (base+0x28)
	var_hexahedron_gz=$(calc16_8 "$var_hexahedron_gy+2")
	ofs_hexahedron_gz=28
	echo -e "var_hexahedron_gz=$var_hexahedron_gz" >>$map_file
	echo -en '\x00\x77'	# 119
	## 頂点H(背面左下)
	### X (base+0x2a)
	var_hexahedron_hx=$(calc16_8 "$var_hexahedron_gz+2")
	ofs_hexahedron_hx=2a
	echo -e "var_hexahedron_hx=$var_hexahedron_hx" >>$map_file
	echo -en '\xFF\xDB'	# -37
	### Y (base+0x2c)
	var_hexahedron_hy=$(calc16_8 "$var_hexahedron_hx+2")
	ofs_hexahedron_hy=2c
	echo -e "var_hexahedron_hy=$var_hexahedron_hy" >>$map_file
	echo -en '\x00\x00'	# 0
	### Z (base+0x2e)
	var_hexahedron_hz=$(calc16_8 "$var_hexahedron_hy+2")
	ofs_hexahedron_hz=2e
	echo -e "var_hexahedron_hz=$var_hexahedron_hz" >>$map_file
	echo -en '\x00\x77'	# 119

	# 座標更新周期カウンタ
	var_coord_update_cyc_counter=$(calc16_8 "$var_hexahedron_hz+2")
	echo -e "var_coord_update_cyc_counter=$var_coord_update_cyc_counter" >>$map_file
	echo -en '\x00'
}
# 変数設定のために空実行
vars >/dev/null
rm -f $map_file

# ゲームパッドの入力状態更新
f_update_gamepad_input_status() {
	# SFへ1をセット
	## SFのアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_SF_ADDR
	## r0へ0x01をセット
	sh2_set_reg r0 01
	## r1の指す先(SF)へr0の値(0x01)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# IREG2へ0xf0をセット
	## IREG2のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_IREG2_ADDR
	## r0へ0xf0をセット
	sh2_set_reg r0 f0
	## r1の指す先(IREG2)へr0の値(0xf0)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# IREG1へ0x08をセット
	## IREG1のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_IREG1_ADDR
	## r0へ0x08をセット
	sh2_set_reg r0 08
	## r1の指す先(IREG1)へr0の値(0x08)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# IREG0へ0x00をセット
	## IREG0のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_IREG0_ADDR
	## r0へ0x00をセット
	sh2_set_reg r0 00
	## r1の指す先(IREG0)へr0の値(0x00)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# COMREGへINTBACKをセット
	## COMREGのアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_COMREG_ADDR
	## r0へINTBACKをセット
	sh2_set_reg r0 $SS_SMPC_COMREG_INTBACK
	## r1の指す先(COMREG)へr0の値(INTBACK)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# SFが0になるのを待つ
	## SFのアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_SF_ADDR
	## r0へr1の指す先(SF)の値をロード
	sh2_copy_to_reg_from_ptr_byte r0 r1
	## bit0が1の間、ここで待つ
	sh2_test_r0_and_val_byte 01
	sh2_rel_jump_if_false $(two_comp_d 4)
	sh2_nop

	# OREG2(1st Data)を変数へロード
	## OREG2のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_OREG2_ADDR
	## r2へr1の指す先(OREG2)の値をロード
	sh2_copy_to_reg_from_ptr_byte r2 r1
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_1
	## r1の指す先(変数)へr2の値を格納
	sh2_copy_to_ptr_from_reg_byte r1 r2

	# OREG3(2nd Data)をr5へロード
	## OREG3のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_OREG3_ADDR
	## r2へr1の指す先(OREG3)の値をロード
	sh2_copy_to_reg_from_ptr_byte r2 r1
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_2
	## r1の指す先(変数)へr2の値を格納
	sh2_copy_to_ptr_from_reg_byte r1 r2

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された2次元座標の原点からの距離を算出
# in  : r5  - 1軸目の値
#       r7  - 2軸目の値
# out : r5  - 結果の距離
# work: r0  - 作業用
#       r6  - 作業用
f_calc_distance_2d() {
	# 戻り値とr0以外で書き換えるレジスタをスタックへ退避
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r7
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r6

	# 1軸目の値(r5)の絶対値をr5へ格納
	## r5 >= 0 ?
	sh2_xor_to_reg_from_reg r0 r0
	sh2_compare_reg_ge_reg_signed r5 r0
	## trueだったら後続処理を飛ばす
	(
		# r5 *= -1
		sh2_set_reg r0 ff	# -1
		sh2_multiply_reg_by_reg_signed_word r5 r0
		sh2_copy_to_reg_from_macl r5
	) >src/f_calc_distance_2d.1.o
	local sz_1=$(stat -c '%s' src/f_calc_distance_2d.1.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_calc_distance_2d.1.o

	# 2軸目の値(r7)の絶対値をr7へ格納
	## r7 >= 0 ?
	sh2_xor_to_reg_from_reg r0 r0
	sh2_compare_reg_ge_reg_signed r7 r0
	## trueだったら後続処理を飛ばす
	(
		# r7 *= -1
		sh2_set_reg r0 ff	# -1
		sh2_multiply_reg_by_reg_signed_word r7 r0
		sh2_copy_to_reg_from_macl r7
	) >src/f_calc_distance_2d.2.o
	local sz_2=$(stat -c '%s' src/f_calc_distance_2d.2.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_2 / 2)))
	sh2_nop
	cat src/f_calc_distance_2d.2.o

	# r5 >= r7 となるようにする
	# (そうでないなら値を入れ替える)
	## r5 >= r7 ?
	sh2_compare_reg_ge_reg_unsigned r5 r7
	## trueだったら後続処理を飛ばす
	(
		# r5とr7の値を入れ替える
		## r0 <- r5
		sh2_copy_to_reg_from_reg r0 r5
		## r5 <- r7
		sh2_copy_to_reg_from_reg r5 r7
		## r7 <- r0
		sh2_copy_to_reg_from_reg r7 r0
	) >src/f_calc_distance_2d.3.o
	local sz_3=$(stat -c '%s' src/f_calc_distance_2d.3.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_3 / 2)))
	sh2_nop
	cat src/f_calc_distance_2d.3.o

	# (2 * r5) < (5 * r7) ?
	## r6 = 2 * r5
	sh2_set_reg r6 02
	sh2_multiply_reg_by_reg_unsigned_word r6 r5
	sh2_copy_to_reg_from_macl r6
	## r0 = 5 * r7
	sh2_set_reg r0 05
	sh2_multiply_reg_by_reg_unsigned_word r0 r7
	sh2_copy_to_reg_from_macl r0
	## r0 > r6 ?
	sh2_compare_reg_gt_reg_unsigned r0 r6
	(
		# trueの場合
		## r5 *= 864(0x0360)
		sh2_set_reg r0 03
		sh2_shift_left_logical_8 r0
		sh2_or_to_r0_from_val_byte 60
		sh2_multiply_reg_by_reg_signed_long r5 r0
		## r7 *= 569(0x0239)
		sh2_set_reg r0 02
		sh2_shift_left_logical_8 r0
		sh2_or_to_r0_from_val_byte 39
		sh2_multiply_reg_by_reg_signed_long r7 r0
	) >src/f_calc_distance_2d.4.o
	(
		# falseの場合
		## r5 *= 1016(0x03f8)
		sh2_set_reg r0 03
		sh2_shift_left_logical_8 r0
		sh2_or_to_r0_from_val_byte f8
		sh2_multiply_reg_by_reg_signed_long r5 r0
		## r7 *= 190(0x00be)
		sh2_set_reg r0 00
		sh2_or_to_r0_from_val_byte be
		sh2_multiply_reg_by_reg_signed_long r7 r0

		# trueの場合の処理を飛ばす
		local sz_4=$(stat -c '%s' src/f_calc_distance_2d.4.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_4 / 2))) 3)
		sh2_nop
	) >src/f_calc_distance_2d.5.o
	## trueだったらジャンプ
	local sz_5=$(stat -c '%s' src/f_calc_distance_2d.5.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_5 / 2)))
	sh2_nop
	cat src/f_calc_distance_2d.5.o	# falseの場合
	cat src/f_calc_distance_2d.4.o	# trueの場合
	## r5 += r7
	sh2_add_to_reg_from_reg r5 r7

	# r5 = (r5 + 512) / 1024
	## r5 += 512(0x0200)
	sh2_set_reg r0 02
	sh2_shift_left_logical_8 r0
	sh2_add_to_reg_from_reg r5 r0
	## r5 /= 1024(0x0400)
	sh2_set_reg r0 04
	sh2_shift_left_logical_8 r0
	div_reg_by_reg_long_sign r5 r0 r7 r6

	# 使用したレジスタをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r6 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_reg_from_ptr_long r7 r15
	sh2_add_to_reg_from_val_byte r15 04

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された4頂点・カラーのポリゴンを描画するコマンドを
# 指定されたアドレスへ配置
# in  : r1  - Ax
#       r2  - Ay
#       r3  - Bx
#       r4  - By
#       r5  - Cx
#       r6  - Cy
#       r7  - Dx
#       r8  - Dy
#       r9  - color
#       r10 - dst addr
# out : r10 - dst addrへ最後に書き込んだ次のアドレス
# work: PR  - この関数を呼び出したBSR/JSR命令のアドレス
#     : r0  - 作業用
f_put_vdp1_command_polygon_draw_to_addr() {
	# CMDCTRL
	# 0b0000 0000 0000 0100
	# - JP(b14-b12) = 0b000
	# 0x0004 -> [r10]
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte 04
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDLINK
	# 0x0000 -> [r10]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDPMOD
	# 0b0000 1000 1100 0000
	# - MON(b15) = 0 (VDP2の機能を使わない)
	# - Pclp(b11) = 1 (クリッピングが必要かどうかの座標計算無効)
	# - Clip(b10) = 0 (ユーザクリッピング座標に従わない)
	# - Cmod(b9) = 0 (Clip=0なので無効)
	# - Mesh(b8) = 0 (メッシュ無効)
	# - 色演算(b2-b0) = 0b000 (色演算は全て無効)
	# 0x08c0 -> [r10]
	sh2_set_reg r0 08
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte c0
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDCOLR
	# r9 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r9
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDSRCA
	# 0x0000 -> [r10]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDSIZE
	# 0x0000 -> [r10]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDXA
	# 頂点AのX座標
	# r1 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r1
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDYA
	# 頂点AのY座標
	# r2 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r2
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDXB
	# 頂点BのX座標
	# r3 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r3
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDYB
	# 頂点BのY座標
	# r4 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r4
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDXC
	# 頂点CのX座標
	# r5 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r5
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDYC
	# 頂点CのY座標
	# r6 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r6
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDXD
	# 頂点DのX座標
	# r7 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r7
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDYD
	# 頂点DのY座標
	# r8 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r8
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDGRDA, dummy
	# 0x00000000 -> [r10]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_long r10 r0
	# r10 += 4
	sh2_add_to_reg_from_val_byte r10 04

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 4つの3次元座標で指定された平面を指定されたカラーで
# 指定されたアドレスへ描画
# in  : r1   - Ax
#       r2   - Ay
#       r3   - Az
#       r4   - Bx
#       r5   - By
#       r6   - Bz
#       r7   - Cx
#       r8   - Cy
#       r9   - Cz
#       r10  - Dx
#       r11  - Dy
#       r12  - Dz
#       r13  - color
#       SP+0 - dst addr
# out : SP+0 - dst addrへ最後に書き込んだ次のアドレス
# work: PR   - この関数を呼び出したBSR/JSR命令のアドレス
#     : r0   - 作業用
#     : r14  - 作業用
f_draw_plate() {
	local _i

	# 投影面Z座標をr14へロード
	copy_to_reg_from_val_long r14 $var_proj_z
	sh2_copy_to_reg_from_ptr_word r14 r14

	# [debug] 無限ループ
	# infinite_loop

	# 投影面Z座標(PRJz)より小さい(カメラに近い)Z座標が1つでもあれば
	# 何もせずreturn
	(
		# 何もせずreturn
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_draw_plate.1.o
	local sz_1=$(stat -c '%s' src/f_draw_plate.1.o)
	## PRJz(r14) > Az(r3)?
	sh2_compare_reg_gt_reg_unsigned r14 r3
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate.1.o
	## PRJz(r14) > Bz(r6)?
	sh2_compare_reg_gt_reg_unsigned r14 r6
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate.1.o
	## PRJz(r14) > Cz(r9)?
	sh2_compare_reg_gt_reg_unsigned r14 r9
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate.1.o
	## PRJz(r14) > Dz(r12)?
	sh2_compare_reg_gt_reg_unsigned r14 r12
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate.1.o

	# 透視投影で2次元座標へ変換
	# - PRJz < Az or Bz or Cz or Dz の時
	#   - 2次元座標(x, y) = 3次元座標(x, y) * PRJz / 3次元座標z
	# - PRJz == Az or Bz or Cz or Dz の時
	#   - 2次元座標(x, y) = 3次元座標(x, y)

	## PRJz(r14) == Az(r3)?
	sh2_compare_reg_eq_reg r14 r3
	(
		# PRJz(r14) < Az(r3) の時

		# 2次元座標Ax(r1) = 3次元座標Ax(r1) * PRJz(r14) / 3次元座標Az(r3)
		## 3次元座標Ax(r1) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r1 r14
		## MACL -> r1
		sh2_copy_to_reg_from_macl r1
		## r1 / 3次元座標Az(r3) -> r1
		div_reg_by_reg_word_sign r1 r3 r2 r4

		# 2次元座標Ay(r2) = 3次元座標Ay(r2) * PRJz(r14) / 3次元座標Az(r3)
		## 3次元座標Ay(r2) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_unsigned_word r2 r14
		## MACL -> r2
		sh2_copy_to_reg_from_macl r2
		## r2 / 3次元座標Az(r3) -> r2
		div_reg_by_reg_word_sign r2 r3 r1 r4
	) >src/f_draw_plate.2.o
	local sz_2=$(stat -c '%s' src/f_draw_plate.2.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_2 / 2)))
	sh2_nop
	cat src/f_draw_plate.2.o	# PRJz(r14) < Az(r3) の時
	# この時点でポリゴン描画の頂点Aの座標(Ax,Ay)を(r1,r2)へ設定完了

	# [debug] 無限ループ
	# infinite_loop

	## PRJz(r14) == Bz(r6)?
	sh2_compare_reg_eq_reg r14 r6
	(
		# PRJz(r14) == Bz(r6) の時

		# 2次元座標Bx(r3) = 3次元座標Bx(r4)
		sh2_copy_to_reg_from_reg r3 r4

		# 2次元座標By(r4) = 3次元座標By(r5)
		sh2_copy_to_reg_from_reg r4 r5
	) >src/f_draw_plate.4.o
	(
		# PRJz(r14) < Bz(r6) の時

		# 2次元座標Bx(r3) = 3次元座標Bx(r4) * PRJz(r14) / 3次元座標Bz(r6)
		## 3次元座標Bx(r4) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_unsigned_word r4 r14
		## MACL -> r3
		sh2_copy_to_reg_from_macl r3
		## r3 / 3次元座標Bz(r6) -> r3
		div_reg_by_reg_word_sign r3 r6 r1 r2

		# 2次元座標By(r4) = 3次元座標By(r5) * PRJz(r14) / 3次元座標Bz(r6)
		## 3次元座標By(r5) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_unsigned_word r5 r14
		## MACL -> r4
		sh2_copy_to_reg_from_macl r4
		## r4 / 3次元座標Bz(r6) -> r4
		div_reg_by_reg_word_sign r4 r6 r1 r2

		# PRJz(r14) == Bz(r6) の時の処理を飛ばす
		local sz_4=$(stat -c '%s' src/f_draw_plate.4.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_4 / 2))) 3)
		sh2_nop
	) >src/f_draw_plate.3.o
	local sz_3=$(stat -c '%s' src/f_draw_plate.3.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_3 / 2)))
	sh2_nop
	cat src/f_draw_plate.3.o	# PRJz(r14) < Bz(r6) の時
	cat src/f_draw_plate.4.o	# PRJz(r14) == Bz(r6) の時
	# この時点でポリゴン描画の頂点Bの座標(Bx,By)を(r3,r4)へ設定完了

	## PRJz(r14) == Cz(r9)?
	sh2_compare_reg_eq_reg r14 r9
	(
		# PRJz(r14) == Cz(r9) の時

		# 2次元座標Cx(r5) = 3次元座標Cx(r7)
		sh2_copy_to_reg_from_reg r5 r7

		# 2次元座標Cy(r6) = 3次元座標Cy(r8)
		sh2_copy_to_reg_from_reg r6 r8
	) >src/f_draw_plate.6.o
	(
		# PRJz(r14) < Cz(r9) の時

		# 2次元座標Cx(r5) = 3次元座標Cx(r7) * PRJz(r14) / 3次元座標Cz(r9)
		## 3次元座標Cx(r7) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_unsigned_word r7 r14
		## MACL -> r5
		sh2_copy_to_reg_from_macl r5
		## r5 / 3次元座標Cz(r9) -> r5
		div_reg_by_reg_word_sign r5 r9 r1 r2

		# 2次元座標Cy(r6) = 3次元座標Cy(r8) * PRJz(r14) / 3次元座標Cz(r9)
		## 3次元座標Cy(r8) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_unsigned_word r8 r14
		## MACL -> r6
		sh2_copy_to_reg_from_macl r6
		## r6 / 3次元座標Cz(r9) -> r6
		div_reg_by_reg_word_sign r6 r9 r1 r2

		# PRJz(r14) == Cz(r9) の時の処理を飛ばす
		local sz_6=$(stat -c '%s' src/f_draw_plate.6.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_6 / 2))) 3)
		sh2_nop
	) >src/f_draw_plate.5.o
	local sz_5=$(stat -c '%s' src/f_draw_plate.5.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_5 / 2)))
	sh2_nop
	cat src/f_draw_plate.5.o	# PRJz(r14) < Bz(r9) の時
	cat src/f_draw_plate.6.o	# PRJz(r14) == Bz(r9) の時
	# この時点でポリゴン描画の頂点Cの座標(Cx,Cy)を(r5,r6)へ設定完了

	## PRJz(r14) == Dz(r12)?
	sh2_compare_reg_eq_reg r14 r12
	(
		# PRJz(r14) == Dz(r12) の時

		# 2次元座標Dx(r7) = 3次元座標Dx(r10)
		sh2_copy_to_reg_from_reg r7 r10

		# 2次元座標Dy(r8) = 3次元座標Dy(r11)
		sh2_copy_to_reg_from_reg r8 r11
	) >src/f_draw_plate.8.o
	(
		# PRJz(r14) < Dz(r12) の時

		# 2次元座標Dx(r7) = 3次元座標Dx(r10) * PRJz(r14) / 3次元座標Dz(r12)
		## 3次元座標Dx(r10) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_unsigned_word r10 r14
		## MACL -> r7
		sh2_copy_to_reg_from_macl r7
		## r7 / 3次元座標Dz(r12) -> r7
		div_reg_by_reg_word_sign r7 r12 r1 r2

		# 2次元座標Dy(r8) = 3次元座標Dy(r11) * PRJz(r14) / 3次元座標Dz(r12)
		## 3次元座標Dy(r11) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_unsigned_word r11 r14
		## MACL -> r8
		sh2_copy_to_reg_from_macl r8
		## r8 / 3次元座標Dz(r12) -> r8
		div_reg_by_reg_word_sign r8 r12 r1 r2

		# PRJz(r14) == Dz(r12) の時の処理を飛ばす
		local sz_8=$(stat -c '%s' src/f_draw_plate.8.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_8 / 2))) 3)
		sh2_nop
	) >src/f_draw_plate.7.o
	local sz_7=$(stat -c '%s' src/f_draw_plate.7.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_7 / 2)))
	sh2_nop
	cat src/f_draw_plate.7.o	# PRJz(r14) < Dz(r12) の時
	cat src/f_draw_plate.8.o	# PRJz(r14) == Dz(r12) の時
	# この時点でポリゴン描画の頂点Dの座標(Dx,Dy)を(r7,r8)へ設定完了

	# 以上のr1-r8(Ax-Dy)は投影面座標系なので、ゲームスクリーン座標計へ変換
	transform_to_gs_from_prj r1 r2	# Ax, Ay
	transform_to_gs_from_prj r3 r4	# Bx, By
	transform_to_gs_from_prj r5 r6	# Cx, Cy
	transform_to_gs_from_prj r7 r8	# Dx, Dy

	# 引数r13のカラーをr9へ設定
	sh2_copy_to_reg_from_reg r9 r13

	# SP+0のdst addrをr10へ設定
	sh2_copy_to_reg_from_ptr_long r10 r15

	# 現在のPRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# ポリゴン描画コマンドを配置する関数を呼び出す
	copy_to_reg_from_val_long r11 $a_put_vdp1_command_polygon_draw_to_addr
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_nop

	# PRをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0

	# SP+0のdst addrをr10で更新
	sh2_copy_to_ptr_from_reg_long r15 r10

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# ポリゴン描画コマンドの更新
f_update_polygon() {
	# 現在のPRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 次にコマンドを配置するVRAMアドレスをスタックに積む
	copy_to_reg_from_val_long r1 $VRAM_DRAW_CMD_BASE
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1

	# [debug] 無限ループ
	# infinite_loop

	# 05c00060
	# 上面ポリゴン
	## 六面体上面の4頂点の3次元座標をレジスタへロード
	### 頂点座標が並ぶ領域の先頭アドレスをr14へロード
	copy_to_reg_from_val_long r14 $var_hexahedron_base
	### Ex -> r1
	sh2_add_to_reg_from_val_byte r14 $ofs_hexahedron_ex
	sh2_copy_to_reg_from_ptr_word r1 r14
	### Ey -> r2
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r2 r14
	### Ez -> r3
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r3 r14
	### Fx -> r4
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r4 r14
	### Fy -> r5
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r5 r14
	### Fz -> r6
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r6 r14
	### Bx -> r7
	sh2_add_to_reg_from_val_byte r14 $(two_comp $(calc16_2 "${ofs_hexahedron_fz}-${ofs_hexahedron_bx}"))
	sh2_copy_to_reg_from_ptr_word r7 r14
	### By -> r8
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r8 r14
	### Bz -> r9
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r9 r14
	### Ax -> r10
	sh2_add_to_reg_from_val_byte r14 $(two_comp $(calc16_2 "${ofs_hexahedron_bz}-${ofs_hexahedron_ax}"))
	sh2_copy_to_reg_from_ptr_word r10 r14
	### Ay -> r11
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r11 r14
	### Az -> r12
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r12 r14
	## 描画カラーをr13へ設定
	### 0xffff -> r13
	sh2_set_reg r13 ff
	## 描画関数呼び出し
	copy_to_reg_from_val_long r14 $a_draw_plate
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 05c00080
	# 側面ポリゴン
	## 六面体左側面の4頂点の3次元座標をレジスタへロード
	### 頂点座標が並ぶ領域の先頭アドレスをr14へロード
	copy_to_reg_from_val_long r14 $var_hexahedron_base
	### Ex -> r1
	sh2_add_to_reg_from_val_byte r14 $ofs_hexahedron_ex
	sh2_copy_to_reg_from_ptr_word r1 r14
	### Ey -> r2
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r2 r14
	### Ez -> r3
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r3 r14
	### Ax -> r4
	sh2_add_to_reg_from_val_byte r14 $(two_comp $ofs_hexahedron_ez)
	sh2_copy_to_reg_from_ptr_word r4 r14
	### Ay -> r5
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r5 r14
	### Az -> r6
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r6 r14
	### Dx -> r7
	sh2_add_to_reg_from_val_byte r14 $(calc16_2 "${ofs_hexahedron_dx}-${ofs_hexahedron_az}")
	sh2_copy_to_reg_from_ptr_word r7 r14
	### Dy -> r8
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r8 r14
	### Dz -> r9
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r9 r14
	### Hx -> r10
	sh2_add_to_reg_from_val_byte r14 $(calc16_2 "${ofs_hexahedron_hx}-${ofs_hexahedron_dz}")
	sh2_copy_to_reg_from_ptr_word r10 r14
	### Hy -> r11
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r11 r14
	### Hz -> r12
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r12 r14
	## 描画カラーをr13へ設定
	### 0xbded -> r13
	sh2_set_reg r0 bd
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ed
	sh2_copy_to_reg_from_reg r13 r0
	## 描画関数呼び出し
	copy_to_reg_from_val_long r14 $a_draw_plate
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 05c000a0
	# 正面ポリゴン
	## 六面体正面の4頂点の3次元座標をレジスタへロード
	### 頂点座標が並ぶ領域の先頭アドレスをr14へロード
	copy_to_reg_from_val_long r14 $var_hexahedron_base
	### Ax -> r1
	sh2_copy_to_reg_from_ptr_word r1 r14
	### Ay -> r2
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r2 r14
	### Az -> r3
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r3 r14
	### Bx -> r4
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r4 r14
	### By -> r5
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r5 r14
	### Bz -> r6
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r6 r14
	### Cx -> r7
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r7 r14
	### Cy -> r8
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r8 r14
	### Cz -> r9
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r9 r14
	### Dx -> r10
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r10 r14
	### Dy -> r11
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r11 r14
	### Dz -> r12
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r12 r14
	## 描画カラーをr13へ設定
	### 0xffdb -> r13
	sh2_set_reg r13 db
	## 描画関数呼び出し
	copy_to_reg_from_val_long r14 $a_draw_plate
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 05c000c0、あるいはそれより手前に終了コマンドを設定
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_copy_to_ptr_from_reg_word r1 r0

	# 次にコマンドを配置するVRAMアドレスをスタックから破棄
	sh2_add_to_reg_from_val_byte r15 04

	# PRをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 全頂点のX座標へ指定された値を加算する関数
# in  : r2 - 加算する値
# work: r0 - 作業用
#     : r3 - 作業用
# ※ r1を変更しないこと
#    (呼び出し元で押下状態を格納している)
f_add_reg_to_all_vertices_x() {
	# 頂点座標値が並ぶ領域の先頭アドレスをr3へ設定
	copy_to_reg_from_val_long r3 $var_hexahedron_base

	# 全頂点のX座標へ加算
	local i
	for i in A B C D E F G H; do
		if [ "$i" != "A" ]; then
			# アドレスを進める
			sh2_add_to_reg_from_val_byte r3 06
		fi
		# 変数をr0へロード
		sh2_copy_to_reg_from_ptr_word r0 r3
		# r0へr2を加算
		sh2_add_to_reg_from_reg r0 r2
		# r0を変数へ書き戻す
		sh2_copy_to_ptr_from_reg_word r3 r0
	done

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 全頂点をY軸(Z-X平面)で指定された角度右回転
# in  : r2 - 回転角度[°]
# work: r0 - 作業用
#     : r3 - 作業用(X座標のアドレス)
#     : r4 - 作業用(X座標の値, xsinθ)
#     : r5 - 作業用(xcosθ)
#     : r6 - 作業用(Z座標のアドレス)
#     : r7 - 作業用(Z座標の値, zcosθ)
#     : r8 - 作業用(zsinθ)
# ※ r1を変更しないこと
#    (呼び出し元で押下状態を格納している)
f_rotate_right_reg_about_yaxis_to_all_vertices() {
	# 頂点座標値が並ぶ領域の先頭アドレスをr3へ設定
	copy_to_reg_from_val_long r3 $var_hexahedron_base

	# 全頂点をY軸で回転
	local i
	for i in A B C D E F G H; do
		# 回転後のX座標を取得
		# x' = xcosθ + zsinθ
		## X座標をr4へロード
		sh2_copy_to_reg_from_ptr_word r4 r3
		## x * cosθをr5へ取得
		sh2_copy_to_reg_from_reg r5 r4
		multiply_reg_by_costheta_signed_long r5 r2 r3 r4 r6
		## Z座標のアドレスをr6へロード
		sh2_copy_to_reg_from_reg r6 r3
		sh2_add_to_reg_from_val_byte r6 04
		## Z座標をr7へロード
		sh2_copy_to_reg_from_ptr_word r7 r6
		## z * sinθをr8へ取得
		sh2_copy_to_reg_from_reg r8 r7
		multiply_reg_by_sintheta_signed_long r8 r2 r3 r4 r5
		## r5(xcosθ) + r8(zsinθ)をr0へ取得
		sh2_copy_to_reg_from_reg r0 r5
		sh2_add_to_reg_from_reg r0 r8
		## x'(r0)でX座標(r3の指す先)を更新
		sh2_copy_to_ptr_from_reg_word r3 r0

		# # [debug] AX == 0かチェック
		# debug_stop_if_ax_eq_0

		# 回転後のZ座標を取得
		# z' = zcosθ - xsinθ
		## z * cosθをr7へ取得
		multiply_reg_by_costheta_signed_long r7 r2 r3 r4 r5
		## x * sinθをr4へ取得
		multiply_reg_by_sintheta_signed_long r4 r2 r3 r5 r6
		## r7(zcosθ) - r4(xsinθ)をr7へ取得
		sh2_sub_to_reg_from_reg r7 r4
		## z'(r7)でZ座標(r6の指す先)を更新
		sh2_copy_to_ptr_from_reg_word r6 r7

		# アドレスを進める
		if [ "$i" != "H" ]; then
			sh2_add_to_reg_from_val_byte r3 06
		fi
	done

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 全頂点をY軸(Z-X平面)で指定された角度左回転
# in  : r2 - 回転角度[°]
# work: r0 - 作業用
#     : r3 - 作業用(Y軸旋回角度のアドレス)
#     : r4 - 作業用(Y軸旋回角度の値)
#     : r5 - 作業用
#     : r6 - 作業用
#     : r7 - 作業用
#     : r8 - 作業用
# ※ r1を変更しないこと
#    (呼び出し元で押下状態を格納している)
f_rotate_left_reg_about_yaxis_to_all_vertices() {
	# Y軸旋回角度へ回転角度を加算
	## 変数のアドレスをr3へ設定
	copy_to_reg_from_val_long r3 $var_rotation_angle_y
	## Y軸旋回角度をr4へロード
	sh2_copy_to_reg_from_ptr_word r4 r3
	## r4へ回転角度r2を加算
	sh2_add_to_reg_from_reg r4 r2
	## r4 >= 360(0x0168) ?
	sh2_set_reg r0 01
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte 68
	sh2_compare_reg_ge_reg_unsigned r4 r0
	## falseだったら後続処理を飛ばす
	(
		# r4 -= 360(0x0168)
		sh2_sub_to_reg_from_reg r4 r0
	) >src/f_rotate_left_reg_about_yaxis_to_all_vertices.1.o
	local sz_1=$(stat -c '%s' src/f_rotate_left_reg_about_yaxis_to_all_vertices.1.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_rotate_left_reg_about_yaxis_to_all_vertices.1.o
	## r4を変数へ書き戻す
	sh2_copy_to_ptr_from_reg_word r3 r4

	# 頂点座標値が並ぶ領域の先頭アドレスをr3へ設定
	copy_to_reg_from_val_long r3 $var_hexahedron_base

	# 全頂点をY軸で回転
	local i
	for i in A B C D E F G H; do
		# 原点から頂点への距離rをr5へ取得
		## X座標をr5へロード
		sh2_copy_to_reg_from_ptr_word r5 r3
		## Z座標のアドレスをr6へロード
		sh2_copy_to_reg_from_reg r6 r3
		sh2_add_to_reg_from_val_byte r6 04
		## Z座標をr7へロード
		sh2_copy_to_reg_from_ptr_word r7 r6
		## 距離算出の関数を呼び出す
		copy_to_reg_from_val_long r8 $a_calc_distance_2d
		sh2_abs_call_to_reg_after_next_inst r8
		sh2_nop

		# 回転後の座標を取得
		## 距離rをr8へもコピー
		sh2_copy_to_reg_from_reg r8 r5
		## x' = r * cosθ
		multiply_reg_by_costheta_signed_long r5 r2 r1 r3 r4
		sh2_copy_to_ptr_from_reg_word r3 r5
		## z' = r * sinθ
		multiply_reg_by_sintheta_signed_long r8 r2 r1 r3 r4
		sh2_copy_to_ptr_from_reg_word r6 r8

		# アドレスを進める
		if [ "$i" != "H" ]; then
			sh2_add_to_reg_from_val_byte r3 06
		fi
	done

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 頂点座標更新
## 頂点座標更新周期
COORD_UPDATE_CYC=0a
f_update_vertex_coordinates() {
	# Vブランク周期での座標更新だと反応が良すぎるので鈍らせる
	## 座標更新周期カウンタ変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_coord_update_cyc_counter
	## 変数の値をr0へロード
	sh2_copy_to_reg_from_ptr_byte r0 r1
	## 変数の値が周期と等しいか?
	sh2_set_reg r2 $COORD_UPDATE_CYC
	sh2_compare_reg_eq_reg r0 r2
	(
		# var_coord_update_cyc_counter != COORD_UPDATE_CYC の場合

		# 変数の値をインクリメント
		sh2_add_to_reg_from_val_byte r0 01
		# 変数の値を書き戻す
		sh2_copy_to_ptr_from_reg_byte r1 r0
		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_update_vertex_coordinates.5.o
	local sz_5=$(stat -c '%s' src/f_update_vertex_coordinates.5.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_5 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.5.o
	## var_coord_update_cyc_counter == COORD_UPDATE_CYC の場合
	### 変数の値をゼロクリア
	sh2_set_reg r0 00
	### 変数の値を書き戻す
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# 現在の押下状態1をr1へロード
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_1
	## アドレスが指す先の値をr1へロード
	sh2_copy_to_reg_from_ptr_byte r1 r1

	# ↓の押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_DOWN
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 投影面Z座標をデクリメント(カメラ後退)

		# 変数のアドレスをr2へロード
		copy_to_reg_from_val_long r2 $var_proj_z

		# 座標値をr3へロード
		sh2_copy_to_reg_from_ptr_word r3 r2

		# 座標値をデクリメント
		sh2_add_to_reg_from_val_byte r3 $(two_comp_d 1)

		# 座標値を変数へ書き戻す
		sh2_copy_to_ptr_from_reg_word r2 r3
	) >src/f_update_vertex_coordinates.3.o
	local sz_3=$(stat -c '%s' src/f_update_vertex_coordinates.3.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_3 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.3.o

	# ↑の押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_UP
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 投影面Z座標をインクリメント(カメラ前進)

		# 変数のアドレスをr2へロード
		copy_to_reg_from_val_long r2 $var_proj_z

		# 座標値をr3へロード
		sh2_copy_to_reg_from_ptr_word r3 r2

		# 座標値をインクリメント
		sh2_add_to_reg_from_val_byte r3 01

		# 座標値を変数へ書き戻す
		sh2_copy_to_ptr_from_reg_word r2 r3
	) >src/f_update_vertex_coordinates.4.o
	local sz_4=$(stat -c '%s' src/f_update_vertex_coordinates.4.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_4 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.4.o

	# ←の押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_LEFT
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 全頂点のX座標をインクリメント(左移動)

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# 各頂点X座標へ加算する値(0x01)をr2へ設定
		sh2_set_reg r2 01

		# 全頂点のX座標へ指定された値を加算する関数を呼び出す
		copy_to_reg_from_val_long r3 $a_add_reg_to_all_vertices_x
		sh2_abs_call_to_reg_after_next_inst r3
		sh2_nop

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_update_vertex_coordinates.6.o
	local sz_6=$(stat -c '%s' src/f_update_vertex_coordinates.6.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_6 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.6.o

	# →の押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_RIGHT
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 全頂点のX座標をデクリメント(右移動)

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# 各頂点X座標へ加算する値(0x01)をr2へ設定
		sh2_set_reg r2 $(two_comp_d 1)

		# 全頂点のX座標へ指定された値を加算する関数を呼び出す
		copy_to_reg_from_val_long r3 $a_add_reg_to_all_vertices_x
		sh2_abs_call_to_reg_after_next_inst r3
		sh2_nop

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_update_vertex_coordinates.7.o
	local sz_7=$(stat -c '%s' src/f_update_vertex_coordinates.7.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_7 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.7.o

	# 現在の押下状態2をr1へロード
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_2
	## アドレスが指す先の値をr1へロード
	sh2_copy_to_reg_from_ptr_byte r1 r1

	# Lの押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_L
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 全頂点をY軸で右回転

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# 回転角度をr2へ設定
		sh2_set_reg r2 01

		# 全頂点を右回転する関数を呼び出す
		copy_to_reg_from_val_long r3 $a_rotate_right_reg_about_yaxis_to_all_vertices
		sh2_abs_call_to_reg_after_next_inst r3
		sh2_nop

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_update_vertex_coordinates.8.o
	local sz_8=$(stat -c '%s' src/f_update_vertex_coordinates.8.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_8 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.8.o

	# Rの押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_R
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 全頂点をY軸で左回転

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# 回転角度をr2へ設定
		sh2_set_reg r2 01

		# 全頂点を左回転する関数を呼び出す
		copy_to_reg_from_val_long r3 $a_rotate_left_reg_about_yaxis_to_all_vertices
		sh2_abs_call_to_reg_after_next_inst r3
		sh2_nop

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_update_vertex_coordinates.9.o
	local sz_9=$(stat -c '%s' src/f_update_vertex_coordinates.9.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_9 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.9.o

	# return
	sh2_return_after_next_inst
	sh2_nop
}

debug 'before: funcs()'

funcs() {
	local fsz

	# ゲームパッドの入力状態更新
	a_update_gamepad_input_status=$FUNCS_BASE
	echo -e "a_update_gamepad_input_status=$a_update_gamepad_input_status" >>$map_file
	f_update_gamepad_input_status >src/f_update_gamepad_input_status.o
	cat src/f_update_gamepad_input_status.o

	# 指定された2次元座標の原点からの距離を算出
	fsz=$(to16 $(stat -c '%s' src/f_update_gamepad_input_status.o))
	a_calc_distance_2d=$(calc16_8 "${a_update_gamepad_input_status}+${fsz}")
	echo -e "a_calc_distance_2d=$a_calc_distance_2d" >>$map_file
	f_calc_distance_2d >src/f_calc_distance_2d.o
	cat src/f_calc_distance_2d.o

	# 指定された4頂点・カラーのポリゴンを描画するコマンドを
	# 指定されたアドレスへ配置
	fsz=$(to16 $(stat -c '%s' src/f_calc_distance_2d.o))
	a_put_vdp1_command_polygon_draw_to_addr=$(calc16_8 "${a_calc_distance_2d}+${fsz}")
	echo -e "a_put_vdp1_command_polygon_draw_to_addr=$a_put_vdp1_command_polygon_draw_to_addr" >>$map_file
	f_put_vdp1_command_polygon_draw_to_addr >src/f_put_vdp1_command_polygon_draw_to_addr.o
	cat src/f_put_vdp1_command_polygon_draw_to_addr.o

	# 4つの3次元座標で指定された平面を指定されたカラーで
	# 指定されたアドレスへ描画
	fsz=$(to16 $(stat -c '%s' src/f_put_vdp1_command_polygon_draw_to_addr.o))
	a_draw_plate=$(calc16_8 "${a_put_vdp1_command_polygon_draw_to_addr}+${fsz}")
	echo -e "a_draw_plate=$a_draw_plate" >>$map_file
	f_draw_plate >src/f_draw_plate.o
	cat src/f_draw_plate.o

	# ポリゴン描画コマンドの更新
	fsz=$(to16 $(stat -c '%s' src/f_draw_plate.o))
	a_update_polygon=$(calc16_8 "${a_draw_plate}+${fsz}")
	echo -e "a_update_polygon=$a_update_polygon" >>$map_file
	f_update_polygon >src/f_update_polygon.o
	cat src/f_update_polygon.o

	# 全頂点のX座標へ指定された値を加算
	fsz=$(to16 $(stat -c '%s' src/f_update_polygon.o))
	a_add_reg_to_all_vertices_x=$(calc16_8 "${a_update_polygon}+${fsz}")
	echo -e "a_add_reg_to_all_vertices_x=$a_add_reg_to_all_vertices_x" >>$map_file
	f_add_reg_to_all_vertices_x >src/f_add_reg_to_all_vertices_x.o
	cat src/f_add_reg_to_all_vertices_x.o

	# 全頂点をY軸(Z-X平面)で指定された角度右回転
	fsz=$(to16 $(stat -c '%s' src/f_add_reg_to_all_vertices_x.o))
	a_rotate_right_reg_about_yaxis_to_all_vertices=$(calc16_8 "${a_add_reg_to_all_vertices_x}+${fsz}")
	echo -e "a_rotate_right_reg_about_yaxis_to_all_vertices=$a_rotate_right_reg_about_yaxis_to_all_vertices" >>$map_file
	f_rotate_right_reg_about_yaxis_to_all_vertices >src/f_rotate_right_reg_about_yaxis_to_all_vertices.o
	cat src/f_rotate_right_reg_about_yaxis_to_all_vertices.o

	# 全頂点をY軸(Z-X平面)で指定された角度左回転
	fsz=$(to16 $(stat -c '%s' src/f_rotate_right_reg_about_yaxis_to_all_vertices.o))
	a_rotate_left_reg_about_yaxis_to_all_vertices=$(calc16_8 "${a_rotate_right_reg_about_yaxis_to_all_vertices}+${fsz}")
	echo -e "a_rotate_left_reg_about_yaxis_to_all_vertices=$a_rotate_left_reg_about_yaxis_to_all_vertices" >>$map_file
	f_rotate_left_reg_about_yaxis_to_all_vertices >src/f_rotate_left_reg_about_yaxis_to_all_vertices.o
	cat src/f_rotate_left_reg_about_yaxis_to_all_vertices.o

	# 頂点座標更新
	fsz=$(to16 $(stat -c '%s' src/f_rotate_left_reg_about_yaxis_to_all_vertices.o))
	a_update_vertex_coordinates=$(calc16_8 "${a_rotate_left_reg_about_yaxis_to_all_vertices}+${fsz}")
	echo -e "a_update_vertex_coordinates=$a_update_vertex_coordinates" >>$map_file
	f_update_vertex_coordinates >src/f_update_vertex_coordinates.o
	cat src/f_update_vertex_coordinates.o
}
# 変数設定のために空実行
funcs >/dev/null
rm -f $map_file

debug 'after: funcs()'

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

	# 05c00060, 05c00080, 05c000a0
	# ポリゴン更新関数呼び出し
	copy_to_reg_from_val_long r1 $a_update_polygon
	sh2_abs_call_to_reg_after_next_inst r1
	sh2_nop
}

debug 'before: main()'

main() {
	# スタックポインタ(r15)の初期化
	copy_to_reg_from_val_long r15 $INIT_SP

	# VRAMコマンドテーブル初期設定
	setup_vram_command_table

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
		# # [debug] AX == 0かチェック
		# debug_stop_if_ax_eq_0

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

		# [debug] 無限ループ
		# infinite_loop

		# 頂点座標更新
		copy_to_reg_from_val_long r1 $a_update_vertex_coordinates
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# # [debug] AX == 0かチェック
		# debug_stop_if_ax_eq_0

		# # [debug] 10°ずつ36回右回転
		# ## 全頂点を右回転する関数を36回呼び出す
		# local i
		# for i in $(seq 36); do
		# 	# 回転角度をr2へ設定
		# 	sh2_set_reg r2 0a
		# 	# 関数を呼び出す
		# 	copy_to_reg_from_val_long r3 $a_rotate_left_reg_about_yaxis_to_all_vertices
		# 	sh2_abs_call_to_reg_after_next_inst r3
		# 	sh2_nop
		# done

		# # [debug] AX == 0かチェック
		# debug_stop_if_ax_eq_0

		# # [debug] 無限ループ
		# infinite_loop

		# ポリゴン更新
		copy_to_reg_from_val_long r1 $a_update_polygon
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# # [debug] AX == 0かチェック
		# debug_stop_if_ax_eq_0

		# # [debug] 無限ループ
		# infinite_loop

		# ゲームパッドの入力状態更新
		copy_to_reg_from_val_long r1 $a_update_gamepad_input_status
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# # [debug] AX == 0かチェック
		# debug_stop_if_ax_eq_0
	) >src/main.1.o
	cat src/main.1.o
	local sz_1=$(stat -c '%s' src/main.1.o)
	sh2_rel_jump_after_next_inst $(two_comp_3_d $(((4 + sz_1) / 2)))
	sh2_nop
}

debug 'before: make_bin()'

make_bin() {
	local file_sz
	local area_sz
	local pad_sz

	debug 'before: src/jmp_main.o'

	# メインプログラム領域へジャンプ(30バイト)
	(
		copy_to_reg_from_val_long r1 $MAIN_BASE
		sh2_abs_jump_to_reg_after_next_inst r1
		sh2_nop
	) >src/jmp_main.o
	cat src/jmp_main.o

	debug 'before: src/vars.o'

	# 変数領域
	vars >src/vars.o
	cat src/vars.o
	file_sz=$(stat -c '%s' src/vars.o)
	area_sz=$(echo "ibase=16;$FUNCS_BASE - $VARS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	dd if=/dev/zero bs=1 count=$pad_sz

	debug 'before: src/funcs.o'

	# 関数領域
	funcs >src/funcs.o
	cat src/funcs.o
	file_sz=$(stat -c '%s' src/funcs.o)
	area_sz=$(echo "ibase=16;$MAIN_BASE - $FUNCS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	dd if=/dev/zero bs=1 count=$pad_sz

	debug 'before: main'

	# メインプログラム領域
	main

	debug 'after: main'
}

debug 'before: make_bin'
make_bin
debug 'after: make_bin'
