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
	## (押下時1)
	### → ← ↓ ↑ Start A C B
	var_pad_current_state_1=$VARS_BASE
	echo -e "var_pad_current_state_1=$var_pad_current_state_1" >>$map_file
	echo -en '\x00'
	### R X Y Z L (bit2-0: 予約)
	var_pad_current_state_2=$(calc16_8 "$var_pad_current_state_1+1")
	echo -e "var_pad_current_state_2=$var_pad_current_state_2" >>$map_file
	echo -en '\x00'
	## 2バイト境界

	# ボタン押下カウンタ
	var_button_pressed_counter=$(calc16_8 "$var_pad_current_state_2+1")
	echo -e "var_button_pressed_counter=$var_button_pressed_counter" >>$map_file
	echo -en '\x00\x00'
	# 4バイト境界

	# VDP1 RAMのキャラクタパターンテーブル(CPT)で
	# 次にキャラクタパターンを配置するアドレス
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

	# synth: 各スロットの状態管理
	## - ノート番号(1バイト)
	##   ※ KEY_OFF時は0x00
	## を32スロット分用意(計32バイト)
	var_synth_slot_state_base=$(calc16_8 "$var_con_cur_y+2")
	echo -e "var_synth_slot_state_base=$var_synth_slot_state_base" >>$map_file
	dd if=/dev/zero bs=1 count=32 status=none

	# cd: f_load_img_from_cd_and_view()の一時的な画像配置領域
	## (143360(0x23000)バイト)
	var_tmp_img_area=$(calc16_8 "$var_synth_slot_state_base+128")
	echo -e "var_tmp_img_area=$var_tmp_img_area" >>$map_file
	dd if=/dev/zero bs=1 count=143360 status=none
	## 4バイト境界
}

vars
