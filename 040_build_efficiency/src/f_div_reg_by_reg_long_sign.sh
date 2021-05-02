#!/bin/bash

# set -uex
set -ue

. include/sh2.sh
. include/lib.sh

# 符号付き32ビット除算
# in  : r1  - 被除数
#     : r0* - 除数
# out : r1  - 計算結果の商
# work: r2* - 作業用
#       r3* - 作業用
# ※ *が付いているレジスタはこの関数の冒頭/末尾でスタックへの退避/復帰を行う
f_div_reg_by_reg_long_sign() {
	div_reg_by_reg_long_sign r1 r0 r2 r3

	# return
	sh2_return_after_next_inst
	sh2_nop
}

f_div_reg_by_reg_long_sign
