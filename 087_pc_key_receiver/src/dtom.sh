# Data Transfer Over Midi
if [ "${SRC_DTOM_SH+is_defined}" ]; then
	return
fi
SRC_DTOM_SH=true

. include/sh2.sh
. include/ss.sh
. include/common.sh
# . include/charcode.sh	# [debug]

DTOM_DATAPACKET_BIT_ENDFLAG=10
ACK_PACKET=fa
NAK_PACKET=fb

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
	# ## [debug] r11
	# sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	# sh2_copy_to_ptr_from_reg_long r15 r11
	# ## [debug] r12
	# sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	# sh2_copy_to_ptr_from_reg_long r15 r12
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14
	# ## [debug] pr
	# sh2_copy_to_reg_from_pr r0
	# sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	# sh2_copy_to_ptr_from_reg_long r15 r0

	# 使用するアドレスをレジスタへ設定しておく
	copy_to_reg_from_val_long r14 $SS_CT_SND_MIOSTAT_ADDR
	copy_to_reg_from_val_long r13 $SS_CT_SND_MOBUF_ADDR
	# copy_to_reg_from_val_long r12 $a_putreg_byte	# [debug]
	# copy_to_reg_from_val_long r11 $a_putchar	# [debug]

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
	) >src/f_rcv_byte.2.o
	f_rcv_byte_sz_2=$(stat -c '%s' src/f_rcv_byte.2.o)
	## MOFULL == 0 になるのを待つ処理
	(
		# MIOSTATを取得
		sh2_copy_to_reg_from_ptr_byte r0 r14
		# MOFULLビットがセットされているか?
		sh2_test_r0_and_val_byte $SS_SND_MIOSTAT_BIT_MOFULL
	) >src/f_rcv_byte.6.o
	f_rcv_byte_sz_6=$(stat -c '%s' src/f_rcv_byte.6.o)

	# データ受信
	(
		# データパケットを受信
		## 1バイト目
		### 0x90が取得されるのを待つ
		sh2_set_reg r2 90
		sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
		(
			# MIEMP == 0 になるのを待つ
			cat src/f_rcv_byte.2.o
			sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_2) / 2)))

			# 取得したバイト == 0x90?
			sh2_extend_unsigned_to_reg_from_reg_byte r1 r1
			sh2_compare_reg_eq_reg r1 r2
		) >src/f_rcv_byte.7.o
		cat src/f_rcv_byte.7.o
		local sz_7=$(stat -c '%s' src/f_rcv_byte.7.o)
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_7) / 2)))
		### 取得した1バイトをr2へ設定
		sh2_copy_to_reg_from_reg r2 r1
		# ### [debug]
		# sh2_abs_call_to_reg_after_next_inst r12
		# sh2_copy_to_reg_from_reg r1 r2
		## 2バイト目
		### MIEMP == 0 になるのを待つ
		cat src/f_rcv_byte.2.o
		sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_2) / 2)))
		### 取得した1バイトをr3へ設定
		sh2_extend_unsigned_to_reg_from_reg_byte r3 r1
		# ### [debug]
		# sh2_abs_call_to_reg_after_next_inst r12
		# sh2_copy_to_reg_from_reg r1 r3
		## 3バイト目
		### MIEMP == 0 になるのを待つ
		cat src/f_rcv_byte.2.o
		sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_2) / 2)))
		### 取得した1バイトをr4へ設定
		sh2_extend_unsigned_to_reg_from_reg_byte r4 r1
		# ### [debug]
		# sh2_abs_call_to_reg_after_next_inst r12
		# sh2_copy_to_reg_from_reg r1 r4

		# 受信したデータパケットに0x00がある?
		## r5 == 0
		sh2_set_reg r5 00
		## 1バイト目(r2) == 0x00?
		sh2_copy_to_reg_from_reg r0 r2
		sh2_compare_r0_eq_val 00
		### r0 != val のとき 0→T
		(
			sh2_add_to_reg_from_val_byte r5 01
		) >src/f_rcv_byte.3.o
		local sz_3=$(stat -c '%s' src/f_rcv_byte.3.o)
		sh2_rel_jump_if_false $(two_digits_d $(((sz_3 - 2) / 2)))
		cat src/f_rcv_byte.3.o
		## 2バイト目(r3) == 0x00?
		sh2_copy_to_reg_from_reg r0 r3
		sh2_compare_r0_eq_val 00
		sh2_rel_jump_if_false $(two_digits_d $(((sz_3 - 2) / 2)))
		cat src/f_rcv_byte.3.o
		## 3バイト目(r4) == 0x00?
		sh2_copy_to_reg_from_reg r0 r4
		sh2_compare_r0_eq_val 00
		sh2_rel_jump_if_false $(two_digits_d $(((sz_3 - 2) / 2)))
		cat src/f_rcv_byte.3.o
		## r5 == 0?
		sh2_copy_to_reg_from_reg r0 r5
		sh2_compare_r0_eq_val 00
		(
			# 受信したデータパケットに0x00がある場合
			# データパケットは正しく受信できなかったと判断

			# NAKパケットを送信
			## MOFULL == 0 になるのを待つ
			cat src/f_rcv_byte.6.o
			sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_6) / 2)))
			## 送信
			sh2_set_reg r0 $NAK_PACKET
			sh2_copy_to_ptr_from_reg_byte r13 r0

			# # [debug]
			# sh2_abs_call_to_reg_after_next_inst r11
			# sh2_set_reg r1 $CHARCODE_N
		) >src/f_rcv_byte.4.o
		(
			# 受信したデータパケットに0x00がない場合
			# データパケットは正しく受信できたと判断

			# ACKパケットを送信
			## MOFULL == 0 になるのを待つ
			cat src/f_rcv_byte.6.o
			sh2_rel_jump_if_false $(two_comp_d $(((4 + f_rcv_byte_sz_6) / 2)))
			## 送信
			sh2_set_reg r0 $ACK_PACKET
			sh2_copy_to_ptr_from_reg_byte r13 r0

			# # [debug]
			# sh2_abs_call_to_reg_after_next_inst r11
			# sh2_set_reg r1 $CHARCODE_A

			# 受信したデータパケットに0x00がある場合の処理を飛ばし、無限ループを抜ける
			local sz_4=$(stat -c '%s' src/f_rcv_byte.4.o)
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $(((sz_4 + 4) / 2))) 3)
			sh2_nop
		) >src/f_rcv_byte.5.o
		local sz_5=$(stat -c '%s' src/f_rcv_byte.5.o)
		sh2_rel_jump_if_false $(two_digits_d $(((sz_5 - 2) / 2)))
		cat src/f_rcv_byte.5.o	# T == 1: r5 == 0: 0x00がない
		cat src/f_rcv_byte.4.o	# T == 0: r5 != 0: 0x00がある
	) >src/f_rcv_byte.1.o
	cat src/f_rcv_byte.1.o
	local sz_1=$(stat -c '%s' src/f_rcv_byte.1.o)
	sh2_rel_jump_after_next_inst $(two_comp_3_d $(((4 + sz_1) / 2)))	# 2
	sh2_nop	# 2

	# 2バイト目(r3)・3バイト目(r4)をパースし、
	# データをr1へ、終了フラグをr2へ設定
	## 終了フラグをr2へ設定
	sh2_copy_to_reg_from_reg r0 r3
	sh2_and_to_r0_from_val_byte $DTOM_DATAPACKET_BIT_ENDFLAG
	sh2_shift_right_logical_2 r0
	sh2_shift_right_logical_2 r0
	sh2_copy_to_reg_from_reg r2 r0
	## データをr1へ設定
	### r3 &= 0x03
	sh2_set_reg r0 03
	sh2_and_to_reg_from_reg r3 r0
	### r4 <<= 2
	sh2_shift_left_logical_2 r4
	### r3 |= r4
	sh2_or_to_reg_from_reg r3 r4
	### r1 = r3
	sh2_copy_to_reg_from_reg r1 r3
	# ## [debug]
	# sh2_abs_call_to_reg_after_next_inst r12
	# sh2_copy_to_reg_from_reg r3 r1
	# sh2_abs_call_to_reg_after_next_inst r12
	# sh2_copy_to_reg_from_reg r1 r2
	# sh2_copy_to_reg_from_reg r1 r3

	# 退避したレジスタを復帰しreturn
	# ## [debug] pr
	# sh2_copy_to_reg_from_ptr_long r0 r15
	# sh2_add_to_reg_from_val_byte r15 04
	# sh2_copy_to_pr_from_reg r0
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	# ## [debug] r12
	# sh2_copy_to_reg_from_ptr_long r12 r15
	# sh2_add_to_reg_from_val_byte r15 04
	# ## [debug] r11
	# sh2_copy_to_reg_from_ptr_long r11 r15
	# sh2_add_to_reg_from_val_byte r15 04
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
