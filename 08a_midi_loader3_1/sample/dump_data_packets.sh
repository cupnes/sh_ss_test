#!/bin/bash

# set -uex
set -ue

target_file=$1
data_packet_file=$2

dump_data_byte() {
	byte_hex_str=$1
	data_bn=$(printf "%08d" $(echo "obase=2;ibase=16;$(echo $byte_hex_str | tr [:lower:] [:upper:])" | bc))
	data_1_0=$(echo $data_bn | cut -c7-8)
	data_7_2=$(echo $data_bn | cut -c1-6)
	data_packet_byte_1='90'
	data_packet_byte_2=$(echo "obase=16;ibase=2;011${end_flag}11${data_1_0}" | bc)
	data_packet_byte_3=$(echo "obase=16;ibase=2;01${data_7_2}" | bc)
	echo -en "\x${data_packet_byte_2}\x${data_packet_byte_3}"
}

echo -en '\x90' >${data_packet_file}

end_flag=0
checksum=0
for b in $(od -A n -t x1 -v -w1 $target_file | tr -d ' ' | head -n -1); do
	# echo -en "${b} "
	dump_data_byte $b >>${data_packet_file}
	b_up=$(echo $b | tr [:lower:] [:upper:])
	checksum=$(echo "obase=16;ibase=16;${checksum}+${b_up}" | bc)
done
end_flag=1
b=$(od -A n -t x1 -v -w1 $target_file | tr -d ' ' | tail -n 1)
# echo ${b}
dump_data_byte $b >>${data_packet_file}
b_up=$(echo $b | tr [:lower:] [:upper:])
checksum=$(echo "obase=16;ibase=16;${checksum}+${b_up}" | bc)
echo "checksum=$checksum"
