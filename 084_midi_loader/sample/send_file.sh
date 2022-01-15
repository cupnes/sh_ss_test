#!/bin/bash

# set -uex
set -ue

target_file=$1

for b in $(od -A n -t x1 -w1 $target_file | tr -d ' '); do
	./send_byte.sh $b
done
