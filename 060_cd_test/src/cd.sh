if [ "${SRC_CD_SH+is_defined}" ]; then
	return
fi
SRC_CD_SH=true

. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/common.sh

# CDコマンドの実行
# 第1引数: CR1に使う値を格納したレジスタ
# 第2引数: CR2に使う値を格納したレジスタ
# 第3引数: CR3に使う値を格納したレジスタ
# 第4引数: CR4に使う値を格納したレジスタ
# 第5引数: 作業用レジスタ
# ※ r0は作業用に使うため指定しないこと
# ※ 作業用レジスタはこのマクロ関数内で破壊される
cd_exec_command() {
	local reg_cr1=$1
	local reg_cr2=$2
	local reg_cr3=$3
	local reg_cr4=$4
	local reg_work=$5

	# 現在のSRのI3〜I0を退避してNMI以外の全ての割り込みをマスクする
	# TODO

	# HIRQレジスタにCMOKビットがセットされるまで待つ
	copy_to_reg_from_val_long $reg_work $SS_CT_CS2_HIRQ_ADDR
	(
		sh2_copy_to_reg_from_ptr_word r0 $reg_work
		sh2_test_r0_and_val_byte $(echo $SS_CS2_HIRQ_BIT_CMOK | cut -c3-4)
	) >src/cd_exec_command.1.o
	cat src/cd_exec_command.1.o
	local sz_1=$(stat -c '%s' src/cd_exec_command.1.o)
	## CMOKビットがセットされていなければ(T=1ならば)、繰り返す
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	sh2_nop

	# 退避したI3〜I0をSRへ復帰する
	# TODO
}

# 初期化処理
# cd_init() {
# }
