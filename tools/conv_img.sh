#!/bin/bash

# set -uex
set -ue

DST_COLOR_RANGE=32

SRC=$1
DST=$2

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

src_name=$(echo $SRC | rev | cut -d'.' -f2- | rev)
ppm=${src_name}.ppm

convert $SRC -compress none $ppm

# width=$(sed -n 2p $ppm | cut -d' ' -f1)
# height=$(sed -n 2p $ppm | cut -d' ' -f2)
src_color_range=$(($(sed -n 3p $ppm) + 1))

color_unit=$((src_color_range / DST_COLOR_RANGE))

rm -f $DST

state=red
for color in $(tail -n +4 $ppm); do
	color_5bit=$((color / color_unit))
	color_bin=$(extend_digit $(echo "obase=2;$color_5bit" | bc) 5)
	case $state in
	red)
		red_bin=$color_bin
		state=green
		;;
	green)
		green_bin=$color_bin
		state=blue
		;;
	blue)
		blue_bin=$color_bin
		rgb_bin="1${blue_bin}${green_bin}${red_bin}"
		rgb_hex=$(echo "obase=16;ibase=2;$rgb_bin" | bc)
		echo -en "\x$(echo $rgb_hex | cut -c1-2)\x$(echo $rgb_hex | cut -c3-4)" >>$DST
		state=red
		;;
	esac
done
