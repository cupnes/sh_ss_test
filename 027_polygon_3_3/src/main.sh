#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/vdp1.sh

INIT_SP=06004000
PROGRAM_ENTRY_ADDR=06004000
VARS_BASE=0600401E
FUNCS_BASE=06005000
MAIN_BASE=06010000

map_file=map.sh
rm -f $map_file

vars() {
	# 投影面Z座標
	var_projection_plane_z=$VARS_BASE
	echo -e "var_projection_plane_z=$var_projection_plane_z" >>$map_file
	echo -en '\x00\x64'	# 100

	# 六面体の8頂点の3次元座標
	## 頂点A(正面左上)
	### X
	var_hexahedron_ax=$(calc16_8 "$var_projection_plane_z+2")
	echo -e "var_hexahedron_ax=$var_hexahedron_ax" >>$map_file
	echo -en '\x00\x7a'	# 122
	### Y
	var_hexahedron_ay=$(calc16_8 "$var_hexahedron_ax+2")
	echo -e "var_hexahedron_ay=$var_hexahedron_ay" >>$map_file
	echo -en '\x00\x2d'	# 45
	### Z
	var_hexahedron_az=$(calc16_8 "$var_hexahedron_ay+2")
	echo -e "var_hexahedron_az=$var_hexahedron_az" >>$map_file
	echo -en '\x00\x64'	# 100
	## 頂点B(正面右上)
	### X
	var_hexahedron_bx=$(calc16_8 "$var_hexahedron_az+2")
	echo -e "var_hexahedron_bx=$var_hexahedron_bx" >>$map_file
	echo -en '\x00\xc5'	# 197
	### Y
	var_hexahedron_by=$(calc16_8 "$var_hexahedron_bx+2")
	echo -e "var_hexahedron_by=$var_hexahedron_by" >>$map_file
	echo -en '\x00\x2d'	# 45
	### Z
	var_hexahedron_bz=$(calc16_8 "$var_hexahedron_by+2")
	echo -e "var_hexahedron_bz=$var_hexahedron_bz" >>$map_file
	echo -en '\x00\x64'	# 100
	## 頂点C(正面右下)
	### X
	var_hexahedron_cx=$(calc16_8 "$var_hexahedron_bz+2")
	echo -e "var_hexahedron_cx=$var_hexahedron_cx" >>$map_file
	echo -en '\x00\xc5'	# 197
	### Y
	var_hexahedron_cy=$(calc16_8 "$var_hexahedron_cx+2")
	echo -e "var_hexahedron_cy=$var_hexahedron_cy" >>$map_file
	echo -en '\x00\xb3'	# 179
	### Z
	var_hexahedron_cz=$(calc16_8 "$var_hexahedron_cy+2")
	echo -e "var_hexahedron_cz=$var_hexahedron_cz" >>$map_file
	echo -en '\x00\x64'	# 100
	## 頂点D(正面左下)
	### X
	var_hexahedron_dx=$(calc16_8 "$var_hexahedron_cz+2")
	echo -e "var_hexahedron_dx=$var_hexahedron_dx" >>$map_file
	echo -en '\x00\x7a'	# 122
	### Y
	var_hexahedron_dy=$(calc16_8 "$var_hexahedron_dx+2")
	echo -e "var_hexahedron_dy=$var_hexahedron_dy" >>$map_file
	echo -en '\x00\xb3'	# 179
	### Z
	var_hexahedron_dz=$(calc16_8 "$var_hexahedron_dy+2")
	echo -e "var_hexahedron_dz=$var_hexahedron_dz" >>$map_file
	echo -en '\x00\x64'	# 100
	## 頂点E(背面左上)
	### X
	var_hexahedron_ex=$(calc16_8 "$var_hexahedron_dz+2")
	echo -e "var_hexahedron_ex=$var_hexahedron_ex" >>$map_file
	echo -en '\x00\x7a'	# 122
	### Y
	var_hexahedron_ey=$(calc16_8 "$var_hexahedron_ex+2")
	echo -e "var_hexahedron_ey=$var_hexahedron_ey" >>$map_file
	echo -en '\x00\x2d'	# 45
	### Z
	var_hexahedron_ez=$(calc16_8 "$var_hexahedron_ey+2")
	echo -e "var_hexahedron_ez=$var_hexahedron_ez" >>$map_file
	echo -en '\x00\x77'	# 119
	## 頂点F(背面右上)
	### X
	var_hexahedron_fx=$(calc16_8 "$var_hexahedron_ez+2")
	echo -e "var_hexahedron_fx=$var_hexahedron_fx" >>$map_file
	echo -en '\x00\xc5'	# 197
	### Y
	var_hexahedron_fy=$(calc16_8 "$var_hexahedron_fx+2")
	echo -e "var_hexahedron_fy=$var_hexahedron_fy" >>$map_file
	echo -en '\x00\x2d'	# 45
	### Z
	var_hexahedron_fz=$(calc16_8 "$var_hexahedron_fy+2")
	echo -e "var_hexahedron_fz=$var_hexahedron_fz" >>$map_file
	echo -en '\x00\x77'	# 119
	## 頂点G(背面右下)
	### X
	var_hexahedron_gx=$(calc16_8 "$var_hexahedron_fz+2")
	echo -e "var_hexahedron_gx=$var_hexahedron_gx" >>$map_file
	echo -en '\x00\xc5'	# 197
	### Y
	var_hexahedron_gy=$(calc16_8 "$var_hexahedron_gx+2")
	echo -e "var_hexahedron_gy=$var_hexahedron_gy" >>$map_file
	echo -en '\x00\xb3'	# 179
	### Z
	var_hexahedron_gz=$(calc16_8 "$var_hexahedron_gy+2")
	echo -e "var_hexahedron_gz=$var_hexahedron_gz" >>$map_file
	echo -en '\x00\x77'	# 119
	## 頂点H(背面左下)
	### X
	var_hexahedron_hx=$(calc16_8 "$var_hexahedron_gz+2")
	echo -e "var_hexahedron_hx=$var_hexahedron_hx" >>$map_file
	echo -en '\x00\x7a'	# 122
	### Y
	var_hexahedron_hy=$(calc16_8 "$var_hexahedron_hx+2")
	echo -e "var_hexahedron_hy=$var_hexahedron_hy" >>$map_file
	echo -en '\x00\xb3'	# 179
	### Z
	var_hexahedron_hz=$(calc16_8 "$var_hexahedron_hy+2")
	echo -e "var_hexahedron_hz=$var_hexahedron_hz" >>$map_file
	echo -en '\x00\x77'	# 119
}
# 変数設定のために空実行
vars >/dev/null
rm -f $map_file

