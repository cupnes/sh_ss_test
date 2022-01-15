if [ "${SRC_PAD_SH+is_defined}" ]; then
	return
fi
SRC_PAD_SH=true

. include/sh2.sh
. include/ss.sh
. include/lib.sh

# BUTTON_PRESSED_TH=0120
BUTTON_PRESSED_TH=0020

# ゲームパッド入力状態変数の更新
# 今の所、押下カウンタはボタンを区別しない
# work: r0 - 作業用
#       r1 - 作業用
#       r2 - 作業用
f_update_gamepad_input_status() {
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
	## r3
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r3

	# SFへ1をセット
	## SFのアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_SF_ADDR
	## r0へ0x01をセット
	sh2_set_reg r0 01
	## r1の指す先(SF)へr0の値(0x01)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# IREG2へ0xf0をセット
	## IREG2のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_IREG2_ADDR
	## r0へ0xf0をセット
	sh2_set_reg r0 f0
	## r1の指す先(IREG2)へr0の値(0xf0)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# IREG1へ0x08をセット
	## IREG1のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_IREG1_ADDR
	## r0へ0x08をセット
	sh2_set_reg r0 08
	## r1の指す先(IREG1)へr0の値(0x08)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# IREG0へ0x00をセット
	## IREG0のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_IREG0_ADDR
	## r0へ0x00をセット
	sh2_xor_to_reg_from_reg r0 r0
	## r1の指す先(IREG0)へr0の値(0x00)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# COMREGへINTBACKをセット
	## COMREGのアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_COMREG_ADDR
	## r0へINTBACKをセット
	sh2_set_reg r0 $SS_SMPC_COMREG_INTBACK
	## r1の指す先(COMREG)へr0の値(INTBACK)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# SFが0になるのを待つ
	## SFのアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_SF_ADDR
	(
		## r0へr1の指す先(SF)の値をロード
		sh2_copy_to_reg_from_ptr_byte r0 r1
		## bit0が1の間、ここで待つ
		sh2_test_r0_and_val_byte 01
	) >src/f_update_gamepad_input_status.1.o
	local sz_1=$(stat -c '%s' src/f_update_gamepad_input_status.1.o)
	cat src/f_update_gamepad_input_status.1.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_1) / 2)))

	# OREG2(1st Data)を変数へロード
	## OREG2のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_OREG2_ADDR
	## r2へr1の指す先(OREG2)の値をロード
	sh2_copy_to_reg_from_ptr_byte r2 r1
	## 押下時0の状態なので反転
	sh2_not_to_reg_from_reg r2 r2
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_1
	## r1の指す先(変数)へr2の値を格納
	sh2_copy_to_ptr_from_reg_byte r1 r2

	# OREG3(2nd Data)を変数へロード
	## OREG3のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_OREG3_ADDR
	## r3へr1の指す先(OREG3)の値をロード
	sh2_copy_to_reg_from_ptr_byte r3 r1
	## 押下時0の状態なので反転
	sh2_not_to_reg_from_reg r3 r3
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_2
	## r1の指す先(変数)へr3の値を格納
	sh2_copy_to_ptr_from_reg_byte r1 r3

	# 押下カウンタ更新
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_button_pressed_counter
	## 何らかのボタンの押下があるか?
	sh2_or_to_reg_from_reg r2 r3
	sh2_copy_to_reg_from_reg r0 r2
	sh2_test_r0_and_val_byte ff
	(
		# 何らかのボタンの押下がある場合

		# 現在の押下カウントをインクリメントした値をr2へ設定
		sh2_copy_to_reg_from_ptr_word r2 r1
		sh2_extend_unsigned_to_reg_from_reg_word r2 r2
		sh2_add_to_reg_from_val_byte r2 01
	) >src/f_update_gamepad_input_status.2.o
	(
		# 何らかのボタンの押下がない場合

		# 0をr2へ設定
		sh2_set_reg r2 00

		# 何らかのボタンの押下がある場合の処理を飛ばす
		local sz_2=$(stat -c '%s' src/f_update_gamepad_input_status.2.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_2 / 2))) 3)
		sh2_nop
	) >src/f_update_gamepad_input_status.3.o
	local sz_3=$(stat -c '%s' src/f_update_gamepad_input_status.3.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_3 - 2) / 2)))
	cat src/f_update_gamepad_input_status.3.o	# 何らかのボタンの押下がない場合(T==1)
	cat src/f_update_gamepad_input_status.2.o	# 何らかのボタンの押下がある場合(T==0)
	## r2を押下カウンタ変数へ反映
	sh2_copy_to_ptr_from_reg_word r1 r2

	# 退避したレジスタを復帰しreturn
	## r3
	sh2_copy_to_reg_from_ptr_long r3 r15
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

