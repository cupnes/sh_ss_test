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
#     : r2* - この中の作業用
# ※ *が付いているレジスタはこの関数で書き換えられる
setup_vram_color_lookup_table() {
	# 配置先アドレスをr1へ設定
	copy_to_reg_from_val_long r1 $VRAM_CLT_BASE

	# | 0 | 透明 | 0x0000 |
	sh2_xor_to_reg_from_reg r0 r0
	sh2_copy_to_ptr_from_reg_word r1 r0

	# # | 1 | 白   | 0xffff |
	# sh2_add_to_reg_from_val_byte r1 02
	# sh2_set_reg r0 ff
	# sh2_copy_to_ptr_from_reg_word r1 r0

	# | 1 | 黒   | 0x8000 |
	sh2_add_to_reg_from_val_byte r1 02
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r1 r0

	# # | 1 | 赤   | 0x801f |
	# sh2_add_to_reg_from_val_byte r1 02
	# copy_to_reg_from_val_word r2 801f
	# sh2_copy_to_ptr_from_reg_word r1 r2

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

	# 説明画像を表示
	## 使用する関数のアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $a_synth_put_bg
	## 画面クリアフラグ=0で関数呼び出し
	## ※ 初期値はオシレータ画面である想定
	sh2_set_reg r1 $SCRNUM_OSC
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_set_reg r2 00

	# 画像を表示した分、各種アドレス変数を進める
	## キャラクタパターンを配置するアドレス
	## 画像のサイズ(143360=0x23000バイト)分進める
	## 0x05C10C00 + 0x23000 = 0x05C33C00
	copy_to_reg_from_val_long r1 $var_next_cp_other_addr
	copy_to_reg_from_val_long r2 05C33C00
	sh2_copy_to_ptr_from_reg_long r1 r2
	## VDPコマンドを配置するアドレス
	## コマンドのサイズ(32=0x20)分進める
	## 0x05C02360 + 0x20 = 0x05C02380
	copy_to_reg_from_val_long r1 $var_next_vdpcom_other_addr
	copy_to_reg_from_val_long r2 05C02380
	sh2_copy_to_ptr_from_reg_long r1 r2

	# オシレータ用のPCMデータをサウンドメモリへ配置
	copy_to_reg_from_val_long r4 $a_memcpy_word
	copy_to_reg_from_val_long r1 $OSC_PCM_AREA_BASE
	sh2_set_reg r3 $OSC_PCM_NUM_SAMPLES
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	## ノコギリ波
	copy_to_reg_from_val_long r2 $var_synth_osc_pcm_saw_base
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop
	## 矩形波
	copy_to_reg_from_val_word r2 $OSC_PCM_SQU_HIGH
	sh2_set_reg r0 $(calc16_2 "${OSC_PCM_NUM_SAMPLES}/2")	# カウント数設定
	(
		sh2_copy_to_ptr_from_reg_word r1 r2
		sh2_add_to_reg_from_val_byte r1 02
		sh2_add_to_reg_from_val_byte r0 $(two_comp_d 1)
		sh2_compare_r0_eq_val 00
	) >src/main.lsqu.o
	cat src/main.lsqu.o
	local sz_lsqu=$(stat -c '%s' src/main.lsqu.o)
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_lsqu) / 2)))
	copy_to_reg_from_val_word r2 $OSC_PCM_SQU_LOW
	sh2_set_reg r0 $(calc16_2 "${OSC_PCM_NUM_SAMPLES}/2")	# カウント数設定
	cat src/main.lsqu.o
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_lsqu) / 2)))
	## サイン波
	copy_to_reg_from_val_long r2 $var_synth_osc_pcm_sin_base
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop

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
	copy_to_reg_from_val_long r14 $a_synth_put_osc_param
	copy_to_reg_from_val_long r12 $a_synth_check_and_enq_midimsg
	copy_to_reg_from_val_long r11 $var_synth_slot_state_base
	copy_to_reg_from_val_long r10 $a_key_off
	copy_to_reg_from_val_long r9 $a_synth_get_slot_on_with_note
	copy_to_reg_from_val_long r8 $a_synth_proc_noteon
	copy_to_reg_from_val_long r7 $a_synth_add_pitch_to_slot
	copy_to_reg_from_val_long r6 $a_synth_midimsg_deq
	copy_to_reg_from_val_long r5 $a_synth_midimsg_is_empty

	# 現在のオシレータを示すカーソルを表示する
	# (デフォルト=ノコギリ波)
	# ※ 初期画面はオシレータ画面である想定
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# # EG関連のレジスタの現在値を表示する
	# copy_to_reg_from_val_long r13 $a_synth_put_eg_param
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_nop

	# # LFO関連のレジスタの現在値を表示する
	# copy_to_reg_from_val_long r13 $a_synth_put_lfo_param
	# sh2_abs_call_to_reg_after_next_inst r13
	# sh2_nop

	(
		# MIBUFに注目対象のMIDIメッセージがあれば取得し
		# 専用のキュー(SYNTH_MIDIMSG_QUEUE)へエンキュー
		sh2_abs_call_to_reg_after_next_inst r12
		sh2_nop

		# SYNTH_MIDIMSG_QUEUEにMIDIメッセージがあれば
		# デキューしMIDIメッセージに応じた処理を実行
		## SYNTH_MIDIMSG_QUEUEにMIDIメッセージがあるか確認
		sh2_abs_call_to_reg_after_next_inst r5
		sh2_nop
		### キューが空でない時、r1 == 0
		## r1 == 0?
		sh2_set_reg r0 00
		sh2_compare_reg_eq_reg r1 r0
		### r1 != 0ならT == 0
		## r1 != 0なら処理を飛ばす
		(
			# キューが空でない場合

			# ステータス・バイトをデキュー
			sh2_abs_call_to_reg_after_next_inst r6
			sh2_nop
			sh2_extend_unsigned_to_reg_from_reg_byte r1 r1

			# ステータス・バイト == 0xe0?
			sh2_set_reg r0 e0
			sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
			sh2_compare_reg_eq_reg r1 r0
			## ステータス・バイト != 0xe0ならT == 0

			# ステータス・バイト != 0xe0なら
			# ピッチ・ベンド・チェンジ固有処理を飛ばす
			(
				# ステータス・バイト == 0xe0 の場合

				# ピッチベンド値(LSB)とピッチベンド値(MSB)をデキュー
				## ピッチベンド値(LSB)をデキューしr2へ設定
				sh2_abs_call_to_reg_after_next_inst r6
				sh2_nop
				sh2_copy_to_reg_from_reg r2 r1
				## ピッチベンド値(MSB)をデキューしr3へ設定
				sh2_abs_call_to_reg_after_next_inst r6
				sh2_nop
				sh2_copy_to_reg_from_reg r3 r1

				# r2へピッチ値への加算値を設定
				## r2 = (r3 << 7) | r2
				sh2_shift_left_logical_8 r3
				sh2_shift_right_logical r3
				sh2_or_to_reg_from_reg r2 r3
				## r2 -= 0x2000
				sh2_set_reg r0 20
				sh2_shift_left_logical_8 r0
				sh2_sub_to_reg_from_reg r2 r0
				## r2を4ビット右シフト
				sh2_shift_right_arithmetic r2
				sh2_shift_right_arithmetic r2
				sh2_shift_right_arithmetic r2
				sh2_shift_right_arithmetic r2

				# KEY_ON中のスロットへピッチ値を加算
				## r3へ各スロットの状態管理変数のアドレスを設定
				sh2_copy_to_reg_from_reg r3 r11
				## スロット番号へ初期値として0を設定
				sh2_set_reg r1 00
				(
					# スロットの状態をr4へ取得
					sh2_copy_to_reg_from_ptr_byte r4 r3

					# スロットはKEY_ONか? (スロットの状態 != 0か?)
					sh2_set_reg r0 00
					sh2_compare_reg_eq_reg r4 r0
					## KEY_OFFの時、r4 == r0なのでT == 1
					(
						# KEY_ONの場合

						# スロットへピッチ値を加算
						sh2_abs_call_to_reg_after_next_inst r7
						sh2_nop
					) >src/main.pbc.1.o
					local sz_pbc_1=$(stat -c '%s' src/main.pbc.1.o)
					## T == 1なら処理を飛ばす
					sh2_rel_jump_if_true $(two_digits_d $(((sz_pbc_1 - 2) / 2)))
					cat src/main.pbc.1.o

					# スロットの状態管理変数のアドレスを1バイト進める
					sh2_add_to_reg_from_val_byte r3 01

					# スロット番号をインクリメント
					sh2_add_to_reg_from_val_byte r1 01

					# スロット番号 >= 0x20?
					sh2_set_reg r0 20
					sh2_compare_reg_ge_reg_unsigned r1 r0
				) >src/main.pbc.2.o
				cat src/main.pbc.2.o
				local sz_pbc_2=$(stat -c '%s' src/main.pbc.2.o)
				### スロット番号 >= 0x20 でない(T == 0)なら繰り返す
				sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_pbc_2) / 2)))
			) >src/main.pbc.o
			local sz_pbc=$(stat -c '%s' src/main.pbc.o)
			sh2_rel_jump_if_false $(two_digits_d $(((sz_pbc - 2) / 2)))
			cat src/main.pbc.o

			# ステータス・バイト == 0x90?
			sh2_set_reg r0 90
			sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
			sh2_compare_reg_eq_reg r1 r0
			## ステータス・バイト != 0x90ならT == 0

			# ステータス・バイト != 0x90なら
			# ノート・オン/オフ固有処理を飛ばす
			(
				# ステータス・バイト == 0x90 の場合

				# ノート番号とベロシティをデキュー
				## 一旦r0へノート番号を設定
				### デキュー
				sh2_abs_call_to_reg_after_next_inst r6
				sh2_nop
				### 一旦r0へコピー
				sh2_copy_to_reg_from_reg r0 r1
				## r2へベロシティを設定
				### デキュー
				sh2_abs_call_to_reg_after_next_inst r6
				sh2_nop
				### r2へコピー
				sh2_copy_to_reg_from_reg r2 r1
				## r1へノート番号を設定
				sh2_copy_to_reg_from_reg r1 r0

				# MIBUFに注目対象のMIDIメッセージがあれば取得し
				# 専用のキュー(SYNTH_MIDIMSG_QUEUE)へエンキュー
				sh2_abs_call_to_reg_after_next_inst r12
				sh2_nop

				# ノート・オンかノート・オフか?
				sh2_set_reg r0 00
				sh2_compare_reg_eq_reg r2 r0
				(
					# ノート・オンの場合

					# r1に格納されているノート番号をr2へコピーしておく
					sh2_copy_to_reg_from_reg r2 r1

					# 既にノート・オンしているか?
					## 取得したノート番号を鳴らしているスロット番号を探す
					sh2_abs_call_to_reg_after_next_inst r9
					sh2_nop
					## MIBUFに注目対象のMIDIメッセージがあれば取得し
					## 専用のキュー(SYNTH_MIDIMSG_QUEUE)へエンキュー
					sh2_abs_call_to_reg_after_next_inst r12
					sh2_nop
					## 取得したスロット番号 == $SLOT_NOT_FOUND?
					sh2_set_reg r0 $SLOT_NOT_FOUND
					sh2_compare_reg_eq_reg r1 r0
					(
						# ノート・オンの場合の処理を呼び出す
						sh2_abs_call_to_reg_after_next_inst r8
						sh2_copy_to_reg_from_reg r1 r2
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
					## MIBUFに注目対象のMIDIメッセージがあれば取得し
					## 専用のキュー(SYNTH_MIDIMSG_QUEUE)へエンキュー
					sh2_abs_call_to_reg_after_next_inst r12
					sh2_nop
					## 取得したスロット番号のスロットをKEY_OFFする
					sh2_abs_call_to_reg_after_next_inst r10
					sh2_nop

					# # WORKAROUND2: 常に全てのスロットをKEY_OFFする
					# # 全スロットをKEY_OFFする
					# local slot_num_dec
					# for slot_num_dec in $(seq 0 31); do
					# 	sh2_abs_call_to_reg_after_next_inst r10
					# 	sh2_set_reg r1 $(to16_2 $slot_num_dec)
					# done

					# ノート・オンの場合の処理を飛ばす
					local sz_noteon=$(stat -c '%s' src/main.noteon.o)
					sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_noteon / 2))) 3)
					sh2_nop
				) >src/main.noteoff.o
				local sz_noteoff=$(stat -c '%s' src/main.noteoff.o)
				sh2_rel_jump_if_false $(two_digits_d $(((sz_noteoff - 2) / 2)))
				cat src/main.noteoff.o
				cat src/main.noteon.o
			) >src/main.noteonoff.o
			local sz_noteonoff=$(stat -c '%s' src/main.noteonoff.o)
			sh2_rel_jump_if_false $(two_digits_d $(((sz_noteonoff - 2) / 2)))
			cat src/main.noteonoff.o

			# ステータス・バイト == 0xb0?
			sh2_set_reg r0 b0
			sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
			sh2_compare_reg_eq_reg r1 r0
			## ステータス・バイト != 0xb0ならT == 0

			# ステータス・バイト != 0xb0なら
			# アサイナブルホイール固有処理を飛ばす
			(
				# ステータス・バイト == 0xb0 の場合

				# アサイナブルホイール固有処理の関数を呼び出す
				copy_to_reg_from_val_long r1 $a_synth_proc_assign
				sh2_abs_call_to_reg_after_next_inst r1
				sh2_nop
			) >src/main.assign.o
			local sz_assign=$(stat -c '%s' src/main.assign.o)
			sh2_rel_jump_if_false $(two_digits_d $(((sz_assign - 2) / 2)))
			cat src/main.assign.o

			# ステータス・バイト == 0xc0?
			sh2_set_reg r0 c0
			sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
			sh2_compare_reg_eq_reg r1 r0
			## ステータス・バイト != 0xc0ならT == 0

			# ステータス・バイト != 0xc0なら
			# プログラム・チェンジ固有処理を飛ばす
			(
				# ステータス・バイト == 0xc0 の場合

				# プログラム・チェンジ固有処理の関数を呼び出す
				copy_to_reg_from_val_long r1 $a_synth_proc_progchg
				sh2_abs_call_to_reg_after_next_inst r1
				sh2_nop
			) >src/main.progchg.o
			local sz_progchg=$(stat -c '%s' src/main.progchg.o)
			sh2_rel_jump_if_false $(two_digits_d $(((sz_progchg - 2) / 2)))
			cat src/main.progchg.o

			# その他のステータス・バイト固有処理
			copy_to_reg_from_val_long r2 $a_synth_proc_others
			sh2_abs_call_to_reg_after_next_inst r2
			sh2_nop
		) >src/main.7.o
		local sz_7=$(stat -c '%s' src/main.7.o)
		### T == 0なら処理を飛ばす
		sh2_rel_jump_if_false $(two_digits_d $(((sz_7 - 2) / 2)))
		cat src/main.7.o
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
