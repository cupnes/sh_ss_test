#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/charcode.sh

main() {
	# 変更が発生するレジスタを退避
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# "ABC\n"を出力
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_set_reg r1 $CHARCODE_A
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_set_reg r1 $CHARCODE_B
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_set_reg r1 $CHARCODE_C
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_set_reg r1 $CHARCODE_LF

	# 退避したレジスタを復帰しreturn
	## pr
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
	## return
	sh2_return_after_next_inst
	sh2_nop
}

main
