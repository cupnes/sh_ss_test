if [ "${SRC_SYNTH_SH+is_defined}" ]; then
	return
fi
SRC_SYNTH_SH=true

. include/sh2.sh
. include/ss.sh
. include/common.sh
. include/lib.sh
. include/synth.sh
. include/cd.sh
. src/vars_map.sh

# SSCTLのビット[8:7]を抽出するマスク(SSCTLビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_ssctl_to_r0() {
	# mask = 0b0000 0001 1000 0000 = 0x0180
	sh2_set_reg r0 01
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte 80
}

# SSCTLビット[8:7]をLSBへ持ってくるように
# 指定されたレジスタをシフトするマクロ
shift_ssctl_to_lsb() {
	local reg=$1

	# $regを7ビット右シフト
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical $reg
}

# D1Rのビット[10:6]を抽出するマスク(D1Rビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_d1r_to_r0() {
	# mask = 0b0000 0111 1100 0000 = 0x07c0
	sh2_set_reg r0 07
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte c0
}

# D1Rビット[10:6]をLSBへ持ってくるように
# 指定されたレジスタをシフトするマクロ
shift_d1r_to_lsb() {
	local reg=$1

	# $regを6ビット右シフト
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical_2 $reg
}

# D2Rのビット[15:11]を抽出するマスク(D2Rビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_d2r_to_r0() {
	# mask = 0b1111 1000 0000 0000 = 0xf800
	sh2_set_reg r0 f8
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
	sh2_shift_left_logical_8 r0
}

# D2Rビット[15:11]をLSBへ持ってくるように
# 指定されたレジスタをシフトするマクロ
shift_d2r_to_lsb() {
	local reg=$1

	# $regを11ビット右シフト
	sh2_shift_right_logical_8 $reg
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical $reg
}

# RRのビット[4:0]を抽出するマスク(RRビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_rr_to_r0() {
	# mask = 0b0000 0000 0001 1111 = 0x001f
	sh2_set_reg r0 1f
}

# DLのビット[9:5]を抽出するマスク(DLビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_dl_to_r0() {
	# mask = 0b0000 0011 1110 0000 = 0x03e0
	sh2_set_reg r0 03
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte e0
}

# DLビット[9:5]をLSBへ持ってくるように
# 指定されたレジスタをシフトするマクロ
shift_dl_to_lsb() {
	local reg=$1

	# $regを5ビット右シフト
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical $reg
}

# TLのビット[7:0]を抽出するマスク(TLビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_tl_to_r0() {
	# mask = 0b0000 0000 1111 1111 = 0x00ff
	sh2_set_reg r0 ff
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
}

# ALFOSのビット[2:0]を抽出するマスク(ALFOSビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_alfos_to_r0() {
	# mask = 0b0000 0000 0000 0111 = 0x0007
	sh2_set_reg r0 07
}

# ALFOWSのビット[4:3]を抽出するマスク(ALFOWSビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_alfows_to_r0() {
	# mask = 0b0000 0000 0001 1000 = 0x0018
	sh2_set_reg r0 18
}

# ALFOWSビット[4:3]をLSBへ持ってくるように
# 指定されたレジスタをシフトするマクロ
shift_alfows_to_lsb() {
	local reg=$1

	# $regを3ビット右シフト
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical $reg
}

# PLFOSのビット[7:5]を抽出するマスク(PLFOSビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_plfos_to_r0() {
	# mask = 0b0000 0000 1110 0000 = 0x00e0
	sh2_set_reg r0 e0
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
}

# PLFOSビット[7:5]をLSBへ持ってくるように
# 指定されたレジスタをシフトするマクロ
shift_plfos_to_lsb() {
	local reg=$1

	# $regを5ビット右シフト
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical_2 $reg
	sh2_shift_right_logical $reg
}

# PLFOWSのビット[9:8]を抽出するマスク(PLFOWSビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_plfows_to_r0() {
	# mask = 0b0000 0011 0000 0000 = 0x0300
	sh2_set_reg r0 03
	sh2_shift_left_logical_8 r0
}

# PLFOWSビット[9:8]をLSBへ持ってくるように
# 指定されたレジスタをシフトするマクロ
shift_plfows_to_lsb() {
	local reg=$1

	# $regを8ビット右シフト
	sh2_shift_right_logical_8 $reg
}

# LFOFのビット[14:10]を抽出するマスク(LFOFビット以外をマスクする)を
# r0へ設定するマクロ
set_mask_expose_lfof_to_r0() {
	# mask = 0b0111 1100 0000 0000 = 0x7c00
	sh2_set_reg r0 7c
	sh2_shift_left_logical_8 r0
}

# LFOFビット[14:10]をLSBへ持ってくるように
# 指定されたレジスタをシフトするマクロ
shift_lfof_to_lsb() {
	local reg=$1

	# $regを10ビット右シフト
	sh2_shift_right_logical_8 $reg
	sh2_shift_right_logical_2 $reg
}

# 指定されたワードで全スロットのレジスタを設定するマクロ
# in  : reg_val        - 設定値が格納されたレジスタ
#     : reg_slot_addr* - スロット0の設定先レジスタアドレス
#     : reg_idx*       - ループ中のスロット番号
#     : reg_eidx*      - 最後のスロット番号
# ※ *が付いているレジスタはマクロ内で変更される
set_to_all_slot_regs_from_reg() {
	local reg_val=$1
	local reg_slot_addr=$2
	local reg_idx=$3
	local reg_eidx=$4

	# スロット番号 = 0
	sh2_set_reg $reg_idx 00

	# 最後のスロット番号 = 0x1f(31)
	sh2_set_reg $reg_eidx 1f

	# 全スロットへ値を設定
	(
		# 設定
		sh2_copy_to_ptr_from_reg_word $reg_slot_addr $reg_val

		# 次のスロットのアドレスへ、オフセットを加算
		sh2_add_to_reg_from_val_byte $reg_slot_addr 20

		# スロット番号をインクリメント
		sh2_add_to_reg_from_val_byte $reg_idx 01

		# スロット番号 > 0x1f(31)?
		sh2_compare_reg_gt_reg_unsigned $reg_idx $reg_eidx
	) >src/set_to_all_slot_regs_from_reg.setreg.o
	cat src/set_to_all_slot_regs_from_reg.setreg.o
	## r1 > 31(0x1f)ならループを抜ける
	local sz_setreg=$(stat -c '%s' src/set_to_all_slot_regs_from_reg.setreg.o)
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
}

