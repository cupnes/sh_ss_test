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
	## 2の倍数バウンダリ

	# ボタン押下カウンタ
	var_button_pressed_counter=$(calc16_8 "$var_pad_current_state_2+1")
	echo -e "var_button_pressed_counter=$var_button_pressed_counter" >>$map_file
	echo -en '\x00\x00'
	# 4の倍数バウンダリ

	# キャラクタデータ
	## フィールドX座標(マス番目)
	var_character_x=$(calc16_8 "$var_button_pressed_counter+2")
	echo -e "var_character_x=$var_character_x" >>$map_file
	echo -en '\x00\x00\x00\x09'
	# 4バイトバウンダリ
	## フィールドY座標(マス番目)
	var_character_y=$(calc16_8 "$var_character_x+4")
	echo -e "var_character_y=$var_character_y" >>$map_file
	echo -en '\x00\x00\x00\x06'
	# 4バイトバウンダリ

	# キャラクタパターンテーブルデータ
	var_char_pat_tbl_dat=$(calc16_8 "$var_character_y+4")
	echo -e "var_char_pat_tbl_dat=$var_char_pat_tbl_dat" >>$map_file
	cat character.lut
	## カラールックアップテーブルを参照する4bits/pixelデータ(128バイト)
	# 4バイトバウンダリ
}

vars
