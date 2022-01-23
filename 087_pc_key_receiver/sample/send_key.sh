#!/bin/bash

# set -uex
set -ue

while read -n 1 c; do
	ascii_code=$(printf "%02x" \"$c)
	if [ "$ascii_code" = "00" ]; then
		# echo -en '0a '
		./send_byte.sh 0a
	else
		# echo -en "${ascii_code} "
		./send_byte.sh $ascii_code
	fi
	echo -en "[$c]"
done