# MIDIメッセージキューへ1バイトエンキューする
# in  : r1 - エンキューする1バイト
f_synth_midimsg_enq() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r3

	# var_synth_midimsg_enqueue_addr の変数アドレスをr2へ設定
	copy_to_reg_from_val_long r2 $var_synth_midimsg_enqueue_addr

	# r2が指す先(変数の値=次にエンキューするアドレス)をr3へ設定
	sh2_copy_to_reg_from_ptr_long r3 r2

	# r3が指す先へエンキューする1バイトを書き込み
	sh2_copy_to_ptr_from_reg_byte r3 r1

	# r3をインクリメント
	sh2_add_to_reg_from_val_byte r3 01

	# r2(変数アドレス)に2を加算する(変数下位2バイトを指すようにする)
	sh2_add_to_reg_from_val_byte r2 02

	# r2が指す先へr3をワード書き込み(r3の下位2バイトのみをr2が指す先へ書く)
	sh2_copy_to_ptr_from_reg_word r2 r3

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# MIDIメッセージキューから1バイトデキューする
# out : r1 - デキューした1バイト
f_synth_midimsg_deq() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r3

	# var_synth_midimsg_dequeue_addr の変数アドレスをr2へ設定
	copy_to_reg_from_val_long r2 $var_synth_midimsg_dequeue_addr

	# r2が指す先(変数の値=次にデキューするアドレス)をr3へ設定
	sh2_copy_to_reg_from_ptr_long r3 r2

	# r3が指す先からデキューする1バイトを読み出し
	sh2_copy_to_reg_from_ptr_byte r1 r3
	sh2_extend_unsigned_to_reg_from_reg_byte r1 r1

	# r3をインクリメント
	sh2_add_to_reg_from_val_byte r3 01

	# r2(変数アドレス)に2を加算する(変数下位2バイトを指すようにする)
	sh2_add_to_reg_from_val_byte r2 02

	# r2が指す先へr3をワード書き込み(r3の下位2バイトのみをr2が指す先へ書く)
	sh2_copy_to_ptr_from_reg_word r2 r3

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# MIDIメッセージキューが空か否かを返す
# out : r1 - MIDIメッセージキューが空か否か(0=空でない,1=空)
f_synth_midimsg_is_empty() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2

	# r1へ次にエンキューするアドレスを設定
	copy_to_reg_from_val_long r1 $var_synth_midimsg_enqueue_addr
	sh2_copy_to_reg_from_ptr_long r1 r1

	# r2へ次にデキューするアドレスを設定
	copy_to_reg_from_val_long r2 $var_synth_midimsg_dequeue_addr
	sh2_copy_to_reg_from_ptr_long r2 r2

	# r1 == r2?
	sh2_compare_reg_eq_reg r1 r2
	(
		# r1 == r2の場合
		sh2_set_reg r1 01
	) >src/f_synth_midimsg_is_empty.1.o
	(
		# r1 != r2の場合
		sh2_set_reg r1 00

		# r1 == r2の場合の処理を飛ばす
		local sz_1=$(stat -c '%s' src/f_synth_midimsg_is_empty.1.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_1 / 2))) 3)
		sh2_nop
	) >src/f_synth_midimsg_is_empty.2.o
	local sz_2=$(stat -c '%s' src/f_synth_midimsg_is_empty.2.o)
	sh2_rel_jump_if_true $(two_digits_d $(((sz_2 - 2) / 2)))
	cat src/f_synth_midimsg_is_empty.2.o	# r1 != r2の場合
	cat src/f_synth_midimsg_is_empty.1.o	# r1 == r2の場合

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# MIBUFに注目対象のMIDIメッセージがあれば取得し
# 専用のキュー(SYNTH_MIDIMSG_QUEUE)へエンキュー
f_synth_check_and_enq_midimsg() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

	# 使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_MCIPDL_ADDR

	# MCIPD[3]を確認
	# (繰り返しでも使用する処理なのでファイルへ書き出しておく)
	(
		sh2_copy_to_reg_from_ptr_byte r0 r14
		sh2_test_r0_and_val_byte $SS_SND_MCIPDL_BIT_MI
	) >src/f_synth_check_and_enq_midimsg.chkmi.o
	local sz_chkmi=$(stat -c '%s' src/f_synth_check_and_enq_midimsg.chkmi.o)
	cat src/f_synth_check_and_enq_midimsg.chkmi.o
	## MCIPD[3] == 1の時、T == 0

	# MCIPD[3] == 0ならreturn
	(
		# MCIPD[3] == 0の場合

		# 退避したレジスタを復帰
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_check_and_enq_midimsg.1.o
	local sz_1=$(stat -c '%s' src/f_synth_check_and_enq_midimsg.1.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_1 - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.1.o

	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13

	# 使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r13 $SS_CT_SND_MIBUF_ADDR

	# 繰り返し使用する処理をファイル書き出し
	## データ・バイト取得処理
	(
		# MCIPD[3] == 1を待つ
		cat src/f_synth_check_and_enq_midimsg.chkmi.o
		## MCIPD[3]がセットされていなければ(T == 1)繰り返す
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_chkmi) / 2)))

		# MIBUFから1バイト取得
		sh2_copy_to_reg_from_ptr_byte r0 r13

		# もし取得したバイトのMSB == 1?
		sh2_test_r0_and_val_byte 80
	) >src/f_synth_check_and_enq_midimsg.getdatabyte.o
	local sz_getdatabyte=$(stat -c '%s' src/f_synth_check_and_enq_midimsg.getdatabyte.o)

	# MIBUFからステータス・バイト取得
	sh2_copy_to_reg_from_ptr_byte r0 r13

	# ステータス・バイト == 0x90 || ステータス・バイト == 0xb0 || ステータス・バイト == 0xe0 ?
	## フラグをゼロクリア
	sh2_set_reg r1 00
	## ステータス・バイト == 0x90ならフラグをセット
	sh2_compare_r0_eq_val 90
	### ステータス・バイト != 0x90の時、T == 0
	(
		sh2_set_reg r1 01
	) >src/f_synth_check_and_enq_midimsg.setr101.o
	local sz_setr101=$(stat -c '%s' src/f_synth_check_and_enq_midimsg.setr101.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_setr101 - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.setr101.o
	## ステータス・バイト == 0xb0ならフラグをセット
	sh2_compare_r0_eq_val b0
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_setr101 - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.setr101.o
	## ステータス・バイト == 0xe0ならフラグをセット
	sh2_compare_r0_eq_val e0
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_setr101 - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.setr101.o
	## フラグはセットされているか?
	sh2_set_reg r2 01
	sh2_compare_reg_eq_reg r1 r2
	### フラグがセットされていない時、T == 0

	# ステータス・バイト == 0x90 || ステータス・バイト == 0xb0 || ステータス・バイト == 0xe0 なら
	# ノート・オン/オフ,アサイナブルホイール,ピッチ・ベンド・チェンジのMIDIメッセージをエンキュー
	(
		# ステータス・バイト == 0x90 || ステータス・バイト == 0xb0 || ステータス・バイト == 0xe0 の場合

		# ステータス・バイトをr1へコピーしておく
		sh2_copy_to_reg_from_reg r1 r0

		# 変更が発生するレジスタを退避
		sh2_copy_to_reg_from_pr r0
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

		# 使用するアドレスをレジスタへ設定
		copy_to_reg_from_val_long r2 $a_synth_midimsg_enq

		# ステータス・バイトをエンキュー
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_nop

		# MIDIメッセージ: ノート・オン/オフ or アサイナブルホイール or ピッチ・ベンド・チェンジ 固有処理
		## ノート番号 or コントロール番号 or ピッチベンド値(LSB) 取得
		### データ・バイト取得処理
		cat src/f_synth_check_and_enq_midimsg.getdatabyte.o
		#### 取得したバイトのMSB == 1(T == 0)なら繰り返す
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_getdatabyte) / 2)))
		### エンキュー
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_copy_to_reg_from_reg r1 r0
		## ベロシティ or ホイール回転角に比例した値 or ピッチベンド値(MSB) 取得
		### データ・バイト取得処理
		cat src/f_synth_check_and_enq_midimsg.getdatabyte.o
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_getdatabyte) / 2)))
		### エンキュー
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_copy_to_reg_from_reg r1 r0

		# 退避したレジスタを復帰
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_check_and_enq_midimsg.noteonoff.o
	local sz_noteonoff=$(stat -c '%s' src/f_synth_check_and_enq_midimsg.noteonoff.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_noteonoff - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.noteonoff.o

	# ステータス・バイト == 0xc0?
	sh2_compare_r0_eq_val c0
	## ステータス・バイト != 0xc0の時、T == 0

	# ステータス・バイト == 0xc0なら
	# プログラム・チェンジのMIDIメッセージをエンキュー
	(
		# ステータス・バイト == 0xc0の場合

		# ステータス・バイトをr1へコピーしておく
		sh2_copy_to_reg_from_reg r1 r0

		# 変更が発生するレジスタを退避
		sh2_copy_to_reg_from_pr r0
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

		# 使用するアドレスをレジスタへ設定
		copy_to_reg_from_val_long r2 $a_synth_midimsg_enq

		# ステータス・バイトをエンキュー
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_nop

		# MIDIメッセージ: プログラム・チェンジ 固有処理
		## プログラム番号取得
		### データ・バイト取得処理
		cat src/f_synth_check_and_enq_midimsg.getdatabyte.o
		#### 取得したバイトのMSB == 1(T == 0)なら繰り返す
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_getdatabyte) / 2)))
		### エンキュー
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_copy_to_reg_from_reg r1 r0

		# 退避したレジスタを復帰
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_check_and_enq_midimsg.progchg.o
	local sz_progchg=$(stat -c '%s' src/f_synth_check_and_enq_midimsg.progchg.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_progchg - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.progchg.o

	# ステータス・バイト == 0xfa || ステータス・バイト == 0xfc ?
	## フラグをゼロクリア
	sh2_set_reg r1 00
	## ステータス・バイト == 0xfaならフラグをセット
	sh2_compare_r0_eq_val fa
	### ステータス・バイト != 0xfaの時、T == 0
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_setr101 - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.setr101.o
	## ステータス・バイト == 0xfcならフラグをセット
	sh2_compare_r0_eq_val fc
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_setr101 - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.setr101.o
	## フラグはセットされているか?
	sh2_set_reg r2 01
	sh2_compare_reg_eq_reg r1 r2
	### フラグがセットされていない時、T == 0

	# ステータス・バイト == 0xfa || ステータス・バイト == 0xfc なら
	# スタート,ストップのMIDIメッセージをエンキュー
	(
		# ステータス・バイト == 0xfa || ステータス・バイト == 0xfc の場合

		# ステータス・バイトをr1へコピーしておく
		sh2_copy_to_reg_from_reg r1 r0

		# 変更が発生するレジスタを退避
		sh2_copy_to_reg_from_pr r0
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

		# 使用するアドレスをレジスタへ設定
		copy_to_reg_from_val_long r2 $a_synth_midimsg_enq

		# ステータス・バイトをエンキュー
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_nop

		# 退避したレジスタを復帰
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_check_and_enq_midimsg.startstop.o
	local sz_startstop=$(stat -c '%s' src/f_synth_check_and_enq_midimsg.startstop.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_startstop - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.startstop.o

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# シンセ共通部分を初期化する
f_synth_common_init() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2

	# SCSP共通制御レジスタを設定
	copy_to_reg_from_val_long r1 $SS_CT_SND_COMMONCTR_ADDR
	## 0x00: 0x020a
	## ---- --12 3333 4444
	## 1:MEM4MB memory size 2:DAC18B dac for digital output
	## 3:VER version number 4:MVOL
	copy_to_reg_from_val_word r2 020a
	sh2_copy_to_ptr_from_reg_word r1 r2

	# 退避したレジスタを復帰しreturn
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# スロットを初期化する
# in  : r1 - スロット番号
f_synth_slot_init() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2

	# スロット別制御レジスタを設定
	## レジスタの先頭アドレスをr1へ設定
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical r1
	copy_to_reg_from_val_long r2 $SS_CT_SND_SLOTCTR_S0_ADDR
	sh2_add_to_reg_from_reg r1 r2
	## 0x00: 0x0020
	## ---1 2334 4556 7777
	## 1:KYONEX 2:KYONB 3:SBCTL 4:SSCTL 5:LPCTL 6:PCM8B
	## 7:SA start address
	sh2_set_reg r2 20
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x02: 0x1000
	## 1111 1111 1111 1111
	## 1:SA start address
	sh2_set_reg r2 10
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x04: 0x0000
	## 1111 1111 1111 1111
	## 1:LSA loop start address
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x06: 0x00$OSC_PCM_NUM_SAMPLES
	## 1111 1111 1111 1111
	## 1:LEA loop end address
	sh2_set_reg r2 $OSC_PCM_NUM_SAMPLES
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x08: 0x001F
	## 1111 1222 2234 4444
	## 1:D2R decay 2 rate 2:D1R decay 1 rate 3:EGHOLD eg hold mode
	## 4:AR attack rate
	sh2_set_reg r2 1f
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x0A: 0x3FFF
	## -122 2233 3334 4444
	## 1:LPSLNK loop start link 2:KRS key rate scaling 3:DL decay level
	## 4:RR release rate
	sh2_set_reg r0 3f
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ff
	sh2_copy_to_ptr_from_reg_word r1 r0
	sh2_add_to_reg_from_val_byte r1 02
	## 0x0C: 0x0000
	## ---- --12 3333 3333
	## 1:STWINH stack write inhibit 2:SDIR sound direct 3:TL total level
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x0E: 0x0000
	## 1111 2222 2233 3333
	## 1:MDL modulation level 2:MDXSL modulation input x
	## 3:MDYSL modulation input y
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x10: 0x0000
	## -111 1-22 2222 2222
	## 1:OCT octave 2:FNS frequency number switch
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x12: 0x0000
	## 1222 2233 4445 5666
	## 1:LFORE 2:LFOF 3:PLFOWS 4:PLFOS 5:ALFOWS 6:ALFOS
	copy_to_reg_from_val_word r2 0000
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x14: 0x0000
	## ---- ---- -111 1222
	## 1:ISEL input select 2:OMXL input mix level
	sh2_set_reg r2 00
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02
	## 0x16: 0xE000
	## 1112 2222 3334 4444
	## 1:DISDL 2:DIPAN 3:EFSDL 4:EFPAN
	sh2_set_reg r2 e0
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_shift_left_logical_8 r2
	sh2_copy_to_ptr_from_reg_word r1 r2
	sh2_add_to_reg_from_val_byte r1 02

	# 退避したレジスタを復帰しreturn
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# スロットを指定された音階でKEY_ONする
# in  : r1 - スロット番号
#     : r2 - PITCHレジスタ値
#     : r3 - ノート番号
f_key_on_with_pitch() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# 一応、r2の上位2バイトをゼロクリア
	sh2_extend_unsigned_to_reg_from_reg_word r2 r2

	# スロット番号をr13へコピー
	sh2_copy_to_reg_from_reg r13 r1

	# 指定されたスロット番号のスロット別制御レジスタのアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical r1
	sh2_add_to_reg_from_reg r14 r1

	# PITCHレジスタ設定
	sh2_add_to_reg_from_val_byte r14 10
	sh2_copy_to_ptr_from_reg_word r14 r2

	# KEY_ON設定
	sh2_add_to_reg_from_val_byte r14 $(two_comp 10)
	sh2_copy_to_reg_from_ptr_word r0 r14
	sh2_set_reg r1 18
	sh2_shift_left_logical_8 r1
	sh2_or_to_reg_from_reg r0 r1
	sh2_copy_to_ptr_from_reg_word r14 r0

	# スロットの状態管理変数更新
	## 該当スロットの変数のアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_synth_slot_state_base
	sh2_add_to_reg_from_reg r1 r13
	## 変数更新
	sh2_copy_to_ptr_from_reg_byte r1 r3
	## ピッチ値を求める (OCT >> 1) | FNS
	### OCTビットを抽出し1ビット右シフトした値をr1へ設定
	sh2_set_reg r0 78
	sh2_shift_left_logical_8 r0
	sh2_copy_to_reg_from_reg r1 r2
	sh2_and_to_reg_from_reg r1 r0
	sh2_shift_right_logical r1
	### FNSビットを抽出しr2へ設定
	sh2_set_reg r0 03
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ff
	sh2_and_to_reg_from_reg r2 r0
	## r2 |= r1
	sh2_or_to_reg_from_reg r2 r1
	## 該当スロットのピッチ値の変数のアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_synth_slot_pitchval_base
	sh2_shift_left_logical r13
	sh2_add_to_reg_from_reg r1 r13
	## 変数更新
	sh2_copy_to_ptr_from_reg_word r1 r2

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定されたスロットをKEY_OFFする
# in  : r1 - スロット番号
f_key_off() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# スロット番号をr13へコピー
	sh2_copy_to_reg_from_reg r13 r1

	# 指定されたスロット番号のスロット別制御レジスタのアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical r1
	sh2_add_to_reg_from_reg r14 r1

	# KEY_OFF設定
	sh2_copy_to_reg_from_ptr_word r1 r14
	sh2_set_reg r0 f7
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ff
	sh2_and_to_reg_from_reg r1 r0
	sh2_set_reg r0 10
	sh2_shift_left_logical_8 r0
	sh2_or_to_reg_from_reg r1 r0
	sh2_copy_to_ptr_from_reg_word r14 r1

	# スロットの状態管理変数更新
	## 該当スロットの変数のアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_synth_slot_state_base
	sh2_add_to_reg_from_reg r1 r13
	## 変数更新
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# KEY_OFFのスロット番号を返す
# out : r1 - スロット番号
f_synth_get_slot_off() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# スロットの状態管理変数のアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $var_synth_slot_state_base

	# スロット番号0を仮定
	sh2_set_reg r1 00

	# KEY_OFFスロットを見つけるまで繰り返し
	(
		# 変数値を取得
		sh2_copy_to_reg_from_ptr_byte r0 r14
		# スロット番号と変数アドレスを進める
		sh2_add_to_reg_from_val_byte r1 01
		sh2_add_to_reg_from_val_byte r14 01
		# 取得した値 == 0?
		sh2_compare_r0_eq_val 00
	) >src/f_synth_get_slot_off.1.o
	cat src/f_synth_get_slot_off.1.o
	local sz_1=$(stat -c '%s' src/f_synth_get_slot_off.1.o)
	## 取得した値 != 0 (T == 0)なら繰り返す
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_1) / 2)))

	# -1した値が見つけたスロット番号
	sh2_add_to_reg_from_val_byte r1 $(two_comp_d 1)

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定されたノート番号を鳴らしているスロット番号を返す
# in  : r1 - ノート番号
# out : r1 - スロット番号
#            ※ 無かった場合は$SLOT_NOT_FOUNDを返す
f_synth_get_slot_on_with_note() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
	## r3
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r3
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14

	# ノート番号をr13へコピーしておく
	sh2_copy_to_reg_from_reg r13 r1

	# スロットの状態管理変数のアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $var_synth_slot_state_base

	# 戻り値を無かった場合の値で初期化
	sh2_set_reg r1 $SLOT_NOT_FOUND

	# スロット番号を0〜31まで繰り返し
	sh2_set_reg r2 00
	sh2_set_reg r3 1f
	(
		# 変数値を取得
		sh2_copy_to_reg_from_ptr_byte r0 r14

		# 取得した値 == 指定されたノート番号?
		sh2_compare_reg_eq_reg r0 r13
		(
			# 取得した値 == 指定されたノート番号の場合

			# 戻り値を設定
			sh2_copy_to_reg_from_reg r1 r2

			# 退避したレジスタを復帰しreturn
			## r14
			sh2_copy_to_reg_from_ptr_long r14 r15
			sh2_add_to_reg_from_val_byte r15 04
			## r13
			sh2_copy_to_reg_from_ptr_long r13 r15
			sh2_add_to_reg_from_val_byte r15 04
			## r3
			sh2_copy_to_reg_from_ptr_long r3 r15
			sh2_add_to_reg_from_val_byte r15 04
			## r2
			sh2_copy_to_reg_from_ptr_long r2 r15
			sh2_add_to_reg_from_val_byte r15 04
			## r0
			sh2_copy_to_reg_from_ptr_long r0 r15
			sh2_add_to_reg_from_val_byte r15 04
			## return
			sh2_return_after_next_inst
			sh2_nop
		) >src/f_synth_get_slot_on_with_note.found.o
		local sz_found=$(stat -c '%s' src/f_synth_get_slot_on_with_note.found.o)
		sh2_rel_jump_if_false $(two_digits_d $(((sz_found - 2) / 2)))
		cat src/f_synth_get_slot_on_with_note.found.o

		# スロット番号と変数アドレスを進める
		sh2_add_to_reg_from_val_byte r2 01
		sh2_add_to_reg_from_val_byte r14 01

		# スロット番号 > 31?
		sh2_compare_reg_gt_reg_unsigned r2 r3
	) >src/f_synth_get_slot_on_with_note.1.o
	cat src/f_synth_get_slot_on_with_note.1.o
	local sz_1=$(stat -c '%s' src/f_synth_get_slot_on_with_note.1.o)
	## スロット番号 > 31ならループを抜ける
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_1) / 2)))

	# 退避したレジスタを復帰しreturn
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r3
	sh2_copy_to_reg_from_ptr_long r3 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r2
	sh2_copy_to_reg_from_ptr_long r2 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# ノート・オンの場合の処理
