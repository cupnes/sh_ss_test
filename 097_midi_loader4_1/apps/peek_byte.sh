#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/ss.sh
. include/sh2.sh
. include/lib.sh
. src/funcs_map.sh

main() {
	local addr=$1

	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# 使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_MCIPDH_ADDR
	copy_to_reg_from_val_long r13 $SS_CT_SND_MOBUF_ADDR

	# 指定されたアドレスから値を読み出し
	copy_to_reg_from_val_long r1 $addr
	sh2_copy_to_reg_from_ptr_byte r1 r1

	# データパケットをMIDI送信
	## ステータス・バイト(0x91)送信
	### MCIPDのMOビットが設定されるのを待つ
	(
		sh2_copy_to_reg_from_ptr_byte r0 r14
		sh2_test_r0_and_val_byte $SS_SND_MCIPDH_BIT_MO
		## 論理積の結果が0の時、T == 1。0以外の時、T == 0
		## なので、MOビット == 1(空き有り)の時、T == 0
		## MOビット == 0(空き無し)の時、T == 1
	) >apps/peek_byte.1.o
	cat apps/peek_byte.1.o
	local sz_1=$(stat -c '%s' apps/peek_byte.1.o)
	#### T == 1なら繰り返す
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	### MOBUFへ書き込み
	sh2_set_reg r0 91
	sh2_copy_to_ptr_from_reg_byte r13 r0
	## 補助バイト送信
	### MCIPDのMOビットが設定されるのを待つ
	cat apps/peek_byte.1.o
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	### 補助バイト作成
	sh2_copy_to_reg_from_reg r0 r1
	sh2_and_to_r0_from_val_byte 80
	sh2_shift_right_logical r0
	### MOBUFへ書き込み
	sh2_copy_to_ptr_from_reg_byte r13 r0
	## データバイト送信
	### MCIPDのMOビットが設定されるのを待つ
	cat apps/peek_byte.1.o
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	### データバイト作成
	sh2_copy_to_reg_from_reg r0 r1
	sh2_and_to_r0_from_val_byte 7f
	### MOBUFへ書き込み
	sh2_copy_to_ptr_from_reg_byte r13 r0

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

main $1
