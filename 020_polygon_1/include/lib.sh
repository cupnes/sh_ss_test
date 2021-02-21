if [ "${INCLUDE_LIB_SH+is_defined}" ]; then
	return
fi
INCLUDE_LIB_SH=true

. include/common.sh
. include/sh2.sh

infinite_loop() {
	sh2_rel_jump_after_next_inst $(two_comp_d 2)
	sh2_nop
}

# ※ 作業用にR0を使用する
copy_to_reg_from_val_long() {
	local reg=$1
	local val=$2

	sh2_set_reg $reg $(echo $val | cut -c1-2)
	sh2_shift_left_logical_8 $reg
	sh2_set_reg r0 $(echo $val | cut -c3-4)
	sh2_and_to_r0_from_val_byte ff
	sh2_or_to_reg_from_reg $reg r0
	sh2_shift_left_logical_8 $reg
	sh2_set_reg r0 $(echo $val | cut -c5-6)
	sh2_and_to_r0_from_val_byte ff
	sh2_or_to_reg_from_reg $reg r0
	sh2_shift_left_logical_8 $reg
	sh2_set_reg r0 $(echo $val | cut -c7-8)
	sh2_and_to_r0_from_val_byte ff
	sh2_or_to_reg_from_reg $reg r0
}

put_file_to_addr() {
	local f=$1
	local adr=$(extend_digit $2 8)

	# R1へ$adrを格納
	copy_to_reg_from_val_long r1 $adr

	# $fを1バイトずつ$adrへ配置
	for b in $(od -A n -t x1 $f); do
		sh2_set_reg r2 $b
		sh2_copy_to_ptr_from_reg_byte r1 r2
		sh2_add_to_reg_from_val_byte r1 01
	done
}
