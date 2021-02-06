if [ "${INCLUDE_COMMON_SH+is_defined}" ]; then
	return
fi
INCLUDE_COMMON_SH=true

echo_2bytes() {
	local val=$1
	local top_half=$(echo $val | cut -c-2)
	local bottom_half=$(echo $val | cut -c3-4)
	echo -en "\x${bottom_half}\x${top_half}"
}

two_digits() {
	local val=$1
	local current_digits=$(echo -n $val | wc -m)
	case $current_digits in
	1)
		echo "0$val"
		;;
	2)
		echo $val
		;;
	*)
		echo "Error: Invalid digits: %val" 1>&2
		return 1
	esac
}

two_digits_d() {
	local val_d=$1
	local val=$(echo "obase=16;$val_d" | bc)
	two_digits $val
}

four_digits() {
	local val=$1
	local current_digits=$(echo -n $val | wc -m)
	case $current_digits in
	1)
		echo "000$val"
		;;
	2)
		echo "00$val"
		;;
	3)
		echo "0$val"
		;;
	4)
		echo $val
		;;
	*)
		echo "Error: Invalid digits: %val" 1>&2
		return 1
	esac
}

extend_digit() {
	local val=$1
	local expected_digits=$2
	local current_digits=$(echo -n $val | wc -m)
	if [ $current_digits -lt $expected_digits ]; then
		local n=$((expected_digits - current_digits))
		local _i
		for _i in $(seq $n); do
			echo -n '0'
		done
	fi
	echo $val
}

dump_val_4() {
	local val=$1
	local i
	for i in 1 3 5 7; do
		echo -en "\x$(echo $val | cut -c${i}-$((i + 1)))"
	done
}

two_comp() {
	local val=$1
	local val_up=$(echo $val | tr [:lower:] [:upper:])
	echo "obase=16;ibase=16;100-${val_up}" | bc
}

two_comp_d() {
	local val=$1
	echo "obase=16;256-${val}" | bc
}

calc16() {
	local bc_form=$1
	local form_up=$(echo $bc_form | tr [:lower:] [:upper:])
	echo "obase=16;ibase=16;$form_up" | bc
}

calc16_2() {
	local bc_form=$1
	two_digits $(calc16 $bc_form)
}

to16() {
	local val=$1
	echo "obase=16;$val" | bc
}
