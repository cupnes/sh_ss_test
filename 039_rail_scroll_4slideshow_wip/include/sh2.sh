if [ "${INCLUDE_SH2_SH+is_defined}" ]; then
	return
fi
INCLUDE_SH2_SH=true

ASM_LIST_FILE=asm.lst
rm -f $ASM_LIST_FILE

to_regnum() {
	local reg=$1
	echo "obase=16;$(echo $1 | cut -c2-)" | bc
}

sh2_set_reg() {
	local reg=$1
	local val=$2
	local regnum=$(to_regnum $reg)
	echo -en "\xe${regnum}\x${val}"	# mov #val, Rn
	echo -e "mov #0x$val,$reg\t;1" >>$ASM_LIST_FILE
}

sh2_copy_to_reg_from_reg() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x6${dstnum}\x${srcnum}3"	# mov $src,$dst
	echo -e "mov $src,$dst\t;1" >>$ASM_LIST_FILE
}

sh2_copy_to_ptr_from_reg_byte() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x2${dstnum}\x${srcnum}0"	# mov.b $src,@$dst
	echo -e "mov.b $src,@$dst\t;1" >>$ASM_LIST_FILE
}

sh2_copy_to_ptr_from_reg_word() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x2${dstnum}\x${srcnum}1"	# mov.w $src,@$dst
	echo -e "mov.w $src,@$dst\t;1" >>$ASM_LIST_FILE
}

sh2_copy_to_ptr_from_reg_long() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x2${dstnum}\x${srcnum}2"	# mov.l $src,@$dst
	echo -e "mov.l $src,@$dst\t;1" >>$ASM_LIST_FILE
}

sh2_copy_to_reg_from_ptr_byte() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x6${dstnum}\x${srcnum}0"	# mov.b @$src,$dst
	echo -e "mov.b @$src,$dst\t;1" >>$ASM_LIST_FILE
}

sh2_copy_to_reg_from_ptr_word() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x6${dstnum}\x${srcnum}1"	# mov.w @$src,$dst
	echo -e "mov.w @$src,$dst\t;1" >>$ASM_LIST_FILE
}

sh2_copy_to_reg_from_ptr_long() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x6${dstnum}\x${srcnum}2"	# mov.l @$src,$dst
	echo -e "mov.l @$src,$dst\t;1" >>$ASM_LIST_FILE
}

sh2_add_to_reg_from_reg() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x3${dstnum}\x${srcnum}c"	# add $src,$dst
	echo -e "add $src,$dst\t;1" >>$ASM_LIST_FILE
}

# 第1引数のレジスタの内容と第2引数のレジスタの内容とTビットを加算し、
# 結果を第1引数のレジスタに格納する
# 演算の結果によってキャリをTビットに反映する
# 32ビットを超える加算を行うとき使用する
# 動作イメージ：
# 第1引数レジスタ + 第2引数レジスタ + T -> 第1引数レジスタ
# キャリ -> T
sh2_add_with_carry_to_reg_from_reg() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x3${dstnum}\x${srcnum}e"	# addc $src,$dst
	echo -e "addc $src,$dst\t;1" >>$ASM_LIST_FILE
}

sh2_add_to_reg_from_val_byte() {
	local reg=$1
	local val=$2
	local regnum=$(to_regnum $reg)
	echo -en "\x7${regnum}\x${val}"	# add #0x$val,$reg
	echo -e "add #0x$val,$reg\t;1" >>$ASM_LIST_FILE
}

sh2_and_to_r0_from_val_byte() {
	local val=$1
	echo -en "\xc9\x${val}"	# and #0x$val,r0
	echo -e "and #0x$val,r0\t;1" >>$ASM_LIST_FILE
}

# reg == reg の時、T = 1
sh2_compare_reg_eq_reg() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x3${regAnum}\x${regBnum}0"	# cmp/eq $regB,$regA
	echo -e "cmp/eq $regB,$regA\t;1" >>$ASM_LIST_FILE
}

sh2_compare_reg_ge_reg_unsigned() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x3${regAnum}\x${regBnum}2"	# cmp/hs $regB,$regA
	echo -e "cmp/hs $regB,$regA\t;1" >>$ASM_LIST_FILE
}

sh2_compare_reg_ge_reg_signed() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x3${regAnum}\x${regBnum}3"	# cmp/ge $regB,$regA
	echo -e "cmp/ge $regB,$regA\t;1" >>$ASM_LIST_FILE
}

sh2_compare_reg_gt_reg_signed() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x3${regAnum}\x${regBnum}7"	# cmp/gt $regB,$regA
	echo -e "cmp/gt $regB,$regA\t;1" >>$ASM_LIST_FILE
}

