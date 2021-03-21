if [ "${INCLUDE_LIB_SH+is_defined}" ]; then
	return
fi
INCLUDE_LIB_SH=true

. include/common.sh
. include/sh2.sh

infinite_loop() {
	sh2_sleep
	sh2_rel_jump_after_next_inst $(two_comp_3_d 3)
	sh2_nop
}

# ※ 作業用にR0を使用する
copy_to_reg_from_val_long() {
	local reg=$1
	local val=$2

	sh2_set_reg $reg $(echo $val | cut -c1-2)
	sh2_shift_left_logical_8 $reg
	sh2_set_reg r0 $(echo $val | cut -c3-4)
	sh2_and_to_r0_from_val_byte ff
	sh2_or_to_reg_from_reg $reg r0
	sh2_shift_left_logical_8 $reg
	sh2_set_reg r0 $(echo $val | cut -c5-6)
	sh2_and_to_r0_from_val_byte ff
	sh2_or_to_reg_from_reg $reg r0
	sh2_shift_left_logical_8 $reg
	sh2_set_reg r0 $(echo $val | cut -c7-8)
	sh2_and_to_r0_from_val_byte ff
	sh2_or_to_reg_from_reg $reg r0
}

# SH-1/SH-2/SH-DSP ソフトウェアマニュアル
# - 6.1.18 DIV1(DIVide 1 step)
#   - (5) 使用例 3
# をマクロ化
# 第1引数: 被除数と計算結果の商に使うレジスタ(使用例のR1)
# 第2引数: 除数に使うレジスタ(使用例のR0)
# 第3引数: 作業用レジスタ1(使用例のR2)
# 第4引数: 作業用レジスタ2(使用例のR3)
div_reg_by_reg_word_sign() {
	local reg_dividend_result=$1
	local reg_divisor=$2
	local reg_work1=$3
	local reg_work2=$4

	# 除数・作業用1・2のレジスタをスタックへ退避
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 $reg_divisor
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 $reg_work1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 $reg_work2

	# 除数を上位 16 ビット、下位 16 ビットを 0 に設定
	sh2_shift_left_logical_16 $reg_divisor

	# 被除数は符号拡張して 32 ビット
	sh2_extend_signed_to_reg_from_reg_word $reg_dividend_result $reg_dividend_result

	# 作業用レジスタ1=0
	sh2_xor_to_reg_from_reg $reg_work1 $reg_work1

	# 被除数を1ビット左シフトし、最上位ビット(符号ビット)をTビットへ格納
	# 被除数が負のときTビットに1が、正のとき0がセットされる
	sh2_copy_to_reg_from_reg $reg_work2 $reg_dividend_result
	sh2_rotate_with_carry_left $reg_work2

	# 被除数が負のとき、-1 する。
	# $reg_dividend_result - $reg_work1(=0) - Tビット -> $reg_dividend_result
	sh2_sub_with_carry_to_reg_from_reg $reg_dividend_result $reg_work1

	# フラグの初期化
	sh2_divide_step0_signed $reg_dividend_result $reg_divisor

	# 16回繰り返し
	local _i
	for _i in $(seq 16); do
		sh2_divide_1step_reg_by_reg $reg_dividend_result $reg_divisor
	done

	sh2_extend_signed_to_reg_from_reg_word $reg_dividend_result $reg_dividend_result

	# reg_dividend_result=商(1の補数表現)
	sh2_rotate_with_carry_left $reg_dividend_result

	# 商のMSBが1のとき、+1して2の補数表現に変換
	sh2_add_with_carry_to_reg_from_reg $reg_dividend_result $reg_work1

	# reg_dividend_result=商(2の補数表現)
	sh2_extend_signed_to_reg_from_reg_word $reg_dividend_result $reg_dividend_result

	# 作業用レジスタ2・1をスタックから復帰
	sh2_copy_to_reg_from_ptr_long $reg_work2 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_reg_from_ptr_long $reg_work1 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_reg_from_ptr_long $reg_divisor r15
	sh2_add_to_reg_from_val_byte r15 04
}

put_file_to_addr() {
	local f=$1
	local adr=$(extend_digit $2 8)

	# R1へ$adrを格納
	copy_to_reg_from_val_long r1 $adr

	# $fを1バイトずつ$adrへ配置
	for b in $(od -A n -t x1 $f); do
		sh2_set_reg r2 $b
		sh2_copy_to_ptr_from_reg_byte r1 r2
		sh2_add_to_reg_from_val_byte r1 01
	done
}
