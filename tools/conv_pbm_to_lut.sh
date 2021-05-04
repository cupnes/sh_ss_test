#!/bin/bash
# Conv PBM to LookUpTexture

# set -uex
set -ue

SRC=$1

wh=$(grep -v '^#' $SRC | sed -n 2p)
w=$(echo $wh | cut -d' ' -f1)
h=$(echo $wh | cut -d' ' -f2)
num_pix=$((w * h))

dat=$(grep -v '^#' $SRC | sed -n '3,$p' | tr -cd 01)

out=''
for i in $(seq 0 $((num_pix - 1))); do
	if [ $((i % 2)) -eq 0 ]; then
		byte=${dat:i:1}
	else
		byte="${byte}${dat:i:1}"
		out="${out}\x${byte}"
	fi
done
echo -en $out
