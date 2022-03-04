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

echo_4bytes() {
	local val=$1
	echo -en "\x$(echo $val | cut -c7-8)"
	echo -en "\x$(echo $val | cut -c5-6)"
	echo -en "\x$(echo $val | cut -c3-4)"
	echo -en "\x$(echo $val | cut -c1-2)"
}

echo_4bytes_be() {
	local val=$1
	echo -en "\x$(echo $val | cut -c1-2)"
	echo -en "\x$(echo $val | cut -c3-4)"
	echo -en "\x$(echo $val | cut -c5-6)"
	echo -en "\x$(echo $val | cut -c7-8)"
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
		echo "Error: Invalid digits: $val" >&2
		return 1
	esac
}

two_digits_d() {
	local val_d=$1
	if [ $val_d -ge 128 ]; then
		echo "Error: Argument($val_d) must be less than 128." >&2
		return 1
	fi
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
		echo "Error: Invalid digits: %val" >&2
		return 1
	esac
}

four_digits_d() {
	local val_d=$1
	if [ $val_d -ge 32768 ]; then
		echo "Error: Argument($val_d) must be less than 32768." >&2
		return 1
	fi
	local val=$(echo "obase=16;$val_d" | bc)
	four_digits $val
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

two_comp() {
	local val=$1
	if [ $val -eq 0 ]; then
		echo "Error: Zero is invalid.(arg=$val)" >&2
		return 1
	fi
	local val_up=$(echo $val | tr [:lower:] [:upper:])
	echo "obase=16;ibase=16;100-${val_up}" | bc
}

two_comp_d() {
	local val=$1
	if [ $val -eq 0 ]; then
		echo "Error: Zero is invalid.(arg=$val)" >&2
		return 1
	fi
	if [ $val -ge 128 ]; then
		echo "Error: Argument($val) must be less than 128." >&2
		return 1
	fi
	echo "obase=16;256-${val}" | bc
}

two_comp_3_d() {
	local val=$1
	if [ $val -eq 0 ]; then
		echo "Error: Zero is invalid.(arg=$val)" >&2
		return 1
	fi
	if [ $val -ge 2048 ]; then
		echo "Error: Argument($val) must be less than 2048." >&2
		return 1
	fi
	echo "obase=16;4096-${val}" | bc
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

calc16_4() {
	local bc_form=$1
	extend_digit $(calc16 $bc_form) 4
}

calc16_8() {
	local bc_form=$1
	extend_digit $(calc16 $bc_form) 8
}

to16() {
	local val=$1
	echo "obase=16;$val" | bc
}

to16_2() {
	local val=$1
	if [ $val -lt 0 ] || [ $val -gt 255 ]; then
		echo "Error: Argument($val) must be between 0 and 255." >&2
		return 1
	fi
	echo "obase=16;$val + 256" | bc | cut -c2-3
}
