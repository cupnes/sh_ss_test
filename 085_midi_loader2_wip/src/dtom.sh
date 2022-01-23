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
	## r5
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r5
	## r6
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r6
	# ## r13
	# sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	# sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 設計:
	# - データパケットを2回受信
	# - データパケットにはノート・オンを使う
	#   - 0b1001 0000: 0x90
	#   - 0b011e 11dd: e=終了フラグ,d=データ[1:0]
	#   - 0b01dd dddd: d=データ[7:2]
	# - 設計上、0x00のバイトは生まれない
	# - MIBUFから0x00を読んでしまった場合
	#   - 2回受信したデータパケットの内、0x00でない方のバイトを使う
	# - 2回共0x00を読んでしまった場合
	#   - 仕方ないので不定値を返す
	#     - 特別な処理は入れない
	#   - 一連のデータ受信後に出すチェックサムで気づく事ができる
	# - 流れとしては以下を2回繰り返す
	#   1. 0x90の取得を待つ
	#      - ノート・オン以外にもアクティブ・センシング(0xfe)等も
	#        受信するため
	#   2. 続く2バイトを取得
	#      - データパケットの2-3バイト目に使う

	# 使用するアドレスをレジスタへ設定しておく
	copy_to_reg_from_val_long r14 $SS_CT_SND_MIOSTAT_ADDR
	# copy_to_reg_from_val_long r13 $a_putreg_byte

	# 繰り返し使用する処理
	## MIEMP == 0 になるのを待つ処理
	(
		# MIOSTATとMIBUFを取得
		sh2_copy_to_reg_from_ptr_word r0 r14
		# 後のためにr1へコピー
		sh2_copy_to_reg_from_reg r1 r0
		# MIOSTAT部分をビット7-0へ持ってくる
		sh2_shift_right_logical_8 r0
		# MIEMPビットがセットされているか?
		sh2_test_r0_and_val_byte $SS_SND_MIOSTAT_BIT_MIEMP
	) >src/f_rcv_byte.1.o
	f_rcv_byte_sz_1=$(stat -c '%s' src/f_rcv_byte.1.o)

	# データパケット受信(1回目)
	## 1バイト目(0x90)
	### 0x90が取得されるのを待つ
	sh2_set_reg r2 90
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	(
		# MIEMP == 0 になるのを待つ
		cat src/f_rcv_byte.1.o
		sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_1) / 2)))

		# 取得したバイト == 0x90?
		sh2_extend_unsigned_to_reg_from_reg_byte r1 r1
		sh2_compare_reg_eq_reg r1 r2
	) >src/f_rcv_byte.2.o
	cat src/f_rcv_byte.2.o
	local sz_2=$(stat -c '%s' src/f_rcv_byte.2.o)
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_2) / 2)))
	# ### [debug]
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_nop
	## 2バイト目(0b011e 11dd)
	### MIEMP == 0 になるのを待つ
	cat src/f_rcv_byte.1.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_1) / 2)))
	### 取得した1バイトをr3へ設定
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r1
	# ### [debug]
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_copy_to_reg_from_reg r1 r3
	## 3バイト目(0b01dd dddd)
	### MIEMP == 0 になるのを待つ
	cat src/f_rcv_byte.1.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_1) / 2)))
	### 取得した1バイトをr4へ設定
	sh2_extend_unsigned_to_reg_from_reg_byte r4 r1
	# ### [debug]
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_copy_to_reg_from_reg r1 r4

	# データパケット受信(2回目)
	## 1バイト目(0x90)
	### 0x90が取得されるのを待つ
	sh2_set_reg r2 90
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	cat src/f_rcv_byte.2.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_2) / 2)))
	# ### [debug]
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_nop
	## 2バイト目(0b011e 11dd)
	### MIEMP == 0 になるのを待つ
	cat src/f_rcv_byte.1.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_1) / 2)))
	### 取得した1バイトをr5へ設定
	sh2_extend_unsigned_to_reg_from_reg_byte r5 r1
	# ### [debug]
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_copy_to_reg_from_reg r1 r5
	## 3バイト目(0b01dd dddd)
	### MIEMP == 0 になるのを待つ
	cat src/f_rcv_byte.1.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_1) / 2)))
	### 取得した1バイトをr6へ設定
	sh2_extend_unsigned_to_reg_from_reg_byte r6 r1
	# ### [debug]
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_copy_to_reg_from_reg r1 r6

	# 0x00化け対処
	sh2_set_reg r0 00
	## r3 == 0?
	sh2_compare_reg_eq_reg r3 r0
	(
		# r3 == 0 の場合の処理

		# r3 = r5
		sh2_copy_to_reg_from_reg r3 r5
	) >src/f_rcv_byte.3.o
	### T == 0なら、処理を飛ばす
	local sz_3=$(stat -c '%s' src/f_rcv_byte.3.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_3 - 2) / 2)))
	cat src/f_rcv_byte.3.o
	## r4 == 0?
	sh2_compare_reg_eq_reg r4 r0
	(
		# r4 == 0 の場合の処理

		# r4 = r6
		sh2_copy_to_reg_from_reg r4 r6
	) >src/f_rcv_byte.4.o
	### T == 0なら、処理を飛ばす
	local sz_4=$(stat -c '%s' src/f_rcv_byte.4.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_4 - 2) / 2)))
	cat src/f_rcv_byte.4.o
	# ## [debug]
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_copy_to_reg_from_reg r1 r3
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_copy_to_reg_from_reg r1 r4

	# データパケットパース
	## 終了フラグを一旦r0へ格納
	sh2_copy_to_reg_from_reg r0 r3
	sh2_and_to_r0_from_val_byte $DTOM_DATAPACKET_BIT_ENDFLAG
	sh2_shift_right_logical_2 r0
	sh2_shift_right_logical_2 r0
	## データをr1へ取得
	### 2バイト目(r3) &= 0x03
	sh2_set_reg r1 03
	sh2_and_to_reg_from_reg r3 r1
	### 3バイト目(r4) <<= 2
	sh2_shift_left_logical_2 r4
	### r3 |= r4
	sh2_or_to_reg_from_reg r3 r4
	### r1 = r3
	sh2_copy_to_reg_from_reg r1 r3
	## r2 = r0
	sh2_copy_to_reg_from_reg r2 r0
	# ## [debug]
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_copy_to_reg_from_reg r3 r1
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_copy_to_reg_from_reg r1 r2
	# sh2_copy_to_reg_from_reg r1 r3

	# 退避したレジスタを復帰しreturn
	## pr
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	# ## r13
	# sh2_copy_to_reg_from_ptr_long r13 r15
	# sh2_add_to_reg_from_val_byte r15 04
	## r6
	sh2_copy_to_reg_from_ptr_long r6 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r5
	sh2_copy_to_reg_from_ptr_long r5 r15
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
