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

	# 繰り返し使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $SS_SMPC_SF_ADDR
	copy_to_reg_from_val_long r13 $SS_SMPC_COMREG_ADDR
	copy_to_reg_from_val_long r12 $SS_CT_SND_COMMONCTR_ADDR

	# サウンドCPUを停止(SNDOFF発行)
	## SFビットに1をセット
	sh2_set_reg r0 01
	sh2_copy_to_ptr_from_reg_byte r14 r0
	## COMREGにSNDOFFをセット
	sh2_set_reg r0 $SS_SMPC_COMREG_SNDOFF
	sh2_copy_to_ptr_from_reg_byte r13 r0
	## SFが0になるのを待つ
	(
		# r0へr14の指す先(SF)の値をロード
		sh2_copy_to_reg_from_ptr_byte r0 r14
		# bit0が1の間、ここで待つ
		sh2_test_r0_and_val_byte 01
	) >apps/mc68k_read_mibuf.main.1.o
	local sz_1=$(stat -c '%s' apps/mc68k_read_mibuf.main.1.o)
	cat apps/mc68k_read_mibuf.main.1.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_1) / 2)))

	# SCSP共通制御レジスタのMEM4MBビットに1、DAC18Bビットに0を設定
	copy_to_reg_from_val_word r1 0208
	sh2_copy_to_ptr_from_reg_word r12 r1

	# サウンドCPUへのすべての割り込み禁止
	

	# 退避したレジスタを復帰しreturn
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

main