# 指定された4頂点・カラーのポリゴンを描画するコマンドを
# 指定されたアドレスへ配置
# in  : r1  - dst addr
#       r2  - Ax
#       r3  - Ay
#       r4  - Bx
#       r5  - By
#       r6  - Cx
#       r7  - Cy
#       r8  - Dx
#       r9  - Dy
#       r10 - color
# out : r1  - dst addrへ最後に書き込んだ次のアドレス
# work: PR  - この関数を呼び出したBSR/JSR命令のアドレス
#     : r0  - 作業用
f_put_vdp1_command_polygon_draw_to_addr() {
	# CMDCTRL
	# 0b0000 0000 0000 0100
	# - JP(b14-b12) = 0b000
	# 0x0004 -> [r1]
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte 04
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDLINK
	# 0x0000 -> [r1]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDPMOD
	# 0b0000 1000 1100 0000
	# - MON(b15) = 0 (VDP2の機能を使わない)
	# - Pclp(b11) = 1 (クリッピングが必要かどうかの座標計算無効)
	# - Clip(b10) = 0 (ユーザクリッピング座標に従わない)
	# - Cmod(b9) = 0 (Clip=0なので無効)
	# - Mesh(b8) = 0 (メッシュ無効)
	# - 色演算(b2-b0) = 0b000 (色演算は全て無効)
	# 0x08c0 -> [r1]
	sh2_set_reg r0 08
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte c0
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDCOLR
	# r10 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r10
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDSRCA
	# 0x0000 -> [r1]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDSIZE
	# 0x0000 -> [r1]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r1 r0
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDXA
	# 頂点AのX座標
	# r2 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r2
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDYA
	# 頂点AのY座標
	# r3 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r3
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDXB
	# 頂点BのX座標
	# r4 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r4
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDYB
	# 頂点BのY座標
	# r5 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r5
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDXC
	# 頂点CのX座標
	# r6 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r6
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDYC
	# 頂点CのY座標
	# r7 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r7
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDXD
	# 頂点DのX座標
	# r8 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r8
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

	# CMDYD
	# 頂点DのY座標
	# r9 -> [r1]
	sh2_copy_to_ptr_from_reg_word r1 r9
	# r1 += 2
	sh2_add_to_reg_from_val_byte r1 02

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
	# 投影面Z座標(PRJz)より小さい(カメラに近い)Z座標が1つでもあれば
	# 何もせずreturn
	## Az < PRJz ?

	# return
	sh2_return_after_next_inst
	sh2_nop
}

