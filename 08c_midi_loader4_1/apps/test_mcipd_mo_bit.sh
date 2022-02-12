#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/ss.sh
. include/sh2.sh
. include/lib.sh
. src/funcs_map.sh

main() {
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
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	copy_to_reg_from_val_long r14 $SS_CT_SND_MCIPDH_ADDR
	copy_to_reg_from_val_long r13 $a_putreg_byte

	# MCIPD(High)を読んで出力
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_copy_to_reg_from_ptr_byte r1 r14
	## -> 0x07 (MOビット == 1)

	# MOBUFを意図的にオーバーフローさせる
	## 10個くらいデータを書く
	copy_to_reg_from_val_long r1 $SS_CT_SND_MOBUF_ADDR
	sh2_set_reg r0 90
	sh2_copy_to_ptr_from_reg_byte r1 r0
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_byte r1 r0
	sh2_set_reg r0 01
	sh2_copy_to_ptr_from_reg_byte r1 r0
	sh2_set_reg r0 02
	sh2_copy_to_ptr_from_reg_byte r1 r0
	sh2_set_reg r0 03
	sh2_copy_to_ptr_from_reg_byte r1 r0
	sh2_set_reg r0 04
	sh2_copy_to_ptr_from_reg_byte r1 r0
	sh2_set_reg r0 05
	sh2_copy_to_ptr_from_reg_byte r1 r0
	sh2_set_reg r0 06
	sh2_copy_to_ptr_from_reg_byte r1 r0
	sh2_set_reg r0 07
	sh2_copy_to_ptr_from_reg_byte r1 r0
	sh2_set_reg r0 08
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# MCIPD(High)を読んで出力
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_copy_to_reg_from_ptr_byte r1 r14
	## -> 0x05 (MOビット == 0)

	# 退避したレジスタを復帰しreturn
	## pr
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
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

main
