if [ "${SRC_SYNTH_SH+is_defined}" ]; then
	return
fi
SRC_SYNTH_SH=true

. include/sh2.sh
. include/ss.sh
. include/common.sh
. include/synth.sh

# シンセ共通部分を初期化する
f_synth_common_init() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2

	# SCSP共通制御レジスタを設定
	copy_to_reg_from_val_long r1 $SS_CT_SND_COMMONCTR_ADDR
	## 00H
	copy_to_reg_from_val_word r2 0208
	sh2_copy_to_ptr_from_reg_word r1 r2

	# 退避したレジスタを復帰しreturn
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# スロットを初期化する
# in  : r1 - スロット番号
f_synth_slot_init() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2

	# スロット別制御レジスタを設定
	## レジスタの先頭アドレスをr1へ設定
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical r1
	copy_to_reg_from_val_long r2 $SS_CT_SND_SLOTCTR_S0_ADDR
	sh2_add_to_reg_from_reg r1 r2
	## 00H
	sh2_set_reg r2 30
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 02H
	sh2_set_reg r2 10
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 04H
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 06H
	sh2_set_reg r2 $SQUARE_WAVE_PERIOD
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 08H
	sh2_set_reg r2 20
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0AH
	sh2_set_reg r0 3f
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ff
	sh2_copy_to_ptr_from_reg_word r1 r0
	sh2_add_to_reg_from_val_byte r1 02
	## 0CH
	copy_to_reg_from_val_word r2 0380
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0EH
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 10H
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 12H
	copy_to_reg_from_val_word r2 8108
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 14H
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 16H
	sh2_set_reg r2 e0
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02

	# 退避したレジスタを復帰しreturn
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# スロットを指定された音階でKEY_ONする
# in  : r1 - スロット番号
#     : r2 - PITCHレジスタ値
#     : r3 - ノート番号
f_key_on_with_pitch() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# 一応、r2の上位2バイトをゼロクリア
	sh2_extend_unsigned_to_reg_from_reg_word r2 r2

	# スロット番号をr13へコピー
	sh2_copy_to_reg_from_reg r13 r1

	# 指定されたスロット番号のスロット別制御レジスタのアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical r1
	sh2_add_to_reg_from_reg r14 r1

	# PITCHレジスタ設定
	sh2_add_to_reg_from_val_byte r14 10
	sh2_copy_to_ptr_from_reg_word r14 r2

	# KEY_ON設定
	sh2_add_to_reg_from_val_byte r14 $(two_comp 10)
	sh2_copy_to_reg_from_ptr_word r0 r14
	sh2_set_reg r1 18
	sh2_shift_left_logical_8 r1
	sh2_or_to_reg_from_reg r0 r1
	sh2_copy_to_ptr_from_reg_word r14 r0

	# スロットの状態管理変数更新
	## 該当スロットの変数のアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_synth_slot_state_base
	sh2_add_to_reg_from_reg r1 r13
	## 変数更新
	sh2_copy_to_ptr_from_reg_byte r1 r3

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定されたスロットをKEY_OFFする
# in  : r1 - スロット番号
f_key_off() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# スロット番号をr13へコピー
	sh2_copy_to_reg_from_reg r13 r1

	# 指定されたスロット番号のスロット別制御レジスタのアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical r1
	sh2_add_to_reg_from_reg r14 r1

	# KEY_OFF設定
	sh2_copy_to_reg_from_ptr_word r1 r14
	sh2_set_reg r0 f7
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ff
	sh2_and_to_reg_from_reg r1 r0
	sh2_set_reg r0 10
	sh2_shift_left_logical_8 r0
	sh2_or_to_reg_from_reg r1 r0
	sh2_copy_to_ptr_from_reg_word r14 r1

	# スロットの状態管理変数更新
	## 該当スロットの変数のアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_synth_slot_state_base
	sh2_add_to_reg_from_reg r1 r13
	## 変数更新
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# KEY_OFFのスロット番号を返す
# out : r1 - スロット番号
f_synth_get_slot_off() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# スロットの状態管理変数のアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $var_synth_slot_state_base

	# スロット番号0を仮定
	sh2_set_reg r1 00

	# KEY_OFFスロットを見つけるまで繰り返し
	(
		# 変数値を取得
		sh2_copy_to_reg_from_ptr_byte r0 r14
		# スロット番号と変数アドレスを進める
		sh2_add_to_reg_from_val_byte r1 01
		sh2_add_to_reg_from_val_byte r14 01
		# 取得した値 == 0?
		sh2_compare_r0_eq_val 00
	) >src/f_synth_get_slot_off.1.o
	cat src/f_synth_get_slot_off.1.o
	local sz_1=$(stat -c '%s' src/f_synth_get_slot_off.1.o)
	## 取得した値 != 0 (T == 0)なら繰り返す
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_1) / 2)))

	# -1した値が見つけたスロット番号
	sh2_add_to_reg_from_val_byte r1 $(two_comp_d 1)

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定されたノート番号を鳴らしているスロット番号を返す
# in  : r1 - ノート番号
# out : r1 - スロット番号
f_synth_get_slot_on_with_note() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# ノート番号をr13へコピーしておく
	sh2_copy_to_reg_from_reg r13 r1

	# スロットの状態管理変数のアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $var_synth_slot_state_base

	# スロット番号0を仮定
	sh2_set_reg r1 00

	# 指定されたノート番号でKEY_ONのスロットを見つけるまで繰り返し
	(
		# 変数値を取得
		sh2_copy_to_reg_from_ptr_byte r0 r14
		# スロット番号と変数アドレスを進める
		sh2_add_to_reg_from_val_byte r1 01
		sh2_add_to_reg_from_val_byte r14 01
		# 取得した値 == 指定されたノート番号?
		sh2_compare_reg_eq_reg r0 r13
	) >src/f_synth_get_slot_on_with_note.1.o
	cat src/f_synth_get_slot_on_with_note.1.o
	local sz_1=$(stat -c '%s' src/f_synth_get_slot_on_with_note.1.o)
	## 取得した値 != 指定されたノート番号 (T == 0)なら繰り返す
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_1) / 2)))

	# -1した値が見つけたスロット番号
	sh2_add_to_reg_from_val_byte r1 $(two_comp_d 1)

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}
