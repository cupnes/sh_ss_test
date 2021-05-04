#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh
. include/memmap.sh

# 指定されたアドレスからアドレスへ、指定されたサイズ分コピー
# in  : r1  - コピー先アドレス
#       r2  - コピー元アドレス
#       r3  - コピーするバイト数
# work: r0  - 作業用
#       r4  - 作業用
# ※ in,work全てのレジスタがこの関数内で何らかの書き換えが行われる
f_memcpy() {
	# r2のアドレスからr1のアドレスへr3バイト分のデータをロード
	## r3 > 0 ?
	sh2_xor_to_reg_from_reg r0 r0	# 2
	sh2_compare_reg_gt_reg_signed r3 r0	# 2
	## falseだったら以降の処理を飛ばす
	(
		# r3 > 0

		# [r1] = [r2]
		sh2_copy_to_reg_from_ptr_byte r4 r2
		sh2_copy_to_ptr_from_reg_byte r1 r4

		# r1 += 1, r2 += 1
		sh2_add_to_reg_from_val_byte r1 01
		sh2_add_to_reg_from_val_byte r2 01

		# r3 += -1
		sh2_add_to_reg_from_val_byte r3 $(two_comp_d 1)
	) >src/f_memcpy.1.o
	local sz_1=$(stat -c '%s' src/f_memcpy.1.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_1 + 2 + 2) / 2)))	# 2
	sh2_nop	# 2
	cat src/f_memcpy.1.o	# sz_1
	sh2_rel_jump_after_next_inst $(two_comp_3_d $(((2 + 2 + sz_1 + 2 + 2 + 2 + 2) / 2)))	# 2
	sh2_nop	# 2

	# return
	sh2_return_after_next_inst
	sh2_nop
}

funcs() {
	map_file=src/funcs_map.sh
	rm -f $map_file

	# 指定されたアドレスからアドレスへ、指定されたサイズ分コピー
	a_memcpy=$FUNCS_BASE
	echo -e "a_memcpy=$a_memcpy" >>$map_file
	f_memcpy >src/f_memcpy.o
	cat src/f_memcpy.o
}

funcs