sh2_compare_reg_gt_reg_unsigned() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x3${regAnum}\x${regBnum}6"	# cmp/hi $regB,$regA
	echo -e "cmp/hi $regB,$regA\t;1" >>$ASM_LIST_FILE
}

# 符号付き除算の初期設定をする
# 本命令に続けて1桁分の除算をするDIV1命令などを組み合わせて、
# 繰り返し除算を行い商を求める
# 動作イメージ：
# 第1引数のレジスタのMSB -> Q
# 第2引数のレジスタのMSB -> M
# M ^ Q -> T (T = !(M == Q))
sh2_divide_step0_signed() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x2${regAnum}\x${regBnum}7"	# div0s $regB,$regA
	echo -e "div0s $regB,$regA\t;1" >>$ASM_LIST_FILE
}

sh2_divide_step0_unsigned() {
	echo -en '\x00\x19'	# div0u
	echo -e 'div0u\t;1' >>$ASM_LIST_FILE
}

sh2_divide_1step_reg_by_reg() {
	local dividend=$1
	local divisor=$2
	local dividendnum=$(to_regnum $dividend)
	local divisornum=$(to_regnum $divisor)
	echo -en "\x3${dividendnum}\x${divisornum}4"	# div1 $divisor,$dividend
	echo -e "div1 $divisor,$dividend\t;1" >>$ASM_LIST_FILE
}

sh2_extend_signed_to_reg_from_reg_word() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x6${dstnum}\x${srcnum}f"	# exts.w $src,$dst
	echo -e "exts.w $src,$dst\t;1" >>$ASM_LIST_FILE
}

sh2_extend_unsigned_to_reg_from_reg_word() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x6${dstnum}\x${srcnum}d"	# extu.w $src,$dst
	echo -e "extu.w $src,$dst\t;1" >>$ASM_LIST_FILE
}

# 2つの汎用レジスタの内容を32ビットで乗算
# 結果の下位側32ビットをMACLレジスタに格納
# MACHの内容は変化しない
sh2_multiply_reg_by_reg_signed_long() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x0${regAnum}\x${regBnum}7"	# mul.l $regB,$regA
	echo -e "mul.l $regB,$regA\t;2-4" >>$ASM_LIST_FILE
}

# 2つの汎用レジスタの内容を16ビットで乗算
# 結果の32ビットをMACLレジスタに格納
# 演算は符号付き算術演算で行う
# MACHの内容は変化しない
sh2_multiply_reg_by_reg_signed_word() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x2${regAnum}\x${regBnum}f"	# muls.w $regB,$regA
	echo -e "muls.w $regB,$regA\t;1-3" >>$ASM_LIST_FILE
}

# 2つの汎用レジスタの内容を16ビットで乗算
# 結果の32ビットをMACLレジスタに格納
# 演算は符号なし算術演算で行う
# MACHの内容は変化しない
sh2_multiply_reg_by_reg_unsigned_word() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x2${regAnum}\x${regBnum}e"	# mulu.w $regB,$regA
	echo -e "mulu.w $regB,$regA\t;1-3" >>$ASM_LIST_FILE
}

sh2_sub_to_reg_from_reg() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x3${dstnum}\x${srcnum}8"	# sub $src,$dst
	echo -e "sub $src,$dst\t;1" >>$ASM_LIST_FILE
}

# 第1引数のレジスタの内容から第2引数のてジスタの内容とTビットを減算し、
# 結果を第1引数のレジスタに格納する
# 演算の結果によってボローをTビットに反映する
# 32ビットを超える減算を行うとき使用する
# 動作イメージ：
# 第1引数のレジスタ - 第2引数のレジスタ - T -> 第1引数のレジスタ
# ボロー -> T
sh2_sub_with_carry_to_reg_from_reg() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x3${dstnum}\x${srcnum}a"	# subc $src,$dst
	echo -e "subc $src,$dst\t;1" >>$ASM_LIST_FILE
}

sh2_or_to_reg_from_reg() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x2${dstnum}\x${srcnum}b"	# or $src,$dst
	echo -e "or $src,$dst\t;1" >>$ASM_LIST_FILE
}

sh2_or_to_r0_from_val_byte() {
	local val=$1
	echo -en "\xcb\x${val}"	# or #0x$val,r0
	echo -e "or #0x$val,r0\t;1" >>$ASM_LIST_FILE
}

# 論理積をとり、結果がゼロのときTビットをセット
# 結果がゼロでないときTビットをクリア
# R0の内容は変更しない
sh2_test_r0_and_val_byte() {
	local val=$1
	echo -en "\xc8\x${val}"	# tst #0x$val,r0
	echo -e "tst #0x$val,r0\t;1" >>$ASM_LIST_FILE
}

