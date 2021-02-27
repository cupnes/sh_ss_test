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

sh2_copy_to_reg_from_ptr_word() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x6${dstnum}\x${srcnum}1"	# mov.w @$src,$dst
	echo -e "mov.w @$src,$dst\t;1" >>$ASM_LIST_FILE
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

sh2_compare_reg_eq_reg() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x3${regAnum}\x${regBnum}0"	# cmp/eq $regB,$regA
	echo -e "cmp/eq $regB,$regA\t;1" >>$ASM_LIST_FILE
}

sh2_compare_reg_gt_reg_unsigned() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x3${regAnum}\x${regBnum}6"	# cmp/hi $regB,$regA
	echo -e "cmp/hi $regB,$regA\t;1" >>$ASM_LIST_FILE
}

# 2つの汎用レジスタの内容を16ビットで乗算
# 結果の32ビットをMACLレジスタに格納
# 演算は符号なし算術演算で行う
# MACHの内容は変化しない
sh2_multiply_reg_and_reg_unsigned_word() {
	local regA=$1
	local regB=$2
	local regAnum=$(to_regnum $regA)
	local regBnum=$(to_regnum $regB)
	echo -en "\x2${regAnum}\x${regBnum}e"	# mulu.w $regB,$regA
	echo -e "mulu.w $regB,$regA\t;1-3" >>$ASM_LIST_FILE
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

sh2_shift_left_logical_8() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x18"	# shll8 Rn
	echo -e "shll8 $reg\t;1" >>$ASM_LIST_FILE
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

sh2_nop() {
	echo -en '\x00\x09'	# nop
	echo -e 'nop\t;1' >>$ASM_LIST_FILE
}
