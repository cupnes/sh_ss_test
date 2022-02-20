#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/ss.sh
. include/sh2.sh
. include/lib.sh
. src/funcs_map.sh

PCM_DATA_BASE=25A01000
SQUARE_WAVE_LOW=80
SQUARE_WAVE_HIGH=7f
SQUARE_WAVE_PERIOD=80
SQUARE_WAVE_PERIOD_DEC=$(echo "ibase=16;$SQUARE_WAVE_PERIOD" | bc)

main() {
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

	# PCMデータをサウンドメモリへ配置
	copy_to_reg_from_val_long r1 $PCM_DATA_BASE
	copy_to_reg_from_val_long r2 ${SQUARE_WAVE_LOW}${SQUARE_WAVE_LOW}${SQUARE_WAVE_LOW}${SQUARE_WAVE_LOW}
	local n=$((SQUARE_WAVE_PERIOD_DEC / 2 / 4))
	local i
	for i in $(seq $n); do
		sh2_copy_to_ptr_from_reg_long r1 r2
		sh2_add_to_reg_from_val_byte r1 04
	done
	copy_to_reg_from_val_long r2 ${SQUARE_WAVE_HIGH}${SQUARE_WAVE_HIGH}${SQUARE_WAVE_HIGH}${SQUARE_WAVE_HIGH}
	for i in $(seq $n); do
		sh2_copy_to_ptr_from_reg_long r1 r2
		sh2_add_to_reg_from_val_byte r1 04
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
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	### 0AH
	sh2_set_reg r2 3c
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
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

	# KEY_ONにする
	copy_to_reg_from_val_long r1 $SS_CT_SND_SLOTCTR_S0_ADDR
	copy_to_reg_from_val_word r2 1830
	sh2_copy_to_ptr_from_reg_word r1 r2

	# 退避したレジスタを復帰しreturn
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

main
