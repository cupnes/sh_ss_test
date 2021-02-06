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
	local com_adr=$SS_VDP1_VRAM_ADDR
	vdp1_command_polygon_draw >src/polygon_draw.o
	put_file_to_addr src/polygon_draw.o $com_adr

	com_adr=$(calc16 "$com_adr+20")
	vdp1_command_draw_end >src/draw_end.o
	put_file_to_addr src/draw_end.o $com_adr

	infinite_loop
}

main
