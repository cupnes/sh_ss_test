#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/memmap.sh
. include/vdp1.sh
. include/con.sh

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
	# var_next_cp_addr=$(calc16_8 "$var_button_pressed_counter+2")
	# echo -e "var_next_cp_addr=$var_next_cp_addr" >>$map_file
	# echo -en "\x$(echo $VRAM_CPT_BASE | cut -c1-2)"
	# echo -en "\x$(echo $VRAM_CPT_BASE | cut -c3-4)"
	# echo -en "\x$(echo $VRAM_CPT_BASE | cut -c5-6)"
	# echo -en "\x$(echo $VRAM_CPT_BASE | cut -c7-8)"
	# コンソール用
	var_next_cp_con_addr=$(calc16_8 "$var_button_pressed_counter+2")
	echo -e "var_next_cp_con_addr=$var_next_cp_con_addr" >>$map_file
	echo -en "\x$(echo $VRAM_CPT_CON_BASE | cut -c1-2)"
	echo -en "\x$(echo $VRAM_CPT_CON_BASE | cut -c3-4)"
	echo -en "\x$(echo $VRAM_CPT_CON_BASE | cut -c5-6)"
	echo -en "\x$(echo $VRAM_CPT_CON_BASE | cut -c7-8)"
	# 4バイト境界
	# その他
	var_next_cp_other_addr=$(calc16_8 "$var_next_cp_con_addr+4")
	echo -e "var_next_cp_other_addr=$var_next_cp_other_addr" >>$map_file
	echo -en "\x$(echo $VRAM_CPT_OTHER_BASE | cut -c1-2)"
	echo -en "\x$(echo $VRAM_CPT_OTHER_BASE | cut -c3-4)"
	echo -en "\x$(echo $VRAM_CPT_OTHER_BASE | cut -c5-6)"
	echo -en "\x$(echo $VRAM_CPT_OTHER_BASE | cut -c7-8)"
	# 4バイト境界

	# VDP1 RAMのコマンドテーブルで次にコマンドを配置するアドレス
	# var_next_vdpcom_addr=$(calc16_8 "$var_next_cp_addr+4")
	# echo -e "var_next_vdpcom_addr=$var_next_vdpcom_addr" >>$map_file
	# echo -en "\x$(echo $VRAM_CT_CON_BASE | cut -c1-2)"
	# echo -en "\x$(echo $VRAM_CT_CON_BASE | cut -c3-4)"
	# echo -en "\x$(echo $VRAM_CT_CON_BASE | cut -c5-6)"
	# echo -en "\x$(echo $VRAM_CT_CON_BASE | cut -c7-8)"
	# コンソール用
	var_next_vdpcom_con_addr=$(calc16_8 "$var_next_cp_other_addr+4")
	echo -e "var_next_vdpcom_con_addr=$var_next_vdpcom_con_addr" >>$map_file
	echo -en "\x$(echo $VRAM_CT_CON_BASE | cut -c1-2)"
	echo -en "\x$(echo $VRAM_CT_CON_BASE | cut -c3-4)"
	echo -en "\x$(echo $VRAM_CT_CON_BASE | cut -c5-6)"
	echo -en "\x$(echo $VRAM_CT_CON_BASE | cut -c7-8)"
	# 4バイト境界
	# その他
	var_next_vdpcom_other_addr=$(calc16_8 "$var_next_vdpcom_con_addr+4")
	echo -e "var_next_vdpcom_other_addr=$var_next_vdpcom_other_addr" >>$map_file
	echo -en "\x$(echo $VRAM_CT_OTHER_BASE | cut -c1-2)"
	echo -en "\x$(echo $VRAM_CT_OTHER_BASE | cut -c3-4)"
	echo -en "\x$(echo $VRAM_CT_OTHER_BASE | cut -c5-6)"
	echo -en "\x$(echo $VRAM_CT_OTHER_BASE | cut -c7-8)"
	# 4バイト境界

	# フォントデータ
	## カラールックアップテーブルを参照するフォントデータ
	## (128バイト * 95文字 = 12160(0x2F80)バイト)
	var_font_dat=$(calc16_8 "$var_next_vdpcom_other_addr+4")
	echo -e "var_font_dat=$var_font_dat" >>$map_file
	cat font.lut
	# 4バイト境界

	# con: 現在のカーソル座標
	var_con_cur_x=$(calc16_8 "$var_font_dat+2F80")
	echo -e "var_con_cur_x=$var_con_cur_x" >>$map_file
	echo -en "\x00\x$CON_AREA_X"
	## 2バイト境界
	var_con_cur_y=$(calc16_8 "$var_con_cur_x+2")
	echo -e "var_con_cur_y=$var_con_cur_y" >>$map_file
	echo -en "\x00\x$CON_AREA_Y"
	## 4バイト境界
}

vars