sh2_xor_to_reg_from_reg() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x2${dstnum}\x${srcnum}a"	# xor $src,$dst
	echo -e "xor $src,$dst\t;1" >>$ASM_LIST_FILE
}

# 引数のレジスタの内容を左方向にTビットを含めて1ビットローテート(回転)し、
# 結果を引数のレジスタに格納
# ローテートしてオペランドの外に出てしまったビットは、Tビットへ転送
# 動作イメージ：
# T <- レジスタ <- T
sh2_rotate_with_carry_left() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x24"	# rotcl $reg
	echo -e "rotcl $reg\t;1" >>$ASM_LIST_FILE
}

sh2_shift_left_logical() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x00"	# shll $reg
	echo -e "shll $reg\t;1" >>$ASM_LIST_FILE
}

sh2_shift_right_logical() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x01"	# shlr $reg
	echo -e "shlr $reg\t;1" >>$ASM_LIST_FILE
}

sh2_shift_left_logical_2() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x08"	# shll2 $reg
	echo -e "shll2 $reg\t;1" >>$ASM_LIST_FILE
}

sh2_shift_left_logical_8() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x18"	# shll8 $reg
	echo -e "shll8 $reg\t;1" >>$ASM_LIST_FILE
}

sh2_shift_left_logical_16() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x28"	# shll16 $reg
	echo -e "shll16 $reg\t;1" >>$ASM_LIST_FILE
}

# Tビットを参照する条件付き分岐命令
# - T=0 のとき、分岐先アドレスに分岐
# - T=1 のとき、次の命令を実行
# 分岐先は PC にディスプレースメントを加えたアドレス
# ただし、この際アドレス計算に使用する PC は、本命令の 4 バイト後のアドレス
# 8 ビットディスプレースメントは符号拡張後 2 倍するので、
# 分岐先との相対距離は −256 バイトから +254 バイトの範囲
sh2_rel_jump_if_false() {
	local offset=$1
	echo -en "\x8b\x${offset}"	# bf $offset
	echo -e "bf 0x$offset\t;3/1" >>$ASM_LIST_FILE
}

# Tビットを参照する条件付き分岐命令
# - T=1 のとき、分岐
# - T=0 のとき、次の命令を実行
# 分岐先は PC にディスプレースメントを加えたアドレス
# この際、アドレス計算に使用する PC は、本命令の 4 バイト後のアドレス
# 8 ビットディスプレースメントは符号拡張後 2 倍するので、
# 分岐先との相対距離は −256 バイトから +254 バイトの範囲
sh2_rel_jump_if_true() {
	local offset=$1
	echo -en "\x89\x${offset}"	# bt $offset
	echo -e "bt 0x$offset\t;3/1" >>$ASM_LIST_FILE
}

# 無条件の遅延分岐命令
# 分岐先は PC にディスプレースメントを加えたアドレス
# ただし、この際アドレス計算に使用する PC は、本命令の 4 バイト後のアドレス
# 12 ビットディスプレースメントは符号拡張後 2 倍するので、
# 分岐先との相対距離は −4096 バイトから +4094 バイトの範囲
sh2_rel_jump_after_next_inst() {
	local offset=$1
	echo -en "\xa$(echo $offset | cut -c1)\x$(echo $offset | cut -c2-3)"	# bra $offset
	echo -e "bra 0x$offset\t;2" >>$ASM_LIST_FILE
}

sh2_abs_jump_to_reg_after_next_inst() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x2b"	# jmp $reg
	echo -e "jmp $reg\t;2" >>$ASM_LIST_FILE
}

sh2_abs_call_to_reg_after_next_inst() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x0b"	# jsr $reg
	echo -e "jsr $reg\t;2" >>$ASM_LIST_FILE
}

sh2_return_after_next_inst() {
	echo -en '\x00\x0b'	# rts
	echo -e 'rts\t;2' >>$ASM_LIST_FILE
}

sh2_copy_to_pr_from_reg() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x2a"	# lds $reg,pr
	echo -e "lds $reg,pr\t;1" >>$ASM_LIST_FILE
}

sh2_nop() {
	echo -en '\x00\x09'	# nop
	echo -e 'nop\t;1' >>$ASM_LIST_FILE
}

sh2_sleep() {
	echo -en '\x00\x1b'	# sleep
	echo -e 'sleep\t;3' >>$ASM_LIST_FILE
}

sh2_copy_to_reg_from_macl() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x0${regnum}\x1a"	# sts macl,$reg
	echo -e "sts macl,$reg\t;1" >>$ASM_LIST_FILE
}

sh2_copy_to_reg_from_pr() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x0${regnum}\x2a"	# sts pr,$reg
	echo -e "sts pr,$reg\t;1" >>$ASM_LIST_FILE
}
