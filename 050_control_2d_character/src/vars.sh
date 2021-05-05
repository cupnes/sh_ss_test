#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/memmap.sh

vars() {
	map_file=src/vars_map.sh
	rm -f $map_file

	# ゲームパッド入力状態
	## 現在の押下状態
	## (押下時0)
	### → ← ↓ ↑ Start A C B
	var_pad_current_state_1=$VARS_BASE
	echo -e "var_pad_current_state_1=$var_pad_current_state_1" >>$map_file
	echo -en '\xff'
	### R X Y Z L (bit2-0: 予約)
	var_pad_current_state_2=$(calc16_8 "$var_pad_current_state_1+1")
	echo -e "var_pad_current_state_2=$var_pad_current_state_2" >>$map_file
	echo -en '\xff'
	## パディング
	echo -en '\x00\x00'
	# 4の倍数バウンダリ

	# 饅頭データ
	## フィールドX座標(マス番目)
	var_manju_x=$(calc16_8 "$var_pad_current_state_2+3")
	echo -e "var_manju_x=$var_manju_x" >>$map_file
	echo -en '\x00\x00\x00\x09'
	# 4バイトバウンダリ
	## フィールドY座標(マス番目)
	var_manju_y=$(calc16_8 "$var_manju_x+4")
	echo -e "var_manju_y=$var_manju_y" >>$map_file
	echo -en '\x00\x00\x00\x06'
	# 4バイトバウンダリ

	# キャラクタパターンテーブルデータ
	var_char_pat_tbl_dat=$(calc16_8 "$var_manju_y+4")
	echo -e "var_char_pat_tbl_dat=$var_char_pat_tbl_dat" >>$map_file
	cat character.lut
	## カラールックアップテーブルを参照する4bits/pixelデータ(128バイト)
	# 4バイトバウンダリ
}

vars
