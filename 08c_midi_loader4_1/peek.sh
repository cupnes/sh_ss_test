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
	echo "TBD"
	;;
"long")
	echo "TBD"
	;;
esac
