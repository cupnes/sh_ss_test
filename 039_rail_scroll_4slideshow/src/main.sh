#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/vdp1.sh
. src/render.sh
. src/debug.sh

VRAM_DRAW_CMD_BASE=05C00060
INIT_SP=06004000
PROGRAM_ENTRY_ADDR=06004000
VARS_BASE=06004020
FUNCS_BASE=060FA000
MAIN_BASE=060FF000

# [debug]
TEXTURE1_IMG='texture1.img'
TEXTURE2_IMG='texture2.img'
TEXTURE3_IMG='texture3.img'
TEXTURE4_IMG='texture4.img'
## 適当にコマンド100(0x64)個分を確保しておく
VRAM_TEXTURE_OFS=$(calc16_4 "${SS_VDP1_COMMAND_SIZE}*64")	# 0x0c80
VRAM_TEXTURE_BASE=$(calc16_8 "${SS_VDP1_VRAM_ADDR}+${VRAM_TEXTURE_OFS}")
## 8で割った値を指定
## ※ 値変更の際は使用箇所を確認
##    (値に応じた最適化をしていたりする)
TEXTURE1_VRAM_OFS_TH=01	# 0x0c80 / 8 = 0x0190
TEXTURE1_VRAM_OFS_BH=90
TEXTURE2_VRAM_OFS=4790	# (0x0c80 + 0x23000(140KB)) / 8
TEXTURE3_VRAM_OFS=8D90	# (0x0c80 + 0x46000(140KB*2)) / 8
TEXTURE4_VRAM_OFS_TH=01	# 0x0c80 / 8 = 0x0190
TEXTURE4_VRAM_OFS_BH=90
## スライドのテクスチャのピクセル数
### (* 320 224)71680(0x11800)
TEXTURE_PIXEL_NUM_B23_16=01
TEXTURE_PIXEL_NUM_B15_8=18
TEXTURE_PIXEL_NUM_B7_0=00
## スライドの各スプライトのZ座標
## ※ カメラ座標系の中でスライドのスプライトを動かさない前提
## ※ 値変更の際は使用箇所を確認
##    (値に応じた最適化をしていたりする)
### スライド1: Z=100(0x00 64)
SPRITE1_Z_TH=00
SPRITE1_Z_BH=64
### スライド2: Z=130(0x00 82)
SPRITE2_Z_TH=00
SPRITE2_Z_BH=82
### スライド3: Z=160(0x00 a0)
SPRITE3_Z_TH=00
SPRITE3_Z_BH=a0
### スライド4: Z=190(0x00 be)
SPRITE4_Z_TH=00
SPRITE4_Z_BH=be

map_file=map.sh
rm -f $map_file

debug 'before: vars()'

