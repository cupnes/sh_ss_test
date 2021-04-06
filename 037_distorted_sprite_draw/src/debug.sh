if [ "${INCLUDE_DEBUG_SH+is_defined}" ]; then
	return
fi
INCLUDE_DEBUG_SH=true

debug() {
	echo "## [$(date '+%T')] $1" >&2
}

# [debug] AX == 0だったら無限ループで固まるマクロ
debug_stop_if_ax_eq_0() {
	# 使用するレジスタをスタックへ退避
	## R1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## R0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# AXをR1へロード
	copy_to_reg_from_val_long r1 $var_hexahedron_ax
	sh2_copy_to_reg_from_ptr_word r1 r1

	# r1 == 0 ?
	sh2_xor_to_reg_from_reg r0 r0
	sh2_compare_reg_eq_reg r1 r0

	# r1 != 0 なら無限ループを飛ばす
	(
		# 無限ループ
		infinite_loop
	) >src/debug_stop_if_ax_eq_0.1.o
	local sz_1=$(stat -c '%s' src/debug_stop_if_ax_eq_0.1.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/debug_stop_if_ax_eq_0.1.o

	# スタックへ退避したレジスタを復帰
	## R0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## R1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
}
