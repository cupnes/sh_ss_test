#!/bin/bash

# set -uex
set -ue

target_file=$1

checksum=0
for b in $(od -A n -t x1 -w1 $target_file | tr -d ' ' | head -n -1); do
	echo -en "${b} "
	./send_byte.sh $b
	b_up=$(echo $b | tr [:lower:] [:upper:])
	checksum=$(echo "obase=16;ibase=16;${checksum}+${b_up}" | bc)
done
b=$(od -A n -t x1 -w1 $target_file | tr -d ' ' | tail -n 1)
echo ${b}
./send_byte.sh -e $b
b_up=$(echo $b | tr [:lower:] [:upper:])
checksum=$(echo "obase=16;ibase=16;${checksum}+${b_up}" | bc)
echo "checksum=$checksum"
