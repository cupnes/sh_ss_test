#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/ss.sh
. include/sh2.sh
. include/lib.sh
. src/funcs_map.sh

OSC_PCM_AREA_BASE=25A01000
OSC_PCM_NUM_SAMPLES=A8
OSC_PCM_SQU_HIGH=7fff
OSC_PCM_SQU_LOW=8000

main() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2

	# オシレータ用のPCMデータ(矩形波)をサウンドメモリへ配置
	copy_to_reg_from_val_long r1 $OSC_PCM_AREA_BASE
	copy_to_reg_from_val_word r2 $OSC_PCM_SQU_HIGH
	sh2_set_reg r0 $(calc16_2 "${OSC_PCM_NUM_SAMPLES}/2")	# カウント数設定
	(
		sh2_copy_to_ptr_from_reg_word r1 r2
		sh2_add_to_reg_from_val_byte r1 02
		sh2_add_to_reg_from_val_byte r0 $(two_comp_d 1)
		sh2_compare_r0_eq_val 00
	) >src/main.lsqu.o
	cat src/main.lsqu.o
	local sz_lsqu=$(stat -c '%s' src/main.lsqu.o)
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_lsqu) / 2)))
	copy_to_reg_from_val_word r2 $OSC_PCM_SQU_LOW
	sh2_set_reg r0 $(calc16_2 "${OSC_PCM_NUM_SAMPLES}/2")	# カウント数設定
	cat src/main.lsqu.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_lsqu) / 2)))

	# SCSP共通制御レジスタを設定
	copy_to_reg_from_val_long r1 $SS_CT_SND_COMMONCTR_ADDR
	## 0x00: 0x0208
	## ---- --12 3333 4444
	## 1:MEM4MB memory size 2:DAC18B dac for digital output
	## 3:VER version number 4:MVOL
	copy_to_reg_from_val_word r2 0208
	sh2_copy_to_ptr_from_reg_word r1 r2

	# スロット別制御レジスタを設定
	## スロット0のレジスタの先頭アドレスをr1へ設定
	copy_to_reg_from_val_long r1 $SS_CT_SND_SLOTCTR_S0_ADDR
	## 0x00: 0x0030
	## ---1 2334 4556 7777
	## 1:KYONEX 2:KYONB 3:SBCTL 4:SSCTL 5:LPCTL 6:PCM8B
	## 7:SA start address
	sh2_set_reg r2 20
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x02: 0x1000
	## 1111 1111 1111 1111
	## 1:SA start address
	sh2_set_reg r2 10
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x04: 0x0000
	## 1111 1111 1111 1111
	## 1:LSA loop start address
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x06: 0x00$OSC_PCM_NUM_SAMPLES
	## 1111 1111 1111 1111
	## 1:LEA loop end address
	sh2_set_reg r2 $OSC_PCM_NUM_SAMPLES
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x08: 0x001F
	## 1111 1222 2234 4444
	## 1:D2R decay 2 rate 2:D1R decay 1 rate 3:EGHOLD eg hold mode
	## 4:AR attack rate
	sh2_set_reg r2 1f
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x0A: 0x3FFF
	## -122 2233 3334 4444
	## 1:LPSLNK loop start link 2:KRS key rate scaling 3:DL decay level
	## 4:RR release rate
	sh2_set_reg r0 3f
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ff
	sh2_copy_to_ptr_from_reg_word r1 r0
	sh2_add_to_reg_from_val_byte r1 02
	## 0x0C: 0x0010
	## ---- --12 3333 3333
	## 1:STWINH stack write inhibit 2:SDIR sound direct 3:TL total level
	copy_to_reg_from_val_word r2 0010
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x0E: 0x0000
	## 1111 2222 2233 3333
	## 1:MDL modulation level 2:MDXSL modulation input x
	## 3:MDYSL modulation input y
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x10: 0x0000
	## -111 1-22 2222 2222
	## 1:OCT octave 2:FNS frequency number switch
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x12: 0x8108
	## 1222 2233 4445 5666
	## 1:LFORE 2:LFOF 3:PLFOWS 4:PLFOS 5:ALFOWS 6:ALFOS
	copy_to_reg_from_val_word r2 8108
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x14: 0x0000
	## ---- ---- -111 1222
	## 1:ISEL input select 2:OMXL input mix level
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x16: 0xE000
	## 1112 2222 3334 4444
	## 1:DISDL 2:DIPAN 3:EFSDL 4:EFPAN
	sh2_set_reg r2 e0
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

main