vars() {
	local vsz

	# 三角関数計算のための係数テーブル
	## N * sinθ を (N * 係数) / 1000 で計算する係数のテーブル
	var_sin_coeff_table=$VARS_BASE
	echo -e "var_sin_coeff_table=$var_sin_coeff_table" >>$map_file
	cat sin_coeff_table.dat	# 1440 bytes
	## N * cosθ を (N * 係数) / 1000 で計算する係数のテーブル
	vsz=$(to16 $(stat -c '%s' sin_coeff_table.dat))
	var_cos_coeff_table=$(calc16_8 "${var_sin_coeff_table}+${vsz}")
	echo -e "var_cos_coeff_table=$var_cos_coeff_table" >>$map_file
	cat cos_coeff_table.dat	# 1440 bytes

	# 4の倍数バウンダリ

	# ゲームパッド入力状態
	## 現在の押下状態
	## (押下時0)
	### → ← ↓ ↑ Start A C B
	vsz=$(to16 $(stat -c '%s' cos_coeff_table.dat))
	var_pad_current_state_1=$(calc16_8 "${var_cos_coeff_table}+${vsz}")
	echo -e "var_pad_current_state_1=$var_pad_current_state_1" >>$map_file
	echo -en '\xff'
	### R X Y Z L (bit2-0: 予約)
	var_pad_current_state_2=$(calc16_8 "$var_pad_current_state_1+1")
	echo -e "var_pad_current_state_2=$var_pad_current_state_2" >>$map_file
	echo -en '\xff'

	# 投影面Z座標
	var_proj_z=$(calc16_8 "$var_pad_current_state_2+1")
	echo -e "var_proj_z=$var_proj_z" >>$map_file
	echo -en '\x00\x64'	# 100

	# 4の倍数バウンダリ

	# 現在のカメラ座標系のY軸旋回角度
	var_rotation_angle_y=$(calc16_8 "$var_proj_z+2")
	echo -e "var_rotation_angle_y=$var_rotation_angle_y" >>$map_file
	echo -en '\x00\x00'	# 0

	# 六面体の8頂点の3次元座標
	## 頂点座標が並ぶ領域のベースアドレス
	var_hexahedron_base=$(calc16_8 "$var_rotation_angle_y+2")
	echo -e "var_hexahedron_base=$var_hexahedron_base" >>$map_file
	## 頂点A(正面左上)
	### X (base+0x00)
	var_hexahedron_ax=$var_hexahedron_base
	ofs_hexahedron_ax=00
	echo -e "var_hexahedron_ax=$var_hexahedron_ax" >>$map_file
	echo -en '\xFF\xDB'	# -37
	# 4の倍数バウンダリ
	### Y (base+0x02)
	var_hexahedron_ay=$(calc16_8 "$var_hexahedron_ax+2")
	ofs_hexahedron_ay=02
	echo -e "var_hexahedron_ay=$var_hexahedron_ay" >>$map_file
	echo -en '\x00\x86'	# 134
	### Z (base+0x04)
	var_hexahedron_az=$(calc16_8 "$var_hexahedron_ay+2")
	ofs_hexahedron_az=04
	echo -e "var_hexahedron_az=$var_hexahedron_az" >>$map_file
	echo -en '\x00\xc8'	# 200
	# 4の倍数バウンダリ
	## 頂点B(正面右上)
	### X (base+0x06)
	var_hexahedron_bx=$(calc16_8 "$var_hexahedron_az+2")
	ofs_hexahedron_bx=06
	echo -e "var_hexahedron_bx=$var_hexahedron_bx" >>$map_file
	echo -en '\x00\x25'	# 37
	### Y (base+0x08)
	var_hexahedron_by=$(calc16_8 "$var_hexahedron_bx+2")
	ofs_hexahedron_by=08
	echo -e "var_hexahedron_by=$var_hexahedron_by" >>$map_file
	echo -en '\x00\x86'	# 134
	# 4の倍数バウンダリ
	### Z (base+0x0a)
	var_hexahedron_bz=$(calc16_8 "$var_hexahedron_by+2")
	ofs_hexahedron_bz=0a
	echo -e "var_hexahedron_bz=$var_hexahedron_bz" >>$map_file
	echo -en '\x00\xc8'	# 200
	## 頂点C(正面右下)
	### X (base+0x0c)
	var_hexahedron_cx=$(calc16_8 "$var_hexahedron_bz+2")
	ofs_hexahedron_cx=0c
	echo -e "var_hexahedron_cx=$var_hexahedron_cx" >>$map_file
	echo -en '\x00\x25'	# 37
	# 4の倍数バウンダリ
	### Y (base+0x0e)
	var_hexahedron_cy=$(calc16_8 "$var_hexahedron_cx+2")
	ofs_hexahedron_cy=0e
	echo -e "var_hexahedron_cy=$var_hexahedron_cy" >>$map_file
	echo -en '\x00\x00'	# 0
	### Z (base+0x10)
	var_hexahedron_cz=$(calc16_8 "$var_hexahedron_cy+2")
	ofs_hexahedron_cz=10
	echo -e "var_hexahedron_cz=$var_hexahedron_cz" >>$map_file
	echo -en '\x00\xc8'	# 200
	# 4の倍数バウンダリ
	## 頂点D(正面左下)
	### X (base+0x12)
	var_hexahedron_dx=$(calc16_8 "$var_hexahedron_cz+2")
	ofs_hexahedron_dx=12
	echo -e "var_hexahedron_dx=$var_hexahedron_dx" >>$map_file
	echo -en '\xFF\xDB'	# -37
	### Y (base+0x14)
	var_hexahedron_dy=$(calc16_8 "$var_hexahedron_dx+2")
	ofs_hexahedron_dy=14
	echo -e "var_hexahedron_dy=$var_hexahedron_dy" >>$map_file
	echo -en '\x00\x00'	# 0
	# 4の倍数バウンダリ
	### Z (base+0x16)
	var_hexahedron_dz=$(calc16_8 "$var_hexahedron_dy+2")
	ofs_hexahedron_dz=16
	echo -e "var_hexahedron_dz=$var_hexahedron_dz" >>$map_file
	echo -en '\x00\xc8'	# 200
	## 頂点E(背面左上)
	### X (base+0x18)
	var_hexahedron_ex=$(calc16_8 "$var_hexahedron_dz+2")
	ofs_hexahedron_ex=18
	echo -e "var_hexahedron_ex=$var_hexahedron_ex" >>$map_file
	echo -en '\xFF\xDB'	# -37
	# 4の倍数バウンダリ
	### Y (base+0x1a)
	var_hexahedron_ey=$(calc16_8 "$var_hexahedron_ex+2")
	ofs_hexahedron_ey=1a
	echo -e "var_hexahedron_ey=$var_hexahedron_ey" >>$map_file
	echo -en '\x00\x86'	# 134
	### Z (base+0x1c)
	var_hexahedron_ez=$(calc16_8 "$var_hexahedron_ey+2")
	ofs_hexahedron_ez=1c
	echo -e "var_hexahedron_ez=$var_hexahedron_ez" >>$map_file
	echo -en '\x00\xdb'	# 219
	# 4の倍数バウンダリ
	## 頂点F(背面右上)
	### X (base+0x1e)
	var_hexahedron_fx=$(calc16_8 "$var_hexahedron_ez+2")
	ofs_hexahedron_fx=1e
	echo -e "var_hexahedron_fx=$var_hexahedron_fx" >>$map_file
	echo -en '\x00\x25'	# 37
	### Y (base+0x20)
	var_hexahedron_fy=$(calc16_8 "$var_hexahedron_fx+2")
	ofs_hexahedron_fy=20
	echo -e "var_hexahedron_fy=$var_hexahedron_fy" >>$map_file
	echo -en '\x00\x86'	# 134
	# 4の倍数バウンダリ
	### Z (base+0x22)
	var_hexahedron_fz=$(calc16_8 "$var_hexahedron_fy+2")
	ofs_hexahedron_fz=22
	echo -e "var_hexahedron_fz=$var_hexahedron_fz" >>$map_file
	echo -en '\x00\xdb'	# 219
	## 頂点G(背面右下)
	### X (base+0x24)
	var_hexahedron_gx=$(calc16_8 "$var_hexahedron_fz+2")
	ofs_hexahedron_gx=24
	echo -e "var_hexahedron_gx=$var_hexahedron_gx" >>$map_file
	echo -en '\x00\x25'	# 37
	# 4の倍数バウンダリ
	### Y (base+0x26)
	var_hexahedron_gy=$(calc16_8 "$var_hexahedron_gx+2")
	ofs_hexahedron_gy=26
	echo -e "var_hexahedron_gy=$var_hexahedron_gy" >>$map_file
	echo -en '\x00\x00'	# 0
	### Z (base+0x28)
	var_hexahedron_gz=$(calc16_8 "$var_hexahedron_gy+2")
	ofs_hexahedron_gz=28
	echo -e "var_hexahedron_gz=$var_hexahedron_gz" >>$map_file
	echo -en '\x00\xdb'	# 219
	# 4の倍数バウンダリ
	## 頂点H(背面左下)
	### X (base+0x2a)
	var_hexahedron_hx=$(calc16_8 "$var_hexahedron_gz+2")
	ofs_hexahedron_hx=2a
	echo -e "var_hexahedron_hx=$var_hexahedron_hx" >>$map_file
	echo -en '\xFF\xDB'	# -37
	### Y (base+0x2c)
	var_hexahedron_hy=$(calc16_8 "$var_hexahedron_hx+2")
	ofs_hexahedron_hy=2c
	echo -e "var_hexahedron_hy=$var_hexahedron_hy" >>$map_file
	echo -en '\x00\x00'	# 0
	# 4の倍数バウンダリ
	### Z (base+0x2e)
	var_hexahedron_hz=$(calc16_8 "$var_hexahedron_hy+2")
	ofs_hexahedron_hz=2e
	echo -e "var_hexahedron_hz=$var_hexahedron_hz" >>$map_file
	echo -en '\x00\xdb'	# 219

	# スプライト座標リスト
	# 各スプライトはカメラ座標系の4頂点で定義される板
	# TEXTURE1_IMG
	var_sprite_ax=$(calc16_8 "$var_hexahedron_hz+2")
	echo -e "var_sprite_ax=$var_sprite_ax" >>$map_file
	echo -en '\xff\x60'	# -160
	# 4の倍数バウンダリ
	var_sprite_ay=$(calc16_8 "$var_sprite_ax+2")
	echo -e "var_sprite_ay=$var_sprite_ay" >>$map_file
	echo -en '\x00\xdf'	# 223
	var_sprite_az=$(calc16_8 "$var_sprite_ay+2")
	echo -e "var_sprite_az=$var_sprite_az" >>$map_file
	echo -en '\x00\x64'	# 100
	# 4の倍数バウンダリ
	var_sprite_bx=$(calc16_8 "$var_sprite_az+2")
	echo -e "var_sprite_bx=$var_sprite_bx" >>$map_file
	echo -en '\x00\x9f'	# 159
	var_sprite_by=$(calc16_8 "$var_sprite_bx+2")
	echo -e "var_sprite_by=$var_sprite_by" >>$map_file
	echo -en '\x00\xdf'	# 223
	# 4の倍数バウンダリ
	var_sprite_bz=$(calc16_8 "$var_sprite_by+2")
	echo -e "var_sprite_bz=$var_sprite_bz" >>$map_file
	echo -en '\x00\x64'	# 100
	var_sprite_cx=$(calc16_8 "$var_sprite_bz+2")
	echo -e "var_sprite_cx=$var_sprite_cx" >>$map_file
	echo -en '\x00\x9f'	# 159
	# 4の倍数バウンダリ
	var_sprite_cy=$(calc16_8 "$var_sprite_cx+2")
	echo -e "var_sprite_cy=$var_sprite_cy" >>$map_file
	echo -en '\x00\x00'	# 0
	var_sprite_cz=$(calc16_8 "$var_sprite_cy+2")
	echo -e "var_sprite_cz=$var_sprite_cz" >>$map_file
	echo -en '\x00\x64'	# 100
	# 4の倍数バウンダリ
	var_sprite_dx=$(calc16_8 "$var_sprite_cz+2")
	echo -e "var_sprite_dx=$var_sprite_dx" >>$map_file
	echo -en '\xff\x60'	# -160
	var_sprite_dy=$(calc16_8 "$var_sprite_dx+2")
	echo -e "var_sprite_dy=$var_sprite_dy" >>$map_file
	echo -en '\x00\x00'	# 0
	# 4の倍数バウンダリ
	var_sprite_dz=$(calc16_8 "$var_sprite_dy+2")
	echo -e "var_sprite_dz=$var_sprite_dz" >>$map_file
	echo -en '\x00\x64'	# 100
	# テクスチャ画像のオフセットとサイズ
	# オフセットは8で割った値を指定
	local tex_ofs_div_8_th=$TEXTURE1_VRAM_OFS_TH
	local tex_ofs_div_8_bh=$TEXTURE1_VRAM_OFS_BH
	var_texture_ofs=$(calc16_8 "$var_sprite_dz+2")
	echo -e "var_texture_ofs=$var_texture_ofs" >>$map_file
	echo -en "\x${tex_ofs_div_8_th}\x${tex_ofs_div_8_bh}"
	# 4の倍数バウンダリ
	# サイズは、(b15-b14)=0b00、(b13-b08)=幅/8、(b07-b00)=高さ を指定
	var_texture_size=$(calc16_8 "$var_texture_ofs+2")
	echo -e "var_texture_size=$var_texture_size" >>$map_file
	echo -en '\x28\xe0'	# 幅:(/ 320 8)40(0x28), 高さ:224(0xe0)

	# TEXTURE2_IMG
	var_sprite2_ax=$(calc16_8 "$var_texture_size+2")
	echo -e "var_sprite2_ax=$var_sprite2_ax" >>$map_file
	echo -en '\xff\x60'	# -160
	# 4の倍数バウンダリ
	var_sprite2_ay=$(calc16_8 "$var_sprite2_ax+2")
	echo -e "var_sprite2_ay=$var_sprite2_ay" >>$map_file
	echo -en '\x00\xdf'	# 223
	var_sprite2_az=$(calc16_8 "$var_sprite2_ay+2")
	echo -e "var_sprite2_az=$var_sprite2_az" >>$map_file
	echo -en '\x00\x82'	# 130
	# 4の倍数バウンダリ
	var_sprite2_bx=$(calc16_8 "$var_sprite2_az+2")
	echo -e "var_sprite2_bx=$var_sprite2_bx" >>$map_file
	echo -en '\x00\x9f'	# 159
	var_sprite2_by=$(calc16_8 "$var_sprite2_bx+2")
	echo -e "var_sprite2_by=$var_sprite2_by" >>$map_file
	echo -en '\x00\xdf'	# 223
	# 4の倍数バウンダリ
	var_sprite2_bz=$(calc16_8 "$var_sprite2_by+2")
	echo -e "var_sprite2_bz=$var_sprite2_bz" >>$map_file
	echo -en '\x00\x82'	# 130
	var_sprite2_cx=$(calc16_8 "$var_sprite2_bz+2")
	echo -e "var_sprite2_cx=$var_sprite2_cx" >>$map_file
	echo -en '\x00\x9f'	# 159
	# 4の倍数バウンダリ
	var_sprite2_cy=$(calc16_8 "$var_sprite2_cx+2")
	echo -e "var_sprite2_cy=$var_sprite2_cy" >>$map_file
	echo -en '\x00\x00'	# 0
	var_sprite2_cz=$(calc16_8 "$var_sprite2_cy+2")
	echo -e "var_sprite2_cz=$var_sprite2_cz" >>$map_file
	echo -en '\x00\x82'	# 130
	# 4の倍数バウンダリ
	var_sprite2_dx=$(calc16_8 "$var_sprite2_cz+2")
	echo -e "var_sprite2_dx=$var_sprite2_dx" >>$map_file
	echo -en '\xff\x60'	# -160
	var_sprite2_dy=$(calc16_8 "$var_sprite2_dx+2")
	echo -e "var_sprite2_dy=$var_sprite2_dy" >>$map_file
	echo -en '\x00\x00'	# 0
	# 4の倍数バウンダリ
	var_sprite2_dz=$(calc16_8 "$var_sprite2_dy+2")
	echo -e "var_sprite2_dz=$var_sprite2_dz" >>$map_file
	echo -en '\x00\x82'	# 130
	# テクスチャ画像のオフセットとサイズ
	# オフセットは8で割った値を指定
	tex_ofs_div_8=$TEXTURE2_VRAM_OFS
	tex_ofs_div_8_th=$(echo $tex_ofs_div_8 | cut -c1-2)
	tex_ofs_div_8_bh=$(echo $tex_ofs_div_8 | cut -c3-4)
	var_texture2_ofs=$(calc16_8 "$var_sprite2_dz+2")
	echo -e "var_texture2_ofs=$var_texture2_ofs" >>$map_file
	echo -en "\x${tex_ofs_div_8_th}\x${tex_ofs_div_8_bh}"
	# 4の倍数バウンダリ
	# サイズは、(b15-b14)=0b00、(b13-b08)=幅/8、(b07-b00)=高さ を指定
	var_texture2_size=$(calc16_8 "$var_texture2_ofs+2")
	echo -e "var_texture2_size=$var_texture2_size" >>$map_file
	echo -en '\x28\xe0'	# 幅:(/ 320 8)40(0x28), 高さ:224(0xe0)

	# TEXTURE3_IMG
	var_sprite3_ax=$(calc16_8 "$var_texture2_size+2")
	echo -e "var_sprite3_ax=$var_sprite3_ax" >>$map_file
	echo -en '\xff\x60'	# -160
	# 4の倍数バウンダリ
	var_sprite3_ay=$(calc16_8 "$var_sprite3_ax+2")
	echo -e "var_sprite3_ay=$var_sprite3_ay" >>$map_file
	echo -en '\x00\xdf'	# 223
	var_sprite3_az=$(calc16_8 "$var_sprite3_ay+2")
	echo -e "var_sprite3_az=$var_sprite3_az" >>$map_file
	echo -en '\x00\xa0'	# 160
	# 4の倍数バウンダリ
	var_sprite3_bx=$(calc16_8 "$var_sprite3_az+2")
	echo -e "var_sprite3_bx=$var_sprite3_bx" >>$map_file
	echo -en '\x00\x9f'	# 159
	var_sprite3_by=$(calc16_8 "$var_sprite3_bx+2")
	echo -e "var_sprite3_by=$var_sprite3_by" >>$map_file
	echo -en '\x00\xdf'	# 223
	# 4の倍数バウンダリ
	var_sprite3_bz=$(calc16_8 "$var_sprite3_by+2")
	echo -e "var_sprite3_bz=$var_sprite3_bz" >>$map_file
	echo -en '\x00\xa0'	# 160
	var_sprite3_cx=$(calc16_8 "$var_sprite3_bz+2")
	echo -e "var_sprite3_cx=$var_sprite3_cx" >>$map_file
	echo -en '\x00\x9f'	# 159
	# 4の倍数バウンダリ
	var_sprite3_cy=$(calc16_8 "$var_sprite3_cx+2")
	echo -e "var_sprite3_cy=$var_sprite3_cy" >>$map_file
	echo -en '\x00\x00'	# 0
	var_sprite3_cz=$(calc16_8 "$var_sprite3_cy+2")
	echo -e "var_sprite3_cz=$var_sprite3_cz" >>$map_file
	echo -en '\x00\xa0'	# 160
	# 4の倍数バウンダリ
	var_sprite3_dx=$(calc16_8 "$var_sprite3_cz+2")
	echo -e "var_sprite3_dx=$var_sprite3_dx" >>$map_file
	echo -en '\xff\x60'	# -160
	var_sprite3_dy=$(calc16_8 "$var_sprite3_dx+2")
	echo -e "var_sprite3_dy=$var_sprite3_dy" >>$map_file
	echo -en '\x00\x00'	# 0
	# 4の倍数バウンダリ
	var_sprite3_dz=$(calc16_8 "$var_sprite3_dy+2")
	echo -e "var_sprite3_dz=$var_sprite3_dz" >>$map_file
	echo -en '\x00\xa0'	# 160
	# テクスチャ画像のオフセットとサイズ
	# オフセットは8で割った値を指定
	tex_ofs_div_8=$TEXTURE3_VRAM_OFS
	tex_ofs_div_8_th=$(echo $tex_ofs_div_8 | cut -c1-2)
	tex_ofs_div_8_bh=$(echo $tex_ofs_div_8 | cut -c3-4)
	var_texture3_ofs=$(calc16_8 "$var_sprite3_dz+2")
	echo -e "var_texture3_ofs=$var_texture3_ofs" >>$map_file
	echo -en "\x${tex_ofs_div_8_th}\x${tex_ofs_div_8_bh}"
	# 4の倍数バウンダリ
	# サイズは、(b15-b14)=0b00、(b13-b08)=幅/8、(b07-b00)=高さ を指定
	var_texture3_size=$(calc16_8 "$var_texture3_ofs+2")
	echo -e "var_texture3_size=$var_texture3_size" >>$map_file
	echo -en '\x28\xe0'	# 幅:(/ 320 8)40(0x28), 高さ:224(0xe0)

	# TEXTURE4_IMG
	var_sprite4_ax=$(calc16_8 "$var_texture3_size+2")
	echo -e "var_sprite4_ax=$var_sprite4_ax" >>$map_file
	echo -en '\xff\x60'	# -160
	# 4の倍数バウンダリ
	var_sprite4_ay=$(calc16_8 "$var_sprite4_ax+2")
	echo -e "var_sprite4_ay=$var_sprite4_ay" >>$map_file
	echo -en '\x00\xdf'	# 223
	var_sprite4_az=$(calc16_8 "$var_sprite4_ay+2")
	echo -e "var_sprite4_az=$var_sprite4_az" >>$map_file
	echo -en '\x00\xbe'	# 190
	# 4の倍数バウンダリ
	var_sprite4_bx=$(calc16_8 "$var_sprite4_az+2")
	echo -e "var_sprite4_bx=$var_sprite4_bx" >>$map_file
	echo -en '\x00\x9f'	# 159
	var_sprite4_by=$(calc16_8 "$var_sprite4_bx+2")
	echo -e "var_sprite4_by=$var_sprite4_by" >>$map_file
	echo -en '\x00\xdf'	# 223
	# 4の倍数バウンダリ
	var_sprite4_bz=$(calc16_8 "$var_sprite4_by+2")
	echo -e "var_sprite4_bz=$var_sprite4_bz" >>$map_file
	echo -en '\x00\xbe'	# 190
	var_sprite4_cx=$(calc16_8 "$var_sprite4_bz+2")
	echo -e "var_sprite4_cx=$var_sprite4_cx" >>$map_file
	echo -en '\x00\x9f'	# 159
	# 4の倍数バウンダリ
	var_sprite4_cy=$(calc16_8 "$var_sprite4_cx+2")
	echo -e "var_sprite4_cy=$var_sprite4_cy" >>$map_file
	echo -en '\x00\x00'	# 0
	var_sprite4_cz=$(calc16_8 "$var_sprite4_cy+2")
	echo -e "var_sprite4_cz=$var_sprite4_cz" >>$map_file
	echo -en '\x00\xbe'	# 190
	# 4の倍数バウンダリ
	var_sprite4_dx=$(calc16_8 "$var_sprite4_cz+2")
	echo -e "var_sprite4_dx=$var_sprite4_dx" >>$map_file
	echo -en '\xff\x60'	# -160
	var_sprite4_dy=$(calc16_8 "$var_sprite4_dx+2")
	echo -e "var_sprite4_dy=$var_sprite4_dy" >>$map_file
	echo -en '\x00\x00'	# 0
	# 4の倍数バウンダリ
	var_sprite4_dz=$(calc16_8 "$var_sprite4_dy+2")
	echo -e "var_sprite4_dz=$var_sprite4_dz" >>$map_file
	echo -en '\x00\xbe'	# 190
	# テクスチャ画像のオフセットとサイズ
	# オフセットは8で割った値を指定
	tex_ofs_div_8_th=$TEXTURE4_VRAM_OFS_TH
	tex_ofs_div_8_bh=$TEXTURE4_VRAM_OFS_BH
	var_texture4_ofs=$(calc16_8 "$var_sprite4_dz+2")
	echo -e "var_texture4_ofs=$var_texture4_ofs" >>$map_file
	echo -en "\x${tex_ofs_div_8_th}\x${tex_ofs_div_8_bh}"
	# 4の倍数バウンダリ
	# サイズは、(b15-b14)=0b00、(b13-b08)=幅/8、(b07-b00)=高さ を指定
	var_texture4_size=$(calc16_8 "$var_texture4_ofs+2")
	echo -e "var_texture4_size=$var_texture4_size" >>$map_file
	echo -en '\x28\xe0'	# 幅:(/ 320 8)40(0x28), 高さ:224(0xe0)

	# 座標更新周期カウンタ
	var_coord_update_cyc_counter=$(calc16_8 "$var_texture4_size+2")
	echo -e "var_coord_update_cyc_counter=$var_coord_update_cyc_counter" >>$map_file
	echo -en '\x00'

	# パディング
	echo -en '\x00'
	# 4の倍数バウンダリ

	# テクスチャ実データ
	var_texture_pixel_num=$(calc16_8 "$var_coord_update_cyc_counter+2")
	echo -e "var_texture_pixel_num=$var_texture_pixel_num" >>$map_file
	echo -en '\x00\x01\x18\x00'	# (* 320 224)71680(0x11800)
	# 4の倍数バウンダリ
	var_texture_data=$(calc16_8 "$var_texture_pixel_num+4")
	echo -e "var_texture_data=$var_texture_data" >>$map_file
	cat $TEXTURE1_IMG	# 143360 bytes(140KB)
	# 4の倍数バウンダリ
	vsz=$(to16 $(stat -c '%s' $TEXTURE1_IMG))
	var_texture2_pixel_num=$(calc16_8 "${var_texture_data}+${vsz}")
	echo -e "var_texture2_pixel_num=$var_texture2_pixel_num" >>$map_file
	echo -en '\x00\x01\x18\x00'	# (* 320 224)71680(0x11800)
	# 4の倍数バウンダリ
	var_texture2_data=$(calc16_8 "$var_texture2_pixel_num+4")
	echo -e "var_texture2_data=$var_texture2_data" >>$map_file
	cat $TEXTURE2_IMG	# 143360 bytes(140KB)
	# 4の倍数バウンダリ
	vsz=$(to16 $(stat -c '%s' $TEXTURE2_IMG))
	var_texture3_pixel_num=$(calc16_8 "${var_texture2_data}+${vsz}")
	echo -e "var_texture3_pixel_num=$var_texture3_pixel_num" >>$map_file
	echo -en '\x00\x01\x18\x00'	# (* 320 224)71680(0x11800)
	# 4の倍数バウンダリ
	var_texture3_data=$(calc16_8 "$var_texture3_pixel_num+4")
	echo -e "var_texture3_data=$var_texture3_data" >>$map_file
	cat $TEXTURE3_IMG	# 143360 bytes(140KB)
	# 4の倍数バウンダリ
	vsz=$(to16 $(stat -c '%s' $TEXTURE3_IMG))
	var_texture4_pixel_num=$(calc16_8 "${var_texture3_data}+${vsz}")
	echo -e "var_texture4_pixel_num=$var_texture4_pixel_num" >>$map_file
	echo -en '\x00\x01\x18\x00'	# (* 320 224)71680(0x11800)
	# 4の倍数バウンダリ
	var_texture4_data=$(calc16_8 "$var_texture4_pixel_num+4")
	echo -e "var_texture4_data=$var_texture4_data" >>$map_file
	cat $TEXTURE4_IMG	# 143360 bytes(140KB)
	# 4の倍数バウンダリ

	# スライドショー用変数
	## VRAM上の3つ分のテクスチャ領域にロードされている
	## スライドのZ座標値を保持する変数
	### 1つ目のテクスチャ領域(0x05C00C80-0x05C23C7F)
	vsz=$(to16 $(stat -c '%s' $TEXTURE4_IMG))
	var_slidez_texbuf1=$(calc16_8 "${var_texture4_data}+${vsz}")
	echo -e "var_slidez_texbuf1=$var_slidez_texbuf1" >>$map_file
	echo -en '\x00\x64'	# スライド1(TEXTURE1),Z=100
	### 2つ目のテクスチャ領域(0x05C23C80-0x05C46C7F)
	var_slidez_texbuf2=$(calc16_8 "${var_slidez_texbuf1}+1")
	echo -e "var_slidez_texbuf2=$var_slidez_texbuf2" >>$map_file
	echo -en '\x00\x82'	# スライド2(TEXTURE2),Z=130
	# 4の倍数バウンダリ
	### 3つ目のテクスチャ領域(0x05C46C80-0x05C69C7F)
	var_slidez_texbuf3=$(calc16_8 "${var_slidez_texbuf2}+1")
	echo -e "var_slidez_texbuf3=$var_slidez_texbuf3" >>$map_file
	echo -en '\x00\xa0'	# スライド3(TEXTURE3),Z=160

	# パディング
	echo -en '\x00\x00'
	# 4の倍数バウンダリ
}
# 変数設定のために空実行
vars >/dev/null
rm -f $map_file

