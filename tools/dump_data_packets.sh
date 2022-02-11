#!/bin/bash

# set -uex
set -ue

BULK_UNIT=7

target_file=$1
data_packet_file=$2

trap "rm -f ${data_packet_file}.x*" EXIT INT ERR

split -b $BULK_UNIT $target_file ${data_packet_file}.x

last_one=$(ls ${data_packet_file}.x* | tac | head -n 1)
last_one_sz=$(stat -c '%s' $last_one)
if [ $last_one_sz -lt $BULK_UNIT ]; then
	bulk_list=$(ls ${data_packet_file}.x* | grep -vx $last_one || true)
	remain_one=$last_one
else
	bulk_list=$(ls ${data_packet_file}.x*)
	remain_one=''
fi

rm -f $data_packet_file
checksum='0'

if [ -n "$bulk_list" ]; then
	echo -en '\x90' >$data_packet_file
	for f in $bulk_list; do
		supp_byte_bin='0'
		data_byte_list_hex=''
		for byte_hex in $(od -A n -t x1 -v -w1 $f | tr [:lower:] [:upper:]); do
			byte_bin=$(printf '%08d' $(echo "obase=2;ibase=16;$byte_hex" | bc))
			byte_bin_7=$(echo $byte_bin | cut -c1)
			byte_bin_6_0=$(echo $byte_bin | cut -c2-8)
			supp_byte_bin="${supp_byte_bin}${byte_bin_7}"
			data_byte_bin="0${byte_bin_6_0}"
			data_byte_hex="\x$(echo "obase=16;ibase=2;$data_byte_bin" | bc)"
			data_byte_list_hex="${data_byte_list_hex}${data_byte_hex}"
			checksum=$(echo "obase=16;ibase=16;${checksum}+${byte_hex}" | bc)
		done
		supp_byte_hex="\x$(echo "obase=16;ibase=2;$supp_byte_bin" | bc)"
		echo -en "${supp_byte_hex}${data_byte_list_hex}" >>$data_packet_file
	done
fi

if [ -n "${remain_one}" ]; then
	echo -en "\x9${last_one_sz}" >>$data_packet_file
	supp_byte_bin='0'
	data_byte_list_hex=''
	for byte_hex in $(od -A n -t x1 -v -w1 $remain_one | tr [:lower:] [:upper:]); do
		byte_bin=$(printf '%08d' $(echo "obase=2;ibase=16;$byte_hex" | bc))
		byte_bin_7=$(echo $byte_bin | cut -c1)
		byte_bin_6_0=$(echo $byte_bin | cut -c2-8)
		supp_byte_bin="${supp_byte_bin}${byte_bin_7}"
		data_byte_bin="0${byte_bin_6_0}"
		data_byte_hex="\x$(echo "obase=16;ibase=2;$data_byte_bin" | bc)"
		data_byte_list_hex="${data_byte_list_hex}${data_byte_hex}"
		checksum=$(echo "obase=16;ibase=16;${checksum}+${byte_hex}" | bc)
	done
	num_pad_bits=$((BULK_UNIT - last_one_sz))
	for _i in $(seq $num_pad_bits); do
		supp_byte_bin="${supp_byte_bin}0"
	done
	if [ $((last_one_sz % 2)) -eq 0 ]; then
		data_byte_list_hex="${data_byte_list_hex}\x00"
	fi
	supp_byte_hex="\x$(echo "obase=16;ibase=2;$supp_byte_bin" | bc)"
	echo -en "${supp_byte_hex}${data_byte_list_hex}" >>$data_packet_file
fi

echo $checksum >${data_packet_file}.sum
