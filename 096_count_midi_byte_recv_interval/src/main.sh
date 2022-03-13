#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/vdp1.sh
. include/memmap.sh
. include/charcode.sh
. include/synth.sh
. src/vars_map.sh
. src/funcs_map.sh
. src/vdp.sh
. src/con.sh

# このアプリで使用するシェル変数設定
## スライドショーの画像枚数(10進数で指定)
NUM_IMGS_DEC=11
## 最初の画像のFAD(4桁の16進数で指定)
FAD_FIRST_IMG=02a2
## 画像間のオフセット[セクタ]
### 10進数で指定
SECTORS_IMG_OFS_DEC=70
### 2桁の16進数で指定
SECTORS_IMG_OFS=$(extend_digit $(to16 $SECTORS_IMG_OFS_DEC) 2)
## 最後の画像のFAD(4桁の16進数で指定)
FAD_LAST_IMG=$(calc16_4 "${FAD_FIRST_IMG}+$(to16 $((SECTORS_IMG_OFS_DEC * (NUM_IMGS_DEC - 1))))")

# コマンドテーブル設定
# work: r0* - put_file_to_addr,copy_to_reg_from_val_long,この中の作業用
#     : r1* - put_file_to_addrの作業用
#     : r2* - put_file_to_addrの作業用
# ※ *が付いているレジスタはこの関数で書き換えられる
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

	# con用のVDPCOMの1件目にskip assignを設定
	## con用のVDPCOMの1件目のアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $VRAM_CT_CON_BASE
	## CMDCTRLのJP(ビット14-12)へ設定する値をr0へ設定
	sh2_set_reg r0 $(two_digits $VDP1_JP_SKIP_ASSIGN)
	## r0を12ビット左シフト
	sh2_shift_left_logical_8 r0
	sh2_shift_left_logical_2 r0
	sh2_shift_left_logical_2 r0
	## r0をr1の指す先へ設定
	sh2_copy_to_ptr_from_reg_word r1 r0
	## アドレス(r1)を2バイト進める
	sh2_add_to_reg_from_val_byte r1 02
	## CMDLINKへ設定する値をr0へ設定
	sh2_set_reg r0 $(echo $VRAM_CT_OTHER_BASE_CMDLINK | cut -c1-2)
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte $(echo $VRAM_CT_OTHER_BASE_CMDLINK | cut -c3-4)
	sh2_extend_unsigned_to_reg_from_reg_word r0 r0
	## r0をr1の指す先へ設定
	sh2_copy_to_ptr_from_reg_word r1 r0

	# other用のVDPCOMの1件目に描画終了コマンドを配置
	## other用のVDPCOMの1件目のアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $VRAM_CT_OTHER_BASE
	## r1のアドレス先へ描画終了コマンドを配置
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r1 r0
}

# カラールックアップテーブル設定
# work: r0* - copy_to_reg_from_val_longの作業用
#     : r1* - この中の作業用
# ※ *が付いているレジスタはこの関数で書き換えられる
setup_vram_color_lookup_table() {
	# 配置先アドレスをr1へ設定
	copy_to_reg_from_val_long r1 $VRAM_CLT_BASE

	# | 0 | 透明 | 0x0000 |
	sh2_xor_to_reg_from_reg r0 r0
	sh2_copy_to_ptr_from_reg_word r1 r0

	# | 1 | 白   | 0xffff |
	sh2_add_to_reg_from_val_byte r1 02
	sh2_set_reg r0 ff
	sh2_copy_to_ptr_from_reg_word r1 r0

	# | 2 | 透明 | 0x0000 |
	# | : |  :   |   :    |
	# | f | 透明 | 0x0000 |
	sh2_xor_to_reg_from_reg r0 r0
	local _i
	for _i in $(seq 2 15); do
		sh2_add_to_reg_from_val_byte r1 02
		sh2_copy_to_ptr_from_reg_word r1 r0
	done
}

