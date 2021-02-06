if [ "${INCLUDE_SH2_SH+is_defined}" ]; then
	return
fi
INCLUDE_SH2_SH=true

ASM_LIST_FILE=asm.lst
rm -f $ASM_LIST_FILE

sh2_rel_jump_after_next_inst() {
	local offset=$1
	echo -en "\xaf\x${offset}"	# bra ${offset}
	echo -e "bra \$$offset\t;2" >>$ASM_LIST_FILE
}

sh2_nop() {
	echo -en '\x00\x09'	# nop
	echo -e 'nop\t;1' >>$ASM_LIST_FILE
}
