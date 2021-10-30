if [ "${SRC_CD_SH+is_defined}" ]; then
	return
fi
SRC_CD_SH=true

. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/common.sh

# CDコマンドを実行する
# in  : r1 - CR1に使う値
#     : r2 - CR2に使う値
#     : r3 - CR3に使う値
#     : r4 - CR4に使う値
# work: r5 - 作業用(HIRQのアドレス)
f_cd_exec_command() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## TODO

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

	# 退避したI3〜I0をSRへ復帰する
	# TODO

	# 退避したレジスタを復帰しreturn
	## TODO
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
