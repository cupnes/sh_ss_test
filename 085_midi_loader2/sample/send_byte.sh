#!/bin/bash

# set -uex
set -ue

midi_dev=/dev/snd/midiC1D0

end_flag=0
if [ "$1" == "-e" ]; then
	end_flag=1
	shift
fi

byte_hex_str=$1

data_bn=$(printf "%08d" $(echo "obase=2;ibase=16;$(echo $byte_hex_str | tr [:lower:] [:upper:])" | bc))
data_1_0=$(echo $data_bn | cut -c7-8)
data_7_2=$(echo $data_bn | cut -c1-6)
data_packet_byte_1='90'
data_packet_byte_2=$(echo "obase=16;ibase=2;011${end_flag}11${data_1_0}" | bc)
data_packet_byte_3=$(echo "obase=16;ibase=2;01${data_7_2}" | bc)
# echo "${data_packet_byte_1} ${data_packet_byte_2} ${data_packet_byte_3}"

n_times=2
for i in $(seq $n_times); do
	# echo "# i=$i"
	echo -en "\x${data_packet_byte_1}\x${data_packet_byte_2}\x${data_packet_byte_3}" >$midi_dev
	# echo 'sent'
	sleep 0.5
done
