#!/bin/bash

# set -uex
set -ue

midi_dev=/dev/snd/midiC1D0

if [ "$1" == "-e" ]; then
	# send end flag
	echo -en '\x90\x7c\x40' >$midi_dev
	exit
fi

byte_hex_str=$1

ACK_PACKET='fa'
RECV_TIMEOUT=200	# times

temp_out=$(mktemp)
echo $temp_out
cat $midi_dev >$temp_out &
temp_out_pid=$!
echo $temp_out_pid
cleanup() {
	kill $temp_out_pid
	rm $temp_out
}
trap "cleanup" EXIT INT ERR

data_bn=$(printf "%08d" $(echo "obase=2;ibase=16;$(echo $byte_hex_str | tr [:lower:] [:upper:])" | bc))
data_1_0=$(echo $data_bn | cut -c7-8)
data_7_2=$(echo $data_bn | cut -c1-6)
data_packet_byte_1='90'
data_packet_byte_2=$(echo "obase=16;ibase=2;011011${data_1_0}" | bc)
data_packet_byte_3=$(echo "obase=16;ibase=2;01${data_7_2}" | bc)
echo "${data_packet_byte_1} ${data_packet_byte_2} ${data_packet_byte_3}"

n_times=1
while :; do
	echo "# n_times=$n_times"

	echo -en "\x${data_packet_byte_1}\x${data_packet_byte_2}\x${data_packet_byte_3}" >$midi_dev
	echo 'sent'

	repeat=0
	while [ $(stat -c '%s' $temp_out) -lt $n_times ]; do
		if [ $repeat -ge $RECV_TIMEOUT ]; then
			break
		fi
		repeat=$((repeat + 1))
	done
	if [ $repeat -ge $RECV_TIMEOUT ]; then
		echo "recv timeout (repeat = $repeat)"
		continue
	fi
	ls -l $temp_out
	recv_byte=$(od -A n -j $((n_times - 1)) -t x1 $temp_out | tr -d ' ')
	echo "recv_byte = [$recv_byte]"
	if [ "$recv_byte" == "$ACK_PACKET" ]; then
		break
	fi

	n_times=$((n_times + 1))
done
