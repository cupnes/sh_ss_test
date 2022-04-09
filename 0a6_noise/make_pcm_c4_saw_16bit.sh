#!/bin/bash

#                envelope
#  32767(0x7FFF) ^-----------
#                |         /|
#                |        / |
#                |       /  |
#                |      /   |
#                |     /    |
#                |    /     |
#                |   /      |
#                |  /       |
#                | /        |
#      1(0x0001) |/         |84        168
#      0(0x0000) +----------+----------+---> sample num
#     -1(0xFFFF) |          |         /
#                |          |        /
#                |          |       /
#                |          |      /
#                |          |     /
#                |          |    /
#                |          |   /
#                |          |  /
#                |          | /
#                |          |/
# -32768(0x8000) +-----------

# set -uex
set -ue

ENV_MAX=32767
ENV_MIN=-32768
NUM_SAMPLES=168

half_samples=$((NUM_SAMPLES / 2))
slope=$(echo "scale=2;$ENV_MAX / $half_samples" | bc)

echo_hex16() {
	local src_val=$1

	# マイナスフラグ設定・絶対値を取る
	local is_minus='false'
	local v=$src_val
	if [ "$(echo $src_val | cut -c1)" = '-' ]; then
		v=$(echo "-1 * $v" | bc)
		if [ "$v" != '0' ]; then
			is_minus='true'
		fi
	fi

	# 四捨五入
	v=$(echo "$v + 0.5" | bc | cut -d'.' -f1)
	if [ "$v" = '' ]; then
		v=0
	fi

	# 16進変換し出力
	if [ "$is_minus" = 'false' ]; then
		echo "obase=16;65536 + $v" | bc | cut -c2-5
	else
		echo "obase=16;65536 - $v" | bc
	fi
}

for initial_val in 0 $ENV_MIN; do
	val=$initial_val
	for i in $(seq $half_samples); do
		echo_hex16 $val
		val=$(echo "$val + $slope" | bc)
	done
done
