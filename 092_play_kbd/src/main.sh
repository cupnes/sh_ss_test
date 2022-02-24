#!/bin/bash

# set -uex
set -ue

. include/common.sh
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

FAD_FIRST_IMG=02a2

PCM_DATA_BASE=25A01000
SQUARE_WAVE_LOW=80
SQUARE_WAVE_HIGH=7f
SQUARE_WAVE_PERIOD=A8
SQUARE_WAVE_PERIOD_DEC=$(echo "ibase=16;$SQUARE_WAVE_PERIOD" | bc)

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

	# con用のVDPCOMの1件目にskip assignを設定
	## con用のVDPCOMの1件目のアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $VRAM_CT_CON_BASE
	## CMDCTRLのJP(ビット14-12)へ設定する値をr0へ設定
	sh2_set_reg r0 $(two_digits $VDP1_JP_SKIP_ASSIGN)
	## r0を12ビット左シフト
	sh2_shift_left_logical_8 r0
	sh2_shift_left_logical_2 r0
	sh2_shift_left_logical_2 r0
	## r0をr1の指す先へ設定
	sh2_copy_to_ptr_from_reg_word r1 r0
	## アドレス(r1)を2バイト進める
	sh2_add_to_reg_from_val_byte r1 02
	## CMDLINKへ設定する値をr0へ設定
	sh2_set_reg r0 $(echo $VRAM_CT_OTHER_BASE_CMDLINK | cut -c1-2)
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte $(echo $VRAM_CT_OTHER_BASE_CMDLINK | cut -c3-4)
	sh2_extend_unsigned_to_reg_from_reg_word r0 r0
	## r0をr1の指す先へ設定
	sh2_copy_to_ptr_from_reg_word r1 r0

	# other用のVDPCOMの1件目に描画終了コマンドを配置
	## other用のVDPCOMの1件目のアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $VRAM_CT_OTHER_BASE
	## r1のアドレス先へ描画終了コマンドを配置
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
main() {
	# NMI以外の全ての割り込みをマスクする
	sh2_copy_to_reg_from_sr r0
	sh2_or_to_r0_from_val_byte $(echo $SH2_SR_BIT_I3210 | cut -c7-8)
	sh2_copy_to_sr_from_reg r0

	# スタックポインタ(r15)の初期化
	copy_to_reg_from_val_long r15 $INIT_SP

	# VRAM初期設定
	setup_vram_command_table
	setup_vram_color_lookup_table

	# VDP1/2の初期化
	vdp_init

	# 説明画像を表示
	## 使用する関数のアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $a_load_img_from_cd_and_view
	## 表示する画像のFADをr12へ設定
	copy_to_reg_from_val_word r12 $FAD_FIRST_IMG
	## 表示画像更新
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_copy_to_reg_from_reg r1 r12

	# PCMデータをサウンドメモリへ配置
	copy_to_reg_from_val_long r1 $PCM_DATA_BASE
	copy_to_reg_from_val_word r2 ${SQUARE_WAVE_LOW}${SQUARE_WAVE_LOW}
	local n=$((SQUARE_WAVE_PERIOD_DEC / 2 / 2))
	local i
	for i in $(seq $n); do
		sh2_copy_to_ptr_from_reg_word r1 r2
		sh2_add_to_reg_from_val_byte r1 02
	done
	copy_to_reg_from_val_word r2 ${SQUARE_WAVE_HIGH}${SQUARE_WAVE_HIGH}
	for i in $(seq $n); do
		sh2_copy_to_ptr_from_reg_word r1 r2
		sh2_add_to_reg_from_val_byte r1 02
	done

	# コントロールレジスタを設定
	## SCSP共通制御レジスタ
	copy_to_reg_from_val_long r1 $SS_CT_SND_COMMONCTR_ADDR
	### 00H
	copy_to_reg_from_val_word r2 0208
	sh2_copy_to_ptr_from_reg_word r1 r2
	## スロット別制御レジスタ(スロット0)
	copy_to_reg_from_val_long r1 $SS_CT_SND_SLOTCTR_S0_ADDR
	### 00H
	sh2_set_reg r2 30
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 02H
	sh2_set_reg r2 10
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 04H
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 06H
	sh2_set_reg r2 $SQUARE_WAVE_PERIOD
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 08H
	sh2_set_reg r2 20
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 0AH
	sh2_set_reg r0 3f
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ff
	sh2_copy_to_ptr_from_reg_word r1 r0
	sh2_add_to_reg_from_val_byte r1 02
	### 0CH
	copy_to_reg_from_val_word r2 0380
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 0EH
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 10H
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 12H
	copy_to_reg_from_val_word r2 8108
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 14H
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 16H
	sh2_set_reg r2 e0
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02

	# 使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_MCIPDL_ADDR
	copy_to_reg_from_val_long r13 $SS_CT_SND_MIBUF_ADDR
	copy_to_reg_from_val_long r12 $SS_CT_SND_SLOTCTR_S0_ADDR

	(
		# 何度も使用する処理を定義
		## MCIPD[3] == 1を待つ処理
		(
			sh2_copy_to_reg_from_ptr_byte r0 r14
			sh2_test_r0_and_val_byte $SS_SND_MCIPDL_BIT_MI
		) >src/main.3.o
		local sz_3=$(stat -c '%s' src/main.3.o)

		# ノート・オンのMIDIメッセージに応じた処理
		## MIBUFから0x90が取得できるまでMIBUFの取得を繰り返す
		(
			# MCIPD[3] == 1を待つ
			cat src/main.3.o
			## MCIPD[3]がセットされていなければ(T == 1)繰り返す
			sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))

			# MIBUFから1バイト取得
			sh2_copy_to_reg_from_ptr_byte r1 r13
			sh2_extend_unsigned_to_reg_from_reg_byte r1 r1

			# 0x90か?
			sh2_set_reg r0 90
			sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
			sh2_compare_reg_eq_reg r1 r0
			## 0x90ならT == 1
		) >src/main.2.o
		cat src/main.2.o
		local sz_2=$(stat -c '%s' src/main.2.o)
		### T == 0なら繰り返す
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_2) / 2)))
		## ノート番号をr1へ取得
		### MCIPD[3] == 1を待つ
		cat src/main.3.o
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))
		### MIBUFから1バイト取得
		sh2_copy_to_reg_from_ptr_byte r1 r13
		## ベロシティをr2へ取得(取得するが今の所使わない)
		### MCIPD[3] == 1を待つ
		cat src/main.3.o
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))
		### MIBUFから1バイト取得
		sh2_copy_to_reg_from_ptr_byte r2 r13
		## ノート番号に応じたPITCHレジスタ値をr3へ設定
		### ノート番号 == 0x48の場合の処理
		(
			# OCT=1, FNS=0x000
			sh2_set_reg r3 08
			sh2_shift_left_logical_8 r3
		) >src/main_n48.o
		local sz_n48=$(stat -c '%s' src/main_n48.o)
		local sz_esc=$((6 + sz_n48))
		### ノート番号 == 0x47の場合の処理
		(
			# OCT=0, FNS=0x38d
			sh2_set_reg r0 03
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte 8d
			sh2_copy_to_reg_from_reg r3 r0

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n47.o
		local sz_n47=$(stat -c '%s' src/main_n47.o)
		sz_esc=$((sz_esc + 6 + sz_n47))
		### ノート番号 == 0x46の場合の処理
		(
			# OCT=0, FNS=0x321
			sh2_set_reg r0 03
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte 21
			sh2_copy_to_reg_from_reg r3 r0

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n46.o
		local sz_n46=$(stat -c '%s' src/main_n46.o)
		sz_esc=$((sz_esc + 6 + sz_n46))
		### ノート番号 == 0x45の場合の処理
		(
			# OCT=0, FNS=0x2ba
			sh2_set_reg r0 02
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte ba
			sh2_copy_to_reg_from_reg r3 r0

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n45.o
		local sz_n45=$(stat -c '%s' src/main_n45.o)
		sz_esc=$((sz_esc + 6 + sz_n45))
		### ノート番号 == 0x44の場合の処理
		(
			# OCT=0, FNS=0x25a
			sh2_set_reg r0 02
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte 5a
			sh2_copy_to_reg_from_reg r3 r0

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n44.o
		local sz_n44=$(stat -c '%s' src/main_n44.o)
		sz_esc=$((sz_esc + 6 + sz_n44))
		### ノート番号 == 0x43の場合の処理
		(
			# OCT=0, FNS=0x1fe
			sh2_set_reg r0 01
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte fe
			sh2_copy_to_reg_from_reg r3 r0

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n43.o
		local sz_n43=$(stat -c '%s' src/main_n43.o)
		sz_esc=$((sz_esc + 6 + sz_n43))
		### ノート番号 == 0x42の場合の処理
		(
			# OCT=0, FNS=0x1a8
			sh2_set_reg r0 01
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte a8
			sh2_copy_to_reg_from_reg r3 r0

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n42.o
		local sz_n42=$(stat -c '%s' src/main_n42.o)
		sz_esc=$((sz_esc + 6 + sz_n42))
		### ノート番号 == 0x41の場合の処理
		(
			# OCT=0, FNS=0x157
			sh2_set_reg r0 01
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte 57
			sh2_copy_to_reg_from_reg r3 r0

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n41.o
		local sz_n41=$(stat -c '%s' src/main_n41.o)
		sz_esc=$((sz_esc + 6 + sz_n41))
		### ノート番号 == 0x40の場合の処理
		(
			# OCT=0, FNS=0x10a
			sh2_set_reg r0 01
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte 0a
			sh2_copy_to_reg_from_reg r3 r0

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n40.o
		local sz_n40=$(stat -c '%s' src/main_n40.o)
		sz_esc=$((sz_esc + 6 + sz_n40))
		### ノート番号 == 0x3fの場合の処理
		(
			# OCT=0, FNS=0x0c2
			sh2_set_reg r3 c2
			sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n3f.o
		local sz_n3f=$(stat -c '%s' src/main_n3f.o)
		sz_esc=$((sz_esc + 6 + sz_n3f))
		### ノート番号 == 0x3eの場合の処理
		(
			# OCT=0, FNS=0x07d
			sh2_set_reg r3 7d

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n3e.o
		local sz_n3e=$(stat -c '%s' src/main_n3e.o)
		sz_esc=$((sz_esc + 6 + sz_n3e))
		### ノート番号 == 0x3dの場合の処理
		(
			# OCT=0, FNS=0x03d
			sh2_set_reg r3 3d

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n3d.o
		local sz_n3d=$(stat -c '%s' src/main_n3d.o)
		sz_esc=$((sz_esc + 6 + sz_n3d))
		### ノート番号 == 0x3cの場合の処理
		(
			# OCT=0, FNS=0x000
			sh2_set_reg r3 00

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n3c.o
		local sz_n3c=$(stat -c '%s' src/main_n3c.o)
		### ノート番号 == 0x3c?
		sh2_set_reg r0 3c
		sh2_compare_reg_eq_reg r1 r0
		#### 等しく無い(T == 0)ならこの処理を飛ばす
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n3c - 2) / 2)))
		cat src/main_n3c.o
		### ノート番号 == 0x3d?
		sh2_set_reg r0 3d
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n3d - 2) / 2)))
		cat src/main_n3d.o
		### ノート番号 == 0x3e?
		sh2_set_reg r0 3e
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n3e - 2) / 2)))
		cat src/main_n3e.o
		### ノート番号 == 0x3f?
		sh2_set_reg r0 3f
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n3f - 2) / 2)))
		cat src/main_n3f.o
		### ノート番号 == 0x40?
		sh2_set_reg r0 40
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n40 - 2) / 2)))
		cat src/main_n40.o
		### ノート番号 == 0x41?
		sh2_set_reg r0 41
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n41 - 2) / 2)))
		cat src/main_n41.o
		### ノート番号 == 0x42?
		sh2_set_reg r0 42
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n42 - 2) / 2)))
		cat src/main_n42.o
		### ノート番号 == 0x43?
		sh2_set_reg r0 43
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n43 - 2) / 2)))
		cat src/main_n43.o
		### ノート番号 == 0x44?
		sh2_set_reg r0 44
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n44 - 2) / 2)))
		cat src/main_n44.o
		### ノート番号 == 0x45?
		sh2_set_reg r0 45
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n45 - 2) / 2)))
		cat src/main_n45.o
		### ノート番号 == 0x46?
		sh2_set_reg r0 46
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n46 - 2) / 2)))
		cat src/main_n46.o
		### ノート番号 == 0x47?
		sh2_set_reg r0 47
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n47 - 2) / 2)))
		cat src/main_n47.o
		### ノート番号 == 0x48?
		sh2_set_reg r0 48	# 2
		sh2_compare_reg_eq_reg r1 r0	# 2
		sh2_rel_jump_if_false $(two_digits_d $(((sz_n48 - 2) / 2)))	# 2
		cat src/main_n48.o
		## r3をPITCHレジスタへ設定
		sh2_copy_to_reg_from_reg r1 r12
		sh2_add_to_reg_from_val_byte r1 10
		sh2_copy_to_ptr_from_reg_word r1 r3
		## KEY_ON
		sh2_copy_to_reg_from_reg r1 r12
		sh2_set_reg r0 18
		sh2_shift_left_logical_8 r0
		sh2_or_to_r0_from_val_byte 30
		sh2_copy_to_ptr_from_reg_word r1 r0

		# ノート・オフのMIDIメッセージに応じた処理
		## MIBUFから0x90が取得できるまでMIBUFの取得を繰り返す
		cat src/main.2.o
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_2) / 2)))
		## 他バイトは読み飛ばす
		## (次のMIDIメッセージ取得処理で読み飛ばされる)
		## KEY_OFF
		sh2_copy_to_reg_from_reg r1 r12
		sh2_set_reg r0 10
		sh2_shift_left_logical_8 r0
		sh2_or_to_r0_from_val_byte 30
		sh2_copy_to_ptr_from_reg_word r1 r0
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
	if [ $pad_sz -lt 0 ]; then
		echo 'Error: variable area overflow.' >&2
		exit 1
	fi
	cat <<EOF >&2
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
		echo 'Error: function area overflow.' >&2
		exit 1
	fi
	cat <<EOF >&2
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
