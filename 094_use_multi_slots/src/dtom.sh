# Data Transfer Over Midi
if [ "${SRC_DTOM_SH+is_defined}" ]; then
	return
fi
SRC_DTOM_SH=true

. include/sh2.sh
. include/ss.sh
. include/common.sh

DTOM_DATAPACKET_BIT_ENDFLAG=10
BULK_END_NO_REMAIN=f6

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

# 一連のデータロード処理を行う
# in  : r1 - ロード先アドレス
# out : r1 - 次にデータをロードするアドレス
#            (ロード先アドレス + ロードしたバイト数)
#     : r2 - チェックサム
f_load_data_from_midi() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r6
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r6
	## r7
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r7
	## r8
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r8
	## r11
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r11
	## r12
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r12
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# 使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_MCIPDL_ADDR
	copy_to_reg_from_val_long r13 $SS_CT_SND_MIBUF_ADDR
	sh2_copy_to_reg_from_reg r12 r1

	# チェックサム用レジスタをゼロクリア
	sh2_set_reg r11 00

	# 何度も使用する処理を定義
	## MCIPD[3] == 1を待つ処理
	(
		sh2_copy_to_reg_from_ptr_byte r0 r14
		sh2_test_r0_and_val_byte $SS_SND_MCIPDL_BIT_MI
	) >src/f_load_data_from_midi.1.o
	local sz_1=$(stat -c '%s' src/f_load_data_from_midi.1.o)

	# 受信開始待ち
	# MIBUFから0x9nが取得できるまでMIBUFの取得を繰り返す
	(
		# MCIPD[3] == 1を待つ
		cat src/f_load_data_from_midi.1.o
		## MCIPD[3]がセットされていなければ(T == 1)繰り返す
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
		# MIBUFから1バイト取得
		sh2_copy_to_reg_from_ptr_byte r1 r13
		sh2_extend_unsigned_to_reg_from_reg_byte r1 r1
		# 0x9nか?
		sh2_set_reg r0 f0
		sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
		sh2_and_to_reg_from_reg r0 r1
		sh2_set_reg r2 90
		sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
		sh2_compare_reg_eq_reg r0 r2
		## 0x9nならT == 1
	) >src/f_load_data_from_midi.2.o
	cat src/f_load_data_from_midi.2.o
	local sz_2=$(stat -c '%s' src/f_load_data_from_midi.2.o)
	## T == 0なら繰り返す
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_2) / 2)))

	# この時点で、r1 == 0x0000009n, r2 == 0x00000090

	# 後のためにr1をr8へコピーしておく
	# これにより、後の端数転送のフェーズでは、
	# バルク転送したか否かに関わらず、r8が0x9nか否かさえ確認すれば
	# 端数転送が必要か否かを判断できる
	sh2_copy_to_reg_from_reg r8 r1

	# r1 == 0x90?
	sh2_compare_reg_eq_reg r1 r2
	(
		# r1 == 0x90 の場合
		# バルク転送

		(
			# 1バイト取得
			## MCIPD[3] == 1を待つ
			cat src/f_load_data_from_midi.1.o
			sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
			## MIBUFからr8へ1バイト取得
			sh2_copy_to_reg_from_ptr_byte r8 r13
			sh2_extend_unsigned_to_reg_from_reg_byte r8 r8

			# 取得した1バイトは何か?
			# - 最上位ビットが0 → 補助バイト
			# - 最上位ビットが1
			#   - 0x9n → 端数転送のためのステータス・バイト
			#     ※ nは0x1〜0xfの想定。n=0の場合の処理は簡単のため実装しない
			#   - それ以外 → 受信終了(端数無し)
			#     TODO 終了パケット(0xf6)でなければこの1バイト取得を繰り返すようにした方が良いかもしれない
			#          ただ、途中でリアルタイム・メッセージを受信する事はここに限らず想定外になっている
			## 最上位ビットは0か?
			sh2_copy_to_reg_from_reg r0 r8
			sh2_test_r0_and_val_byte 80
			### 1ならT == 0 → 端数転送あるいは受信終了 → バルク転送の受信ループを抜ける
			### 0ならT == 1 → 補助バイト → バルク転送の受信ループ継続
		) >src/f_load_data_from_midi.9.o
		cat src/f_load_data_from_midi.9.o
		(
			# 7バイト受信
			(
				# 1バイト目取得・書き込み
				## MCIPD[3] == 1を待つ
				cat src/f_load_data_from_midi.1.o
				sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
				## MIBUFからr1へ1バイト取得
				sh2_copy_to_reg_from_ptr_byte r1 r13
				## 補助バイトからこのバイトのMSBをr0へ取得
				sh2_shift_left_logical r8
				sh2_copy_to_reg_from_reg r0 r8
				sh2_and_to_r0_from_val_byte 80
				## r1 = r0 | r1
				sh2_or_to_reg_from_reg r1 r0
				## r1をロード先へ書き込み
				sh2_copy_to_ptr_from_reg_byte r12 r1
				## ロード先アドレスをインクリメント
				sh2_add_to_reg_from_val_byte r12 01
				## チェックサムへ加算
				sh2_add_to_reg_from_reg r11 r1

				# 2バイト目取得・書き込み
				## MCIPD[3] == 1を待つ
				cat src/f_load_data_from_midi.1.o
				sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
				## MIBUFからr1へ1バイト取得
				sh2_copy_to_reg_from_ptr_byte r1 r13
				## 補助バイトからこのバイトのMSBをr0へ取得
				sh2_shift_left_logical r8
				sh2_copy_to_reg_from_reg r0 r8
				sh2_and_to_r0_from_val_byte 80
				## r1 = r0 | r1
				sh2_or_to_reg_from_reg r1 r0
				## r1をロード先へ書き込み
				sh2_copy_to_ptr_from_reg_byte r12 r1
				## ロード先アドレスをインクリメント
				sh2_add_to_reg_from_val_byte r12 01
				## チェックサムへ加算
				sh2_add_to_reg_from_reg r11 r1

				# 3バイト目取得・書き込み
				## MCIPD[3] == 1を待つ
				cat src/f_load_data_from_midi.1.o
				sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
				## MIBUFからr1へ1バイト取得
				sh2_copy_to_reg_from_ptr_byte r1 r13
				## 補助バイトからこのバイトのMSBをr0へ取得
				sh2_shift_left_logical r8
				sh2_copy_to_reg_from_reg r0 r8
				sh2_and_to_r0_from_val_byte 80
				## r1 = r0 | r1
				sh2_or_to_reg_from_reg r1 r0
				## r1をロード先へ書き込み
				sh2_copy_to_ptr_from_reg_byte r12 r1
				## ロード先アドレスをインクリメント
				sh2_add_to_reg_from_val_byte r12 01
				## チェックサムへ加算
				sh2_add_to_reg_from_reg r11 r1

				# 4バイト目取得・書き込み
				## MCIPD[3] == 1を待つ
				cat src/f_load_data_from_midi.1.o
				sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
				## MIBUFからr1へ1バイト取得
				sh2_copy_to_reg_from_ptr_byte r1 r13
				## 補助バイトからこのバイトのMSBをr0へ取得
				sh2_shift_left_logical r8
				sh2_copy_to_reg_from_reg r0 r8
				sh2_and_to_r0_from_val_byte 80
				## r1 = r0 | r1
				sh2_or_to_reg_from_reg r1 r0
				## r1をロード先へ書き込み
				sh2_copy_to_ptr_from_reg_byte r12 r1
				## ロード先アドレスをインクリメント
				sh2_add_to_reg_from_val_byte r12 01
				## チェックサムへ加算
				sh2_add_to_reg_from_reg r11 r1

				# 5バイト目取得・書き込み
				## MCIPD[3] == 1を待つ
				cat src/f_load_data_from_midi.1.o
				sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
				## MIBUFからr1へ1バイト取得
				sh2_copy_to_reg_from_ptr_byte r1 r13
				## 補助バイトからこのバイトのMSBをr0へ取得
				sh2_shift_left_logical r8
				sh2_copy_to_reg_from_reg r0 r8
				sh2_and_to_r0_from_val_byte 80
				## r1 = r0 | r1
				sh2_or_to_reg_from_reg r1 r0
				## r1をロード先へ書き込み
				sh2_copy_to_ptr_from_reg_byte r12 r1
				## ロード先アドレスをインクリメント
				sh2_add_to_reg_from_val_byte r12 01
				## チェックサムへ加算
				sh2_add_to_reg_from_reg r11 r1

				# 6バイト目取得・書き込み
				## MCIPD[3] == 1を待つ
				cat src/f_load_data_from_midi.1.o
				sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
				## MIBUFからr1へ1バイト取得
				sh2_copy_to_reg_from_ptr_byte r1 r13
				## 補助バイトからこのバイトのMSBをr0へ取得
				sh2_shift_left_logical r8
				sh2_copy_to_reg_from_reg r0 r8
				sh2_and_to_r0_from_val_byte 80
				## r1 = r0 | r1
				sh2_or_to_reg_from_reg r1 r0
				## r1をロード先へ書き込み
				sh2_copy_to_ptr_from_reg_byte r12 r1
				## ロード先アドレスをインクリメント
				sh2_add_to_reg_from_val_byte r12 01
				## チェックサムへ加算
				sh2_add_to_reg_from_reg r11 r1

				# 7バイト目取得・書き込み
				## MCIPD[3] == 1を待つ
				cat src/f_load_data_from_midi.1.o
				sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
				## MIBUFからr1へ1バイト取得
				sh2_copy_to_reg_from_ptr_byte r1 r13
				## 補助バイトからこのバイトのMSBをr0へ取得
				sh2_shift_left_logical r8
				sh2_copy_to_reg_from_reg r0 r8
				sh2_and_to_r0_from_val_byte 80
				## r1 = r0 | r1
				sh2_or_to_reg_from_reg r1 r0
				## r1をロード先へ書き込み
				sh2_copy_to_ptr_from_reg_byte r12 r1
				## ロード先アドレスをインクリメント
				sh2_add_to_reg_from_val_byte r12 01
				## チェックサムへ加算
				sh2_add_to_reg_from_reg r11 r1
			) >src/f_load_data_from_midi.6.o
			cat src/f_load_data_from_midi.6.o

			# バルク転送の受信を繰り返す
			local sz_6=$(stat -c '%s' src/f_load_data_from_midi.6.o)
			local sz_9=$(stat -c '%s' src/f_load_data_from_midi.9.o)
			sh2_rel_jump_after_next_inst $(two_comp_3_d $(((2 + 2 + sz_6 + 2 + sz_9) / 2)))	# 2
			sh2_nop	# 2
		) >src/f_load_data_from_midi.5.o
		local sz_5=$(stat -c '%s' src/f_load_data_from_midi.5.o)
		sh2_rel_jump_if_false $(two_digits_d $(((sz_5 - 2) / 2)))	# 2
		cat src/f_load_data_from_midi.5.o
	) >src/f_load_data_from_midi.3.o
	## T == 0(r1 != 0x90)ならバルク転送処理を飛ばす
	local sz_3=$(stat -c '%s' src/f_load_data_from_midi.3.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_3 - 2) / 2)))
	cat src/f_load_data_from_midi.3.o

	# この時、r8に終了パケットあるいは端数転送のステータス・バイト(0x9n)が設定されている

	# r8 == 0x9n?
	sh2_copy_to_reg_from_reg r0 r8
	sh2_and_to_r0_from_val_byte f0
	sh2_set_reg r2 90
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_compare_reg_eq_reg r0 r2
	## r8 == 0x9nならT == 1 → 端数転送する

	(
		# r8 == 0x9n の場合
		# 端数転送

		# 端数のバイト数をr6へ取得
		sh2_copy_to_reg_from_reg r0 r8
		sh2_and_to_r0_from_val_byte 0f
		sh2_copy_to_reg_from_reg r6 r0

		# 最後の1バイト空読みが必要か否か
		sh2_and_to_r0_from_val_byte 01
		sh2_copy_to_reg_from_reg r7 r0
		## この時、r7 == 0x00なら最後に1バイト空読みする(0x00を読み捨てる)

		# 補助バイト取得
		## MCIPD[3] == 1を待つ
		cat src/f_load_data_from_midi.1.o
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
		# MIBUFからr8へ1バイト取得
		sh2_copy_to_reg_from_ptr_byte r8 r13

		# r6の回数分、MIBUFからバイト取得・書き込みを繰り返す
		(
			# 1バイト取得・書き込み
			## MCIPD[3] == 1を待つ
			cat src/f_load_data_from_midi.1.o
			sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
			## MIBUFからr1へ1バイト取得
			sh2_copy_to_reg_from_ptr_byte r1 r13
			## 補助バイトからこのバイトのMSBをr0へ取得
			sh2_shift_left_logical r8
			sh2_copy_to_reg_from_reg r0 r8
			sh2_and_to_r0_from_val_byte 80
			## r1 = r0 | r1
			sh2_or_to_reg_from_reg r1 r0
			## r1をロード先へ書き込み
			sh2_copy_to_ptr_from_reg_byte r12 r1
			## ロード先アドレスをインクリメント
			sh2_add_to_reg_from_val_byte r12 01
			## チェックサムへ加算
			sh2_add_to_reg_from_reg r11 r1

			# 端数の残バイト数(r6)を更新
			sh2_add_to_reg_from_val_byte r6 $(two_comp_d 1)

			# 残バイト数 == 0?
			sh2_set_reg r0 00
			sh2_compare_reg_eq_reg r6 r0
		) >src/f_load_data_from_midi.7.o
		## 残バイト数 != 0(T == 0)なら繰り返す
		cat src/f_load_data_from_midi.7.o
		local sz_7=$(stat -c '%s' src/f_load_data_from_midi.7.o)
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_7) / 2)))

		# r7 == 0?
		sh2_compare_reg_eq_reg r7 r0
		(
			# r7 == 0の場合

			# MIBUFから1バイト読み捨てる
			## MCIPD[3] == 1を待つ
			cat src/f_load_data_from_midi.1.o
			sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
			## MIBUFからr0へ1バイト取得
			sh2_copy_to_reg_from_ptr_byte r0 r13
		) >src/f_load_data_from_midi.8.o
		local sz_8=$(stat -c '%s' src/f_load_data_from_midi.8.o)
		## r7 != 0(T == 0)なら処理を飛ばす
		sh2_rel_jump_if_false $(two_digits_d $(((sz_8 - 2) / 2)))
		cat src/f_load_data_from_midi.8.o
	) >src/f_load_data_from_midi.4.o
	local sz_4=$(stat -c '%s' src/f_load_data_from_midi.4.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_4 - 2) / 2)))
	## T == 0(r8 != 0x9n)なら端数転送処理を飛ばす
	cat src/f_load_data_from_midi.4.o

	# r1へ次にデータをロードするアドレスを設定
	# (r12をr1へ書き戻す)
	sh2_copy_to_reg_from_reg r1 r12

	# r2へチェックサムを設定
	sh2_copy_to_reg_from_reg r2 r11

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
	## r11
	sh2_copy_to_reg_from_ptr_long r11 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r8
	sh2_copy_to_reg_from_ptr_long r8 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r7
	sh2_copy_to_reg_from_ptr_long r7 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r6
	sh2_copy_to_reg_from_ptr_long r6 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}
