# Data Transfer Over Midi
if [ "${SRC_DTOM_SH+is_defined}" ]; then
	return
fi
SRC_DTOM_SH=true

. include/sh2.sh
. include/ss.sh
. include/common.sh

DTOM_DATAPACKET_BIT_ENDFLAG=10

# データを1バイト受信する
# out : r1 - 受信したデータ(1バイト)
#       r2 - 終了フラグ
f_rcv_byte() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r3
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r3
	## r4
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r4
	## r12
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r12
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# 使用するアドレスをレジスタへ設定しておく
	copy_to_reg_from_val_long r14 $SS_CT_SND_MCIPDL_ADDR
	copy_to_reg_from_val_long r13 $SS_CT_SND_MIBUF_ADDR

	# 取得済みデータ・バイト数 = 0
	sh2_set_reg r12 00

	# 繰り返し使用する処理
	## MCIPD[3] == 1を待つ処理
	(
		sh2_copy_to_reg_from_ptr_byte r0 r14
		sh2_test_r0_and_val_byte $SS_SND_MCIPDL_BIT_MI
	) >src/f_rcv_byte.1.o
	local f_rcv_byte_sz_1=$(stat -c '%s' src/f_rcv_byte.1.o)
	## データ・バイトを1バイト取得する処理
	(
		# MCIPD[3] == 1を待つ
		cat src/f_rcv_byte.1.o
		## MCIPD[3]がセットされていなければ(T == 1)繰り返す
		sh2_rel_jump_if_true $(two_comp_d $(((4 + f_rcv_byte_sz_1) / 2)))

		# MIBUFから1バイト取得
		sh2_copy_to_reg_from_ptr_byte r0 r13

		# 取得したバイトの最上位ビット == 1?
		sh2_test_r0_and_val_byte 80
	) >src/f_rcv_byte.2.o
	local f_rcv_byte_sz_2=$(stat -c '%s' src/f_rcv_byte.2.o)

	(
		# データ・バイトを1バイト取得する
		cat src/f_rcv_byte.2.o
		## 取得したバイトの最上位ビット == 1なら(T == 0)繰り返す
		sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_2) / 2)))

		# 取得したバイトをスタックへpush
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# 取得済みデータ・バイト数++
		sh2_add_to_reg_from_val_byte r12 01

		# 取得済みデータ・バイト数 < 2?
		sh2_set_reg r0 02
		sh2_compare_reg_gt_reg_unsigned r0 r12
	) >src/f_rcv_byte.3.o
	cat src/f_rcv_byte.3.o
	## T == 1なら繰り返す
	local sz_3=$(stat -c '%s' src/f_rcv_byte.3.o)
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))

	# データ(2バイト目)へスタックからpop
	sh2_copy_to_reg_from_ptr_long r4 r15
	sh2_add_to_reg_from_val_byte r15 04

	# データ(1バイト目)へスタックからpop
	sh2_copy_to_reg_from_ptr_long r3 r15
	sh2_add_to_reg_from_val_byte r15 04

	# 終了フラグ(r2) = データ(1バイト目) & 0x10
	sh2_copy_to_reg_from_reg r2 r3
	sh2_set_reg r0 10
	sh2_and_to_reg_from_reg r2 r0

	# 終了フラグ(r2) >>= 4
	sh2_shift_right_logical_2 r2
	sh2_shift_right_logical_2 r2

	# データ(1バイト目) &= 0x03
	sh2_set_reg r0 03
	sh2_and_to_reg_from_reg r3 r0

	# データ(2バイト目) <<= 2
	sh2_shift_left_logical_2 r4

	# データ = データ(2バイト目) | データ(1バイト目)
	sh2_or_to_reg_from_reg r3 r4
	sh2_copy_to_reg_from_reg r1 r3

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r12
	sh2_copy_to_reg_from_ptr_long r12 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r4
	sh2_copy_to_reg_from_ptr_long r4 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r3
	sh2_copy_to_reg_from_ptr_long r3 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}
