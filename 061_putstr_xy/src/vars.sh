#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/memmap.sh
. include/vdp1.sh

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
	## 2バイト境界

	# ボタン押下カウンタ
	var_button_pressed_counter=$(calc16_8 "$var_pad_current_state_2+1")
	echo -e "var_button_pressed_counter=$var_button_pressed_counter" >>$map_file
	echo -en '\x00\x00'
	# 4バイト境界

	# VDP1 RAMのキャラクタパターンテーブル(CPT)で
	# 次にキャラクタパターンを配置するアドレス
	var_next_cp_addr=$(calc16_8 "$var_button_pressed_counter+2")
	echo -e "var_next_cp_addr=$var_next_cp_addr" >>$map_file
	echo -en '\x05\xc0\x0c\x80'
	# 4バイト境界

	# VDP1 RAMのコマンドテーブルで次にコマンドを配置するアドレス
	var_next_vdpcom_addr=$(calc16_8 "$var_next_cp_addr+4")
	echo -e "var_next_vdpcom_addr=$var_next_vdpcom_addr" >>$map_file
	echo -en "\x$(echo $VRAM_DRAW_CMD_BASE | cut -c1-2)"
	echo -en "\x$(echo $VRAM_DRAW_CMD_BASE | cut -c3-4)"
	echo -en "\x$(echo $VRAM_DRAW_CMD_BASE | cut -c5-6)"
	echo -en "\x$(echo $VRAM_DRAW_CMD_BASE | cut -c7-8)"
	# 4バイト境界

	# フォントデータ
	## カラールックアップテーブルを参照するフォントデータ
	## (128バイト * 95文字 = 12160(0x2F80)バイト)
	var_font_dat=$(calc16_8 "$var_next_vdpcom_addr+4")
	echo -e "var_font_dat=$var_font_dat" >>$map_file
	cat font.lut
	# 4バイト境界

	# 出力する文字列
	var_output_str=$(calc16_8 "$var_font_dat+2F80")
	echo -e "var_output_str=$var_output_str" >>$map_file
	echo -en '0123456789\x00'
}

vars
