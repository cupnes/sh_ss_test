if [ "${INCLUDE_SH2_SH+is_defined}" ]; then
	return
fi
INCLUDE_SH2_SH=true

ASM_LIST_FILE=asm.lst
rm -f $ASM_LIST_FILE

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

sh2_nop() {
	echo -en '\x00\x09'	# nop
	echo -e 'nop\t;1' >>$ASM_LIST_FILE
}