funcs() {
	local fsz

	# 指定された4頂点・カラーのポリゴンを描画するコマンドを
	# 指定されたアドレスへ配置
	a_put_vdp1_command_polygon_draw_to_addr=$FUNCS_BASE
	echo -e "a_put_vdp1_command_polygon_draw_to_addr=$a_put_vdp1_command_polygon_draw_to_addr" >>$map_file
	f_put_vdp1_command_polygon_draw_to_addr

	# 4つの3次元座標で指定された平面を指定されたカラーで
	# 指定されたアドレスへ描画
	f_put_vdp1_command_polygon_draw_to_addr >src/f_put_vdp1_command_polygon_draw_to_addr.o
	fsz=$(to16 $(stat -c '%s' src/f_put_vdp1_command_polygon_draw_to_addr.o))
	a_draw_plate=$(calc16_8 "${a_put_vdp1_command_polygon_draw_to_addr}+${fsz}")
	echo -e "a_draw_plate=$a_draw_plate" >>$map_file
	f_draw_plate
}
# 変数設定のために空実行
funcs >/dev/null
rm -f $map_file

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

	# 05c00060
	# 正面ポリゴン
	## 次にコマンドを配置するVRAMアドレスをスタックに積む
	## (この時点のr1にそのアドレスが入っている)
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	infinite_loop
	## 六面体正面の4頂点の3次元座標をレジスタへロード
	## 描画関数呼び出し

	## 0x007a -> r2 (Ax)
	sh2_set_reg r2 7a
	## 0x002d -> r3 (Ay)
	sh2_set_reg r3 2d
	# 頂点B
	## 0x00c5 -> r4 (Bx)
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte c5
	sh2_copy_to_reg_from_reg r4 r0
	## 0x002d -> r5 (By)
	sh2_set_reg r5 2d
	# 頂点C
	## 0x00c5 -> r6 (Cx)
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte c5
	sh2_copy_to_reg_from_reg r6 r0
	## 0x00b3 -> r7 (Cy)
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte b3
	sh2_copy_to_reg_from_reg r7 r0
	# 頂点D
	## 0x007a -> r8 (Dx)
	sh2_set_reg r8 7a
	## 0x00b3 -> r9 (Dy)
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte b3
	sh2_copy_to_reg_from_reg r9 r0
	# カラー
	## 0xffdb -> r10
	sh2_set_reg r10 db
	# $a_put_vdp1_command_polygon_draw_to_addr -> r11
	copy_to_reg_from_val_long r11 $a_put_vdp1_command_polygon_draw_to_addr
	# call r11
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_nop

	# 05c00080
	# 側面ポリゴン
	# 0x0066 -> r2
	sh2_set_reg r2 66
	# 0x0025 -> r3
	sh2_set_reg r3 25
	# 0x007a -> r4
	sh2_set_reg r4 7a
	# 0x002d -> r5
	sh2_set_reg r5 2d
	# 0x007a -> r6
	sh2_set_reg r6 7a
	# 0x00b3 -> r7
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte b3
	sh2_copy_to_reg_from_reg r7 r0
	# 0x0066 -> r8
	sh2_set_reg r8 66
	# 0x0096 -> r9
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte 96
	sh2_copy_to_reg_from_reg r9 r0
	# 0xbded -> r10
	sh2_set_reg r0 bd
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ed
	sh2_copy_to_reg_from_reg r10 r0
	# $a_put_vdp1_command_polygon_draw_to_addr -> r11
	copy_to_reg_from_val_long r11 $a_put_vdp1_command_polygon_draw_to_addr
	# call r11
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_nop

	# 05c000a0
	# 上面ポリゴン
	# 0x0066 -> r2
	sh2_set_reg r2 66
	# 0x0025 -> r3
	sh2_set_reg r3 25
	# 0x00a5 -> r4
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte a5
	sh2_copy_to_reg_from_reg r4 r0
	# 0x0025 -> r5
	sh2_set_reg r5 25
	# 0x00c5 -> r6
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte c5
	sh2_copy_to_reg_from_reg r6 r0
	# 0x002d -> r7
	sh2_set_reg r7 2d
	# 0x007a -> r8
	sh2_set_reg r8 7a
	# 0x002d -> r9
	sh2_set_reg r9 2d
	# 0xffff -> r10
	sh2_set_reg r10 ff
	# $a_put_vdp1_command_polygon_draw_to_addr -> r11
	copy_to_reg_from_val_long r11 $a_put_vdp1_command_polygon_draw_to_addr
	# call r11
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_nop

	com_adr=$(calc16 "$com_adr+80")
	vdp1_command_draw_end >src/draw_end.o
	put_file_to_addr src/draw_end.o $com_adr
}

main() {
	# スタックポインタ(r15)の初期化
	copy_to_reg_from_val_long r15 $INIT_SP

	# VRAMコマンドテーブル設定
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

	infinite_loop
}

make_bin() {
	local file_sz
	local area_sz
	local pad_sz

	# メインプログラム領域へジャンプ(30バイト)
	(
		copy_to_reg_from_val_long r1 $MAIN_BASE
		sh2_abs_jump_to_reg_after_next_inst r1
		sh2_nop
	) >src/jmp_main.o
	cat src/jmp_main.o

	# 変数領域
	vars >src/vars.o
	cat src/vars.o
	file_sz=$(stat -c '%s' src/vars.o)
	area_sz=$(echo "ibase=16;$FUNCS_BASE - $VARS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	dd if=/dev/zero bs=1 count=$pad_sz

	# 関数領域
	funcs >src/funcs.o
	cat src/funcs.o
	file_sz=$(stat -c '%s' src/funcs.o)
	area_sz=$(echo "ibase=16;$MAIN_BASE - $FUNCS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	dd if=/dev/zero bs=1 count=$pad_sz

	# メインプログラム領域
	main
}

make_bin