# 符号付き32ビット除算
# in  : r1  - 被除数
#     : r0* - 除数
# out : r1  - 計算結果の商
# work: r2* - 作業用
#       r3* - 作業用
# ※ *が付いているレジスタはこの関数の冒頭/末尾でスタックへの退避/復帰を行う
f_div_reg_by_reg_long_sign() {
	div_reg_by_reg_long_sign r1 r0 r2 r3

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# ゲームパッドの入力状態更新
f_update_gamepad_input_status() {
	# SFへ1をセット
	## SFのアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_SF_ADDR
	## r0へ0x01をセット
	sh2_set_reg r0 01
	## r1の指す先(SF)へr0の値(0x01)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# IREG2へ0xf0をセット
	## IREG2のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_IREG2_ADDR
	## r0へ0xf0をセット
	sh2_set_reg r0 f0
	## r1の指す先(IREG2)へr0の値(0xf0)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# IREG1へ0x08をセット
	## IREG1のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_IREG1_ADDR
	## r0へ0x08をセット
	sh2_set_reg r0 08
	## r1の指す先(IREG1)へr0の値(0x08)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# IREG0へ0x00をセット
	## IREG0のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_IREG0_ADDR
	## r0へ0x00をセット
	sh2_set_reg r0 00
	## r1の指す先(IREG0)へr0の値(0x00)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# COMREGへINTBACKをセット
	## COMREGのアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_COMREG_ADDR
	## r0へINTBACKをセット
	sh2_set_reg r0 $SS_SMPC_COMREG_INTBACK
	## r1の指す先(COMREG)へr0の値(INTBACK)を設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# SFが0になるのを待つ
	## SFのアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_SF_ADDR
	## r0へr1の指す先(SF)の値をロード
	sh2_copy_to_reg_from_ptr_byte r0 r1
	## bit0が1の間、ここで待つ
	sh2_test_r0_and_val_byte 01
	sh2_rel_jump_if_false $(two_comp_d 4)
	sh2_nop

	# OREG2(1st Data)を変数へロード
	## OREG2のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_OREG2_ADDR
	## r2へr1の指す先(OREG2)の値をロード
	sh2_copy_to_reg_from_ptr_byte r2 r1
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_1
	## r1の指す先(変数)へr2の値を格納
	sh2_copy_to_ptr_from_reg_byte r1 r2

	# OREG3(2nd Data)をr5へロード
	## OREG3のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $SS_SMPC_OREG3_ADDR
	## r2へr1の指す先(OREG3)の値をロード
	sh2_copy_to_reg_from_ptr_byte r2 r1
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_2
	## r1の指す先(変数)へr2の値を格納
	sh2_copy_to_ptr_from_reg_byte r1 r2

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された2次元座標の原点からの距離を算出
# in  : r5  - 1軸目の値
#       r7  - 2軸目の値
# out : r5  - 結果の距離
# work: r0  - 作業用
#       r6  - 作業用
f_calc_distance_2d() {
	# 戻り値とr0以外で書き換えるレジスタをスタックへ退避
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r7
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r6

	# 1軸目の値(r5)の絶対値をr5へ格納
	## r5 >= 0 ?
	sh2_xor_to_reg_from_reg r0 r0
	sh2_compare_reg_ge_reg_signed r5 r0
	## trueだったら後続処理を飛ばす
	(
		# r5 *= -1
		sh2_set_reg r0 ff	# -1
		sh2_multiply_reg_by_reg_signed_word r5 r0
		sh2_copy_to_reg_from_macl r5
	) >src/f_calc_distance_2d.1.o
	local sz_1=$(stat -c '%s' src/f_calc_distance_2d.1.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_calc_distance_2d.1.o

	# 2軸目の値(r7)の絶対値をr7へ格納
	## r7 >= 0 ?
	sh2_xor_to_reg_from_reg r0 r0
	sh2_compare_reg_ge_reg_signed r7 r0
	## trueだったら後続処理を飛ばす
	(
		# r7 *= -1
		sh2_set_reg r0 ff	# -1
		sh2_multiply_reg_by_reg_signed_word r7 r0
		sh2_copy_to_reg_from_macl r7
	) >src/f_calc_distance_2d.2.o
	local sz_2=$(stat -c '%s' src/f_calc_distance_2d.2.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_2 / 2)))
	sh2_nop
	cat src/f_calc_distance_2d.2.o

	# r5 >= r7 となるようにする
	# (そうでないなら値を入れ替える)
	## r5 >= r7 ?
	sh2_compare_reg_ge_reg_unsigned r5 r7
	## trueだったら後続処理を飛ばす
	(
		# r5とr7の値を入れ替える
		## r0 <- r5
		sh2_copy_to_reg_from_reg r0 r5
		## r5 <- r7
		sh2_copy_to_reg_from_reg r5 r7
		## r7 <- r0
		sh2_copy_to_reg_from_reg r7 r0
	) >src/f_calc_distance_2d.3.o
	local sz_3=$(stat -c '%s' src/f_calc_distance_2d.3.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_3 / 2)))
	sh2_nop
	cat src/f_calc_distance_2d.3.o

	# (2 * r5) < (5 * r7) ?
	## r6 = 2 * r5
	sh2_set_reg r6 02
	sh2_multiply_reg_by_reg_unsigned_word r6 r5
	sh2_copy_to_reg_from_macl r6
	## r0 = 5 * r7
	sh2_set_reg r0 05
	sh2_multiply_reg_by_reg_unsigned_word r0 r7
	sh2_copy_to_reg_from_macl r0
	## r0 > r6 ?
	sh2_compare_reg_gt_reg_unsigned r0 r6
	(
		# trueの場合
		## r5 *= 864(0x0360)
		sh2_set_reg r0 03
		sh2_shift_left_logical_8 r0
		sh2_or_to_r0_from_val_byte 60
		sh2_multiply_reg_by_reg_signed_long r5 r0
		## r7 *= 569(0x0239)
		sh2_set_reg r0 02
		sh2_shift_left_logical_8 r0
		sh2_or_to_r0_from_val_byte 39
		sh2_multiply_reg_by_reg_signed_long r7 r0
	) >src/f_calc_distance_2d.4.o
	(
		# falseの場合
		## r5 *= 1016(0x03f8)
		sh2_set_reg r0 03
		sh2_shift_left_logical_8 r0
		sh2_or_to_r0_from_val_byte f8
		sh2_multiply_reg_by_reg_signed_long r5 r0
		## r7 *= 190(0x00be)
		sh2_set_reg r0 00
		sh2_or_to_r0_from_val_byte be
		sh2_multiply_reg_by_reg_signed_long r7 r0

		# trueの場合の処理を飛ばす
		local sz_4=$(stat -c '%s' src/f_calc_distance_2d.4.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_4 / 2))) 3)
		sh2_nop
	) >src/f_calc_distance_2d.5.o
	## trueだったらジャンプ
	local sz_5=$(stat -c '%s' src/f_calc_distance_2d.5.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_5 / 2)))
	sh2_nop
	cat src/f_calc_distance_2d.5.o	# falseの場合
	cat src/f_calc_distance_2d.4.o	# trueの場合
	## r5 += r7
	sh2_add_to_reg_from_reg r5 r7

	# r5 = (r5 + 512) / 1024
	## r5 += 512(0x0200)
	sh2_set_reg r0 02
	sh2_shift_left_logical_8 r0
	sh2_add_to_reg_from_reg r5 r0
	## r5 /= 1024(0x0400)
	sh2_set_reg r0 04
	sh2_shift_left_logical_8 r0
	div_reg_by_reg_long_sign r5 r0 r7 r6

	# 使用したレジスタをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r6 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_reg_from_ptr_long r7 r15
	sh2_add_to_reg_from_val_byte r15 04

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された4頂点・カラーの変形スプライトを描画するコマンドを
# 指定されたアドレスへ配置
# in  : r1  - Ax
#       r2  - Ay
#       r3  - Bx
#       r4  - By
#       r5  - Cx
#       r6  - Cy
#       r7  - Dx
#       r8  - Dy
#       r9  - キャラクタパターンテーブルのアドレス/8
#       r10 - キャラクタサイズ
#             - (b15-b14) = 0b00
#             - (b13-b08) = 幅/8
#             - (b07-b00) = 高さ
#       r11 - dst addr
# out : r11 - dst addrへ最後に書き込んだ次のアドレス
# work: PR  - この関数を呼び出したBSR/JSR命令のアドレス
#     : r0  - 作業用
f_put_vdp1_command_distorted_sprite_draw_to_addr() {
	# CMDCTRL
	# 0b0000 0000 0000 0010
	# - JP(b14-b12) = 0b000
	# - Dir(b5-b4) = 0b00
	# 0x0002 -> [r11]
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte 02
	sh2_copy_to_ptr_from_reg_word r11 r0
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDLINK
	# 0x0000 -> [r11]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r11 r0
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDPMOD
	# 0b0000 1000 1110 1000
	# - MON(b15) = 0 (VDP2の機能を使わない)
	# - HSS(b12) = 0 (ハイスピードシュリンク無効)
	# - Pclp(b11) = 1 (クリッピングが必要かどうかの座標計算無効)
	# - Clip(b10) = 0 (ユーザクリッピング座標に従わない)
	# - Cmod(b9) = 0 (Clip=0なので無効)
	# - Mesh(b8) = 0 (メッシュ無効)
	# - ECD(b7) = 1 (エンドコード無効)
	# - SPD(b6) = 1 (透明ピクセル無効)
	# - カラーモード(b5-b3) = 0b101 (RGBモード)
	# - 色演算(b2-b0) = 0b000 (色演算は全て無効)
	# 0x08e8 -> [r11]
	sh2_set_reg r0 08
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte e8
	sh2_copy_to_ptr_from_reg_word r11 r0
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDCOLR
	# テクスチャパーツでRGBモードなのでこのワードは無視される
	# 0x0000 -> [r11]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r11 r0
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDSRCA
	# キャラクタパターンテーブルのアドレスを8で割った値を設定する
	# r9 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r9
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDSIZE
	# キャラクタパターンテーブルに定義したキャラクタの幅と高さを設定する
	# 幅は8で割った値を設定する
	# r10 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r10
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDXA
	# 頂点AのX座標
	# r1 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r1
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDYA
	# 頂点AのY座標
	# r2 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r2
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDXB
	# 頂点BのX座標
	# r3 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r3
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDYB
	# 頂点BのY座標
	# r4 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r4
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDXC
	# 頂点CのX座標
	# r5 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r5
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDYC
	# 頂点CのY座標
	# r6 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r6
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDXD
	# 頂点DのX座標
	# r7 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r7
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDYD
	# 頂点DのY座標
	# r8 -> [r11]
	sh2_copy_to_ptr_from_reg_word r11 r8
	# r11 += 2
	sh2_add_to_reg_from_val_byte r11 02

	# CMDGRDA, dummy
	# 0x00000000 -> [r11]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_long r11 r0
	# r11 += 4
	sh2_add_to_reg_from_val_byte r11 04

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された4頂点・カラーのポリゴンを描画するコマンドを
# 指定されたアドレスへ配置
# in  : r1  - Ax
#       r2  - Ay
#       r3  - Bx
#       r4  - By
#       r5  - Cx
#       r6  - Cy
#       r7  - Dx
#       r8  - Dy
#       r9  - color
#       r10 - dst addr
# out : r10 - dst addrへ最後に書き込んだ次のアドレス
# work: PR  - この関数を呼び出したBSR/JSR命令のアドレス
#     : r0  - 作業用
f_put_vdp1_command_polygon_draw_to_addr() {
	# CMDCTRL
	# 0b0000 0000 0000 0100
	# - JP(b14-b12) = 0b000
	# 0x0004 -> [r10]
	sh2_set_reg r0 00
	sh2_or_to_r0_from_val_byte 04
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDLINK
	# 0x0000 -> [r10]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDPMOD
	# 0b0000 1000 1100 0000
	# - MON(b15) = 0 (VDP2の機能を使わない)
	# - Pclp(b11) = 1 (クリッピングが必要かどうかの座標計算無効)
	# - Clip(b10) = 0 (ユーザクリッピング座標に従わない)
	# - Cmod(b9) = 0 (Clip=0なので無効)
	# - Mesh(b8) = 0 (メッシュ無効)
	# - 色演算(b2-b0) = 0b000 (色演算は全て無効)
	# 0x08c0 -> [r10]
	sh2_set_reg r0 08
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte c0
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDCOLR
	# r9 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r9
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDSRCA
	# 0x0000 -> [r10]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDSIZE
	# 0x0000 -> [r10]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r10 r0
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDXA
	# 頂点AのX座標
	# r1 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r1
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDYA
	# 頂点AのY座標
	# r2 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r2
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDXB
	# 頂点BのX座標
	# r3 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r3
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDYB
	# 頂点BのY座標
	# r4 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r4
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDXC
	# 頂点CのX座標
	# r5 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r5
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDYC
	# 頂点CのY座標
	# r6 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r6
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDXD
	# 頂点DのX座標
	# r7 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r7
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDYD
	# 頂点DのY座標
	# r8 -> [r10]
	sh2_copy_to_ptr_from_reg_word r10 r8
	# r10 += 2
	sh2_add_to_reg_from_val_byte r10 02

	# CMDGRDA, dummy
	# 0x00000000 -> [r10]
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_long r10 r0
	# r10 += 4
	sh2_add_to_reg_from_val_byte r10 04

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 4つの3次元座標で指定された平面を指定されたカラーで
# 指定されたアドレスへ描画
# in  : r1   - Ax
#       r2   - Ay
#       r3   - Az
#       r4   - Bx
#       r5   - By
#       r6   - Bz
#       r7   - Cx
#       r8   - Cy
#       r9   - Cz
#       r10  - Dx
#       r11  - Dy
#       r12  - Dz
#       r13  - color
#       SP+0 - dst addr
# out : SP+0 - dst addrへ最後に書き込んだ次のアドレス
# work: PR   - この関数を呼び出したBSR/JSR命令のアドレス
#     : r0   - 作業用
#     : r14  - 作業用
f_draw_plate() {
	local _i

	# 投影面Z座標をr14へロード
	copy_to_reg_from_val_long r14 $var_proj_z
	sh2_copy_to_reg_from_ptr_word r14 r14
	sh2_extend_unsigned_to_reg_from_reg_word r14 r14

	# 投影面Z座標(PRJz)より小さい(カメラに近い)Z座標が1つでもあれば
	# 何もせずreturn
	(
		# 何もせずreturn
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_draw_plate.1.o
	local sz_1=$(stat -c '%s' src/f_draw_plate.1.o)
	## PRJz(r14) > Az(r3)?
	sh2_compare_reg_gt_reg_unsigned r14 r3
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate.1.o
	## PRJz(r14) > Bz(r6)?
	sh2_compare_reg_gt_reg_unsigned r14 r6
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate.1.o
	## PRJz(r14) > Cz(r9)?
	sh2_compare_reg_gt_reg_unsigned r14 r9
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate.1.o
	## PRJz(r14) > Dz(r12)?
	sh2_compare_reg_gt_reg_unsigned r14 r12
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate.1.o

	# 現在のPRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 透視投影で2次元座標へ変換
	# - PRJz < Az or Bz or Cz or Dz の時
	#   - 2次元座標(x, y) = 3次元座標(x, y) * PRJz / 3次元座標z
	# - PRJz == Az or Bz or Cz or Dz の時
	#   - 2次元座標(x, y) = 3次元座標(x, y)

	## PRJz(r14) == Az(r3)?
	sh2_compare_reg_eq_reg r14 r3
	(
		# PRJz(r14) < Az(r3) の時

		# r13をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r13

		# r13に除算関数のアドレスを設定
		copy_to_reg_from_val_long r13 $a_div_reg_by_reg_long_sign

		# 2次元座標Ax(r1) = 3次元座標Ax(r1) * PRJz(r14) / 3次元座標Az(r3)
		## 3次元座標Ax(r1) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r1 r14
		## MACL -> r1
		sh2_copy_to_reg_from_macl r1
		## r1 / 3次元座標Az(r3) -> r1
		### r3 -> r0
		sh2_copy_to_reg_from_reg r0 r3
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop

		# 2次元座標Ay(r2) = 3次元座標Ay(r2) * PRJz(r14) / 3次元座標Az(r3)
		## 3次元座標Ay(r2) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r2 r14
		## MACL -> r2
		sh2_copy_to_reg_from_macl r2
		## r2 / 3次元座標Az(r3) -> r2
		### r1をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r1
		### r2 -> r1
		sh2_copy_to_reg_from_reg r1 r2
		### r0には先程除算した時の除数が残っていることを想定
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r2
		sh2_copy_to_reg_from_reg r2 r1
		### r1をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r1 r15
		sh2_add_to_reg_from_val_byte r15 04

		# r13をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r13 r15
		sh2_add_to_reg_from_val_byte r15 04
	) >src/f_draw_plate.2.o
	local sz_2=$(stat -c '%s' src/f_draw_plate.2.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_2 / 2)))
	sh2_nop
	cat src/f_draw_plate.2.o	# PRJz(r14) < Az(r3) の時
	# この時点でポリゴン描画の頂点Aの座標(Ax,Ay)を(r1,r2)へ設定完了

	## PRJz(r14) == Bz(r6)?
	sh2_compare_reg_eq_reg r14 r6
	(
		# PRJz(r14) == Bz(r6) の時

		# 2次元座標Bx(r3) = 3次元座標Bx(r4)
		sh2_copy_to_reg_from_reg r3 r4

		# 2次元座標By(r4) = 3次元座標By(r5)
		sh2_copy_to_reg_from_reg r4 r5
	) >src/f_draw_plate.4.o
	(
		# PRJz(r14) < Bz(r6) の時

		# r13をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r13
		# r1をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r1

		# r13に除算関数のアドレスを設定
		copy_to_reg_from_val_long r13 $a_div_reg_by_reg_long_sign

		# 2次元座標Bx(r3) = 3次元座標Bx(r4) * PRJz(r14) / 3次元座標Bz(r6)
		## 3次元座標Bx(r4) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r4 r14
		## MACL -> r3
		sh2_copy_to_reg_from_macl r3
		## r3 / 3次元座標Bz(r6) -> r3
		### r3 -> r1
		sh2_copy_to_reg_from_reg r1 r3
		### r6 -> r0
		sh2_copy_to_reg_from_reg r0 r6
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r3
		sh2_copy_to_reg_from_reg r3 r1

		# 2次元座標By(r4) = 3次元座標By(r5) * PRJz(r14) / 3次元座標Bz(r6)
		## 3次元座標By(r5) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r5 r14
		## MACL -> r4
		sh2_copy_to_reg_from_macl r4
		## r4 / 3次元座標Bz(r6) -> r4
		### r4 -> r1
		sh2_copy_to_reg_from_reg r1 r4
		### r0には先程除算した時の除数が残っていることを想定
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r4
		sh2_copy_to_reg_from_reg r4 r1

		# r1をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r1 r15
		sh2_add_to_reg_from_val_byte r15 04
		# r13をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r13 r15
		sh2_add_to_reg_from_val_byte r15 04

		# PRJz(r14) == Bz(r6) の時の処理を飛ばす
		local sz_4=$(stat -c '%s' src/f_draw_plate.4.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_4 / 2))) 3)
		sh2_nop
	) >src/f_draw_plate.3.o
	local sz_3=$(stat -c '%s' src/f_draw_plate.3.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_3 / 2)))
	sh2_nop
	cat src/f_draw_plate.3.o	# PRJz(r14) < Bz(r6) の時
	cat src/f_draw_plate.4.o	# PRJz(r14) == Bz(r6) の時
	# この時点でポリゴン描画の頂点Bの座標(Bx,By)を(r3,r4)へ設定完了

	## PRJz(r14) == Cz(r9)?
	sh2_compare_reg_eq_reg r14 r9
	(
		# PRJz(r14) == Cz(r9) の時

		# 2次元座標Cx(r5) = 3次元座標Cx(r7)
		sh2_copy_to_reg_from_reg r5 r7

		# 2次元座標Cy(r6) = 3次元座標Cy(r8)
		sh2_copy_to_reg_from_reg r6 r8
	) >src/f_draw_plate.6.o
	(
		# PRJz(r14) < Cz(r9) の時

		# r13をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r13
		# r1をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r1

		# r13に除算関数のアドレスを設定
		copy_to_reg_from_val_long r13 $a_div_reg_by_reg_long_sign

		# 2次元座標Cx(r5) = 3次元座標Cx(r7) * PRJz(r14) / 3次元座標Cz(r9)
		## 3次元座標Cx(r7) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r7 r14
		## MACL -> r5
		sh2_copy_to_reg_from_macl r5
		## r5 / 3次元座標Cz(r9) -> r5
		### r5 -> r1
		sh2_copy_to_reg_from_reg r1 r5
		### r9 -> r0
		sh2_copy_to_reg_from_reg r0 r9
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r5
		sh2_copy_to_reg_from_reg r5 r1

		# 2次元座標Cy(r6) = 3次元座標Cy(r8) * PRJz(r14) / 3次元座標Cz(r9)
		## 3次元座標Cy(r8) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r8 r14
		## MACL -> r6
		sh2_copy_to_reg_from_macl r6
		## r6 / 3次元座標Cz(r9) -> r6
		### r6 -> r1
		sh2_copy_to_reg_from_reg r1 r6
		### r0には先程除算した時の除数が残っていることを想定
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r6
		sh2_copy_to_reg_from_reg r6 r1

		# r1をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r1 r15
		sh2_add_to_reg_from_val_byte r15 04
		# r13をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r13 r15
		sh2_add_to_reg_from_val_byte r15 04

		# PRJz(r14) == Cz(r9) の時の処理を飛ばす
		local sz_6=$(stat -c '%s' src/f_draw_plate.6.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_6 / 2))) 3)
		sh2_nop
	) >src/f_draw_plate.5.o
	local sz_5=$(stat -c '%s' src/f_draw_plate.5.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_5 / 2)))
	sh2_nop
	cat src/f_draw_plate.5.o	# PRJz(r14) < Bz(r9) の時
	cat src/f_draw_plate.6.o	# PRJz(r14) == Bz(r9) の時
	# この時点でポリゴン描画の頂点Cの座標(Cx,Cy)を(r5,r6)へ設定完了

	## PRJz(r14) == Dz(r12)?
	sh2_compare_reg_eq_reg r14 r12
	(
		# PRJz(r14) == Dz(r12) の時

		# 2次元座標Dx(r7) = 3次元座標Dx(r10)
		sh2_copy_to_reg_from_reg r7 r10

		# 2次元座標Dy(r8) = 3次元座標Dy(r11)
		sh2_copy_to_reg_from_reg r8 r11
	) >src/f_draw_plate.8.o
	(
		# PRJz(r14) < Dz(r12) の時

		# r13をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r13
		# r1をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r1

		# r13に除算関数のアドレスを設定
		copy_to_reg_from_val_long r13 $a_div_reg_by_reg_long_sign

		# 2次元座標Dx(r7) = 3次元座標Dx(r10) * PRJz(r14) / 3次元座標Dz(r12)
		## 3次元座標Dx(r10) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r10 r14
		## MACL -> r7
		sh2_copy_to_reg_from_macl r7
		## r7 / 3次元座標Dz(r12) -> r7
		### r7 -> r1
		sh2_copy_to_reg_from_reg r1 r7
		### r12 -> r0
		sh2_copy_to_reg_from_reg r0 r12
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r7
		sh2_copy_to_reg_from_reg r7 r1

		# 2次元座標Dy(r8) = 3次元座標Dy(r11) * PRJz(r14) / 3次元座標Dz(r12)
		## 3次元座標Dy(r11) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r11 r14
		## MACL -> r8
		sh2_copy_to_reg_from_macl r8
		## r8 / 3次元座標Dz(r12) -> r8
		### r8 -> r1
		sh2_copy_to_reg_from_reg r1 r8
		### r0には先程除算した時の除数が残っていることを想定
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r8
		sh2_copy_to_reg_from_reg r8 r1

		# r1をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r1 r15
		sh2_add_to_reg_from_val_byte r15 04
		# r13をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r13 r15
		sh2_add_to_reg_from_val_byte r15 04

		# PRJz(r14) == Dz(r12) の時の処理を飛ばす
		local sz_8=$(stat -c '%s' src/f_draw_plate.8.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_8 / 2))) 3)
		sh2_nop
	) >src/f_draw_plate.7.o
	local sz_7=$(stat -c '%s' src/f_draw_plate.7.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_7 / 2)))
	sh2_nop
	cat src/f_draw_plate.7.o	# PRJz(r14) < Dz(r12) の時
	cat src/f_draw_plate.8.o	# PRJz(r14) == Dz(r12) の時
	# この時点でポリゴン描画の頂点Dの座標(Dx,Dy)を(r7,r8)へ設定完了

	# 以上のr1-r8(Ax-Dy)は投影面座標系なので、ゲームスクリーン座標計へ変換
	transform_to_gs_from_prj r1 r2	# Ax, Ay
	transform_to_gs_from_prj r3 r4	# Bx, By
	transform_to_gs_from_prj r5 r6	# Cx, Cy
	transform_to_gs_from_prj r7 r8	# Dx, Dy

	# 引数r13のカラーをr9へ設定
	sh2_copy_to_reg_from_reg r9 r13

	# SP+4のdst addrをr10へ設定
	sh2_copy_to_reg_from_reg r10 r15
	sh2_add_to_reg_from_val_byte r10 04
	sh2_copy_to_reg_from_ptr_long r10 r10

	# ポリゴン描画コマンドを配置する関数を呼び出す
	copy_to_reg_from_val_long r11 $a_put_vdp1_command_polygon_draw_to_addr
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_nop

	# PRをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0

	# SP+0のdst addrをr10で更新
	sh2_copy_to_ptr_from_reg_long r15 r10

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# テクスチャ画像データの更新
# in  : r1  - テクスチャ実データアドレス
#       r2  - 配置先のVRAMオフセット/8
#             (関数内で配置先のVRAMアドレスへ書き換えられる)
#       r3  - テクスチャのピクセル数
f_update_texture() {
	# 配置先のVRAMアドレスをr2へ設定
	## VRAMベースアドレスをr4へ設定
	copy_to_reg_from_val_long r4 $SS_VDP1_VRAM_ADDR
	## テクスチャを配置するオフセット/8を3ビット左シフト(8倍)
	sh2_shift_left_logical_2 r2
	sh2_shift_left_logical r2
	## r2 += r4
	sh2_add_to_reg_from_reg r2 r4

	# テクスチャのピクセル数/2をr3へ設定
	sh2_shift_right_logical r3

	# r1のアドレスからr2のアドレスへr3分のデータをロード
	## r3 > 0 ?
	sh2_xor_to_reg_from_reg r0 r0	# 2
	sh2_compare_reg_gt_reg_signed r3 r0	# 2
	## falseだったら以降の処理を飛ばす
	(
		# r3 > 0

		# 描画終了を待つ
		(
			# r4へEDSRのアドレスを取得
			copy_to_reg_from_val_long r4 $SS_VDP1_EDSR_ADDR
			# r4の指す先(EDSRの内容)をr0へ取得
			sh2_copy_to_reg_from_ptr_word r0 r4
			sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
		) >src/f_update_texture.2.o
		cat src/f_update_texture.2.o
		local sz_2=$(stat -c '%s' src/f_update_texture.2.o)
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_2) / 2)))
		sh2_nop
		## 論理積結果がゼロのとき、
		## 即ちTビットがセットされたとき、
		## 待つ処理を繰り返す

		# [r2] = [r1]
		sh2_copy_to_reg_from_ptr_long r4 r1
		sh2_copy_to_ptr_from_reg_long r2 r4

		# r1 += 4, r2 += 4
		sh2_add_to_reg_from_val_byte r1 04
		sh2_add_to_reg_from_val_byte r2 04

		# r3 += -1
		sh2_add_to_reg_from_val_byte r3 $(two_comp_d 1)
	) >src/f_update_texture.1.o
	local sz_1=$(stat -c '%s' src/f_update_texture.1.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_1 + 2 + 2) / 2)))	# 2
	sh2_nop	# 2
	cat src/f_update_texture.1.o	# sz_1
	sh2_rel_jump_after_next_inst $(two_comp_3_d $(((2 + 2 + sz_1 + 2 + 2 + 2 + 2) / 2)))	# 2
	sh2_nop	# 2

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# スライドテクスチャの更新処理
# VRAMのスライドテクスチャ領域の更新を必要に応じて行う
# f_draw_plate_texture()から呼び出す用の関数
# この関数が呼ばれる時の状態:
# SP+0 - 呼び出し元がこの関数を呼ぶ直前のPR
# SP+4 - 次にコマンドを配置するVRAMアドレス
f_update_slide_texture() {
	# このスライドがVRAMにロードされているか確認
	## r1を「ロードされている(1)か否(0)か」を示すものとして使う
	## ロードされていない(0)としてr1を初期化
	sh2_xor_to_reg_from_reg r1 r1
	## r2を変数のアドレスに使う
	## 1つ目のバッファの変数のアドレスをr2へロード
	copy_to_reg_from_val_long r2 $var_slidez_texbuf1
	## 後のためにr5へコピー
	sh2_copy_to_reg_from_reg r5 r2
	## 1つ目のZ座標をr4へロード
	sh2_copy_to_reg_from_ptr_word r4 r2
	sh2_extend_unsigned_to_reg_from_reg_word r4 r4
	## r4 == r3(Az) ?
	sh2_compare_reg_eq_reg r4 r3
	## 等しくない(T==0)なら以降の処理を飛ばす
	(
		# 1 -> r1
		sh2_set_reg r1 01
	) >src/f_update_slide_texture.1.o
	local sz_1=$(stat -c '%s' src/f_update_slide_texture.1.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_update_slide_texture.1.o
	## r2が2つ目の変数を指すようにする
	sh2_add_to_reg_from_val_byte r2 02
	## 後のためにr6へコピー
	sh2_copy_to_reg_from_reg r6 r2
	## 2つ目のZ座標をr4へロード
	sh2_copy_to_reg_from_ptr_word r4 r2
	sh2_extend_unsigned_to_reg_from_reg_word r4 r4
	## r4 == r3(Az) ?
	sh2_compare_reg_eq_reg r4 r3
	## 等しくない(T==0)なら以降の処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_update_slide_texture.1.o
	## r2が3つ目の変数を指すようにする
	sh2_add_to_reg_from_val_byte r2 02
	## 後のためにr7へコピー
	sh2_copy_to_reg_from_reg r7 r2
	## 3つ目のZ座標をr4へロード
	sh2_copy_to_reg_from_ptr_word r4 r2
	sh2_extend_unsigned_to_reg_from_reg_word r4 r4
	## r4 == r3(Az) ?
	sh2_compare_reg_eq_reg r4 r3
	## 等しくない(T==0)なら以降の処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_update_slide_texture.1.o
	## この時、このスライドがVRAMへロードされているならr1 == 1
	## そうでないなら、r1 == 0

	# このスライドがVRAMへロードされているか(r1 == 1)?
	sh2_set_reg r0 01
	sh2_compare_reg_eq_reg r1 r0

	# ロードされていない(T==0)なら以降の処理を飛ばす
	(
		# ロードされているスライドが見切れた瞬間の処理

		# テクスチャロード中が見えないように
		# 現在のコマンドアドレスに終了コマンドを設定
		## SP+4のアドレスをr1へ設定
		sh2_copy_to_reg_from_reg r1 r15
		sh2_add_to_reg_from_val_byte r1 04
		## 次にコマンドを配置するVRAMアドレスをr1へロード
		sh2_copy_to_reg_from_ptr_long r1 r1
		## r1のアドレス先へ描画終了コマンドを配置
		sh2_set_reg r0 80
		sh2_shift_left_logical_8 r0
		sh2_copy_to_ptr_from_reg_word r1 r0

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# r4にf_update_texture()のアドレスをロード
		copy_to_reg_from_val_long r4 $a_update_texture
		# ※ r5が1つ目の変数のアドレス、
		#    r6が2つ目の変数のアドレス、
		#    r7が3つ目の変数のアドレスを保持している

		# スライド1か?
		## スライド1のZ座標(0x0064)をr0へロード
		sh2_set_reg r0 $SPRITE1_Z_BH
		## r3(Az) == r0 ?
		sh2_compare_reg_eq_reg r3 r0
		## 等しくない(T==0)なら以降の処理を飛ばす
		(
			# 1つ目のバッファへTEXTURE4をロード
			## テクスチャ実データアドレスをr1へ設定
			copy_to_reg_from_val_long r1 $var_texture4_data
			## テクスチャを配置するオフセット/8をr2へ設定
			sh2_set_reg r0 $TEXTURE4_VRAM_OFS_TH
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte $TEXTURE4_VRAM_OFS_BH
			sh2_copy_to_reg_from_reg r2 r0
			## テクスチャのピクセル数をr3へ設定
			sh2_set_reg r0 $TEXTURE_PIXEL_NUM_B23_16
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte $TEXTURE_PIXEL_NUM_B15_8
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte $TEXTURE_PIXEL_NUM_B7_0
			sh2_copy_to_reg_from_reg r3 r0
			## 関数呼び出し
			sh2_abs_call_to_reg_after_next_inst r4
			sh2_nop

			# 変数更新
			## 1つ目の変数へスプライト4のZ座標を保存
			sh2_xor_to_reg_from_reg r0 r0
			sh2_or_to_r0_from_val_byte $SPRITE4_Z_BH
			sh2_copy_to_ptr_from_reg_word r5 r0
		) >src/f_update_slide_texture.3.o
		local sz_3=$(stat -c '%s' src/f_update_slide_texture.3.o)
		sh2_rel_jump_if_false $(two_digits_d $((sz_3 / 2)))
		sh2_nop
		cat src/f_update_slide_texture.3.o

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_update_slide_texture.2.o
	local sz_2=$(stat -c '%s' src/f_update_slide_texture.2.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_2 / 2)))
	sh2_nop
	cat src/f_update_slide_texture.2.o

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 4つの3次元座標で指定された平面を指定されたテクスチャで
# 指定されたアドレスへ描画
# in  : r1   - Ax
#       r2   - Ay
#       r3   - Az
#       r4   - Bx
#       r5   - By
#       r6   - Bz
#       r7   - Cx
#       r8   - Cy
#       r9   - Cz
#       r10  - Dx
#       r11  - Dy
#       r12  - Dz
#       r13  - キャラクタパターンテーブルのアドレス/8
#       SP+4 - キャラクタサイズ
#              - (b15-b14) = 0b00
#              - (b13-b08) = 幅/8
#              - (b07-b00) = 高さ
#       SP+0 - dst addr
# out : SP+0 - dst addrへ最後に書き込んだ次のアドレス
# work: PR   - この関数を呼び出したBSR/JSR命令のアドレス
#     : r0   - 作業用
#     : r14  - 作業用
f_draw_plate_texture() {
	local _i

	# 投影面Z座標をr14へロード
	copy_to_reg_from_val_long r14 $var_proj_z
	sh2_copy_to_reg_from_ptr_word r14 r14
	sh2_extend_unsigned_to_reg_from_reg_word r14 r14

	# 投影面Z座標(PRJz)より小さい(カメラに近い)Z座標が1つでもあれば
	# スプライト描画は行わずにreturn
	(
		# スプライトのZ座標が投影面より小さい場合の処理

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# スライドテクスチャの更新処理を行う
		copy_to_reg_from_val_long r1 $a_update_slide_texture
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0

		# 何もせずreturn
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_draw_plate_texture.1.o
	local sz_1=$(stat -c '%s' src/f_draw_plate_texture.1.o)
	## PRJz(r14) > Az(r3)?
	sh2_compare_reg_gt_reg_unsigned r14 r3
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.1.o
	## PRJz(r14) > Bz(r6)?
	sh2_compare_reg_gt_reg_unsigned r14 r6
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.1.o
	## PRJz(r14) > Cz(r9)?
	sh2_compare_reg_gt_reg_unsigned r14 r9
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.1.o
	## PRJz(r14) > Dz(r12)?
	sh2_compare_reg_gt_reg_unsigned r14 r12
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.1.o

	# 作業に使用するレジスタをスタックへ退避
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## r3
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r3
	## r4
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r4
	## r5
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r5
	## r6
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r6
	## r7
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r7

	# このスライドがVRAMにロードされているか確認
	## r1を「ロードされている(1)か否(0)か」を示すものとして使う
	## ロードされていない(0)としてr1を初期化
	sh2_xor_to_reg_from_reg r1 r1
	## r2を変数のアドレスに使う
	## 1つ目のバッファの変数のアドレスをr2へロード
	copy_to_reg_from_val_long r2 $var_slidez_texbuf1
	## 後のためにr5へコピー
	sh2_copy_to_reg_from_reg r5 r2
	## 1つ目のZ座標をr4へロード
	sh2_copy_to_reg_from_ptr_word r4 r2
	sh2_extend_unsigned_to_reg_from_reg_word r4 r4
	## r4 == r3(Az) ?
	sh2_compare_reg_eq_reg r4 r3
	## 等しくない(T==0)なら以降の処理を飛ばす
	(
		# 1 -> r1
		sh2_set_reg r1 01
	) >src/f_draw_plate_texture.9.o
	local sz_9=$(stat -c '%s' src/f_draw_plate_texture.9.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_9 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.9.o
	## r2が2つ目の変数を指すようにする
	sh2_add_to_reg_from_val_byte r2 02
	## 後のためにr6へコピー
	sh2_copy_to_reg_from_reg r6 r2
	## 2つ目のZ座標をr4へロード
	sh2_copy_to_reg_from_ptr_word r4 r2
	sh2_extend_unsigned_to_reg_from_reg_word r4 r4
	## r4 == r3(Az) ?
	sh2_compare_reg_eq_reg r4 r3
	## 等しくない(T==0)なら以降の処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $((sz_9 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.9.o
	## r2が3つ目の変数を指すようにする
	sh2_add_to_reg_from_val_byte r2 02
	## 後のためにr7へコピー
	sh2_copy_to_reg_from_reg r7 r2
	## 3つ目のZ座標をr4へロード
	sh2_copy_to_reg_from_ptr_word r4 r2
	sh2_extend_unsigned_to_reg_from_reg_word r4 r4
	## r4 == r3(Az) ?
	sh2_compare_reg_eq_reg r4 r3
	## 等しくない(T==0)なら以降の処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $((sz_9 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.9.o
	## この時、このスライドがVRAMへロードされているならr1 == 1
	## そうでないなら、r1 == 0

	# VRAMへロードされていない(r1 == 0)か?
	sh2_xor_to_reg_from_reg r0 r0
	sh2_compare_reg_eq_reg r1 r0

	# ロードされている(T==0)なら以降の処理を飛ばす
	(
		# 見切れていたスライドが見えるようになった瞬間の処理

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# r4にf_update_texture()のアドレスをロード
		copy_to_reg_from_val_long r4 $a_update_texture
		# ※ r5が1つ目の変数のアドレス、
		#    r6が2つ目の変数のアドレス、
		#    r7が3つ目の変数のアドレスを保持している

		# スライド1か?
		## スライド1のZ座標(0x0064)をr0へロード
		sh2_set_reg r0 $SPRITE1_Z_BH
		## r3(Az) == r0 ?
		sh2_compare_reg_eq_reg r3 r0
		## 等しくない(T==0)なら以降の処理を飛ばす
		(
			# 1つ目のバッファへTEXTURE1をロード
			## テクスチャ実データアドレスをr1へ設定
			copy_to_reg_from_val_long r1 $var_texture_data
			## テクスチャを配置するオフセット/8をr2へ設定
			sh2_set_reg r0 $TEXTURE1_VRAM_OFS_TH
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte $TEXTURE1_VRAM_OFS_BH
			sh2_copy_to_reg_from_reg r2 r0
			## テクスチャのピクセル数をr3へ設定
			sh2_set_reg r0 $TEXTURE_PIXEL_NUM_B23_16
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte $TEXTURE_PIXEL_NUM_B15_8
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte $TEXTURE_PIXEL_NUM_B7_0
			sh2_copy_to_reg_from_reg r3 r0
			## 関数呼び出し
			sh2_abs_call_to_reg_after_next_inst r4
			sh2_nop

			# 変数更新
			## 1つ目の変数へスプライト1のZ座標を保存
			sh2_set_reg r0 $SPRITE1_Z_BH
			sh2_copy_to_ptr_from_reg_word r5 r0
		) >src/f_draw_plate_texture.11.o
		local sz_11=$(stat -c '%s' src/f_draw_plate_texture.11.o)
		sh2_rel_jump_if_false $(two_digits_d $((sz_11 / 2)))
		sh2_nop
		cat src/f_draw_plate_texture.11.o

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_draw_plate_texture.10.o
	local sz_10=$(stat -c '%s' src/f_draw_plate_texture.10.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_10 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.10.o

	# スタックへ退避したレジスタを復帰
	## r7
	sh2_copy_to_reg_from_ptr_long r7 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r6
	sh2_copy_to_reg_from_ptr_long r6 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r5
	sh2_copy_to_reg_from_ptr_long r5 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r4
	sh2_copy_to_reg_from_ptr_long r4 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r3
	sh2_copy_to_reg_from_ptr_long r3 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04

	# 現在のPRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 透視投影で2次元座標へ変換
	# - PRJz < Az or Bz or Cz or Dz の時
	#   - 2次元座標(x, y) = 3次元座標(x, y) * PRJz / 3次元座標z
	# - PRJz == Az or Bz or Cz or Dz の時
	#   - 2次元座標(x, y) = 3次元座標(x, y)

	## PRJz(r14) == Az(r3)?
	sh2_compare_reg_eq_reg r14 r3
	(
		# PRJz(r14) < Az(r3) の時

		# r13をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r13

		# r13に除算関数のアドレスを設定
		copy_to_reg_from_val_long r13 $a_div_reg_by_reg_long_sign

		# 2次元座標Ax(r1) = 3次元座標Ax(r1) * PRJz(r14) / 3次元座標Az(r3)
		## 3次元座標Ax(r1) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r1 r14
		## MACL -> r1
		sh2_copy_to_reg_from_macl r1
		## r1 / 3次元座標Az(r3) -> r1
		### r3 -> r0
		sh2_copy_to_reg_from_reg r0 r3
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop

		# 2次元座標Ay(r2) = 3次元座標Ay(r2) * PRJz(r14) / 3次元座標Az(r3)
		## 3次元座標Ay(r2) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r2 r14
		## MACL -> r2
		sh2_copy_to_reg_from_macl r2
		## r2 / 3次元座標Az(r3) -> r2
		### r1をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r1
		### r2 -> r1
		sh2_copy_to_reg_from_reg r1 r2
		### r0には先程除算した時の除数が残っていることを想定
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r2
		sh2_copy_to_reg_from_reg r2 r1
		### r1をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r1 r15
		sh2_add_to_reg_from_val_byte r15 04

		# r13をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r13 r15
		sh2_add_to_reg_from_val_byte r15 04
	) >src/f_draw_plate_texture.2.o
	local sz_2=$(stat -c '%s' src/f_draw_plate_texture.2.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_2 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.2.o	# PRJz(r14) < Az(r3) の時
	# この時点でポリゴン描画の頂点Aの座標(Ax,Ay)を(r1,r2)へ設定完了

	## PRJz(r14) == Bz(r6)?
	sh2_compare_reg_eq_reg r14 r6
	(
		# PRJz(r14) == Bz(r6) の時

		# 2次元座標Bx(r3) = 3次元座標Bx(r4)
		sh2_copy_to_reg_from_reg r3 r4

		# 2次元座標By(r4) = 3次元座標By(r5)
		sh2_copy_to_reg_from_reg r4 r5
	) >src/f_draw_plate_texture.4.o
	(
		# PRJz(r14) < Bz(r6) の時

		# r13をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r13
		# r1をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r1

		# r13に除算関数のアドレスを設定
		copy_to_reg_from_val_long r13 $a_div_reg_by_reg_long_sign

		# 2次元座標Bx(r3) = 3次元座標Bx(r4) * PRJz(r14) / 3次元座標Bz(r6)
		## 3次元座標Bx(r4) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r4 r14
		## MACL -> r3
		sh2_copy_to_reg_from_macl r3
		## r3 / 3次元座標Bz(r6) -> r3
		### r3 -> r1
		sh2_copy_to_reg_from_reg r1 r3
		### r6 -> r0
		sh2_copy_to_reg_from_reg r0 r6
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r3
		sh2_copy_to_reg_from_reg r3 r1

		# 2次元座標By(r4) = 3次元座標By(r5) * PRJz(r14) / 3次元座標Bz(r6)
		## 3次元座標By(r5) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r5 r14
		## MACL -> r4
		sh2_copy_to_reg_from_macl r4
		## r4 / 3次元座標Bz(r6) -> r4
		### r4 -> r1
		sh2_copy_to_reg_from_reg r1 r4
		### r0には先程除算した時の除数が残っていることを想定
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r4
		sh2_copy_to_reg_from_reg r4 r1

		# r1をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r1 r15
		sh2_add_to_reg_from_val_byte r15 04
		# r13をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r13 r15
		sh2_add_to_reg_from_val_byte r15 04

		# PRJz(r14) == Bz(r6) の時の処理を飛ばす
		local sz_4=$(stat -c '%s' src/f_draw_plate_texture.4.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_4 / 2))) 3)
		sh2_nop
	) >src/f_draw_plate_texture.3.o
	local sz_3=$(stat -c '%s' src/f_draw_plate_texture.3.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_3 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.3.o	# PRJz(r14) < Bz(r6) の時
	cat src/f_draw_plate_texture.4.o	# PRJz(r14) == Bz(r6) の時
	# この時点でポリゴン描画の頂点Bの座標(Bx,By)を(r3,r4)へ設定完了

	## PRJz(r14) == Cz(r9)?
	sh2_compare_reg_eq_reg r14 r9
	(
		# PRJz(r14) == Cz(r9) の時

		# 2次元座標Cx(r5) = 3次元座標Cx(r7)
		sh2_copy_to_reg_from_reg r5 r7

		# 2次元座標Cy(r6) = 3次元座標Cy(r8)
		sh2_copy_to_reg_from_reg r6 r8
	) >src/f_draw_plate_texture.6.o
	(
		# PRJz(r14) < Cz(r9) の時

		# r13をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r13
		# r1をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r1

		# r13に除算関数のアドレスを設定
		copy_to_reg_from_val_long r13 $a_div_reg_by_reg_long_sign

		# 2次元座標Cx(r5) = 3次元座標Cx(r7) * PRJz(r14) / 3次元座標Cz(r9)
		## 3次元座標Cx(r7) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r7 r14
		## MACL -> r5
		sh2_copy_to_reg_from_macl r5
		## r5 / 3次元座標Cz(r9) -> r5
		### r5 -> r1
		sh2_copy_to_reg_from_reg r1 r5
		### r9 -> r0
		sh2_copy_to_reg_from_reg r0 r9
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r5
		sh2_copy_to_reg_from_reg r5 r1

		# 2次元座標Cy(r6) = 3次元座標Cy(r8) * PRJz(r14) / 3次元座標Cz(r9)
		## 3次元座標Cy(r8) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r8 r14
		## MACL -> r6
		sh2_copy_to_reg_from_macl r6
		## r6 / 3次元座標Cz(r9) -> r6
		### r6 -> r1
		sh2_copy_to_reg_from_reg r1 r6
		### r0には先程除算した時の除数が残っていることを想定
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r6
		sh2_copy_to_reg_from_reg r6 r1

		# r1をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r1 r15
		sh2_add_to_reg_from_val_byte r15 04
		# r13をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r13 r15
		sh2_add_to_reg_from_val_byte r15 04

		# PRJz(r14) == Cz(r9) の時の処理を飛ばす
		local sz_6=$(stat -c '%s' src/f_draw_plate_texture.6.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_6 / 2))) 3)
		sh2_nop
	) >src/f_draw_plate_texture.5.o
	local sz_5=$(stat -c '%s' src/f_draw_plate_texture.5.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_5 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.5.o	# PRJz(r14) < Bz(r9) の時
	cat src/f_draw_plate_texture.6.o	# PRJz(r14) == Bz(r9) の時
	# この時点でポリゴン描画の頂点Cの座標(Cx,Cy)を(r5,r6)へ設定完了

	## PRJz(r14) == Dz(r12)?
	sh2_compare_reg_eq_reg r14 r12
	(
		# PRJz(r14) == Dz(r12) の時

		# 2次元座標Dx(r7) = 3次元座標Dx(r10)
		sh2_copy_to_reg_from_reg r7 r10

		# 2次元座標Dy(r8) = 3次元座標Dy(r11)
		sh2_copy_to_reg_from_reg r8 r11
	) >src/f_draw_plate_texture.8.o
	(
		# PRJz(r14) < Dz(r12) の時

		# r13をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r13
		# r1をスタックへ退避
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r1

		# r13に除算関数のアドレスを設定
		copy_to_reg_from_val_long r13 $a_div_reg_by_reg_long_sign

		# 2次元座標Dx(r7) = 3次元座標Dx(r10) * PRJz(r14) / 3次元座標Dz(r12)
		## 3次元座標Dx(r10) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r10 r14
		## MACL -> r7
		sh2_copy_to_reg_from_macl r7
		## r7 / 3次元座標Dz(r12) -> r7
		### r7 -> r1
		sh2_copy_to_reg_from_reg r1 r7
		### r12 -> r0
		sh2_copy_to_reg_from_reg r0 r12
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r7
		sh2_copy_to_reg_from_reg r7 r1

		# 2次元座標Dy(r8) = 3次元座標Dy(r11) * PRJz(r14) / 3次元座標Dz(r12)
		## 3次元座標Dy(r11) * PRJz(r14) -> MACL
		sh2_multiply_reg_by_reg_signed_word r11 r14
		## MACL -> r8
		sh2_copy_to_reg_from_macl r8
		## r8 / 3次元座標Dz(r12) -> r8
		### r8 -> r1
		sh2_copy_to_reg_from_reg r1 r8
		### r0には先程除算した時の除数が残っていることを想定
		### r1 / r0 -> r1
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		### r1 -> r8
		sh2_copy_to_reg_from_reg r8 r1

		# r1をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r1 r15
		sh2_add_to_reg_from_val_byte r15 04
		# r13をスタックから復帰
		sh2_copy_to_reg_from_ptr_long r13 r15
		sh2_add_to_reg_from_val_byte r15 04

		# PRJz(r14) == Dz(r12) の時の処理を飛ばす
		local sz_8=$(stat -c '%s' src/f_draw_plate_texture.8.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_8 / 2))) 3)
		sh2_nop
	) >src/f_draw_plate_texture.7.o
	local sz_7=$(stat -c '%s' src/f_draw_plate_texture.7.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_7 / 2)))
	sh2_nop
	cat src/f_draw_plate_texture.7.o	# PRJz(r14) < Dz(r12) の時
	cat src/f_draw_plate_texture.8.o	# PRJz(r14) == Dz(r12) の時
	# この時点でポリゴン描画の頂点Dの座標(Dx,Dy)を(r7,r8)へ設定完了

	# 以上のr1-r8(Ax-Dy)は投影面座標系なので、ゲームスクリーン座標計へ変換
	transform_to_gs_from_prj r1 r2	# Ax, Ay
	transform_to_gs_from_prj r3 r4	# Bx, By
	transform_to_gs_from_prj r5 r6	# Cx, Cy
	transform_to_gs_from_prj r7 r8	# Dx, Dy

	# 引数r13のキャラクタパターンテーブルのアドレス/8をr9へ設定
	sh2_copy_to_reg_from_reg r9 r13

	# SP+8のキャラクタサイズをr10へ設定
	sh2_copy_to_reg_from_reg r10 r15
	sh2_add_to_reg_from_val_byte r10 08
	sh2_copy_to_reg_from_ptr_long r10 r10

	# SP+4のdst addrをr11へ設定
	sh2_copy_to_reg_from_reg r11 r15
	sh2_add_to_reg_from_val_byte r11 04
	sh2_copy_to_reg_from_ptr_long r11 r11

	# ポリゴン描画コマンドを配置する関数を呼び出す
	copy_to_reg_from_val_long r12 $a_put_vdp1_command_distorted_sprite_draw_to_addr
	sh2_abs_call_to_reg_after_next_inst r12
	sh2_nop

	# PRをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0

	# SP+0のdst addrをr11で更新
	sh2_copy_to_ptr_from_reg_long r15 r11

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# ポリゴン描画コマンドの更新
# out : r1  - 次にコマンドを配置するVRAMアドレス
# ※ 描画終了コマンドの配置は行わないので
#    この関数から戻った後、描画終了コマンドを配置すること
f_update_polygon() {
	# 現在のPRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 次にコマンドを配置するVRAMアドレスをスタックに積む
	copy_to_reg_from_val_long r1 $VRAM_DRAW_CMD_BASE
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1

	# 05c00060
	# 上面ポリゴン
	## 六面体上面の4頂点の3次元座標をレジスタへロード
	### 頂点座標が並ぶ領域の先頭アドレスをr14へロード
	copy_to_reg_from_val_long r14 $var_hexahedron_base
	### Ex -> r1
	sh2_add_to_reg_from_val_byte r14 $ofs_hexahedron_ex
	sh2_copy_to_reg_from_ptr_word r1 r14
	### Ey -> r2
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r2 r14
	### Ez -> r3
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r3 r14
	### Fx -> r4
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r4 r14
	### Fy -> r5
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r5 r14
	### Fz -> r6
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r6 r14
	### Bx -> r7
	sh2_add_to_reg_from_val_byte r14 $(two_comp $(calc16_2 "${ofs_hexahedron_fz}-${ofs_hexahedron_bx}"))
	sh2_copy_to_reg_from_ptr_word r7 r14
	### By -> r8
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r8 r14
	### Bz -> r9
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r9 r14
	### Ax -> r10
	sh2_add_to_reg_from_val_byte r14 $(two_comp $(calc16_2 "${ofs_hexahedron_bz}-${ofs_hexahedron_ax}"))
	sh2_copy_to_reg_from_ptr_word r10 r14
	### Ay -> r11
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r11 r14
	### Az -> r12
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r12 r14
	## 描画カラーをr13へ設定
	### 0xffff -> r13
	sh2_set_reg r13 ff
	## 描画関数呼び出し
	copy_to_reg_from_val_long r14 $a_draw_plate
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 05c00080
	# 側面ポリゴン
	## 六面体左側面の4頂点の3次元座標をレジスタへロード
	### 頂点座標が並ぶ領域の先頭アドレスをr14へロード
	copy_to_reg_from_val_long r14 $var_hexahedron_base
	### Ex -> r1
	sh2_add_to_reg_from_val_byte r14 $ofs_hexahedron_ex
	sh2_copy_to_reg_from_ptr_word r1 r14
	### Ey -> r2
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r2 r14
	### Ez -> r3
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r3 r14
	### Ax -> r4
	sh2_add_to_reg_from_val_byte r14 $(two_comp $ofs_hexahedron_ez)
	sh2_copy_to_reg_from_ptr_word r4 r14
	### Ay -> r5
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r5 r14
	### Az -> r6
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r6 r14
	### Dx -> r7
	sh2_add_to_reg_from_val_byte r14 $(calc16_2 "${ofs_hexahedron_dx}-${ofs_hexahedron_az}")
	sh2_copy_to_reg_from_ptr_word r7 r14
	### Dy -> r8
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r8 r14
	### Dz -> r9
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r9 r14
	### Hx -> r10
	sh2_add_to_reg_from_val_byte r14 $(calc16_2 "${ofs_hexahedron_hx}-${ofs_hexahedron_dz}")
	sh2_copy_to_reg_from_ptr_word r10 r14
	### Hy -> r11
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r11 r14
	### Hz -> r12
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r12 r14
	## 描画カラーをr13へ設定
	### 0xbded -> r13
	sh2_set_reg r0 bd
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ed
	sh2_copy_to_reg_from_reg r13 r0
	## 描画関数呼び出し
	copy_to_reg_from_val_long r14 $a_draw_plate
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 05c000a0
	# 正面ポリゴン
	## 六面体正面の4頂点の3次元座標をレジスタへロード
	### 頂点座標が並ぶ領域の先頭アドレスをr14へロード
	copy_to_reg_from_val_long r14 $var_hexahedron_base
	### Ax -> r1
	sh2_copy_to_reg_from_ptr_word r1 r14
	### Ay -> r2
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r2 r14
	### Az -> r3
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r3 r14
	### Bx -> r4
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r4 r14
	### By -> r5
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r5 r14
	### Bz -> r6
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r6 r14
	### Cx -> r7
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r7 r14
	### Cy -> r8
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r8 r14
	### Cz -> r9
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r9 r14
	### Dx -> r10
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r10 r14
	### Dy -> r11
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r11 r14
	### Dz -> r12
	sh2_add_to_reg_from_val_byte r14 02
	sh2_copy_to_reg_from_ptr_word r12 r14
	## 描画カラーをr13へ設定
	### 0xffdb -> r13
	sh2_set_reg r13 db
	## 描画関数呼び出し
	copy_to_reg_from_val_long r14 $a_draw_plate
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 次にコマンドを配置するVRAMアドレスをr1(戻り値)へ設定
	sh2_copy_to_reg_from_ptr_long r1 r15

	# 次にコマンドを配置するVRAMアドレスをスタックから破棄
	sh2_add_to_reg_from_val_byte r15 04

	# PRをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# スライド4の描画処理
# ※ f_update_sprite()から呼ばれる用の関数
# in  : r1  - 次にコマンドを配置するVRAMアドレス
# out : r1  - 次にコマンドを配置するVRAMアドレス
f_draw_slide4() {
	# 現在のPRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# f_draw_plate_texture()の引数設定
	## SP+4 - キャラクタサイズ
	##        - (b15-b14) = 0b00
	##        - (b13-b08) = 幅/8
	##        - (b07-b00) = 高さ
	copy_to_reg_from_val_long r2 $var_texture4_size
	sh2_copy_to_reg_from_ptr_word r2 r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## SP+0 - dst addr
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r1   - Ax
	copy_to_reg_from_val_long r1 $var_sprite4_ax
	sh2_copy_to_reg_from_ptr_word r1 r1
	## r2   - Ay
	copy_to_reg_from_val_long r2 $var_sprite4_ay
	sh2_copy_to_reg_from_ptr_word r2 r2
	## r3   - Az
	copy_to_reg_from_val_long r3 $var_sprite4_az
	sh2_copy_to_reg_from_ptr_word r3 r3
	## r4   - Bx
	copy_to_reg_from_val_long r4 $var_sprite4_bx
	sh2_copy_to_reg_from_ptr_word r4 r4
	## r5   - By
	copy_to_reg_from_val_long r5 $var_sprite4_by
	sh2_copy_to_reg_from_ptr_word r5 r5
	## r6   - Bz
	copy_to_reg_from_val_long r6 $var_sprite4_bz
	sh2_copy_to_reg_from_ptr_word r6 r6
	## r7   - Cx
	copy_to_reg_from_val_long r7 $var_sprite4_cx
	sh2_copy_to_reg_from_ptr_word r7 r7
	## r8   - Cy
	copy_to_reg_from_val_long r8 $var_sprite4_cy
	sh2_copy_to_reg_from_ptr_word r8 r8
	## r9   - Cz
	copy_to_reg_from_val_long r9 $var_sprite4_cz
	sh2_copy_to_reg_from_ptr_word r9 r9
	## r10  - Dx
	copy_to_reg_from_val_long r10 $var_sprite4_dx
	sh2_copy_to_reg_from_ptr_word r10 r10
	## r11  - Dy
	copy_to_reg_from_val_long r11 $var_sprite4_dy
	sh2_copy_to_reg_from_ptr_word r11 r11
	## r12  - Dz
	copy_to_reg_from_val_long r12 $var_sprite4_dz
	sh2_copy_to_reg_from_ptr_word r12 r12
	## r13  - キャラクタパターンテーブルのアドレス/8
	copy_to_reg_from_val_long r13 $var_texture4_ofs
	sh2_copy_to_reg_from_ptr_word r13 r13

	# f_draw_plate_texture()を呼び出す
	copy_to_reg_from_val_long r14 $a_draw_plate_texture
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# dst addrをpopし、戻り値としてr1へ設定
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04

	# キャラクタサイズをpop
	sh2_add_to_reg_from_val_byte r15 04

	# PRをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# スライド3の描画処理
# ※ f_update_sprite()から呼ばれる用の関数
# in  : r1  - 次にコマンドを配置するVRAMアドレス
# out : r1  - 次にコマンドを配置するVRAMアドレス
f_draw_slide3() {
	# 現在のPRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# f_draw_plate_texture()の引数設定
	## SP+4 - キャラクタサイズ
	##        - (b15-b14) = 0b00
	##        - (b13-b08) = 幅/8
	##        - (b07-b00) = 高さ
	copy_to_reg_from_val_long r2 $var_texture3_size
	sh2_copy_to_reg_from_ptr_word r2 r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## SP+0 - dst addr
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r1   - Ax
	copy_to_reg_from_val_long r1 $var_sprite3_ax
	sh2_copy_to_reg_from_ptr_word r1 r1
	## r2   - Ay
	copy_to_reg_from_val_long r2 $var_sprite3_ay
	sh2_copy_to_reg_from_ptr_word r2 r2
	## r3   - Az
	copy_to_reg_from_val_long r3 $var_sprite3_az
	sh2_copy_to_reg_from_ptr_word r3 r3
	## r4   - Bx
	copy_to_reg_from_val_long r4 $var_sprite3_bx
	sh2_copy_to_reg_from_ptr_word r4 r4
	## r5   - By
	copy_to_reg_from_val_long r5 $var_sprite3_by
	sh2_copy_to_reg_from_ptr_word r5 r5
	## r6   - Bz
	copy_to_reg_from_val_long r6 $var_sprite3_bz
	sh2_copy_to_reg_from_ptr_word r6 r6
	## r7   - Cx
	copy_to_reg_from_val_long r7 $var_sprite3_cx
	sh2_copy_to_reg_from_ptr_word r7 r7
	## r8   - Cy
	copy_to_reg_from_val_long r8 $var_sprite3_cy
	sh2_copy_to_reg_from_ptr_word r8 r8
	## r9   - Cz
	copy_to_reg_from_val_long r9 $var_sprite3_cz
	sh2_copy_to_reg_from_ptr_word r9 r9
	## r10  - Dx
	copy_to_reg_from_val_long r10 $var_sprite3_dx
	sh2_copy_to_reg_from_ptr_word r10 r10
	## r11  - Dy
	copy_to_reg_from_val_long r11 $var_sprite3_dy
	sh2_copy_to_reg_from_ptr_word r11 r11
	## r12  - Dz
	copy_to_reg_from_val_long r12 $var_sprite3_dz
	sh2_copy_to_reg_from_ptr_word r12 r12
	## r13  - キャラクタパターンテーブルのアドレス/8
	copy_to_reg_from_val_long r13 $var_texture3_ofs
	sh2_copy_to_reg_from_ptr_word r13 r13

	# f_draw_plate_texture()を呼び出す
	copy_to_reg_from_val_long r14 $a_draw_plate_texture
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# dst addrをpopし、戻り値としてr1へ設定
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04

	# キャラクタサイズをpop
	sh2_add_to_reg_from_val_byte r15 04

	# PRをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# スプライト描画コマンドの更新
# in  : r1  - 次にコマンドを配置するVRAMアドレス
# out : r1  - 次にコマンドを配置するVRAMアドレス
# work: r0  - 作業用
# ※ 描画終了コマンドの配置は行わないので
#    この関数から戻った後、描画終了コマンドを配置すること
f_update_sprite() {
	# 現在のPRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# TEXTURE4_IMG
	# PRJzが一つ手前の画像より小さいか?
	# PRJz <= TEXTURE3のZ座標 だったら、TEXTURE4描画処理は飛ばす
	## PRJzをr2へロード
	copy_to_reg_from_val_long r2 $var_proj_z
	sh2_copy_to_reg_from_ptr_word r2 r2
	## TEXTURE3のZ座標をr0へロード
	sh2_xor_to_reg_from_reg r0 r0
	sh2_or_to_r0_from_val_byte $SPRITE3_Z_BH
	## r0(TEXTURE3) >= r2(PRJz) ?
	sh2_compare_reg_ge_reg_signed r0 r2
	## Trueだったら、TEXTURE4描画処理を飛ばす
	(
		# 描画関数を呼び出す
		copy_to_reg_from_val_long r2 $a_draw_slide4
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_nop
	) >src/f_update_sprite.2.o
	local sz_2=$(stat -c '%s' src/f_update_sprite.2.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_2 / 2)))
	sh2_nop
	cat src/f_update_sprite.2.o

	# TEXTURE3_IMG
	# PRJzが一つ手前の画像より小さいか?
	# PRJz <= TEXTURE2のZ座標 だったら、TEXTURE3描画処理は飛ばす
	## PRJzをr2へロード
	copy_to_reg_from_val_long r2 $var_proj_z
	sh2_copy_to_reg_from_ptr_word r2 r2
	## TEXTURE2のZ座標をr0へロード
	sh2_xor_to_reg_from_reg r0 r0
	sh2_or_to_r0_from_val_byte $SPRITE2_Z_BH
	## r0(TEXTURE2) >= r2(PRJz) ?
	sh2_compare_reg_ge_reg_signed r0 r2
	## Trueだったら、TEXTURE3描画処理を飛ばす
	(
		# 描画関数を呼び出す
		copy_to_reg_from_val_long r2 $a_draw_slide3
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_nop
	) >src/f_update_sprite.3.o
	local sz_3=$(stat -c '%s' src/f_update_sprite.3.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_3 / 2)))
	sh2_nop
	cat src/f_update_sprite.3.o

	# 描画終了を待つ
	(
		# r2へEDSRのアドレスを取得
		copy_to_reg_from_val_long r2 $SS_VDP1_EDSR_ADDR
		# r2の指す先(EDSRの内容)をr0へ取得
		sh2_copy_to_reg_from_ptr_word r0 r2
		sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
	) >src/f_update_sprite.1.o
	cat src/f_update_sprite.1.o
	local sz_1=$(stat -c '%s' src/f_update_sprite.1.o)
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	sh2_nop
	## 論理積結果がゼロのとき、
	## 即ちTビットがセットされたとき、
	## 待つ処理を繰り返す

	# TEXTURE2_IMG
	# f_draw_plate_texture()の引数設定
	## SP+4 - キャラクタサイズ
	##        - (b15-b14) = 0b00
	##        - (b13-b08) = 幅/8
	##        - (b07-b00) = 高さ
	copy_to_reg_from_val_long r2 $var_texture2_size
	sh2_copy_to_reg_from_ptr_word r2 r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## SP+0 - dst addr
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r1   - Ax
	copy_to_reg_from_val_long r1 $var_sprite2_ax
	sh2_copy_to_reg_from_ptr_word r1 r1
	## r2   - Ay
	copy_to_reg_from_val_long r2 $var_sprite2_ay
	sh2_copy_to_reg_from_ptr_word r2 r2
	## r3   - Az
	copy_to_reg_from_val_long r3 $var_sprite2_az
	sh2_copy_to_reg_from_ptr_word r3 r3
	## r4   - Bx
	copy_to_reg_from_val_long r4 $var_sprite2_bx
	sh2_copy_to_reg_from_ptr_word r4 r4
	## r5   - By
	copy_to_reg_from_val_long r5 $var_sprite2_by
	sh2_copy_to_reg_from_ptr_word r5 r5
	## r6   - Bz
	copy_to_reg_from_val_long r6 $var_sprite2_bz
	sh2_copy_to_reg_from_ptr_word r6 r6
	## r7   - Cx
	copy_to_reg_from_val_long r7 $var_sprite2_cx
	sh2_copy_to_reg_from_ptr_word r7 r7
	## r8   - Cy
	copy_to_reg_from_val_long r8 $var_sprite2_cy
	sh2_copy_to_reg_from_ptr_word r8 r8
	## r9   - Cz
	copy_to_reg_from_val_long r9 $var_sprite2_cz
	sh2_copy_to_reg_from_ptr_word r9 r9
	## r10  - Dx
	copy_to_reg_from_val_long r10 $var_sprite2_dx
	sh2_copy_to_reg_from_ptr_word r10 r10
	## r11  - Dy
	copy_to_reg_from_val_long r11 $var_sprite2_dy
	sh2_copy_to_reg_from_ptr_word r11 r11
	## r12  - Dz
	copy_to_reg_from_val_long r12 $var_sprite2_dz
	sh2_copy_to_reg_from_ptr_word r12 r12
	## r13  - キャラクタパターンテーブルのアドレス/8
	copy_to_reg_from_val_long r13 $var_texture2_ofs
	sh2_copy_to_reg_from_ptr_word r13 r13

	# f_draw_plate_texture()を呼び出す
	copy_to_reg_from_val_long r14 $a_draw_plate_texture
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# TEXTURE1_IMG
	# f_draw_plate_texture()の引数設定
	## SP+4 - キャラクタサイズ
	## 変わらないのでそのまま
	## SP+0 - dst addr
	## 次のアドレスが格納されているのでこのまま
	## r1   - Ax
	copy_to_reg_from_val_long r1 $var_sprite_ax
	sh2_copy_to_reg_from_ptr_word r1 r1
	## r2   - Ay
	copy_to_reg_from_val_long r2 $var_sprite_ay
	sh2_copy_to_reg_from_ptr_word r2 r2
	## r3   - Az
	copy_to_reg_from_val_long r3 $var_sprite_az
	sh2_copy_to_reg_from_ptr_word r3 r3
	## r4   - Bx
	copy_to_reg_from_val_long r4 $var_sprite_bx
	sh2_copy_to_reg_from_ptr_word r4 r4
	## r5   - By
	copy_to_reg_from_val_long r5 $var_sprite_by
	sh2_copy_to_reg_from_ptr_word r5 r5
	## r6   - Bz
	copy_to_reg_from_val_long r6 $var_sprite_bz
	sh2_copy_to_reg_from_ptr_word r6 r6
	## r7   - Cx
	copy_to_reg_from_val_long r7 $var_sprite_cx
	sh2_copy_to_reg_from_ptr_word r7 r7
	## r8   - Cy
	copy_to_reg_from_val_long r8 $var_sprite_cy
	sh2_copy_to_reg_from_ptr_word r8 r8
	## r9   - Cz
	copy_to_reg_from_val_long r9 $var_sprite_cz
	sh2_copy_to_reg_from_ptr_word r9 r9
	## r10  - Dx
	copy_to_reg_from_val_long r10 $var_sprite_dx
	sh2_copy_to_reg_from_ptr_word r10 r10
	## r11  - Dy
	copy_to_reg_from_val_long r11 $var_sprite_dy
	sh2_copy_to_reg_from_ptr_word r11 r11
	## r12  - Dz
	copy_to_reg_from_val_long r12 $var_sprite_dz
	sh2_copy_to_reg_from_ptr_word r12 r12
	## r13  - キャラクタパターンテーブルのアドレス/8
	copy_to_reg_from_val_long r13 $var_texture_ofs
	sh2_copy_to_reg_from_ptr_word r13 r13

	# f_draw_plate_texture()を呼び出す
	copy_to_reg_from_val_long r14 $a_draw_plate_texture
	# r14 = 060FA93C = a_draw_plate_texture
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 次にコマンドを配置するVRAMアドレスを
	# スタックからpopしてr1へセット
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04

	# キャラクタサイズをスタックからpop
	sh2_add_to_reg_from_val_byte r15 04

	# PRをスタックから復帰
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 全頂点のX座標へ指定された値を加算する関数
# in  : r2 - 加算する値
# work: r0 - 作業用
#     : r3 - 作業用
# ※ r1を変更しないこと
#    (呼び出し元で押下状態を格納している)
f_add_reg_to_all_vertices_x() {
	# 頂点座標値が並ぶ領域の先頭アドレスをr3へ設定
	copy_to_reg_from_val_long r3 $var_hexahedron_base

	# 全頂点のX座標へ加算
	local i
	for i in A B C D E F G H; do
		if [ "$i" != "A" ]; then
			# アドレスを進める
			sh2_add_to_reg_from_val_byte r3 06
		fi
		# 変数をr0へロード
		sh2_copy_to_reg_from_ptr_word r0 r3
		# r0へr2を加算
		sh2_add_to_reg_from_reg r0 r2
		# r0を変数へ書き戻す
		sh2_copy_to_ptr_from_reg_word r3 r0
	done

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 全頂点をY軸(Z-X平面)で指定された角度右回転
# in  : r2 - 回転角度[°]
# work: r0 - 作業用
#     : r3 - 作業用(X座標のアドレス)
#     : r4 - 作業用(X座標の値, xsinθ)
#     : r5 - 作業用(xcosθ)
#     : r6 - 作業用(Z座標のアドレス)
#     : r7 - 作業用(Z座標の値, zcosθ)
#     : r8 - 作業用(zsinθ)
# ※ r1を変更しないこと
#    (呼び出し元で押下状態を格納している)
f_rotate_right_reg_about_yaxis_to_all_vertices() {
	# 頂点座標値が並ぶ領域の先頭アドレスをr3へ設定
	copy_to_reg_from_val_long r3 $var_hexahedron_base

	# 全頂点をY軸で回転
	local i
	for i in A B C D E F G H; do
		# 回転後のX座標を取得
		# x' = xcosθ + zsinθ
		## X座標をr4へロード
		sh2_copy_to_reg_from_ptr_word r4 r3
		## x * cosθをr5へ取得
		sh2_copy_to_reg_from_reg r5 r4
		multiply_reg_by_costheta_signed_long r5 r2 r3 r4 r6
		## Z座標のアドレスをr6へロード
		sh2_copy_to_reg_from_reg r6 r3
		sh2_add_to_reg_from_val_byte r6 04
		## Z座標をr7へロード
		sh2_copy_to_reg_from_ptr_word r7 r6
		## z * sinθをr8へ取得
		sh2_copy_to_reg_from_reg r8 r7
		multiply_reg_by_sintheta_signed_long r8 r2 r3 r4 r5
		## r5(xcosθ) + r8(zsinθ)をr0へ取得
		sh2_copy_to_reg_from_reg r0 r5
		sh2_add_to_reg_from_reg r0 r8
		## x'(r0)でX座標(r3の指す先)を更新
		sh2_copy_to_ptr_from_reg_word r3 r0

		# 回転後のZ座標を取得
		# z' = zcosθ - xsinθ
		## z * cosθをr7へ取得
		multiply_reg_by_costheta_signed_long r7 r2 r3 r4 r5
		## x * sinθをr4へ取得
		multiply_reg_by_sintheta_signed_long r4 r2 r3 r5 r6
		## r7(zcosθ) - r4(xsinθ)をr7へ取得
		sh2_sub_to_reg_from_reg r7 r4
		## z'(r7)でZ座標(r6の指す先)を更新
		sh2_copy_to_ptr_from_reg_word r6 r7

		# アドレスを進める
		if [ "$i" != "H" ]; then
			sh2_add_to_reg_from_val_byte r3 06
		fi
	done

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 全頂点をY軸(Z-X平面)で指定された角度左回転
# in  : r2 - 回転角度[°]
# work: r0 - 作業用
#     : r3 - 作業用(Y軸旋回角度のアドレス)
#     : r4 - 作業用(Y軸旋回角度の値)
#     : r5 - 作業用
#     : r6 - 作業用
#     : r7 - 作業用
#     : r8 - 作業用
# ※ r1を変更しないこと
#    (呼び出し元で押下状態を格納している)
f_rotate_left_reg_about_yaxis_to_all_vertices() {
	# Y軸旋回角度へ回転角度を加算
	## 変数のアドレスをr3へ設定
	copy_to_reg_from_val_long r3 $var_rotation_angle_y
	## Y軸旋回角度をr4へロード
	sh2_copy_to_reg_from_ptr_word r4 r3
	## r4へ回転角度r2を加算
	sh2_add_to_reg_from_reg r4 r2
	## r4 >= 360(0x0168) ?
	sh2_set_reg r0 01
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte 68
	sh2_compare_reg_ge_reg_unsigned r4 r0
	## falseだったら後続処理を飛ばす
	(
		# r4 -= 360(0x0168)
		sh2_sub_to_reg_from_reg r4 r0
	) >src/f_rotate_left_reg_about_yaxis_to_all_vertices.1.o
	local sz_1=$(stat -c '%s' src/f_rotate_left_reg_about_yaxis_to_all_vertices.1.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_1 / 2)))
	sh2_nop
	cat src/f_rotate_left_reg_about_yaxis_to_all_vertices.1.o
	## r4を変数へ書き戻す
	sh2_copy_to_ptr_from_reg_word r3 r4

	# 頂点座標値が並ぶ領域の先頭アドレスをr3へ設定
	copy_to_reg_from_val_long r3 $var_hexahedron_base

	# 全頂点をY軸で回転
	local i
	for i in A B C D E F G H; do
		# 原点から頂点への距離rをr5へ取得
		## X座標をr5へロード
		sh2_copy_to_reg_from_ptr_word r5 r3
		## Z座標のアドレスをr6へロード
		sh2_copy_to_reg_from_reg r6 r3
		sh2_add_to_reg_from_val_byte r6 04
		## Z座標をr7へロード
		sh2_copy_to_reg_from_ptr_word r7 r6
		## 距離算出の関数を呼び出す
		copy_to_reg_from_val_long r8 $a_calc_distance_2d
		sh2_abs_call_to_reg_after_next_inst r8
		sh2_nop

		# 回転後の座標を取得
		## 距離rをr8へもコピー
		sh2_copy_to_reg_from_reg r8 r5
		## x' = r * cosθ
		multiply_reg_by_costheta_signed_long r5 r2 r1 r3 r4
		sh2_copy_to_ptr_from_reg_word r3 r5
		## z' = r * sinθ
		multiply_reg_by_sintheta_signed_long r8 r2 r1 r3 r4
		sh2_copy_to_ptr_from_reg_word r6 r8

		# アドレスを進める
		if [ "$i" != "H" ]; then
			sh2_add_to_reg_from_val_byte r3 06
		fi
	done

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 頂点座標更新
## 頂点座標更新周期
COORD_UPDATE_CYC=0a
f_update_vertex_coordinates() {
	# Vブランク周期での座標更新だと反応が良すぎるので鈍らせる
	## 座標更新周期カウンタ変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_coord_update_cyc_counter
	## 変数の値をr0へロード
	sh2_copy_to_reg_from_ptr_byte r0 r1
	## 変数の値が周期と等しいか?
	sh2_set_reg r2 $COORD_UPDATE_CYC
	sh2_compare_reg_eq_reg r0 r2
	(
		# var_coord_update_cyc_counter != COORD_UPDATE_CYC の場合

		# 変数の値をインクリメント
		sh2_add_to_reg_from_val_byte r0 01
		# 変数の値を書き戻す
		sh2_copy_to_ptr_from_reg_byte r1 r0
		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_update_vertex_coordinates.5.o
	local sz_5=$(stat -c '%s' src/f_update_vertex_coordinates.5.o)
	sh2_rel_jump_if_true $(two_digits_d $((sz_5 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.5.o
	## var_coord_update_cyc_counter == COORD_UPDATE_CYC の場合
	### 変数の値をゼロクリア
	sh2_set_reg r0 00
	### 変数の値を書き戻す
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# 現在の押下状態1をr1へロード
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_1
	## アドレスが指す先の値をr1へロード
	sh2_copy_to_reg_from_ptr_byte r1 r1

	# ↓の押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_DOWN
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 投影面Z座標をデクリメント(カメラ後退)

		# 変数のアドレスをr2へロード
		copy_to_reg_from_val_long r2 $var_proj_z

		# 座標値をr3へロード
		sh2_copy_to_reg_from_ptr_word r3 r2

		# 座標値をデクリメント
		sh2_add_to_reg_from_val_byte r3 $(two_comp_d 1)

		# 座標値を変数へ書き戻す
		sh2_copy_to_ptr_from_reg_word r2 r3
	) >src/f_update_vertex_coordinates.3.o
	local sz_3=$(stat -c '%s' src/f_update_vertex_coordinates.3.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_3 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.3.o

	# ↑の押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_UP
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 投影面Z座標をインクリメント(カメラ前進)

		# 変数のアドレスをr2へロード
		copy_to_reg_from_val_long r2 $var_proj_z

		# 座標値をr3へロード
		sh2_copy_to_reg_from_ptr_word r3 r2

		# 座標値をインクリメント
		sh2_add_to_reg_from_val_byte r3 01

		# 座標値を変数へ書き戻す
		sh2_copy_to_ptr_from_reg_word r2 r3
	) >src/f_update_vertex_coordinates.4.o
	local sz_4=$(stat -c '%s' src/f_update_vertex_coordinates.4.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_4 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.4.o

	# ←の押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_LEFT
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 全頂点のX座標をインクリメント(左移動)

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# 各頂点X座標へ加算する値(0x01)をr2へ設定
		sh2_set_reg r2 01

		# 全頂点のX座標へ指定された値を加算する関数を呼び出す
		copy_to_reg_from_val_long r3 $a_add_reg_to_all_vertices_x
		sh2_abs_call_to_reg_after_next_inst r3
		sh2_nop

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_update_vertex_coordinates.6.o
	local sz_6=$(stat -c '%s' src/f_update_vertex_coordinates.6.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_6 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.6.o

	# →の押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_RIGHT
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 全頂点のX座標をデクリメント(右移動)

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# 各頂点X座標へ加算する値(0x01)をr2へ設定
		sh2_set_reg r2 $(two_comp_d 1)

		# 全頂点のX座標へ指定された値を加算する関数を呼び出す
		copy_to_reg_from_val_long r3 $a_add_reg_to_all_vertices_x
		sh2_abs_call_to_reg_after_next_inst r3
		sh2_nop

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_update_vertex_coordinates.7.o
	local sz_7=$(stat -c '%s' src/f_update_vertex_coordinates.7.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_7 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.7.o

	# 現在の押下状態2をr1へロード
	## 変数のアドレスをr1へロード
	copy_to_reg_from_val_long r1 $var_pad_current_state_2
	## アドレスが指す先の値をr1へロード
	sh2_copy_to_reg_from_ptr_byte r1 r1

	# Lの押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_L
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 全頂点をY軸で右回転

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# 回転角度をr2へ設定
		sh2_set_reg r2 01

		# 全頂点を右回転する関数を呼び出す
		copy_to_reg_from_val_long r3 $a_rotate_right_reg_about_yaxis_to_all_vertices
		sh2_abs_call_to_reg_after_next_inst r3
		sh2_nop

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_update_vertex_coordinates.8.o
	local sz_8=$(stat -c '%s' src/f_update_vertex_coordinates.8.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_8 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.8.o

	# Rの押下確認
	sh2_copy_to_reg_from_reg r0 r1
	sh2_test_r0_and_val_byte $SS_SMPC_PAD_STATE_BIT_R
	## 押下されていないとき、論理積の結果がゼロでなく、
	## Tビットがクリアされる(false)
	## その場合、座標更新処理を飛ばす
	(
		# 全頂点をY軸で左回転

		# 現在のPRをスタックへ退避
		sh2_copy_to_reg_from_pr r0
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r0

		# 回転角度をr2へ設定
		sh2_set_reg r2 01

		# 全頂点を左回転する関数を呼び出す
		copy_to_reg_from_val_long r3 $a_rotate_left_reg_about_yaxis_to_all_vertices
		sh2_abs_call_to_reg_after_next_inst r3
		sh2_nop

		# PRをスタックから復帰
		sh2_copy_to_reg_from_ptr_long r0 r15
		sh2_add_to_reg_from_val_byte r15 04
		sh2_copy_to_pr_from_reg r0
	) >src/f_update_vertex_coordinates.9.o
	local sz_9=$(stat -c '%s' src/f_update_vertex_coordinates.9.o)
	sh2_rel_jump_if_false $(two_digits_d $((sz_9 / 2)))
	sh2_nop
	cat src/f_update_vertex_coordinates.9.o

	# return
	sh2_return_after_next_inst
	sh2_nop
}

debug 'before: funcs()'

funcs() {
	local fsz

	# 符号付き32ビット除算
	a_div_reg_by_reg_long_sign=$FUNCS_BASE
	echo -e "a_div_reg_by_reg_long_sign=$a_div_reg_by_reg_long_sign" >>$map_file
	f_div_reg_by_reg_long_sign >src/f_div_reg_by_reg_long_sign.o
	cat src/f_div_reg_by_reg_long_sign.o

	# ゲームパッドの入力状態更新
	fsz=$(to16 $(stat -c '%s' src/f_div_reg_by_reg_long_sign.o))
	a_update_gamepad_input_status=$(calc16_8 "${a_div_reg_by_reg_long_sign}+${fsz}")
	echo -e "a_update_gamepad_input_status=$a_update_gamepad_input_status" >>$map_file
	f_update_gamepad_input_status >src/f_update_gamepad_input_status.o
	cat src/f_update_gamepad_input_status.o

	# 指定された2次元座標の原点からの距離を算出
	fsz=$(to16 $(stat -c '%s' src/f_update_gamepad_input_status.o))
	a_calc_distance_2d=$(calc16_8 "${a_update_gamepad_input_status}+${fsz}")
	echo -e "a_calc_distance_2d=$a_calc_distance_2d" >>$map_file
	f_calc_distance_2d >src/f_calc_distance_2d.o
	cat src/f_calc_distance_2d.o

	# 指定された4頂点・カラーの変形スプライトを描画するコマンドを
	# 指定されたアドレスへ配置
	fsz=$(to16 $(stat -c '%s' src/f_calc_distance_2d.o))
	a_put_vdp1_command_distorted_sprite_draw_to_addr=$(calc16_8 "${a_calc_distance_2d}+${fsz}")
	echo -e "a_put_vdp1_command_distorted_sprite_draw_to_addr=$a_put_vdp1_command_distorted_sprite_draw_to_addr" >>$map_file
	f_put_vdp1_command_distorted_sprite_draw_to_addr >src/f_put_vdp1_command_distorted_sprite_draw_to_addr.o
	cat src/f_put_vdp1_command_distorted_sprite_draw_to_addr.o

	# 指定された4頂点・カラーのポリゴンを描画するコマンドを
	# 指定されたアドレスへ配置
	fsz=$(to16 $(stat -c '%s' src/f_put_vdp1_command_distorted_sprite_draw_to_addr.o))
	a_put_vdp1_command_polygon_draw_to_addr=$(calc16_8 "${a_put_vdp1_command_distorted_sprite_draw_to_addr}+${fsz}")
	echo -e "a_put_vdp1_command_polygon_draw_to_addr=$a_put_vdp1_command_polygon_draw_to_addr" >>$map_file
	f_put_vdp1_command_polygon_draw_to_addr >src/f_put_vdp1_command_polygon_draw_to_addr.o
	cat src/f_put_vdp1_command_polygon_draw_to_addr.o

	# 4つの3次元座標で指定された平面を指定されたカラーで
	# 指定されたアドレスへ描画
	fsz=$(to16 $(stat -c '%s' src/f_put_vdp1_command_polygon_draw_to_addr.o))
	a_draw_plate=$(calc16_8 "${a_put_vdp1_command_polygon_draw_to_addr}+${fsz}")
	echo -e "a_draw_plate=$a_draw_plate" >>$map_file
	f_draw_plate >src/f_draw_plate.o
	cat src/f_draw_plate.o

	# テクスチャ画像データの更新
	fsz=$(to16 $(stat -c '%s' src/f_draw_plate.o))
	a_update_texture=$(calc16_8 "${a_draw_plate}+${fsz}")
	echo -e "a_update_texture=$a_update_texture" >>$map_file
	f_update_texture >src/f_update_texture.o
	cat src/f_update_texture.o

	# スライドテクスチャの更新処理
	fsz=$(to16 $(stat -c '%s' src/f_update_texture.o))
	a_update_slide_texture=$(calc16_8 "${a_update_texture}+${fsz}")
	echo -e "a_update_slide_texture=$a_update_slide_texture" >>$map_file
	f_update_slide_texture >src/f_update_slide_texture.o
	cat src/f_update_slide_texture.o

	# 4つの3次元座標で指定された平面を指定されたテクスチャで
	# 指定されたアドレスへ描画
	fsz=$(to16 $(stat -c '%s' src/f_update_slide_texture.o))
	a_draw_plate_texture=$(calc16_8 "${a_update_slide_texture}+${fsz}")
	echo -e "a_draw_plate_texture=$a_draw_plate_texture" >>$map_file
	f_draw_plate_texture >src/f_draw_plate_texture.o
	cat src/f_draw_plate_texture.o

	# ポリゴン描画コマンドの更新
	fsz=$(to16 $(stat -c '%s' src/f_draw_plate_texture.o))
	a_update_polygon=$(calc16_8 "${a_draw_plate_texture}+${fsz}")
	echo -e "a_update_polygon=$a_update_polygon" >>$map_file
	f_update_polygon >src/f_update_polygon.o
	cat src/f_update_polygon.o

	# スライド4の描画処理
	fsz=$(to16 $(stat -c '%s' src/f_update_polygon.o))
	a_draw_slide4=$(calc16_8 "${a_update_polygon}+${fsz}")
	echo -e "a_draw_slide4=$a_draw_slide4" >>$map_file
	f_draw_slide4 >src/f_draw_slide4.o
	cat src/f_draw_slide4.o

	# スライド3の描画処理
	fsz=$(to16 $(stat -c '%s' src/f_draw_slide4.o))
	a_draw_slide3=$(calc16_8 "${a_draw_slide4}+${fsz}")
	echo -e "a_draw_slide3=$a_draw_slide3" >>$map_file
	f_draw_slide3 >src/f_draw_slide3.o
	cat src/f_draw_slide3.o

	# スプライト描画コマンドの更新
	fsz=$(to16 $(stat -c '%s' src/f_draw_slide3.o))
	a_update_sprite=$(calc16_8 "${a_draw_slide3}+${fsz}")
	echo -e "a_update_sprite=$a_update_sprite" >>$map_file
	f_update_sprite >src/f_update_sprite.o
	cat src/f_update_sprite.o

	# 全頂点のX座標へ指定された値を加算
	fsz=$(to16 $(stat -c '%s' src/f_update_sprite.o))
	a_add_reg_to_all_vertices_x=$(calc16_8 "${a_update_sprite}+${fsz}")
	echo -e "a_add_reg_to_all_vertices_x=$a_add_reg_to_all_vertices_x" >>$map_file
	f_add_reg_to_all_vertices_x >src/f_add_reg_to_all_vertices_x.o
	cat src/f_add_reg_to_all_vertices_x.o

	# 全頂点をY軸(Z-X平面)で指定された角度右回転
	fsz=$(to16 $(stat -c '%s' src/f_add_reg_to_all_vertices_x.o))
	a_rotate_right_reg_about_yaxis_to_all_vertices=$(calc16_8 "${a_add_reg_to_all_vertices_x}+${fsz}")
	echo -e "a_rotate_right_reg_about_yaxis_to_all_vertices=$a_rotate_right_reg_about_yaxis_to_all_vertices" >>$map_file
	f_rotate_right_reg_about_yaxis_to_all_vertices >src/f_rotate_right_reg_about_yaxis_to_all_vertices.o
	cat src/f_rotate_right_reg_about_yaxis_to_all_vertices.o

	# 全頂点をY軸(Z-X平面)で指定された角度左回転
	fsz=$(to16 $(stat -c '%s' src/f_rotate_right_reg_about_yaxis_to_all_vertices.o))
	a_rotate_left_reg_about_yaxis_to_all_vertices=$(calc16_8 "${a_rotate_right_reg_about_yaxis_to_all_vertices}+${fsz}")
	echo -e "a_rotate_left_reg_about_yaxis_to_all_vertices=$a_rotate_left_reg_about_yaxis_to_all_vertices" >>$map_file
	f_rotate_left_reg_about_yaxis_to_all_vertices >src/f_rotate_left_reg_about_yaxis_to_all_vertices.o
	cat src/f_rotate_left_reg_about_yaxis_to_all_vertices.o

	# 頂点座標更新
	fsz=$(to16 $(stat -c '%s' src/f_rotate_left_reg_about_yaxis_to_all_vertices.o))
	a_update_vertex_coordinates=$(calc16_8 "${a_rotate_left_reg_about_yaxis_to_all_vertices}+${fsz}")
	echo -e "a_update_vertex_coordinates=$a_update_vertex_coordinates" >>$map_file
	f_update_vertex_coordinates >src/f_update_vertex_coordinates.o
	cat src/f_update_vertex_coordinates.o
}
# 変数設定のために空実行
funcs >/dev/null
rm -f $map_file

debug 'after: funcs()'

# コマンドテーブル設定
setup_vram_command_table() {
	# 05c00000
	local com_adr=$SS_VDP1_VRAM_ADDR
	vdp1_command_system_clipping_coordinates >src/system_clipping_coordinates.o
	put_file_to_addr src/system_clipping_coordinates.o $com_adr

	# 05c00020
	com_adr=$(calc16 "$com_adr+20")
	vdp1_command_user_clipping_coordinates >src/user_clipping_coordinates.o
	put_file_to_addr src/user_clipping_coordinates.o $com_adr

	# 05c00040
	com_adr=$(calc16 "$com_adr+20")
	vdp1_command_local_coordinates >src/local_coordinates.o
	put_file_to_addr src/local_coordinates.o $com_adr

	# 05c00060, 05c00080, 05c000a0
	# ポリゴン更新関数呼び出し
	copy_to_reg_from_val_long r1 $a_update_polygon
	sh2_abs_call_to_reg_after_next_inst r1
	sh2_nop

	# # r1へ次にコマンドを配置するVRAMアドレスを設定
	# copy_to_reg_from_val_long r1 $VRAM_DRAW_CMD_BASE

	# r1のアドレス先へ描画終了コマンドを配置
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
}

debug 'before: main()'

main() {
	# スタックポインタ(r15)の初期化
	copy_to_reg_from_val_long r15 $INIT_SP

	# VRAM初期設定
	setup_vram_command_table
	## TEXTURE1_IMG
	### テクスチャ実データアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_texture_data
	### テクスチャを配置するオフセット/8をr2へ設定
	copy_to_reg_from_val_long r2 $var_texture_ofs
	sh2_copy_to_reg_from_ptr_word r2 r2
	sh2_extend_unsigned_to_reg_from_reg_word r2 r2
	### テクスチャのピクセル数をr3へ設定
	copy_to_reg_from_val_long r3 $var_texture_pixel_num
	sh2_copy_to_reg_from_ptr_long r3 r3
	### 関数呼び出し
	copy_to_reg_from_val_long r4 $a_update_texture
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop
	## TEXTURE2_IMG
	### テクスチャ実データアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_texture2_data
	### テクスチャを配置するオフセット/8をr2へ設定
	copy_to_reg_from_val_long r2 $var_texture2_ofs
	sh2_copy_to_reg_from_ptr_word r2 r2
	sh2_extend_unsigned_to_reg_from_reg_word r2 r2
	### テクスチャのピクセル数をr3へ設定
	copy_to_reg_from_val_long r3 $var_texture2_pixel_num
	sh2_copy_to_reg_from_ptr_long r3 r3
	### 関数呼び出し
	copy_to_reg_from_val_long r4 $a_update_texture
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop
	## TEXTURE3_IMG
	### テクスチャ実データアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_texture3_data
	### テクスチャを配置するオフセット/8をr2へ設定
	copy_to_reg_from_val_long r2 $var_texture3_ofs
	sh2_copy_to_reg_from_ptr_word r2 r2
	sh2_extend_unsigned_to_reg_from_reg_word r2 r2
	### テクスチャのピクセル数をr3へ設定
	copy_to_reg_from_val_long r3 $var_texture3_pixel_num
	sh2_copy_to_reg_from_ptr_long r3 r3
	### 関数呼び出し
	copy_to_reg_from_val_long r4 $a_update_texture
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop

	# VDP2のシステムレジスタ設定
	## TVMD
	## - DISP(b15) = 1
	## - BDCLMD(b8) = 1
	## - LSMD(b7-b6) = 0b00
	## - VRESO(b5-b4) = 0b00
	## - HRESO(b2-b0) = 0b000
	copy_to_reg_from_val_long r4 $SS_VDP2_TVMD_ADDR
	sh2_set_reg r0 81
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r4 r0
	## BGON
	sh2_add_to_reg_from_val_byte r4 20
	sh2_set_reg r0 00
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r4 r0
	## PRISA
	sh2_add_to_reg_from_val_byte r4 68
	sh2_add_to_reg_from_val_byte r4 68
	sh2_set_reg r0 06
	sh2_copy_to_ptr_from_reg_word r4 r0

	# VDP1のシステムレジスタ設定
	## TVMR
	## - VBE(b3) = 0
	## - TVM(b2-b0) = 0b000
	copy_to_reg_from_val_long r3 $SS_VDP1_TVMR_ADDR
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r3 r0
	## FBCR(TVMRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_copy_to_ptr_from_reg_word r3 r0
	## PTMR(FBCRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	## PTM(b1-b0) = 0b10
	sh2_set_reg r0 02
	sh2_copy_to_ptr_from_reg_word r3 r0
	## EWDR(PTMRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r3 r0
	## EWLR(EWDRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_set_reg r0 00
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r3 r0
	## EWRR(EWLRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_set_reg r0 50
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte df
	sh2_copy_to_ptr_from_reg_word r3 r0

	# EDSRのアドレスをスタックへ積んでおく
	copy_to_reg_from_val_long r1 $SS_VDP1_EDSR_ADDR
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1

	# メインループ
	(
		# 描画終了を待つ
		(
			# r1へEDSRのアドレスを取得
			sh2_copy_to_reg_from_ptr_long r1 r15
			# r1の指す先(EDSRの内容)をr0へ取得
			sh2_copy_to_reg_from_ptr_word r0 r1
			sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
		) >src/main.2.o
		cat src/main.2.o
		local sz_2=$(stat -c '%s' src/main.2.o)
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_2) / 2)))
		sh2_nop
		## 論理積結果がゼロのとき、
		## 即ちTビットがセットされたとき、
		## 待つ処理を繰り返す

		# 頂点座標更新
		copy_to_reg_from_val_long r1 $a_update_vertex_coordinates
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# 描画終了を待つ
		(
			# r2へEDSRのアドレスを取得
			sh2_copy_to_reg_from_ptr_long r2 r15
			# r2の指す先(EDSRの内容)をr0へ取得
			sh2_copy_to_reg_from_ptr_word r0 r2
			sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
		) >src/main.3.o
		cat src/main.3.o
		local sz_3=$(stat -c '%s' src/main.3.o)
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))
		sh2_nop
		## 論理積結果がゼロのとき、
		## 即ちTビットがセットされたとき、
		## 待つ処理を繰り返す

		# ポリゴン更新
		copy_to_reg_from_val_long r1 $a_update_polygon
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# 描画終了を待つ
		(
			# r2へEDSRのアドレスを取得
			sh2_copy_to_reg_from_ptr_long r2 r15
			# r2の指す先(EDSRの内容)をr0へ取得
			sh2_copy_to_reg_from_ptr_word r0 r2
			sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
		) >src/main.3.o
		cat src/main.3.o
		local sz_3=$(stat -c '%s' src/main.3.o)
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))
		sh2_nop
		## 論理積結果がゼロのとき、
		## 即ちTビットがセットされたとき、
		## 待つ処理を繰り返す

		# # r1へ次にコマンドを配置するVRAMアドレスを設定
		# copy_to_reg_from_val_long r1 $VRAM_DRAW_CMD_BASE

		# スプライト更新
		copy_to_reg_from_val_long r2 $a_update_sprite
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_nop

		# r1のアドレス先へ描画終了コマンドを配置
		sh2_set_reg r0 80
		sh2_shift_left_logical_8 r0
		sh2_copy_to_ptr_from_reg_word r1 r0

		# ゲームパッドの入力状態更新
		copy_to_reg_from_val_long r1 $a_update_gamepad_input_status
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop
	) >src/main.1.o
	cat src/main.1.o
	local sz_1=$(stat -c '%s' src/main.1.o)
	sh2_rel_jump_after_next_inst $(two_comp_3_d $(((4 + sz_1) / 2)))
	sh2_nop
}