# in  : r1 - ノート・オン対象のノート番号
f_synth_proc_noteon() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r3
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r4
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r5
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# 使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $a_synth_check_and_enq_midimsg

	# ノート番号に応じたPITCHレジスタ値をr3へ設定
	local note_dec note pitch sz_nXX
	## ノート番号 == 0x54の場合の処理
	note=54
	### ノート番号に応じたPITCHレジスタ値を表から取得
	pitch=$(awk -F ',' '$1=="'$note'"{print $2}' $NOTE_PITCH_CSV)
	(
		# PITCHレジスタ値をr3へ設定
		sh2_set_reg r0 $(echo $pitch | cut -c1-2)
		sh2_shift_left_logical_8 r0
		sh2_or_to_r0_from_val_byte $(echo $pitch | cut -c3-4)
		sh2_copy_to_reg_from_reg r3 r0

		# MIBUFに注目対象のMIDIメッセージがあれば取得し
		# 専用のキュー(SYNTH_MIDIMSG_QUEUE)へエンキュー
		sh2_abs_call_to_reg_after_next_inst r14
		sh2_nop
	) >src/main_n${note}.o
	local sz_nXX=$(stat -c '%s' src/main_n${note}.o)
	local sz_esc=$((6 + sz_nXX))
	## ノート番号が0x30(48)〜0x53(83)の場合の処理
	for note_dec in $(seq 48 83 | tac); do
		# ノート番号を16進数へ変換
		note=$(to16_2 $note_dec)

		# ノート番号に応じたPITCHレジスタ値を表から取得
		pitch=$(awk -F ',' '$1=="'$note'"{print $2}' $NOTE_PITCH_CSV)

		# 処理を生成
		(
			# PITCHレジスタ値をr3へ設定
			sh2_set_reg r0 $(echo $pitch | cut -c1-2)
			sh2_shift_left_logical_8 r0
			sh2_or_to_r0_from_val_byte $(echo $pitch | cut -c3-4)
			sh2_copy_to_reg_from_reg r3 r0

			# MIBUFに注目対象のMIDIメッセージがあれば取得し
			# 専用のキュー(SYNTH_MIDIMSG_QUEUE)へエンキュー
			sh2_abs_call_to_reg_after_next_inst r14
			sh2_nop

			# 以降の条件処理を飛ばす
			sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_esc / 2))) 3)
			sh2_nop
		) >src/main_n${note}.o
		sz_nXX=$(stat -c '%s' src/main_n${note}.o)
		sz_esc=$((sz_esc + 6 + sz_nXX))
	done
	## ノート番号が0x30(48)〜0x54(84)の場合の条件分岐
	for note_dec in $(seq 48 84); do
		# ノート番号を16進数へ変換
		note=$(to16_2 $note_dec)

		# ノート番号に応じた処理
		sh2_set_reg r0 $note
		sh2_compare_reg_eq_reg r1 r0
		sz_nXX=$(stat -c '%s' src/main_n${note}.o)
		sh2_rel_jump_if_false $(two_digits_d $(((sz_nXX - 2) / 2)))
		cat src/main_n${note}.o
	done

	# ノート番号をr4へコピーしておく
	sh2_copy_to_reg_from_reg r4 r1

	# KEY_OFFのスロット番号を取得
	copy_to_reg_from_val_long r1 $a_synth_get_slot_off
	sh2_abs_call_to_reg_after_next_inst r1
	sh2_nop

	# MIBUFに注目対象のMIDIメッセージがあれば取得し
	# 専用のキュー(SYNTH_MIDIMSG_QUEUE)へエンキュー
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 取得した番号のスロットをr3のPITCHレジスタ値でKEY_ONする
	copy_to_reg_from_val_long r5 $a_key_on_with_pitch
	sh2_copy_to_reg_from_reg r2 r3
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_copy_to_reg_from_reg r3 r4

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_pr_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r5 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r4 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# スロットの波形データ開始アドレスを設定する
# in  : r1 - スロット番号
#     : r2 - 開始アドレス
# ※ 開始アドレスは2バイト以内であること
f_synth_set_start_addr() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

	# 指定されたスロット番号のスロット別制御レジスタのアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical r1
	sh2_add_to_reg_from_reg r14 r1

	# 開始アドレス下位2バイトのレジスタへのオフセットを加算
	sh2_add_to_reg_from_val_byte r14 02

	# 開始アドレスを設定
	sh2_copy_to_ptr_from_reg_word r14 r2

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 現在のオシレータを示すカーソルを表示する
# ※ スロット間で設定値は同一という想定でスロット0の値を表示
f_synth_put_osc_param() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r3
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r4
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# Y座標をr3へ設定
	copy_to_reg_from_val_long r1 $var_synth_current_osc_cursor_y
	sh2_copy_to_reg_from_ptr_byte r3 r1
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	# X座標をr2へ設定
	sh2_set_reg r2 $OSC_CURSOR_X

	# '>'を表示
	copy_to_reg_from_val_long r4 $a_putchar_xy
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_set_reg r1 $CHARCODE_GREATER_THAN

	# 次に表示するときのために各種アドレス変数を戻す
	## キャラクタパターンを配置するアドレス
	## 1文字のフォントサイズ($CON_FONT_SIZE)分戻す
	copy_to_reg_from_val_long r1 $var_next_cp_other_addr
	sh2_copy_to_reg_from_ptr_long r2 r1
	sh2_set_reg r3 $CON_FONT_SIZE
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	sh2_sub_to_reg_from_reg r2 r3
	sh2_copy_to_ptr_from_reg_long r1 r2
	## VDPコマンドを配置するアドレス
	## コマンドのサイズ(32=0x20)分戻す
	copy_to_reg_from_val_long r1 $var_next_vdpcom_other_addr
	sh2_copy_to_reg_from_ptr_long r2 r1
	sh2_set_reg r3 20
	sh2_sub_to_reg_from_reg r2 r3
	sh2_copy_to_ptr_from_reg_long r1 r2

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_pr_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r4 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# LFO関連のレジスタの現在値を表示する
# ※ スロット間で設定値は同一という想定でスロット0の値を表示
# ※ 各ビットフィールドの値を表示する座標はグローバル変数で定義
f_synth_put_lfo_param() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r3
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r12
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14
	sh2_copy_to_reg_from_macl r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# 繰り返し使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $(calc16_8 "$SS_CT_SND_SLOTCTR_S0_ADDR+8")
	copy_to_reg_from_val_long r13 $a_putreg_xy_byte
	copy_to_reg_from_val_long r12 $a_putchar_xy

	# r14がLFOFを含む1ワードのレジスタを指すようにオフセットを加える
	sh2_add_to_reg_from_val_byte r14 0a

	# LFOFビット
	## レジスタのLFOFビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	set_mask_expose_lfof_to_r0
	sh2_and_to_reg_from_reg r1 r0
	shift_lfof_to_lsb r1
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r2 $DUMP_LFO_LFOF_X
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_set_reg r3 $DUMP_LFO_LFOF_Y
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	# PLFOWSビット
	## レジスタのPLFOWSビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	set_mask_expose_plfows_to_r0
	sh2_and_to_reg_from_reg r1 r0
	shift_plfows_to_lsb r1
	## カーソルのY座標をr3へ設定
	## r3 = coef * r1 + base
	sh2_set_reg r3 $DUMP_LFO_PLFOWS_Y_BASE
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	sh2_set_reg r0 $DUMP_LFO_PLFOWS_Y_COEF
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
	sh2_multiply_reg_by_reg_unsigned_word r0 r1
	sh2_copy_to_reg_from_macl r0
	sh2_add_to_reg_from_reg r3 r0
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r2 $DUMP_LFO_PLFOWS_X
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_abs_call_to_reg_after_next_inst r12
	sh2_set_reg r1 $CHARCODE_GREATER_THAN

	# PLFOSビット
	## レジスタのPLFOSビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	set_mask_expose_plfos_to_r0
	sh2_and_to_reg_from_reg r1 r0
	shift_plfos_to_lsb r1
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r2 $DUMP_LFO_PLFOS_X
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_set_reg r3 $DUMP_LFO_PLFOS_Y
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	# ALFOWSビット
	## レジスタのALFOWSビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	set_mask_expose_alfows_to_r0
	sh2_and_to_reg_from_reg r1 r0
	shift_alfows_to_lsb r1
	## カーソルのY座標をr3へ設定
	## r3 = coef * r1 + base
	sh2_set_reg r3 $DUMP_LFO_ALFOWS_Y_BASE
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	sh2_set_reg r0 $DUMP_LFO_ALFOWS_Y_COEF
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
	sh2_multiply_reg_by_reg_unsigned_word r0 r1
	sh2_copy_to_reg_from_macl r0
	sh2_add_to_reg_from_reg r3 r0
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r2 $DUMP_LFO_ALFOWS_X
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_abs_call_to_reg_after_next_inst r12
	sh2_set_reg r1 $CHARCODE_LESS_THAN

	# ALFOSビット
	## レジスタのALFOSビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	set_mask_expose_alfos_to_r0
	sh2_and_to_reg_from_reg r1 r0
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r0 $(echo $DUMP_LFO_ALFOS_X | cut -c1-2)
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte $(echo $DUMP_LFO_ALFOS_X | cut -c3-4)
	sh2_copy_to_reg_from_reg r2 r0
	sh2_set_reg r3 $DUMP_LFO_ALFOS_Y
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	# 次に表示するときのために各種アドレス変数を戻す
	## キャラクタパターンを配置するアドレス
	## 8文字のフォントサイズ分戻す
	## $CON_FONT_SIZE * 8
	## = $CON_FONT_SIZE * (4 + 4)
	## = ($CON_FONT_SIZE * 4) + ($CON_FONT_SIZE * 4)
	## = ($CON_FONT_SIZE * 2^2) + ($CON_FONT_SIZE * 2^2)
	## = ($CON_FONT_SIZE << 2) + ($CON_FONT_SIZE << 2)
	copy_to_reg_from_val_long r1 $var_next_cp_other_addr
	sh2_copy_to_reg_from_ptr_long r2 r1
	sh2_set_reg r3 $CON_FONT_SIZE
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	sh2_copy_to_reg_from_reg r0 r3
	### $CON_FONT_SIZE << 2
	sh2_shift_left_logical_2 r3
	### $CON_FONT_SIZE << 2
	sh2_shift_left_logical_2 r0
	### ($CON_FONT_SIZE << 2) + ($CON_FONT_SIZE << 2)
	sh2_add_to_reg_from_reg r3 r0
	sh2_sub_to_reg_from_reg r2 r3
	sh2_copy_to_ptr_from_reg_long r1 r2
	## VDPコマンドを配置するアドレス
	## コマンド8個のサイズ(32 * 8 = 256 = 0x100)分戻す
	copy_to_reg_from_val_long r1 $var_next_vdpcom_other_addr
	sh2_copy_to_reg_from_ptr_long r2 r1
	sh2_set_reg r0 01
	sh2_shift_left_logical_8 r0
	sh2_sub_to_reg_from_reg r2 r0
	sh2_copy_to_ptr_from_reg_long r1 r2

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_pr_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_macl_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r12 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# プログラム・チェンジ固有処理
f_synth_proc_progchg() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# プログラム番号をデキュー
	copy_to_reg_from_val_long r1 $a_synth_midimsg_deq
	sh2_abs_call_to_reg_after_next_inst r1
	sh2_nop

	# 繰り返し使用する処理をファイルへ出力
	set_to_all_slot_regs_from_reg r2 r14 r0 r1 >src/f_synth_proc_progchg.setallslot.o
	(
		# カーソル表示を更新
		copy_to_reg_from_val_long r14 $a_synth_put_osc_param
		sh2_abs_call_to_reg_after_next_inst r14
		sh2_nop
	) >src/f_synth_proc_progchg.updatecursor.o
	local sz_updatecursor=$(stat -c '%s' src/f_synth_proc_progchg.updatecursor.o)
	(
		# LFO関連のパラメータ表示を更新
		copy_to_reg_from_val_long r14 $a_synth_put_lfo_param
		sh2_abs_call_to_reg_after_next_inst r14
		sh2_nop
	) >src/f_synth_proc_progchg.updatelfo.o
	local sz_updatelfo=$(stat -c '%s' src/f_synth_proc_progchg.updatelfo.o)

	# SSCTL・SA[15:0]設定
	## プログラム番号 == $PROGNUM_OSC_SAW?
	sh2_set_reg r0 $PROGNUM_OSC_SAW
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_OSC_SAWならT == 0
	(
		# プログラム番号 == $PROGNUM_OSC_SAW の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 現在のオシレータカーソルY座標の変数を更新
		copy_to_reg_from_val_long r14 $var_synth_current_osc_cursor_y
		sh2_set_reg r0 $OSC_CURSOR_Y_SAW
		sh2_copy_to_ptr_from_reg_byte r14 r0

		# 現在の画面がオシレータ設定画面ならカーソル表示を更新
		## 現在の画面番号変数のアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		## 現在の画面番号をr1へ設定
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_OSC?
		sh2_set_reg r0 $SCRNUM_OSC
		sh2_compare_reg_eq_reg r1 r0
		## 現在の画面番号 == $SCRNUM_OSCならカーソル表示を更新
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatecursor - 2) / 2)))
		cat src/f_synth_proc_progchg.updatecursor.o

		# 繰り返し使用するアドレスをレジスタへ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_copy_to_reg_from_reg r13 r14

		# 全スロットのSSCTL=0
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## SSCTLを0するマスクをr0へ設定
		set_mask_expose_ssctl_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のSSCTLビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# SA[15:0]設定
		## スロットのレジスタへ設定する値をr2へ設定
		### 1ワード分のみ設定する
		copy_to_reg_from_val_word r2 $(echo $OSC_PCM_SAW_MC68K_BASE | cut -c5-8)
		## スロット0における該当レジスタアドレスをr14へ設定
		sh2_copy_to_reg_from_reg r14 r13
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_SA_15_0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.sa.saw.o
	local sz_sa_saw=$(stat -c '%s' src/f_synth_proc_progchg.sa.saw.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_sa_saw - 2) / 2)))
	cat src/f_synth_proc_progchg.sa.saw.o
	## プログラム番号 == $PROGNUM_OSC_SQU?
	sh2_set_reg r0 $PROGNUM_OSC_SQU
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_OSC_SQUならT == 0
	(
		# プログラム番号 == $PROGNUM_OSC_SQU の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 現在のオシレータカーソルY座標の変数を更新
		copy_to_reg_from_val_long r14 $var_synth_current_osc_cursor_y
		sh2_set_reg r0 $OSC_CURSOR_Y_SQU
		sh2_copy_to_ptr_from_reg_byte r14 r0

		# 現在の画面がオシレータ設定画面ならカーソル表示を更新
		## 現在の画面番号変数のアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		## 現在の画面番号をr1へ設定
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_OSC?
		sh2_set_reg r0 $SCRNUM_OSC
		sh2_compare_reg_eq_reg r1 r0
		## 現在の画面番号 == $SCRNUM_OSCならカーソル表示を更新
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatecursor - 2) / 2)))
		cat src/f_synth_proc_progchg.updatecursor.o

		# 繰り返し使用するアドレスをレジスタへ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_copy_to_reg_from_reg r13 r14

		# 全スロットのSSCTL=0
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## SSCTLを0するマスクをr0へ設定
		set_mask_expose_ssctl_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のSSCTLビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# SA[15:0]設定
		## スロットのレジスタへ設定する値をr2へ設定
		### 1ワード分のみ設定する
		copy_to_reg_from_val_word r2 $(echo $OSC_PCM_SQU_MC68K_BASE | cut -c5-8)
		## スロット0における該当レジスタアドレスをr14へ設定
		sh2_copy_to_reg_from_reg r14 r13
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_SA_15_0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.sa.squ.o
	local sz_sa_squ=$(stat -c '%s' src/f_synth_proc_progchg.sa.squ.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_sa_squ - 2) / 2)))
	cat src/f_synth_proc_progchg.sa.squ.o
	## プログラム番号 == $PROGNUM_OSC_SIN?
	sh2_set_reg r0 $PROGNUM_OSC_SIN
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_OSC_SINならT == 0
	(
		# プログラム番号 == $PROGNUM_OSC_SIN の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 現在のオシレータカーソルY座標の変数を更新
		copy_to_reg_from_val_long r14 $var_synth_current_osc_cursor_y
		sh2_set_reg r0 $OSC_CURSOR_Y_SIN
		sh2_copy_to_ptr_from_reg_byte r14 r0

		# 現在の画面がオシレータ設定画面ならカーソル表示を更新
		## 現在の画面番号変数のアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		## 現在の画面番号をr1へ設定
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_OSC?
		sh2_set_reg r0 $SCRNUM_OSC
		sh2_compare_reg_eq_reg r1 r0
		## 現在の画面番号 == $SCRNUM_OSCならカーソル表示を更新
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatecursor - 2) / 2)))
		cat src/f_synth_proc_progchg.updatecursor.o

		# 繰り返し使用するアドレスをレジスタへ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_copy_to_reg_from_reg r13 r14

		# 全スロットのSSCTL=0
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## SSCTLを0するマスクをr0へ設定
		set_mask_expose_ssctl_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のSSCTLビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# SA[15:0]設定
		## スロットのレジスタへ設定する値をr2へ設定
		### 1ワード分のみ設定する
		copy_to_reg_from_val_word r2 $(echo $OSC_PCM_SIN_MC68K_BASE | cut -c5-8)
		## スロット0における該当レジスタアドレスをr14へ設定
		sh2_copy_to_reg_from_reg r14 r13
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_SA_15_0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.sa.sin.o
	local sz_sa_sin=$(stat -c '%s' src/f_synth_proc_progchg.sa.sin.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_sa_sin - 2) / 2)))
	cat src/f_synth_proc_progchg.sa.sin.o
	## プログラム番号 == $PROGNUM_OSC_NOISE?
	sh2_set_reg r0 $PROGNUM_OSC_NOISE
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_OSC_NOISEならT == 0
	(
		# プログラム番号 == $PROGNUM_OSC_NOISE の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 現在のオシレータカーソルY座標の変数を更新
		copy_to_reg_from_val_long r14 $var_synth_current_osc_cursor_y
		sh2_set_reg r0 $OSC_CURSOR_Y_NOISE
		sh2_copy_to_ptr_from_reg_byte r14 r0

		# 現在の画面がオシレータ設定画面ならカーソル表示を更新
		## 現在の画面番号変数のアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		## 現在の画面番号をr1へ設定
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_OSC?
		sh2_set_reg r0 $SCRNUM_OSC
		sh2_compare_reg_eq_reg r1 r0
		## 現在の画面番号 == $SCRNUM_OSCならカーソル表示を更新
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatecursor - 2) / 2)))
		cat src/f_synth_proc_progchg.updatecursor.o

		# 全スロットのSSCTL=1
		## スロット0における該当レジスタアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## SSCTLを0するマスクをr0へ設定
		set_mask_expose_ssctl_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のSSCTLビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## r2 |= 0x80 (SSCTL=1)
		sh2_copy_to_reg_from_reg r0 r2
		sh2_or_to_r0_from_val_byte 80
		sh2_copy_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.sa.sin.o
	local sz_sa_sin=$(stat -c '%s' src/f_synth_proc_progchg.sa.sin.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_sa_sin - 2) / 2)))
	cat src/f_synth_proc_progchg.sa.sin.o

	# PLFOWS設定
	## プログラム番号 == $PROGNUM_LFO_PLFOWS_SAW?
	sh2_set_reg r0 $PROGNUM_LFO_PLFOWS_SAW
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_LFO_PLFOWS_SAWならT == 0
	(
		# プログラム番号 == $PROGNUM_LFO_PLFOWS_SAW の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 全スロットのPLFOWS=0
		## スロット0における該当レジスタアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_RE_LFOF_PLFOWS_PLFOS_ALFOWS_ALFOS
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## PLFOWSを0するマスクをr0へ設定
		set_mask_expose_plfows_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のPLFOWSビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 現在の画面番号に応じてパラメータ表示を更新
		## 現在の画面番号をr1へ取得
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_LFOならLFO関連のパラメータ表示を更新
		sh2_set_reg r0 $SCRNUM_LFO
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatelfo - 2) / 2)))
		cat src/f_synth_proc_progchg.updatelfo.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.plfows.saw.o
	local sz_plfows_saw=$(stat -c '%s' src/f_synth_proc_progchg.plfows.saw.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_plfows_saw - 2) / 2)))
	cat src/f_synth_proc_progchg.plfows.saw.o
	## プログラム番号 == $PROGNUM_LFO_PLFOWS_SQU?
	sh2_set_reg r0 $PROGNUM_LFO_PLFOWS_SQU
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_LFO_PLFOWS_SQUならT == 0
	(
		# プログラム番号 == $PROGNUM_LFO_PLFOWS_SQU の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 全スロットのPLFOWS=1
		## スロット0における該当レジスタアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_RE_LFOF_PLFOWS_PLFOS_ALFOWS_ALFOS
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## PLFOWSを0するマスクをr0へ設定
		set_mask_expose_plfows_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のPLFOWSビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## r2 |= 0x0100 (PLFOWS=1)
		sh2_set_reg r0 01
		sh2_shift_left_logical_8 r0
		sh2_or_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 現在の画面番号に応じてパラメータ表示を更新
		## 現在の画面番号をr1へ取得
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_LFOならLFO関連のパラメータ表示を更新
		sh2_set_reg r0 $SCRNUM_LFO
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatelfo - 2) / 2)))
		cat src/f_synth_proc_progchg.updatelfo.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.plfows.squ.o
	local sz_plfows_squ=$(stat -c '%s' src/f_synth_proc_progchg.plfows.squ.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_plfows_squ - 2) / 2)))
	cat src/f_synth_proc_progchg.plfows.squ.o
	## プログラム番号 == $PROGNUM_LFO_PLFOWS_TRI?
	sh2_set_reg r0 $PROGNUM_LFO_PLFOWS_TRI
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_LFO_PLFOWS_TRIならT == 0
	(
		# プログラム番号 == $PROGNUM_LFO_PLFOWS_TRI の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 全スロットのPLFOWS=2
		## スロット0における該当レジスタアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_RE_LFOF_PLFOWS_PLFOS_ALFOWS_ALFOS
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## PLFOWSを0するマスクをr0へ設定
		set_mask_expose_plfows_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のPLFOWSビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## r2 |= 0x0200 (PLFOWS=2)
		sh2_set_reg r0 02
		sh2_shift_left_logical_8 r0
		sh2_or_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 現在の画面番号に応じてパラメータ表示を更新
		## 現在の画面番号をr1へ取得
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_LFOならLFO関連のパラメータ表示を更新
		sh2_set_reg r0 $SCRNUM_LFO
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatelfo - 2) / 2)))
		cat src/f_synth_proc_progchg.updatelfo.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.plfows.tri.o
	local sz_plfows_tri=$(stat -c '%s' src/f_synth_proc_progchg.plfows.tri.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_plfows_tri - 2) / 2)))
	cat src/f_synth_proc_progchg.plfows.tri.o
	## プログラム番号 == $PROGNUM_LFO_PLFOWS_NOISE?
	sh2_set_reg r0 $PROGNUM_LFO_PLFOWS_NOISE
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_LFO_PLFOWS_NOISEならT == 0
	(
		# プログラム番号 == $PROGNUM_LFO_PLFOWS_NOISE の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 全スロットのPLFOWS=3
		## スロット0における該当レジスタアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_RE_LFOF_PLFOWS_PLFOS_ALFOWS_ALFOS
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## PLFOWSを0するマスクをr0へ設定
		set_mask_expose_plfows_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のPLFOWSビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## r2 |= 0x0300 (PLFOWS=3)
		sh2_set_reg r0 03
		sh2_shift_left_logical_8 r0
		sh2_or_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 現在の画面番号に応じてパラメータ表示を更新
		## 現在の画面番号をr1へ取得
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_LFOならLFO関連のパラメータ表示を更新
		sh2_set_reg r0 $SCRNUM_LFO
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatelfo - 2) / 2)))
		cat src/f_synth_proc_progchg.updatelfo.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.plfows.noise.o
	local sz_plfows_noise=$(stat -c '%s' src/f_synth_proc_progchg.plfows.noise.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_plfows_noise - 2) / 2)))
	cat src/f_synth_proc_progchg.plfows.noise.o

	# ALFOWS設定
	## プログラム番号 == $PROGNUM_LFO_ALFOWS_SAW?
	sh2_set_reg r0 $PROGNUM_LFO_ALFOWS_SAW
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_LFO_ALFOWS_SAWならT == 0
	(
		# プログラム番号 == $PROGNUM_LFO_ALFOWS_SAW の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 全スロットのALFOWS=0
		## スロット0における該当レジスタアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_RE_LFOF_PLFOWS_PLFOS_ALFOWS_ALFOS
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## ALFOWSを0するマスクをr0へ設定
		set_mask_expose_alfows_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のALFOWSビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 現在の画面番号に応じてパラメータ表示を更新
		## 現在の画面番号をr1へ取得
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_LFOならLFO関連のパラメータ表示を更新
		sh2_set_reg r0 $SCRNUM_LFO
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatelfo - 2) / 2)))
		cat src/f_synth_proc_progchg.updatelfo.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.alfows.saw.o
	local sz_alfows_saw=$(stat -c '%s' src/f_synth_proc_progchg.alfows.saw.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_alfows_saw - 2) / 2)))
	cat src/f_synth_proc_progchg.alfows.saw.o
	## プログラム番号 == $PROGNUM_LFO_ALFOWS_SQU?
	sh2_set_reg r0 $PROGNUM_LFO_ALFOWS_SQU
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_LFO_ALFOWS_SQUならT == 0
	(
		# プログラム番号 == $PROGNUM_LFO_ALFOWS_SQU の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 全スロットのALFOWS=1
		## スロット0における該当レジスタアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_RE_LFOF_PLFOWS_PLFOS_ALFOWS_ALFOS
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## ALFOWSを0するマスクをr0へ設定
		set_mask_expose_alfows_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のALFOWSビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## r2 |= 0x0008 (ALFOWS=1)
		sh2_set_reg r0 08
		sh2_or_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 現在の画面番号に応じてパラメータ表示を更新
		## 現在の画面番号をr1へ取得
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_LFOならLFO関連のパラメータ表示を更新
		sh2_set_reg r0 $SCRNUM_LFO
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatelfo - 2) / 2)))
		cat src/f_synth_proc_progchg.updatelfo.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.alfows.squ.o
	local sz_alfows_squ=$(stat -c '%s' src/f_synth_proc_progchg.alfows.squ.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_alfows_squ - 2) / 2)))
	cat src/f_synth_proc_progchg.alfows.squ.o
	## プログラム番号 == $PROGNUM_LFO_ALFOWS_TRI?
	sh2_set_reg r0 $PROGNUM_LFO_ALFOWS_TRI
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_LFO_ALFOWS_TRIならT == 0
	(
		# プログラム番号 == $PROGNUM_LFO_ALFOWS_TRI の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 全スロットのALFOWS=2
		## スロット0における該当レジスタアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_RE_LFOF_PLFOWS_PLFOS_ALFOWS_ALFOS
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## ALFOWSを0するマスクをr0へ設定
		set_mask_expose_alfows_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のALFOWSビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## r2 |= 0x0010 (ALFOWS=2)
		sh2_set_reg r0 10
		sh2_or_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 現在の画面番号に応じてパラメータ表示を更新
		## 現在の画面番号をr1へ取得
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_LFOならLFO関連のパラメータ表示を更新
		sh2_set_reg r0 $SCRNUM_LFO
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatelfo - 2) / 2)))
		cat src/f_synth_proc_progchg.updatelfo.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.alfows.tri.o
	local sz_alfows_tri=$(stat -c '%s' src/f_synth_proc_progchg.alfows.tri.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_alfows_tri - 2) / 2)))
	cat src/f_synth_proc_progchg.alfows.tri.o
	## プログラム番号 == $PROGNUM_LFO_ALFOWS_NOISE?
	sh2_set_reg r0 $PROGNUM_LFO_ALFOWS_NOISE
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != $PROGNUM_LFO_ALFOWS_NOISEならT == 0
	(
		# プログラム番号 == $PROGNUM_LFO_ALFOWS_NOISE の場合

		# 変更が発生するレジスタを退避
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

		# 全スロットのALFOWS=3
		## スロット0における該当レジスタアドレスをr14へ設定
		copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
		sh2_add_to_reg_from_val_byte r14 $SS_SND_SLOT_OFS_RE_LFOF_PLFOWS_PLFOS_ALFOWS_ALFOS
		## r2へ現在の値を1ワード分取得
		sh2_copy_to_reg_from_ptr_word r2 r14
		## ALFOWSを0するマスクをr0へ設定
		set_mask_expose_alfows_to_r0
		sh2_not_to_reg_from_reg r0 r0
		## r2のALFOWSビット部分を0にする
		sh2_and_to_reg_from_reg r2 r0
		## r2 |= 0x0018 (ALFOWS=3)
		sh2_set_reg r0 18
		sh2_or_to_reg_from_reg r2 r0
		## 全スロットへr2を設定
		cat src/f_synth_proc_progchg.setallslot.o

		# 現在の画面番号に応じてパラメータ表示を更新
		## 現在の画面番号をr1へ取得
		copy_to_reg_from_val_long r14 $var_synth_current_scrnum
		sh2_copy_to_reg_from_ptr_byte r1 r14
		## 現在の画面番号 == $SCRNUM_LFOならLFO関連のパラメータ表示を更新
		sh2_set_reg r0 $SCRNUM_LFO
		sh2_compare_reg_eq_reg r1 r0
		sh2_rel_jump_if_false $(two_digits_d $(((sz_updatelfo - 2) / 2)))
		cat src/f_synth_proc_progchg.updatelfo.o

		# 退避したレジスタを復帰
		## この処理
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_progchg.alfows.noise.o
	local sz_alfows_noise=$(stat -c '%s' src/f_synth_proc_progchg.alfows.noise.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_alfows_noise - 2) / 2)))
	cat src/f_synth_proc_progchg.alfows.noise.o

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_pr_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# スロットへピッチ値を加算する
# in  : r1 - スロット番号(0始まり)
#     : r2 - ピッチ値
f_synth_add_pitch_to_slot() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r3
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14

	# スロット番号をr3へコピー
	sh2_copy_to_reg_from_reg r3 r1

	# 指定されたスロット番号のスロット別制御レジスタのアドレスをr14へ設定
	copy_to_reg_from_val_long r14 $SS_CT_SND_SLOTCTR_S0_ADDR
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical_2 r1
	sh2_shift_left_logical r1
	sh2_add_to_reg_from_reg r14 r1

	# PITCHレジスタへのオフセットを加算
	sh2_add_to_reg_from_val_byte r14 10

	# 指定されたスロット番号のピッチ値の変数のアドレスをr13へ設定
	copy_to_reg_from_val_long r13 $var_synth_slot_pitchval_base
	sh2_shift_left_logical r3
	sh2_add_to_reg_from_reg r13 r3

	# スロットのピッチ値を取得
	sh2_copy_to_reg_from_ptr_word r1 r13

	# r1 += r2
	sh2_add_to_reg_from_reg r1 r2

	# r1からOCTとFNSを抽出しPITCHレジスタの形式にする
	## OCTビットを抽出し1ビット左シフトした値をr3へ設定
	sh2_set_reg r0 3c
	sh2_shift_left_logical_8 r0
	sh2_copy_to_reg_from_reg r3 r1
	sh2_and_to_reg_from_reg r3 r0
	sh2_shift_left_logical r3
	## FNSビットを抽出しr1へ設定
	sh2_set_reg r0 03
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte ff
	sh2_and_to_reg_from_reg r1 r0
	## r1 |= r3
	sh2_or_to_reg_from_reg r1 r3

	# 結果をPITCHレジスタへ設定
	sh2_copy_to_ptr_from_reg_word r14 r1

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# EG関連のレジスタの現在値を表示する
# ※ スロット間で設定値は同一という想定でスロット0の値を表示
# ※ 各ビットフィールドの値を表示する座標はグローバル変数で定義
f_synth_put_eg_param() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r3
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# 繰り返し使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $(calc16_8 "$SS_CT_SND_SLOTCTR_S0_ADDR+8")
	copy_to_reg_from_val_long r13 $a_putreg_xy_byte

	# ARビット
	## EGレジスタのARビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	sh2_set_reg r0 1f
	sh2_and_to_reg_from_reg r1 r0
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r2 $DUMP_EG_AR_X
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_set_reg r3 $DUMP_EG_AR_Y
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	# D1Rビット
	## EGレジスタのD1Rビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	set_mask_expose_d1r_to_r0
	sh2_and_to_reg_from_reg r1 r0
	shift_d1r_to_lsb r1
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r2 $DUMP_EG_D1R_X
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_set_reg r3 $DUMP_EG_D1R_Y
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	# D2Rビット
	## EGレジスタのD2Rビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	set_mask_expose_d2r_to_r0
	sh2_and_to_reg_from_reg r1 r0
	shift_d2r_to_lsb r1
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r2 $DUMP_EG_D2R_X
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_set_reg r3 $DUMP_EG_D2R_Y
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	# r14がRRとDLを含む1ワードのEGレジスタを指すようにオフセットを加える
	sh2_add_to_reg_from_val_byte r14 02

	# RRビット
	## EGレジスタのRRビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	set_mask_expose_rr_to_r0
	sh2_and_to_reg_from_reg r1 r0
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r2 $DUMP_EG_RR_X
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_set_reg r3 $DUMP_EG_RR_Y
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	# DLビット
	## EGレジスタのDLビットをr1へ取得
	sh2_copy_to_reg_from_ptr_word r1 r14
	set_mask_expose_dl_to_r0
	sh2_and_to_reg_from_reg r1 r0
	shift_dl_to_lsb r1
	## r1をグローバル変数で指定された座標へ出力
	sh2_set_reg r2 $DUMP_EG_DL_X
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	sh2_set_reg r3 $DUMP_EG_DL_Y
	sh2_abs_call_to_reg_after_next_inst r13
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	# 次に表示するときのために各種アドレス変数を戻す
	## キャラクタパターンを配置するアドレス
	## 10文字のフォントサイズ分戻す
	## $CON_FONT_SIZE * 10
	## = $CON_FONT_SIZE * (8 + 2)
	## = ($CON_FONT_SIZE * 8) + ($CON_FONT_SIZE * 2)
	## = ($CON_FONT_SIZE * 2^3) + ($CON_FONT_SIZE * 2^1)
	## = ($CON_FONT_SIZE << 3) + ($CON_FONT_SIZE << 1)
	copy_to_reg_from_val_long r1 $var_next_cp_other_addr
	sh2_copy_to_reg_from_ptr_long r2 r1
	sh2_set_reg r3 $CON_FONT_SIZE
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	sh2_copy_to_reg_from_reg r0 r3
	### $CON_FONT_SIZE << 3
	sh2_shift_left_logical_2 r3
	sh2_shift_left_logical r3
	### $CON_FONT_SIZE << 1
	sh2_shift_left_logical r0
	### ($CON_FONT_SIZE << 3) + ($CON_FONT_SIZE << 1)
	sh2_add_to_reg_from_reg r3 r0
	sh2_sub_to_reg_from_reg r2 r3
	sh2_copy_to_ptr_from_reg_long r1 r2
	## VDPコマンドを配置するアドレス
	## コマンド10個のサイズ(32 * 10 = 320 = 0x140)分戻す
	copy_to_reg_from_val_long r1 $var_next_vdpcom_other_addr
	sh2_copy_to_reg_from_ptr_long r2 r1
	sh2_set_reg r0 01
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte 40
	sh2_sub_to_reg_from_reg r2 r0
	sh2_copy_to_ptr_from_reg_long r1 r2

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_pr_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# アサイナブルホイール固有処理
f_synth_proc_assign() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# 繰り返し使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $a_synth_midimsg_deq
	copy_to_reg_from_val_long r13 $SS_CT_SND_SLOTCTR_S0_ADDR

	# コントロール番号をデキューしr2へ設定
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop
	sh2_copy_to_reg_from_reg r2 r1

	# ホイール回転角に比例した値をデキューしr1へ設定
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# AR(attack rate)処理
	## 共通で使用する処理
	(
		# AR更新
		sh2_copy_to_ptr_from_reg_word r13 r2

		# 次のスロットのアドレスへ、オフセットを加算
		sh2_add_to_reg_from_val_byte r13 20

		# スロット番号をインクリメント
		sh2_add_to_reg_from_val_byte r1 01

		# スロット番号 > 0x1f(31)?
		sh2_set_reg r0 1f
		sh2_compare_reg_gt_reg_unsigned r1 r0
	) >src/f_synth_proc_assign.setreg.o
	local sz_setreg=$(stat -c '%s' src/f_synth_proc_assign.setreg.o)
	## コントロール番号 == 0x01?
	sh2_set_reg r0 01
	sh2_compare_reg_eq_reg r2 r0
	### コントロール番号 != 0x01ならT == 0
	(
		# コントロール番号 == 0x01 の場合

		# r1を2ビット右シフト
		sh2_shift_right_logical_2 r1

		# ARを含む1ワード分のEGレジスタアドレスをr13へ設定
		sh2_add_to_reg_from_val_byte r13 08

		# 現在のレジスタ値をr2へ取得
		sh2_copy_to_reg_from_ptr_word r2 r13

		# ARビット[4:0]をマスク
		sh2_set_reg r0 E0
		sh2_and_to_reg_from_reg r2 r0

		# r2 |= r1
		sh2_or_to_reg_from_reg r2 r1

		# 全スロットへr2を設定
		sh2_set_reg r1 00
		cat src/f_synth_proc_assign.setreg.o
		## r1 > 31(0x1f)ならループを抜ける
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
	) >src/f_synth_proc_assign.ar.o
	local sz_ar=$(stat -c '%s' src/f_synth_proc_assign.ar.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_ar - 2) / 2)))
	cat src/f_synth_proc_assign.ar.o

	# D1R(decay 1 rate)処理
	## コントロール番号 == 0x02?
	sh2_set_reg r0 02
	sh2_compare_reg_eq_reg r2 r0
	### コントロール番号 != 0x02ならT == 0
	(
		# コントロール番号 == 0x02 の場合

		# r1の下位2ビットを切り捨てた値をD1Rのビット位置へシフト
		# それは、r1のビット[6:2]をD1Rのビット[10:6]への移動
		# 即ち、r1を4ビット左シフトする
		sh2_shift_left_logical_2 r1
		sh2_shift_left_logical_2 r1

		# D1Rのビット[10:6]を抽出するマスクをr0へ設定
		set_mask_expose_d1r_to_r0

		# r1のD1R以外のビットをマスク
		sh2_and_to_reg_from_reg r1 r0

		# ARを含む1ワード分のEGレジスタアドレスをr13へ設定
		sh2_add_to_reg_from_val_byte r13 08

		# 現在のレジスタ値をr2へ取得
		sh2_copy_to_reg_from_ptr_word r2 r13

		# r0をビット反転してD1R以外のビットを抽出するマスクにする
		sh2_not_to_reg_from_reg r0 r0

		# r2のD1Rビット[10:6]をマスク
		sh2_and_to_reg_from_reg r2 r0

		# r2 |= r1
		sh2_or_to_reg_from_reg r2 r1

		# 全スロットへr2を設定
		sh2_set_reg r1 00
		cat src/f_synth_proc_assign.setreg.o
		## r1 > 31(0x1f)ならループを抜ける
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
	) >src/f_synth_proc_assign.d1r.o
	local sz_d1r=$(stat -c '%s' src/f_synth_proc_assign.d1r.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_d1r - 2) / 2)))
	cat src/f_synth_proc_assign.d1r.o

	# D2R(decay 2 rate)処理
	## コントロール番号 == 0x03?
	sh2_set_reg r0 03
	sh2_compare_reg_eq_reg r2 r0
	### コントロール番号 != 0x03ならT == 0
	(
		# コントロール番号 == 0x03 の場合

		# r1の下位2ビットを切り捨てた値をD2Rのビット位置へシフト
		# それは、r1のビット[6:2]をD2Rのビット[15:11]への移動
		# 即ち、r1を9ビット左シフトする
		sh2_shift_left_logical_8 r1
		sh2_shift_left_logical r1

		# D2Rのビット[15:11]を抽出するマスクをr0へ設定
		set_mask_expose_d2r_to_r0

		# r1のD2R以外のビットをマスク
		sh2_and_to_reg_from_reg r1 r0

		# ARを含む1ワード分のEGレジスタアドレスをr13へ設定
		sh2_add_to_reg_from_val_byte r13 08

		# 現在のレジスタ値をr2へ取得
		sh2_copy_to_reg_from_ptr_word r2 r13

		# r0をビット反転してD2R以外のビットを抽出するマスクにする
		sh2_not_to_reg_from_reg r0 r0

		# r2のD2Rビット[15:11]をマスク
		sh2_and_to_reg_from_reg r2 r0

		# r2 |= r1
		sh2_or_to_reg_from_reg r2 r1

		# 全スロットへr2を設定
		sh2_set_reg r1 00
		cat src/f_synth_proc_assign.setreg.o
		## r1 > 31(0x1f)ならループを抜ける
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
	) >src/f_synth_proc_assign.d2r.o
	local sz_d2r=$(stat -c '%s' src/f_synth_proc_assign.d2r.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_d2r - 2) / 2)))
	cat src/f_synth_proc_assign.d2r.o

	# RR(release rate)処理
	## コントロール番号 == 0x04?
	sh2_set_reg r0 04
	sh2_compare_reg_eq_reg r2 r0
	### コントロール番号 != 0x04ならT == 0
	(
		# コントロール番号 == 0x04 の場合

		# r1の下位2ビットを切り捨てた値をRRのビット位置へシフト
		# それは、r1のビット[6:2]をRRのビット[4:0]への移動
		# 即ち、r1を2ビット右シフトする
		sh2_shift_right_logical_2 r1

		# RRのビット[4:0]を抽出するマスクをr0へ設定
		set_mask_expose_rr_to_r0

		# r1のRR以外のビットをマスク
		sh2_and_to_reg_from_reg r1 r0

		# RRを含む1ワード分のEGレジスタアドレスをr13へ設定
		sh2_add_to_reg_from_val_byte r13 0a

		# 現在のレジスタ値をr2へ取得
		sh2_copy_to_reg_from_ptr_word r2 r13

		# r0をビット反転してRR以外のビットを抽出するマスクにする
		sh2_not_to_reg_from_reg r0 r0

		# r2のRRビット[4:0]をマスク
		sh2_and_to_reg_from_reg r2 r0

		# r2 |= r1
		sh2_or_to_reg_from_reg r2 r1

		# 全スロットへr2を設定
		sh2_set_reg r1 00
		cat src/f_synth_proc_assign.setreg.o
		## r1 > 31(0x1f)ならループを抜ける
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
	) >src/f_synth_proc_assign.rr.o
	local sz_rr=$(stat -c '%s' src/f_synth_proc_assign.rr.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_rr - 2) / 2)))
	cat src/f_synth_proc_assign.rr.o

	# DL(decay level)処理
	## コントロール番号 == 0x05?
	sh2_set_reg r0 05
	sh2_compare_reg_eq_reg r2 r0
	### コントロール番号 != 0x05ならT == 0
	(
		# コントロール番号 == 0x05 の場合

		# r1の下位2ビットを切り捨てた値をDLのビット位置へシフト
		# それは、r1のビット[6:2]をDLのビット[9:5]への移動
		# 即ち、r1を3ビット左シフトする
		sh2_shift_left_logical_2 r1
		sh2_shift_left_logical r1

		# DLのビット[9:5]を抽出するマスクをr0へ設定
		set_mask_expose_dl_to_r0

		# r1のDL以外のビットをマスク
		sh2_and_to_reg_from_reg r1 r0

		# DLを含む1ワード分のEGレジスタアドレスをr13へ設定
		sh2_add_to_reg_from_val_byte r13 0a

		# 現在のレジスタ値をr2へ取得
		sh2_copy_to_reg_from_ptr_word r2 r13

		# r0をビット反転してDL以外のビットを抽出するマスクにする
		sh2_not_to_reg_from_reg r0 r0

		# r2のDLビット[9:5]をマスク
		sh2_and_to_reg_from_reg r2 r0

		# r2 |= r1
		sh2_or_to_reg_from_reg r2 r1

		# 全スロットへr2を設定
		sh2_set_reg r1 00
		cat src/f_synth_proc_assign.setreg.o
		## r1 > 31(0x1f)ならループを抜ける
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
	) >src/f_synth_proc_assign.dl.o
	local sz_dl=$(stat -c '%s' src/f_synth_proc_assign.dl.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_dl - 2) / 2)))
	cat src/f_synth_proc_assign.dl.o

	# KRS(key rate scaling)
	## コントロール番号 == 0x06?
	### TBD

	# TL(total level)
	## コントロール番号 == 0x07?
	sh2_set_reg r0 07
	sh2_compare_reg_eq_reg r2 r0
	### コントロール番号 != 0x07ならT == 0
	(
		# コントロール番号 == 0x07 の場合

		# ※ TLは8ビットのビットフィールドだが、
		# 　 現在はMIDIメッセージのデータバイト(0x00〜0x7f)を
		# 　 そのまま設定している
		# 　 TLは設定値が小さいほど減衰が少ない(音量が大きい)ため
		# 　 0x80以上の減衰量が設定できない状態だが、
		# 　 それ程の減衰量を設定して音量を小さくしたいケースは
		# 　 今の所無いため、問題無い

		# TLのビット[7:0]を抽出するマスクをr0へ設定
		set_mask_expose_tl_to_r0

		# r1のTL以外のビットをマスク
		sh2_and_to_reg_from_reg r1 r0

		# TLを含む1ワード分のレジスタアドレスをr13へ設定
		sh2_add_to_reg_from_val_byte r13 0c

		# 現在のレジスタ値をr2へ取得
		sh2_copy_to_reg_from_ptr_word r2 r13

		# r0をビット反転してTL以外のビットを抽出するマスクにする
		sh2_not_to_reg_from_reg r0 r0

		# r2のTLビット[7:0]をマスク
		sh2_and_to_reg_from_reg r2 r0

		# r2 |= r1
		sh2_or_to_reg_from_reg r2 r1

		# 全スロットへr2を設定
		sh2_set_reg r1 00
		cat src/f_synth_proc_assign.setreg.o
		## r1 > 31(0x1f)ならループを抜ける
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
	) >src/f_synth_proc_assign.tl.o
	local sz_tl=$(stat -c '%s' src/f_synth_proc_assign.tl.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_tl - 2) / 2)))
	cat src/f_synth_proc_assign.tl.o

	# LFOF
	## コントロール番号 == 0x08?
	sh2_set_reg r0 08
	sh2_compare_reg_eq_reg r2 r0
	### コントロール番号 != 0x08ならT == 0
	(
		# コントロール番号 == 0x08 の場合

		# r1の下位2ビットを切り捨てた値をLFOFのビット位置へシフト
		# それは、r1のビット[6:2]をLFOFのビット[14:10]への移動
		# 即ち、r1を8ビット左シフトする
		sh2_shift_left_logical_8 r1

		# LFOFのビット[14:10]を抽出するマスクをr0へ設定
		set_mask_expose_lfof_to_r0

		# r1のLFOF以外のビットをマスク
		sh2_and_to_reg_from_reg r1 r0

		# LFOFを含む1ワード分のレジスタアドレスをr13へ設定
		sh2_add_to_reg_from_val_byte r13 12

		# 現在のレジスタ値をr2へ取得
		sh2_copy_to_reg_from_ptr_word r2 r13

		# r0をビット反転してLFOF以外のビットを抽出するマスクにする
		sh2_not_to_reg_from_reg r0 r0

		# r2のLFOFビット[14:10]をマスク
		sh2_and_to_reg_from_reg r2 r0

		# r2 |= r1
		sh2_or_to_reg_from_reg r2 r1

		# 全スロットへr2を設定
		sh2_set_reg r1 00
		cat src/f_synth_proc_assign.setreg.o
		## r1 > 31(0x1f)ならループを抜ける
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
	) >src/f_synth_proc_assign.lfof.o
	local sz_lfof=$(stat -c '%s' src/f_synth_proc_assign.lfof.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_lfof - 2) / 2)))
	cat src/f_synth_proc_assign.lfof.o

	# PLFOS
	## コントロール番号 == 0x09?
	sh2_set_reg r0 09
	sh2_compare_reg_eq_reg r2 r0
	### コントロール番号 != 0x09ならT == 0
	(
		# コントロール番号 == 0x09 の場合

		# r1の下位4ビットを切り捨てた値をPLFOSのビット位置へシフト
		# それは、r1のビット[6:4]をPLFOSのビット[7:5]への移動
		# 即ち、r1を1ビット左シフトする
		sh2_shift_left_logical r1

		# PLFOSのビット[7:5]を抽出するマスクをr0へ設定
		set_mask_expose_plfos_to_r0

		# r1のPLFOS以外のビットをマスク
		sh2_and_to_reg_from_reg r1 r0

		# PLFOSを含む1ワード分のレジスタアドレスをr13へ設定
		sh2_add_to_reg_from_val_byte r13 12

		# 現在のレジスタ値をr2へ取得
		sh2_copy_to_reg_from_ptr_word r2 r13

		# r0をビット反転してPLFOS以外のビットを抽出するマスクにする
		sh2_not_to_reg_from_reg r0 r0

		# r2のPLFOSビット[7:5]をマスク
		sh2_and_to_reg_from_reg r2 r0

		# r2 |= r1
		sh2_or_to_reg_from_reg r2 r1

		# 全スロットへr2を設定
		sh2_set_reg r1 00
		cat src/f_synth_proc_assign.setreg.o
		## r1 > 31(0x1f)ならループを抜ける
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
	) >src/f_synth_proc_assign.plfos.o
	local sz_plfos=$(stat -c '%s' src/f_synth_proc_assign.plfos.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_plfos - 2) / 2)))
	cat src/f_synth_proc_assign.plfos.o

	# ALFOS
	## コントロール番号 == 0x0a?
	sh2_set_reg r0 0a
	sh2_compare_reg_eq_reg r2 r0
	### コントロール番号 != 0x0aならT == 0
	(
		# コントロール番号 == 0x0a の場合

		# r1の下位4ビットを切り捨てた値をALFOSのビット位置へシフト
		# それは、r1のビット[6:4]をALFOSのビット[2:0]への移動
		# 即ち、r1を4ビット右シフトする
		sh2_shift_right_logical_2 r1
		sh2_shift_right_logical_2 r1

		# ALFOSのビット[2:0]を抽出するマスクをr0へ設定
		set_mask_expose_alfos_to_r0

		# r1のALFOS以外のビットをマスク
		sh2_and_to_reg_from_reg r1 r0

		# ALFOSを含む1ワード分のレジスタアドレスをr13へ設定
		sh2_add_to_reg_from_val_byte r13 12

		# 現在のレジスタ値をr2へ取得
		sh2_copy_to_reg_from_ptr_word r2 r13

		# r0をビット反転してALFOS以外のビットを抽出するマスクにする
		sh2_not_to_reg_from_reg r0 r0

		# r2のALFOSビット[2:0]をマスク
		sh2_and_to_reg_from_reg r2 r0

		# r2 |= r1
		sh2_or_to_reg_from_reg r2 r1

		# 全スロットへr2を設定
		sh2_set_reg r1 00
		cat src/f_synth_proc_assign.setreg.o
		## r1 > 31(0x1f)ならループを抜ける
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setreg) / 2)))
	) >src/f_synth_proc_assign.alfos.o
	local sz_alfos=$(stat -c '%s' src/f_synth_proc_assign.alfos.o)
	## T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_alfos - 2) / 2)))
	cat src/f_synth_proc_assign.alfos.o

	# 現在の画面番号に応じてパラメータ表示を更新
	## 現在の画面番号をr1へ取得
	copy_to_reg_from_val_long r1 $var_synth_current_scrnum
	sh2_copy_to_reg_from_ptr_byte r1 r1
	## 現在の画面番号 == $SCRNUM_EGならEG関連のパラメータ表示を更新
	sh2_set_reg r0 $SCRNUM_EG
	sh2_compare_reg_eq_reg r1 r0
	(
		# EG関連のパラメータ表示を更新
		copy_to_reg_from_val_long r14 $a_synth_put_eg_param
		sh2_abs_call_to_reg_after_next_inst r14
		sh2_nop
	) >src/f_synth_proc_assign.updateeg.o
	local sz_updateeg=$(stat -c '%s' src/f_synth_proc_assign.updateeg.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_updateeg - 2) / 2)))
	cat src/f_synth_proc_assign.updateeg.o
	## 現在の画面番号 == $SCRNUM_LFOならLFO関連のパラメータ表示を更新
	sh2_set_reg r0 $SCRNUM_LFO
	sh2_compare_reg_eq_reg r1 r0
	(
		# LFO関連のパラメータ表示を更新
		copy_to_reg_from_val_long r14 $a_synth_put_lfo_param
		sh2_abs_call_to_reg_after_next_inst r14
		sh2_nop
	) >src/f_synth_proc_assign.updatelfo.o
	local sz_updatelfo=$(stat -c '%s' src/f_synth_proc_assign.updatelfo.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_updatelfo - 2) / 2)))
	cat src/f_synth_proc_assign.updatelfo.o

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_pr_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定された画面番号の背景を表示する
# in  : r1 - 画面番号(0〜)
#     : r2 - 画面クリアフラグ(0=画面クリア無し, 1=画面クリア有り)
f_synth_put_bg() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r12
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14
	sh2_copy_to_reg_from_macl r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# 使用する関数のアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $var_next_cp_other_addr
	copy_to_reg_from_val_long r13 $var_next_vdpcom_other_addr
	copy_to_reg_from_val_long r12 $a_load_img_from_cd_and_view

	# 画面クリアフラグがセットされている場合、
	# キャラクタパターンを配置するアドレスと
	# VDPコマンドを配置するアドレスを
	# 初期値へ戻す
	sh2_set_reg r0 01
	sh2_compare_reg_eq_reg r2 r0
	## r2 != 01ならT == 0
	(
		# 画面クリアフラグがセットされている場合

		# キャラクタパターンを配置するアドレスを初期値へ戻す
		copy_to_reg_from_val_long r2 $VRAM_CPT_OTHER_BASE
		sh2_copy_to_ptr_from_reg_long r14 r2

		# VDPコマンドを配置するアドレスを初期値へ戻す
		copy_to_reg_from_val_long r2 $VRAM_CT_OTHER_BASE
		sh2_copy_to_ptr_from_reg_long r13 r2
	) >src/f_synth_put_bg.init.o
	local sz_init=$(stat -c '%s' src/f_synth_put_bg.init.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_init - 2) / 2)))
	cat src/f_synth_put_bg.init.o

	# 表示する画像のFADをr1へ設定
	# r1 = $FAD_FIRST_IMG + ($SECTORS_IMG_OFS * r1)
	## r1 *= $SECTORS_IMG_OFS
	sh2_set_reg r0 $SECTORS_IMG_OFS
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
	sh2_multiply_reg_by_reg_unsigned_word r1 r0
	sh2_copy_to_reg_from_macl r1
	## r1 += $FAD_FIRST_IMG
	copy_to_reg_from_val_word r2 $FAD_FIRST_IMG
	sh2_add_to_reg_from_reg r1 r2

	# 画像表示
	sh2_abs_call_to_reg_after_next_inst r12
	sh2_nop

	# 画像を表示した分、各種アドレス変数を進める
	## キャラクタパターンを配置するアドレス
	## 画像のサイズ(143360=0x23000バイト)分進める
	## 0x05C10C00 + 0x23000 = 0x05C33C00
	copy_to_reg_from_val_long r2 05C33C00
	sh2_copy_to_ptr_from_reg_long r14 r2
	## VDPコマンドを配置するアドレス
	## コマンドのサイズ(32=0x20)分進める
	## 0x05C02360 + 0x20 = 0x05C02380
	copy_to_reg_from_val_long r2 05C02380
	sh2_copy_to_ptr_from_reg_long r13 r2

	# 現在VDPコマンドを配置するアドレスが指す場所(r2の内容)に
	# 描画終了コマンドを配置
	## 描画終了を待つ
	copy_to_reg_from_val_long r14 $SS_VDP1_EDSR_ADDR
	(
		# r14の指す先(EDSRの内容)をr0へ取得
		sh2_copy_to_reg_from_ptr_word r0 r14
		# r0とCEFビット(0x02)との論理積をとり、
		# 結果がゼロのときTビットをセット
		# (CEFビットは描画終了状態でセットされるビット)
		sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
	) >src/f_synth_put_bg.wait.o
	local sz_wait=$(stat -c '%s' src/f_synth_put_bg.wait.o)
	cat src/f_synth_put_bg.wait.o
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_wait) / 2)))
	## 描画終了コマンドを配置
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r2 r0

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_pr_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_macl_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r12 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# スタート・ストップ固有処理
# in  : r1 - スタートあるいはストップのMIDIメッセージ
#            スタート = 0x000000fa
#            ストップ = 0x000000fc
f_synth_proc_startstop() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r3

	# 繰り返し使用するアドレスをレジスタへ設定
	copy_to_reg_from_val_long r2 $var_synth_current_scrnum

	# 繰り返し使用する処理をファイルへ出力
	(
		# 退避したレジスタを復帰
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_startstop.ret.o
	local sz_ret=$(stat -c '%s' src/f_synth_proc_startstop.ret.o)

	# 現在の画面番号をr3へ取得
	sh2_copy_to_reg_from_ptr_byte r3 r2

	# r1 == スタート?
	sh2_set_reg r0 fa
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
	sh2_compare_reg_eq_reg r1 r0
	## r1 == スタートの時、T == 1

	# r1 == スタートか否かに応じた処理
	(
		# r1 == スタートの場合

		# 現在の画面番号 >= 最後の画面番号?
		sh2_set_reg r0 $SCRNUM_LAST
		sh2_compare_reg_ge_reg_unsigned r3 r0
		## T == 0なら処理を飛ばす
		sh2_rel_jump_if_false $(two_digits_d $(((sz_ret - 2) / 2)))
		cat src/f_synth_proc_startstop.ret.o

		# 画面番号をインクリメント
		sh2_add_to_reg_from_val_byte r3 01
	) >src/f_synth_proc_startstop.start.o
	(
		# r1 != スタート(== ストップ)の場合

		# 現在の画面番号 == 0?
		sh2_set_reg r0 00
		sh2_compare_reg_eq_reg r3 r0
		## T == 0なら処理を飛ばす
		sh2_rel_jump_if_false $(two_digits_d $(((sz_ret - 2) / 2)))
		cat src/f_synth_proc_startstop.ret.o

		# 画面番号をデクリメント
		sh2_add_to_reg_from_val_byte r3 $(two_comp 01)

		# r1 == スタートの場合の処理を飛ばす
		local sz_start=$(stat -c '%s' src/f_synth_proc_startstop.start.o)
		sh2_rel_jump_after_next_inst $(extend_digit $(to16 $((sz_start / 2))) 3)
		sh2_nop
	) >src/f_synth_proc_startstop.stop.o
	## T == 1ならr1 != スタート(== ストップ)の場合の処理を飛ばす
	local sz_stop=$(stat -c '%s' src/f_synth_proc_startstop.stop.o)
	sh2_rel_jump_if_true $(two_digits_d $(((sz_stop - 2) / 2)))
	cat src/f_synth_proc_startstop.stop.o
	cat src/f_synth_proc_startstop.start.o

	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# 画面番号を変数へ設定
	sh2_copy_to_ptr_from_reg_byte r2 r3

	# 背景を再表示
	sh2_copy_to_reg_from_reg r1 r3
	copy_to_reg_from_val_long r3 $a_synth_put_bg
	sh2_abs_call_to_reg_after_next_inst r3
	sh2_set_reg r2 01

	# 現在の画面がオシレータ設定画面の場合、カーソルを表示しreturn
	sh2_set_reg r0 $SCRNUM_OSC
	sh2_compare_reg_eq_reg r1 r0
	(
		# 現在の画面番号 == オシレータ設定画面番号の場合

		# カーソルを表示
		copy_to_reg_from_val_long r1 $a_synth_put_osc_param
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# 退避したレジスタを復帰
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_startstop.osc.o
	local sz_osc=$(stat -c '%s' src/f_synth_proc_startstop.osc.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_osc - 2) / 2)))
	cat src/f_synth_proc_startstop.osc.o

	# 現在の画面がEG設定画面の場合、EG関連のパラメータを表示しreturn
	sh2_set_reg r0 $SCRNUM_EG
	sh2_compare_reg_eq_reg r1 r0
	(
		# 現在の画面番号 == EG設定画面番号の場合

		# EG関連のパラメータを表示
		copy_to_reg_from_val_long r1 $a_synth_put_eg_param
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# 退避したレジスタを復帰
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_startstop.eg.o
	local sz_eg=$(stat -c '%s' src/f_synth_proc_startstop.eg.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_eg - 2) / 2)))
	cat src/f_synth_proc_startstop.eg.o

	# 現在の画面がLFO設定画面の場合、LFO関連のパラメータを表示しreturn
	sh2_set_reg r0 $SCRNUM_LFO
	sh2_compare_reg_eq_reg r1 r0
	(
		# 現在の画面番号 == LFO設定画面番号の場合

		# LFO関連のパラメータを表示
		copy_to_reg_from_val_long r1 $a_synth_put_lfo_param
		sh2_abs_call_to_reg_after_next_inst r1
		sh2_nop

		# 退避したレジスタを復帰
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_startstop.lfo.o
	local sz_lfo=$(stat -c '%s' src/f_synth_proc_startstop.lfo.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_lfo - 2) / 2)))
	cat src/f_synth_proc_startstop.lfo.o

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_pr_from_reg r0
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r1 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r3 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}

