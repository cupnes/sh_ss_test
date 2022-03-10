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

	# FAD指定で画像を表示する関数を使ってスライドショーする
	## 使用する関数のアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $a_load_img_from_cd_and_view
	copy_to_reg_from_val_long r13 $a_getchar_from_pad

	## 表示する画像のFADをr12へ設定
	copy_to_reg_from_val_word r12 $FAD_FIRST_IMG

	## 無限ループでスライドショー
	(
		# 表示画像更新
		sh2_abs_call_to_reg_after_next_inst r14
		sh2_copy_to_reg_from_reg r1 r12

		# ボタン押下に応じた処理
		(
			# コントロールパッドからの入力をバインドされた文字で取得
			sh2_abs_call_to_reg_after_next_inst r13
			sh2_nop

			# 画像更新フラグ(r11)を0で初期化
			sh2_set_reg r11 00

			# 取得した文字(r1)に応じた処理
			## '1'(→のみ)か?
			sh2_copy_to_reg_from_reg r0 r1
			sh2_compare_r0_eq_val $CHARCODE_1
			(
				# '1'(→のみ)の場合

				# 今の画像は最後の画像か?
				copy_to_reg_from_val_word r2 $FAD_LAST_IMG
				sh2_compare_reg_eq_reg r12 r2
				(
					# 最後の画像でない場合

					# 表示する画像のFAD(r12)へ
					# 画像間のオフセット(SECTORS_IMG_OFS)を
					# 加算
					sh2_set_reg r2 $SECTORS_IMG_OFS
					sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
					sh2_add_to_reg_from_reg r12 r2

					# 画像更新フラグ(r11)を立てる
					sh2_set_reg r11 01
				) >src/main.ss.5.o
				## 最後の画像である(T == 1)ならこの処理を飛ばす
				local sz_ss_5=$(stat -c '%s' src/main.ss.5.o)
				sh2_rel_jump_if_true $(two_digits_d $(((sz_ss_5 - 2) / 2)))
				cat src/main.ss.5.o
			) >src/main.ss.3.o
			### '1'(→のみ)でない(T == 0)ならこの処理を飛ばす
			local sz_ss_3=$(stat -c '%s' src/main.ss.3.o)
			sh2_rel_jump_if_false $(two_digits_d $(((sz_ss_3 - 2) / 2)))
			cat src/main.ss.3.o

			## '3'(←のみ)か?
			sh2_copy_to_reg_from_reg r0 r1
			sh2_compare_r0_eq_val $CHARCODE_3
			(
				# '3'(←のみ)の場合

				# 今の画像は最初の画像か?
				copy_to_reg_from_val_word r2 $FAD_FIRST_IMG
				sh2_compare_reg_eq_reg r12 r2
				(
					# 最初の画像でない場合

					# 表示する画像のFAD(r12)から
					# 画像間のオフセット(SECTORS_IMG_OFS)を
					# 減算
					sh2_set_reg r2 $SECTORS_IMG_OFS
					sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
					sh2_sub_to_reg_from_reg r12 r2

					# 画像更新フラグ(r11)を立てる
					sh2_set_reg r11 01
				) >src/main.ss.6.o
				## 最初の画像である(T == 1)ならこの処理を飛ばす
				local sz_ss_6=$(stat -c '%s' src/main.ss.6.o)
				sh2_rel_jump_if_true $(two_digits_d $(((sz_ss_6 - 2) / 2)))
				cat src/main.ss.6.o
			) >src/main.ss.4.o
			### '3'(←のみ)でない(T == 0)ならこの処理を飛ばす
			local sz_ss_4=$(stat -c '%s' src/main.ss.4.o)
			sh2_rel_jump_if_false $(two_digits_d $(((sz_ss_4 - 2) / 2)))
			cat src/main.ss.4.o

			## 改行(Startのみ)か?
			sh2_copy_to_reg_from_reg r0 r1
			sh2_compare_r0_eq_val $CHARCODE_LF
			(
				# 改行(Startのみ)の場合

				# スライドショーのループを抜ける
				sh2_rel_jump_after_next_inst $(extend_digit $(to16 $(((2 * 5) / 2))) 3)
				sh2_nop
			) >src/main.ss.7.o
			### 改行(Startのみ)でない(T == 0)ならこの処理を飛ばす
			local sz_ss_7=$(stat -c '%s' src/main.ss.7.o)
			sh2_rel_jump_if_false $(two_digits_d $(((sz_ss_7 - 2) / 2)))
			cat src/main.ss.7.o

			# 画像更新フラグが立っているか?
			sh2_copy_to_reg_from_reg r0 r11	# 2
			sh2_compare_r0_eq_val 00	# 2
		) >src/main.ss.2.o
		# 画像更新フラグが立っていない(T == 1)なら
		# 「ボタン押下に応じた処理」を繰り返す
		cat src/main.ss.2.o
		local sz_ss_2=$(stat -c '%s' src/main.ss.2.o)
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_ss_2) / 2)))	# 2
	) >src/main.ss.1.o
	### 無限ループ
	cat src/main.ss.1.o
	local sz_ss_1=$(stat -c '%s' src/main.ss.1.o)
	sh2_rel_jump_after_next_inst $(two_comp_3_d $(((4 + sz_ss_1) / 2)))	# 2
	sh2_nop									# 2

	# PCMデータをサウンドメモリへ配置
	copy_to_reg_from_val_long r1 $PCM_DATA_BASE
	copy_to_reg_from_val_word r2 ${SQUARE_WAVE_LOW}${SQUARE_WAVE_LOW}
	local n=$((SQUARE_WAVE_PERIOD_DEC / 2 / 2))
	local i
	for i in $(seq $n); do
		sh2_copy_to_ptr_from_reg_word r1 r2
		sh2_add_to_reg_from_val_byte r1 02
	done
	copy_to_reg_from_val_word r2 ${SQUARE_WAVE_HIGH}${SQUARE_WAVE_HIGH}
	for i in $(seq $n); do
		sh2_copy_to_ptr_from_reg_word r1 r2
		sh2_add_to_reg_from_val_byte r1 02
	done

	# コントロールレジスタを設定
	## SCSP共通制御レジスタ
	copy_to_reg_from_val_long r1 $a_synth_common_init
	sh2_abs_call_to_reg_after_next_inst r1
	sh2_nop
	## スロット別制御レジスタ(スロット0〜31)
	copy_to_reg_from_val_long r2 $a_synth_slot_init
	sh2_set_reg r1 00
	sh2_set_reg r0 1f
	(
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_nop
		sh2_add_to_reg_from_val_byte r1 01
		sh2_compare_reg_gt_reg_unsigned r1 r0
	) >src/main.4.o
	cat src/main.4.o
	### r1 > 31(0x1f)ならループを抜ける
	local sz_4=$(stat -c '%s' src/main.4.o)
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_4) / 2)))

	# 使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_MCIPDL_ADDR
	copy_to_reg_from_val_long r13 $SS_CT_SND_MIBUF_ADDR
	copy_to_reg_from_val_long r12 $a_synth_get_slot_off
	copy_to_reg_from_val_long r11 $a_key_on_with_pitch
	copy_to_reg_from_val_long r10 $a_key_off
	copy_to_reg_from_val_long r9 $a_synth_get_slot_on_with_note
	copy_to_reg_from_val_long r8 $a_synth_proc_noteon

	(
		# 何度も使用する処理を定義
		## MCIPD[3] == 1を待つ処理
		(
			sh2_copy_to_reg_from_ptr_byte r0 r14
			sh2_test_r0_and_val_byte $SS_SND_MCIPDL_BIT_MI
		) >src/main.3.o
		local sz_3=$(stat -c '%s' src/main.3.o)

		# ノート・オン/オフのMIDIメッセージを取得
		## MIBUFから0x90が取得できるまでMIBUFの取得を繰り返す
		(
			# MCIPD[3] == 1を待つ
			cat src/main.3.o
			## MCIPD[3]がセットされていなければ(T == 1)繰り返す
			sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))

			# MIBUFから1バイト取得
			sh2_copy_to_reg_from_ptr_byte r1 r13
			sh2_extend_unsigned_to_reg_from_reg_byte r1 r1

			# 0x90か?
			sh2_set_reg r0 90
			sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
			sh2_compare_reg_eq_reg r1 r0
			## 0x90ならT == 1
		) >src/main.2.o
		cat src/main.2.o
		local sz_2=$(stat -c '%s' src/main.2.o)
		### T == 0なら繰り返す
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_2) / 2)))
		## ノート番号をr1へ取得
		### MCIPD[3] == 1を待つ
		cat src/main.3.o
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))
		### MIBUFから1バイト取得
		sh2_copy_to_reg_from_ptr_byte r1 r13
		## ベロシティをr2へ取得
		### MCIPD[3] == 1を待つ
		cat src/main.3.o
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))
		### MIBUFから1バイト取得
		sh2_copy_to_reg_from_ptr_byte r2 r13

		# 受信したMIDIメッセージはノート・オンかノート・オフか?
		sh2_set_reg r0 00
		sh2_compare_reg_eq_reg r2 r0
		(
			# ノート・オンの場合

			# r1に格納されているノート番号をr4へコピーしておく
			sh2_copy_to_reg_from_reg r4 r1

			# 既にノート・オンしているか?
			## 取得したノート番号を鳴らしているスロット番号を探す
			sh2_abs_call_to_reg_after_next_inst r9
			sh2_nop
			## 取得したスロット番号 == $SLOT_NOT_FOUND?
			sh2_set_reg r0 $SLOT_NOT_FOUND
			sh2_compare_reg_eq_reg r1 r0
			(
				sh2_abs_call_to_reg_after_next_inst r8
				sh2_nop
			) >src/main.noteon.1.o
			local sz_noteon_1=$(stat -c '%s' src/main.noteon.1.o)
			### 取得したスロット番号 != $SLOT_NOT_FOUNDなら処理を飛ばす
			sh2_rel_jump_if_false $(two_digits_d $(((sz_noteon_1 - 2) / 2)))
			cat src/main.noteon.1.o
		) >src/main.noteon.o
		(
			# ノート・オフの場合

			# KEY_OFF
			## 取得したノート番号を鳴らしているスロット番号を返す
			sh2_abs_call_to_reg_after_next_inst r9
			sh2_nop
			## 取得したスロット番号のスロットをKEY_OFFする
			sh2_abs_call_to_reg_after_next_inst r10
			sh2_nop

			# ノート・オンの場合の処理を飛ばす
			local sz_noteon=$(stat -c '%s' src/main.noteon.o)
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_noteon / 2))) 3)
			sh2_nop
		) >src/main.noteoff.o
		local sz_noteoff=$(stat -c '%s' src/main.noteoff.o)
		sh2_rel_jump_if_false $(two_digits_d $(((sz_noteoff - 2) / 2)))
		cat src/main.noteoff.o
		cat src/main.noteon.o
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