# メイン関数
main() {
	# NMI以外の全ての割り込みをマスクする
	sh2_copy_to_reg_from_sr r0
	sh2_or_to_r0_from_val_byte $(echo $SH2_SR_BIT_I3210 | cut -c7-8)
	sh2_copy_to_sr_from_reg r0

	# スタックポインタ(r15)の初期化
	copy_to_reg_from_val_long r15 $INIT_SP

	# VRAM初期設定
	setup_vram_command_table
	setup_vram_color_lookup_table

	# VDP1/2の初期化
	vdp_init

	# 使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_MCIPDL_ADDR
	copy_to_reg_from_val_long r13 $SS_CT_SND_MIBUF_ADDR
	copy_to_reg_from_val_long r11 $a_putreg
	copy_to_reg_from_val_long r10 $a_putchar

	# 最小カウント数を最大値で初期化
	sh2_set_reg r12 ff

	# MIDI受信を待つ
	## MCIPD[3] == 1を待つ処理
	(
		sh2_copy_to_reg_from_ptr_byte r0 r14
		sh2_test_r0_and_val_byte $SS_SND_MCIPDL_BIT_MI
	) >src/main.3.o
	cat src/main.3.o
	## MCIPD[3]がセットされていなければ(T == 1)繰り返す
	local sz_3=$(stat -c '%s' src/main.3.o)
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))

	# 無限ループ
	(
		# MIBUFを確実に空にするように4バイト読み出す
		sh2_copy_to_reg_from_ptr_byte r0 r13
		sh2_copy_to_reg_from_ptr_byte r0 r13
		sh2_copy_to_reg_from_ptr_byte r0 r13
		sh2_copy_to_reg_from_ptr_byte r0 r13

		# MIDI受信を待つ
		## カウンタをゼロクリア
		sh2_set_reg r1 00
		## MCIPD[3] == 1を待つ処理
		(
			# カウントアップ
			sh2_add_to_reg_from_val_byte r1 01

			# MCIPDを読み出して確認
			sh2_copy_to_reg_from_ptr_byte r0 r14
			sh2_test_r0_and_val_byte $SS_SND_MCIPDL_BIT_MI
		) >src/main.3.o
		cat src/main.3.o
		## MCIPD[3]がセットされていなければ(T == 1)繰り返す
		local sz_3=$(stat -c '%s' src/main.3.o)
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))

		# 最小カウント数(r12) > カウント値(r1)?
		sh2_compare_reg_gt_reg_unsigned r12 r1
		(
			# 最小カウント数(r12) > カウント値(r1)の場合

			# 最小カウント数を更新しカウント値を出力
			sh2_abs_call_to_reg_after_next_inst r11
			sh2_copy_to_reg_from_reg r12 r1

			# スペースを出力
			sh2_abs_call_to_reg_after_next_inst r10
			sh2_set_reg r1 $CHARCODE_SPACE
		) >src/main.2.o
		## 最小カウント数(r12) > カウント値(r1)でなかったら(T == 0)スキップ
		local sz_2=$(stat -c '%s' src/main.2.o)
		sh2_rel_jump_if_false $(two_digits_d $(((sz_2 - 2) / 2)))
		cat src/main.2.o
	) >src/main.1.o
	cat src/main.1.o
	local sz_1=$(stat -c '%s' src/main.1.o)
	sh2_rel_jump_after_next_inst $(two_comp_3_d $(((4 + sz_1) / 2)))
	sh2_nop
}

make_bin() {
	local file_sz
	local area_sz
	local pad_sz

	# メインプログラム領域へジャンプ(32バイト)
	(
		copy_to_reg_from_val_long r1 $MAIN_BASE
		sh2_abs_jump_to_reg_after_next_inst r1
		sh2_nop
		sh2_nop	# jmp_main.oのサイズを4の倍数にするためのパディング
	) >src/jmp_main.o
	cat src/jmp_main.o

	# 変数領域
	cat src/vars.o
	file_sz=$(stat -c '%s' src/vars.o)
	area_sz=$(echo "ibase=16;$FUNCS_BASE - $VARS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	if [ $pad_sz -lt 0 ]; then
		echo 'Error: variable area overflow.' >&2
		exit 1
	fi
	cat <<EOF >&2
[variable area (unit: byte)]
- size : $area_sz
- used : $file_sz
- avail: $pad_sz
EOF
	dd if=/dev/zero bs=1 count=$pad_sz

	# 関数領域
	cat src/funcs.o
	file_sz=$(stat -c '%s' src/funcs.o)
	area_sz=$(echo "ibase=16;$MAIN_BASE - $FUNCS_BASE" | bc)
	pad_sz=$((area_sz - file_sz))
	if [ $pad_sz -lt 0 ]; then
		echo 'Error: function area overflow.' >&2
		exit 1
	fi
	cat <<EOF >&2
[function area (unit: byte)]
- size : $area_sz
- used : $file_sz
- avail: $pad_sz
EOF
	dd if=/dev/zero bs=1 count=$pad_sz

	# メインプログラム領域
	main
}

make_bin
