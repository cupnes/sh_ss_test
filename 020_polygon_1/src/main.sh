#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh
. include/ss.sh
. include/vdp1.sh

infinite_loop() {
	sh2_rel_jump_after_next_inst $(two_comp_d 2)
	sh2_nop
}

put_file_to_addr() {
	local f=$1
	local adr=$(extend_digit $2 8)

	# R1へ$adrを格納
	sh2_set_reg r1 $(echo $adr | cut -c1-2)
	sh2_shift_left_logical_8 r1
	sh2_set_reg r0 $(echo $adr | cut -c3-4)
	sh2_and_to_r0_from_val_byte ff
	sh2_or_to_reg_from_reg r1 r0
	sh2_shift_left_logical_8 r1
	sh2_set_reg r0 $(echo $adr | cut -c5-6)
	sh2_and_to_r0_from_val_byte ff
	sh2_or_to_reg_from_reg r1 r0
	sh2_shift_left_logical_8 r1
	sh2_set_reg r0 $(echo $adr | cut -c7-8)
	sh2_and_to_r0_from_val_byte ff
	sh2_or_to_reg_from_reg r1 r0

	# $fを1バイトずつ$adrへ配置
	for b in $(od -A n -t x1 $f); do
		sh2_set_reg r2 $b
		sh2_copy_to_ptr_from_reg_byte r1 r2
		sh2_add_to_reg_from_val_byte r1 01
	done
}

main() {
	# VDP1のシステムレジスタ設定
	## TVMR(0x00100000)
	## b20に1がセットされているアドレス
	sh2_set_reg r3 10
	### 0x00000010
	sh2_shift_left_logical_8 r3
	### 0x00001000
	sh2_shift_left_logical_8 r3
	### 0x00100000
	### VBE(b3) = 0
	### TVM(b2-b0) = 0b000
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r3 r0
	## FBCR(0x100002)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_copy_to_ptr_from_reg_word r3 r0


	# コマンドテーブル設定
	local com_adr=$SS_VDP1_VRAM_ADDR
	vdp1_command_polygon_draw >src/polygon_draw.o
	put_file_to_addr src/polygon_draw.o $com_adr

	com_adr=$(calc16 "$com_adr+20")
	vdp1_command_draw_end >src/draw_end.o
	put_file_to_addr src/draw_end.o $com_adr


	# VDP1のシステムレジスタ設定
	## PTMR(0x00100004)
	sh2_add_to_reg_from_val_byte r3 02
	## PTM(b1-b0) = 0b01
	sh2_set_reg r0 01
	sh2_copy_to_ptr_from_reg_word r3 r0

	infinite_loop
}

main