# その他のステータス・バイト固有処理
# in  : r1 - ステータス・バイト(0x000000XX)
f_synth_proc_others() {
	# 変更が発生するレジスタを退避
	## 共通
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2

	# ステータス・バイト == 0xfa || ステータス・バイト == 0xfc?
	## フラグをゼロクリア
	sh2_set_reg r2 00
	## ステータス・バイト == 0xfaならフラグをセット
	sh2_set_reg r0 fa
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
	sh2_compare_reg_eq_reg r1 r0
	### ステータス・バイト != 0xfaならT == 0
	(
		sh2_set_reg r2 01
	) >src/f_synth_proc_others.setr201.o
	local sz_setr201=$(stat -c '%s' src/f_synth_proc_others.setr201.o)
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_setr201 - 2) / 2)))
	cat src/f_synth_proc_others.setr201.o
	## ステータス・バイト == 0xfcならフラグをセット
	sh2_set_reg r0 fc
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
	sh2_compare_reg_eq_reg r1 r0
	sh2_rel_jump_if_false $(two_digits_d $(((sz_setr201 - 2) / 2)))
	cat src/f_synth_proc_others.setr201.o
	## フラグはセットされているか?
	sh2_set_reg r0 01
	sh2_compare_reg_eq_reg r2 r0
	### フラグがセットされていない時、T == 0

	# ステータス・バイト != 0xfa && ステータス・バイト != 0xfcなら
	# スタート・ストップ固有処理を飛ばす
	(
		# ステータス・バイト == 0xfa || ステータス・バイト == 0xfc の場合

		# 変更が発生するレジスタを退避
		## 個別
		sh2_copy_to_reg_from_pr r0
		sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

		# スタート・ストップ固有処理の関数を呼び出す
		copy_to_reg_from_val_long r2 $a_synth_proc_startstop
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_nop

		# 退避したレジスタを復帰
		## 個別
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
		sh2_copy_to_pr_from_reg r0
		## 共通
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
		sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

		# return
		sh2_return_after_next_inst
		sh2_nop
	) >src/f_synth_proc_others.startstop.o
	local sz_startstop=$(stat -c '%s' src/f_synth_proc_others.startstop.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_startstop - 2) / 2)))
	cat src/f_synth_proc_others.startstop.o

	# 退避したレジスタを復帰
	## 共通
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15

	# return
	sh2_return_after_next_inst
	sh2_nop
}