debug 'before: make_bin()'

make_bin() {
	local file_sz
	local area_sz
	local pad_sz

	debug 'before: src/jmp_main.o'

	# メインプログラム領域へジャンプ(32バイト)
	(
		copy_to_reg_from_val_long r1 $MAIN_BASE
		sh2_abs_jump_to_reg_after_next_inst r1
		sh2_nop
		sh2_nop	# jmp_main.oのサイズを4の倍数にするためのパディング
	) >src/jmp_main.o
	cat src/jmp_main.o

	debug 'before: src/vars.o'

	# 変数領域
	vars >src/vars.o
	cat src/vars.o
	file_sz=$(stat -c '%s' src/vars.o)
	area_sz=$(echo "ibase=16;$FUNCS_BASE - $VARS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	dd if=/dev/zero bs=1 count=$pad_sz

	debug 'before: src/funcs.o'

	# 関数領域
	funcs >src/funcs.o
	cat src/funcs.o
	file_sz=$(stat -c '%s' src/funcs.o)
	area_sz=$(echo "ibase=16;$MAIN_BASE - $FUNCS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	dd if=/dev/zero bs=1 count=$pad_sz

	debug 'before: main'

	# メインプログラム領域
	main

	debug 'after: main'
}

debug 'before: make_bin'
make_bin
debug 'after: make_bin'
