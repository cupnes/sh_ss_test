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
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r12
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

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
	copy_to_reg_from_val_long r1 $SS_CT_SND_SCIEB_ADDR
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2

	# サウンドCPUへの割り込み要求を全てリセットする
	copy_to_reg_from_val_long r1 $SS_CT_SND_SCIRE_ADDR
	copy_to_reg_from_val_word r2 07ff
	sh2_copy_to_ptr_from_reg_word r1 r2

	# サウンドCPUのスタックポインタ設定
	# SP = 0x00080000
	copy_to_reg_from_val_long r1 $SS_CT_SND_CPU_RIISP_ADDR
	sh2_set_reg r2 08
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2

	# サウンドCPUのプログラムカウンタ設定
	# PC = 0x00000400
	copy_to_reg_from_val_long r1 $SS_CT_SND_CPU_RIPC_ADDR
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	sh2_set_reg r2 04
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2

	# サウンドCPU(MC68000)命令をシェル変数へ設定
	## 全ての割り込みを無効にする
	## 46FC 2700             move.w  #0x2700, %sr
	local mc68k_ml='46FC 2700'
	## 0x25A00500(mc68kから見たアドレス=0x00000500)へ0xbeefを設定
	## 31FC BEEF             move.w  #0xbeef, 0x00000500
	## 0500
	mc68k_ml="${mc68k_ml} 31FC BEEF 0500"
	## 無限ループ
	## 4EFA FFFE             jmp     .
	mc68k_ml="${mc68k_ml} 4EFA FFFE"

	# サウンドRAMへMC68000命令を設定
	copy_to_reg_from_val_long r1 $SS_CT_SND_CPU_AFTER_VEC_ADDR
	local w
	for w in $mc68k_ml; do
		copy_to_reg_from_val_word r2 $w
		sh2_copy_to_ptr_from_reg_word r1 r2
		sh2_add_to_reg_from_val_byte r1 02
	done

	# サウンドCPUを起動(SNDON発行)
	## SFビットに1をセット
	sh2_set_reg r0 01
	sh2_copy_to_ptr_from_reg_byte r14 r0
	## COMREGにSNDONをセット
	sh2_set_reg r0 $SS_SMPC_COMREG_SNDON
	sh2_copy_to_ptr_from_reg_byte r13 r0
	## SFが0になるのを待つ
	cat apps/mc68k_read_mibuf.main.1.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_1) / 2)))

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r12 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

main
