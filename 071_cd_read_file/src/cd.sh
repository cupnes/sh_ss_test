if [ "${SRC_CD_SH+is_defined}" ]; then
	return
fi
SRC_CD_SH=true

. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/common.sh
. include/con.sh

# CR1〜CR4を指定された座標にダンプする
# in  : r1 - X座標
#     : r2 - Y座標
# work: r0 - 作業用
#     : r3 - 作業用
#     : r4 - 作業用
#     : r5 - 作業用
#     : r6 - 作業用
f_dump_cr1234_xy() {
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
	## r4
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r4
	## r5
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r5
	## r6
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r6
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# Y座標をr4へコピー
	sh2_copy_to_reg_from_reg r4 r2

	# r2へX座標を設定
	# X座標は変わらないのでずっとこのまま
	sh2_copy_to_reg_from_reg r2 r1

	# 使用する関数のアドレスをレジスタへ設定
	copy_to_reg_from_val_long r5 $a_putreg_xy

	# CR1のアドレスをr6へ設定
	# 以降、4ずつ加算しながらCR2・CR3・CR4とアクセスする
	copy_to_reg_from_val_long r6 $SS_CT_CS2_CR1_ADDR

	# CR1をダンプ
	## r1へCR1の値を設定
	sh2_copy_to_reg_from_ptr_word r1 r6
	## r3へY座標を設定
	sh2_copy_to_reg_from_reg r3 r4
	## 関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_nop

	# CR2をダンプ
	## r1へCR2の値を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_reg_from_ptr_word r1 r6
	## r3へY座標を設定
	sh2_add_to_reg_from_val_byte r4 $CON_FONT_HEIGHT
	sh2_copy_to_reg_from_reg r3 r4
	## 関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_nop

	# CR3をダンプ
	## r1へCR3の値を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_reg_from_ptr_word r1 r6
	## r3へY座標を設定
	sh2_add_to_reg_from_val_byte r4 $CON_FONT_HEIGHT
	sh2_copy_to_reg_from_reg r3 r4
	## 関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_nop

	# CR4をダンプ
	## r1へCR4の値を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_reg_from_ptr_word r1 r6
	## r3へY座標を設定
	sh2_add_to_reg_from_val_byte r4 $CON_FONT_HEIGHT
	sh2_copy_to_reg_from_reg r3 r4
	## 関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_nop

	# 退避したレジスタを復帰しreturn
	## pr
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
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

# CDコマンドを実行する
# in  : r1 - CR1に使う値
#     : r2 - CR2に使う値
#     : r3 - CR3に使う値
#     : r4 - CR4に使う値
# work: r5 - 作業用(HIRQのアドレス)
#     : r6 - 作業用
f_cd_exec_command() {
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
	## r4
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r4
	## r5
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r5
	## r6
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r6

	# 現在のSRのI3〜I0を退避してNMI以外の全ての割り込みをマスクする
	# TODO

	# HIRQレジスタにCMOKビットがセットされるまで待つ
	copy_to_reg_from_val_long r5 $SS_CT_CS2_HIRQ_ADDR
	(
		sh2_copy_to_reg_from_ptr_word r0 r5
		sh2_test_r0_and_val_byte $(echo $SS_CS2_HIRQ_BIT_CMOK | cut -c3-4)
	) >src/f_cd_exec_command.1.o
	cat src/f_cd_exec_command.1.o
	local sz_1=$(stat -c '%s' src/f_cd_exec_command.1.o)
	## CMOKビットがセットされていなければ(T=1ならば)、繰り返す
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))

	# HIRQのCMOKとその他のユーザー定義フラグをクリアする
	# (0を書くとそのビットに対応するフラグをクリアできる)
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r5 r0

	# CR1〜CR4を設定する
	## CR1のアドレスをr6へ設定
	copy_to_reg_from_val_long r6 $SS_CT_CS2_CR1_ADDR
	## CR1へr1を設定
	sh2_copy_to_ptr_from_reg_word r6 r1
	## CR2へr2を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_ptr_from_reg_word r6 r2
	## CR3へr3を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_ptr_from_reg_word r6 r3
	## CR4へr4を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_ptr_from_reg_word r6 r4

	# HIRQレジスタにCMOKビットがセットされるまで待つ
	cat src/f_cd_exec_command.1.o
	## CMOKビットがセットされていなければ(T=1ならば)、繰り返す
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))

	# 退避したI3〜I0をSRへ復帰する
	# TODO

	# 退避したレジスタを復帰しreturn
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

# 初期化処理
# cd_init() {
# }