# コントロールパッドから1文字の入力を取得する
# キーバインド:
# |   BS | R      |
# | 改行 | Start  |
# |    0 | ↑     |
# |    1 | →     |
# |    2 | ↓     |
# |    3 | ←     |
# |    4 | A + ↑ |
# |    5 | A + → |
# |    6 | A + ↓ |
# |    7 | A + ← |
# |    8 | B + ↑ |
# |    9 | B + → |
# |    A | B + ↓ |
# |    B | B + ← |
# |    C | C + ↑ |
# |    D | C + → |
# |    E | C + ↓ |
# |    F | C + ← |
# out : r1 - 文字コード(入力が無かった場合:CHARCODE_NULL)
# work: r0 - 作業用
#     : r1 - 作業用
f_getchar_from_pad() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## r3
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r3
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# return共通処理
	(
		# 退避したレジスタを復帰しreturn
		## pr
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
		## r3
		sh2_copy_to_reg_from_ptr_long r3 r15
		sh2_add_to_reg_from_val_byte r15 04
		## r2
		sh2_copy_to_reg_from_ptr_long r2 r15
		sh2_add_to_reg_from_val_byte r15 04
		## r0
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		## return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_getchar_from_pad.1.o

	# ゲームパッド入力状態の変数を更新する
	copy_to_reg_from_val_long r1 $a_update_gamepad_input_status
	sh2_abs_call_to_reg_after_next_inst r1
	sh2_nop

	# 押下カウントチェック
	## 押下カウントがしきい値を超えているか?
	copy_to_reg_from_val_long r1 $var_button_pressed_counter
	sh2_copy_to_reg_from_ptr_word r2 r1
	copy_to_reg_from_val_word r3 $BUTTON_PRESSED_TH
	sh2_compare_reg_gt_reg_unsigned r2 r3
	(
		# var_button_pressed_counter <= BUTTON_PRESSED_TH の場合

		# 戻り値(r1)にCHARCODE_NULLを設定
		sh2_set_reg r1 $CHARCODE_NULL

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.2.o
	## var_button_pressed_counter > BUTTON_PRESSED_TH (T==1)なら
	## 処理をスキップする
	local sz_2=$(stat -c '%s' src/f_getchar_from_pad.2.o)
	sh2_rel_jump_if_true $(two_digits_d $(((sz_2 - 2) / 2)))
	cat src/f_getchar_from_pad.2.o

	# 押下カウンタをゼロクリア
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2

	# バインドされている押下があるかチェックし戻り値を返す

	## BS：R (var_pad_current_state_2=0x80)
	copy_to_reg_from_val_long r1 $var_pad_current_state_2
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_test_r0_and_val_byte 80
	(
		# Rの押下有りの場合

		# 戻り値(r1)にCHARCODE_BSを設定
		sh2_set_reg r1 $CHARCODE_BS

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.3.o
	### Rの押下が無い場合(T==1)は処理を飛ばす
	local sz_3=$(stat -c '%s' src/f_getchar_from_pad.3.o)
	sh2_rel_jump_if_true $(two_digits_d $(((sz_3 - 2) / 2)))
	cat src/f_getchar_from_pad.3.o
	## 改行：Start (var_pad_current_state_1=0x08)
	copy_to_reg_from_val_long r1 $var_pad_current_state_1
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_test_r0_and_val_byte 08
	(
		# 改行の押下有りの場合

		# 戻り値(r1)にCHARCODE_LFを設定
		sh2_set_reg r1 $CHARCODE_LF

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.4.o
	### 改行の押下が無い場合(T==1)は処理を飛ばす
	local sz_4=$(stat -c '%s' src/f_getchar_from_pad.4.o)
	sh2_rel_jump_if_true $(two_digits_d $(((sz_4 - 2) / 2)))
	cat src/f_getchar_from_pad.4.o

	## '0'：↑のみ (var_pad_current_state_1=0x10)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 10
	(
		# ↑のみの押下有りの場合

		# 戻り値(r1)にCHARCODE_4を設定
		sh2_set_reg r1 $CHARCODE_0

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.5.o
	### ↑のみの押下が無い場合(T==0)は処理を飛ばす
	local sz_5=$(stat -c '%s' src/f_getchar_from_pad.5.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_5 - 2) / 2)))
	cat src/f_getchar_from_pad.5.o
	## '1'：→のみ (var_pad_current_state_1=0x80)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 80
	(
		# →のみの押下有りの場合

		# 戻り値(r1)にCHARCODE_1を設定
		sh2_set_reg r1 $CHARCODE_1

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.6.o
	### →のみの押下が無い場合(T==0)は処理を飛ばす
	local sz_6=$(stat -c '%s' src/f_getchar_from_pad.6.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_6 - 2) / 2)))
	cat src/f_getchar_from_pad.6.o
	## '2'：↓のみ (var_pad_current_state_1=0x20)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 20
	(
		# ↓のみの押下有りの場合

		# 戻り値(r1)にCHARCODE_2を設定
		sh2_set_reg r1 $CHARCODE_2

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.7.o
	### ↓のみの押下が無い場合(T==0)は処理を飛ばす
	local sz_7=$(stat -c '%s' src/f_getchar_from_pad.7.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_7 - 2) / 2)))
	cat src/f_getchar_from_pad.7.o
	## '3'：←のみ (var_pad_current_state_1=0x40)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 40
	(
		# ←のみの押下有りの場合

		# 戻り値(r1)にCHARCODE_3を設定
		sh2_set_reg r1 $CHARCODE_3

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.8.o
	### ←のみの押下が無い場合(T==0)は処理を飛ばす
	local sz_8=$(stat -c '%s' src/f_getchar_from_pad.8.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_8 - 2) / 2)))
	cat src/f_getchar_from_pad.8.o

	## '4'：A + ↑ (var_pad_current_state_1=0x14)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 14
	(
		# A + ↑の押下有りの場合

		# 戻り値(r1)にCHARCODE_4を設定
		sh2_set_reg r1 $CHARCODE_4

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.9.o
	### A + ↑の押下が無い場合(T==0)は処理を飛ばす
	local sz_9=$(stat -c '%s' src/f_getchar_from_pad.9.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_9 - 2) / 2)))
	cat src/f_getchar_from_pad.9.o
	## '5'：A + → (var_pad_current_state_1=0x84)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 84
	(
		# A + →の押下有りの場合

		# 戻り値(r1)にCHARCODE_5を設定
		sh2_set_reg r1 $CHARCODE_5

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.10.o
	### A + →の押下が無い場合(T==0)は処理を飛ばす
	local sz_10=$(stat -c '%s' src/f_getchar_from_pad.10.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_10 - 2) / 2)))
	cat src/f_getchar_from_pad.10.o
	## '6'：A + ↓ (var_pad_current_state_1=0x24)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 24
	(
		# A + ↓の押下有りの場合

		# 戻り値(r1)にCHARCODE_6を設定
		sh2_set_reg r1 $CHARCODE_6

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.11.o
	### A + ↓の押下が無い場合(T==0)は処理を飛ばす
	local sz_11=$(stat -c '%s' src/f_getchar_from_pad.11.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_11 - 2) / 2)))
	cat src/f_getchar_from_pad.11.o
	## '7'：A + ← (var_pad_current_state_1=0x44)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 44
	(
		# A + ←の押下有りの場合

		# 戻り値(r1)にCHARCODE_7を設定
		sh2_set_reg r1 $CHARCODE_7

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.12.o
	### A + ←の押下が無い場合(T==0)は処理を飛ばす
	local sz_12=$(stat -c '%s' src/f_getchar_from_pad.12.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_12 - 2) / 2)))
	cat src/f_getchar_from_pad.12.o

	## '8'：B + ↑ (var_pad_current_state_1=0x11)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 11
	(
		# B + ↑の押下有りの場合

		# 戻り値(r1)にCHARCODE_8を設定
		sh2_set_reg r1 $CHARCODE_8

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.13.o
	### B + ↑の押下が無い場合(T==0)は処理を飛ばす
	local sz_13=$(stat -c '%s' src/f_getchar_from_pad.13.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_13 - 2) / 2)))
	cat src/f_getchar_from_pad.13.o
	## '9'：B + → (var_pad_current_state_1=0x81)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 81
	(
		# B + →の押下有りの場合

		# 戻り値(r1)にCHARCODE_9を設定
		sh2_set_reg r1 $CHARCODE_9

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.14.o
	### B + →の押下が無い場合(T==0)は処理を飛ばす
	local sz_14=$(stat -c '%s' src/f_getchar_from_pad.14.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_14 - 2) / 2)))
	cat src/f_getchar_from_pad.14.o
	## 'A'：B + ↓ (var_pad_current_state_1=0x21)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 21
	(
		# B + ↓の押下有りの場合

		# 戻り値(r1)にCHARCODE_Aを設定
		sh2_set_reg r1 $CHARCODE_A

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.15.o
	### B + ↓の押下が無い場合(T==0)は処理を飛ばす
	local sz_15=$(stat -c '%s' src/f_getchar_from_pad.15.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_15 - 2) / 2)))
	cat src/f_getchar_from_pad.15.o
	## 'B'：B + ← (var_pad_current_state_1=0x41)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 41
	(
		# B + ←の押下有りの場合

		# 戻り値(r1)にCHARCODE_Bを設定
		sh2_set_reg r1 $CHARCODE_B

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.16.o
	### B + ←の押下が無い場合(T==0)は処理を飛ばす
	local sz_16=$(stat -c '%s' src/f_getchar_from_pad.16.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_16 - 2) / 2)))
	cat src/f_getchar_from_pad.16.o

	## 'C'：C + ↑ (var_pad_current_state_1=0x12)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 12
	(
		# C + ↑の押下有りの場合

		# 戻り値(r1)にCHARCODE_8を設定
		sh2_set_reg r1 $CHARCODE_C

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.17.o
	### C + ↑の押下が無い場合(T==0)は処理を飛ばす
	local sz_17=$(stat -c '%s' src/f_getchar_from_pad.17.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_17 - 2) / 2)))
	cat src/f_getchar_from_pad.17.o
	## 'D'：C + → (var_pad_current_state_1=0x82)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 82
	(
		# C + →の押下有りの場合

		# 戻り値(r1)にCHARCODE_Dを設定
		sh2_set_reg r1 $CHARCODE_D

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.18.o
	### C + →の押下が無い場合(T==0)は処理を飛ばす
	local sz_18=$(stat -c '%s' src/f_getchar_from_pad.18.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_18 - 2) / 2)))
	cat src/f_getchar_from_pad.18.o
	## 'E'：C + ↓ (var_pad_current_state_1=0x22)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 22
	(
		# C + ↓の押下有りの場合

		# 戻り値(r1)にCHARCODE_Eを設定
		sh2_set_reg r1 $CHARCODE_E

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.19.o
	### C + ↓の押下が無い場合(T==0)は処理を飛ばす
	local sz_19=$(stat -c '%s' src/f_getchar_from_pad.19.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_19 - 2) / 2)))
	cat src/f_getchar_from_pad.19.o
	## 'F'：C + ← (var_pad_current_state_1=0x42)
	sh2_copy_to_reg_from_ptr_byte r0 r1
	sh2_compare_r0_eq_val 42
	(
		# C + ←の押下有りの場合

		# 戻り値(r1)にCHARCODE_Fを設定
		sh2_set_reg r1 $CHARCODE_F

		# return共通処理
		cat src/f_getchar_from_pad.1.o
	) >src/f_getchar_from_pad.20.o
	### C + ←の押下が無い場合(T==0)は処理を飛ばす
	local sz_20=$(stat -c '%s' src/f_getchar_from_pad.20.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_20 - 2) / 2)))
	cat src/f_getchar_from_pad.20.o

	# 戻り値(r1)にCHARCODE_NULLを設定
	sh2_set_reg r1 $CHARCODE_NULL

	# return共通処理
	cat src/f_getchar_from_pad.1.o
}
