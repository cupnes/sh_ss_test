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
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## r3
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r3
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
	sh2_copy_to_reg_from_ptr_word r1 r1

	# 1バイト目(b15-8)をr2へ設定
	sh2_copy_to_reg_from_reg r2 r1
	sh2_shift_right_logical_8 r2

	# 2バイト目(b7-0)をr3へ設定
	sh2_copy_to_reg_from_reg r3 r1

	# 補助バイトをr1へ設定
	sh2_set_reg r1 00
	sh2_copy_to_reg_from_reg r0 r2
	sh2_and_to_r0_from_val_byte 80
	sh2_shift_right_logical r0
	sh2_or_to_reg_from_reg r1 r0
	sh2_copy_to_reg_from_reg r0 r3
	sh2_and_to_r0_from_val_byte 80
	sh2_shift_right_logical_2 r0
	sh2_or_to_reg_from_reg r1 r0

	# MSBを0にする
	## 1バイト目
	sh2_set_reg r0 7f
	sh2_and_to_reg_from_reg r2 r0
	## 2バイト目
	sh2_and_to_reg_from_reg r3 r0

	# データパケットをMIDI送信
	## ステータス・バイト(0x92)送信
	### MCIPDのMOビットが設定されるのを待つ
	(
		sh2_copy_to_reg_from_ptr_byte r0 r14
		sh2_test_r0_and_val_byte $SS_SND_MCIPDH_BIT_MO
		## 論理積の結果が0の時、T == 1。0以外の時、T == 0
		## なので、MOビット == 1(空き有り)の時、T == 0
		## MOビット == 0(空き無し)の時、T == 1
	) >apps/peek_word.1.o
	cat apps/peek_word.1.o
	local sz_1=$(stat -c '%s' apps/peek_word.1.o)
	#### T == 1なら繰り返す
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	### MOBUFへ書き込み
	sh2_set_reg r0 92
	sh2_copy_to_ptr_from_reg_byte r13 r0
	## 補助バイト送信
	### MCIPDのMOビットが設定されるのを待つ
	cat apps/peek_word.1.o
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	### MOBUFへ書き込み
	sh2_copy_to_ptr_from_reg_byte r13 r1
	## データバイト(1バイト目)送信
	### MCIPDのMOビットが設定されるのを待つ
	cat apps/peek_word.1.o
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	### MOBUFへ書き込み
	sh2_copy_to_ptr_from_reg_byte r13 r2
	## データバイト(2バイト目)送信
	### MCIPDのMOビットが設定されるのを待つ
	cat apps/peek_word.1.o
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	### MOBUFへ書き込み
	sh2_copy_to_ptr_from_reg_byte r13 r3
	## パディング送信
	### MCIPDのMOビットが設定されるのを待つ
	cat apps/peek_word.1.o
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	### MOBUFへ書き込み
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_byte r13 r0

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r3
	sh2_copy_to_reg_from_ptr_long r3 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
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
