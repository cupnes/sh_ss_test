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

sh2_copy_to_ptr_from_reg_byte() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x2${dstnum}\x${srcnum}0"	# mov $src,@$dst
	echo -e "mov $src,@$dst\t;1" >>$ASM_LIST_FILE
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

sh2_or_to_reg_from_reg() {
	local dst=$1
	local src=$2
	local dstnum=$(to_regnum $dst)
	local srcnum=$(to_regnum $src)
	echo -en "\x2${dstnum}\x${srcnum}b"	# or $src,$dst
	echo -e "or $src,$dst\t;1" >>$ASM_LIST_FILE
}

sh2_shift_left_logical_8() {
	local reg=$1
	local regnum=$(to_regnum $reg)
	echo -en "\x4${regnum}\x18"	# shll8 Rn
	echo -e "shll8 $reg\t;1" >>$ASM_LIST_FILE
}

sh2_rel_jump_after_next_inst() {
	local offset=$1
	echo -en "\xaf\x${offset}"	# bra ${offset}
	echo -e "bra 0x$offset\t;2" >>$ASM_LIST_FILE
}

sh2_nop() {
	echo -en '\x00\x09'	# nop
	echo -e 'nop\t;1' >>$ASM_LIST_FILE
}
