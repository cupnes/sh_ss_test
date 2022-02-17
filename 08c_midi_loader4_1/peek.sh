#!/bin/bash

# 一発 apps/test_mcipd_mo_bit.sh を実行してからでないとうまく動かない
# 具体的には、MCIPDのMOが1にならず、それを待ち続けてしまう
# 一度何かMIDI送信しないとMOビットが機能しないのかもしれない

# set -uex
set -ue

MIDI_DEV=/dev/snd/midiC1D0

access_width=$1
addr=$2

temp_out=$(mktemp)
cat $MIDI_DEV >$temp_out &
temp_out_pid=$!
cleanup() {
	kill $temp_out_pid
	rm $temp_out
}
trap "cleanup" EXIT INT ERR

apps/peek_${access_width}.sh $addr >apps/peek_${access_width}.exe
../tools/dump_data_packets apps/peek_${access_width}.{exe,pkt}
dd if=apps/peek_${access_width}.pkt of=$MIDI_DEV status=none

case "$access_width" in
"byte")
	packet_sz=3
	;;
"word")
	packet_sz=5
	;;
"long")
	packet_sz=7
	;;
esac

while :; do
	recv_sz=$(stat -c '%s' $temp_out)
	if [ $recv_sz -ge $packet_sz ]; then
		break
	fi
	# echo "waiting to receive the data packet (${recv_sz}/${packet_sz} byte was received)."
	# sleep 1
done

case "$access_width" in
"byte")
	supp_byte_hex=$(dd if=$temp_out ibs=1 skip=1 bs=1 count=1 status=none | od -A n -t x1 -v | tr -d ' ' | tr [:lower:] [:upper:])
	data_byte_hex=$(dd if=$temp_out ibs=1 skip=2 bs=1 count=1 status=none | od -A n -t x1 -v | tr -d ' ' | tr [:lower:] [:upper:])
	echo "obase=16;ibase=16;($supp_byte_hex * 2) + $data_byte_hex + 100" | bc | cut -c2-3
	;;
"word")
	data_byte_list_hex=$(od -A n -t x1 -v $temp_out | tr ' ' '\n' | tr [:lower:] [:upper:] | grep -vE '^$|^9.$')
	supp_byte_hex=$(printf "%s\n" $data_byte_list_hex | sed -n '1p')
	supp_byte_bin=$(printf "%08d" $(echo "obase=2;ibase=16;$supp_byte_hex" | bc))
	for i in 2 3; do
		data_byte_hex=$(printf "%s\n" $data_byte_list_hex | sed -n "${i}p")
		data_byte_bin_nomsb=$(printf "%07d" $(echo "obase=2;ibase=16;$data_byte_hex" | bc))
		data_msb=$(echo "$supp_byte_bin" | cut -c${i})
		data_hex=$(echo "obase=16;ibase=2;${data_msb}${data_byte_bin_nomsb}" | bc)
		data_hex_2=$(echo "obase=16;ibase=16;$data_hex + 100" | bc | cut -c2-3)
		echo -n $data_hex_2
	done
	echo
	;;
"long")
	data_byte_list_hex=$(od -A n -t x1 -v $temp_out | tr ' ' '\n' | tr [:lower:] [:upper:] | grep -vE '^$|^9.$')
	supp_byte_hex=$(printf "%s\n" $data_byte_list_hex | sed -n '1p')
	supp_byte_bin=$(printf "%08d" $(echo "obase=2;ibase=16;$supp_byte_hex" | bc))
	for i in 2 3 4 5; do
		data_byte_hex=$(printf "%s\n" $data_byte_list_hex | sed -n "${i}p")
		data_byte_bin_nomsb=$(printf "%07d" $(echo "obase=2;ibase=16;$data_byte_hex" | bc))
		data_msb=$(echo "$supp_byte_bin" | cut -c${i})
		data_hex=$(echo "obase=16;ibase=2;${data_msb}${data_byte_bin_nomsb}" | bc)
		data_hex_2=$(echo "obase=16;ibase=16;$data_hex + 100" | bc | cut -c2-3)
		echo -n $data_hex_2
	done
	echo
	;;
esac
