if [ "${SRC_SYNTH_SH+is_defined}" ]; then
	return
fi
SRC_SYNTH_SH=true

. include/sh2.sh
. include/ss.sh
. include/common.sh
. include/lib.sh
. include/synth.sh

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

	# ステータス・バイト == 0x90 || ステータス・バイト == 0xe0 ?
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
	## ステータス・バイト == 0xe0ならフラグをセット
	sh2_compare_r0_eq_val e0
	### T == 0なら処理を飛ばす
	sh2_rel_jump_if_false $(two_digits_d $(((sz_setr101 - 2) / 2)))
	cat src/f_synth_check_and_enq_midimsg.setr101.o
	## フラグはセットされているか?
	sh2_set_reg r2 01
	sh2_compare_reg_eq_reg r1 r2
	### フラグがセットされていない時、T == 0

	# ステータス・バイト == 0x90 || ステータス・バイト == 0xe0 なら
	# ノート・オン/オフあるいはピッチ・ベンド・チェンジのMIDIメッセージをエンキュー
	(
		# ステータス・バイト == 0x90 || ステータス・バイト == 0xe0 の場合

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

		# MIDIメッセージ: ノート・オン/オフ or ピッチ・ベンド・チェンジ 固有処理
		## ノート番号 or ピッチベンド値(LSB) 取得
		### データ・バイト取得処理
		cat src/f_synth_check_and_enq_midimsg.getdatabyte.o
		#### 取得したバイトのMSB == 1(T == 0)なら繰り返す
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_getdatabyte) / 2)))
		### エンキュー
		sh2_abs_call_to_reg_after_next_inst r2
		sh2_copy_to_reg_from_reg r1 r0
		## ベロシティ or ピッチベンド値(MSB) 取得
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
	## 0x00: 0x0208
	## ---- --12 3333 4444
	## 1:MEM4MB memory size 2:DAC18B dac for digital output
	## 3:VER version number 4:MVOL
	copy_to_reg_from_val_word r2 0208
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
	## 0x00: 0x0030
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
	## 0x08: 0x0020
	## 1111 1222 2234 4444
	## 1:D2R decay 2 rate 2:D1R decay 1 rate 3:EGHOLD eg hold mode
	## 4:AR attack rate
	sh2_set_reg r2 20
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
	## 0x0C: 0x0380
	## ---- --12 3333 3333
	## 1:STWINH stack write inhibit 2:SDIR sound direct 3:TL total level
	copy_to_reg_from_val_word r2 0380
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
	## 0x12: 0x8108
	## 1222 2233 4445 5666
	## 1:LFORE 2:LFOF 3:PLFOWS 4:PLFOS 5:ALFOWS 6:ALFOS
	copy_to_reg_from_val_word r2 8108
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

# 現在のオシレータを示す文字を表示する(デモ用)
# in  : r1 - 領域左上のX座標
#     : r2 - 領域左上のY座標
f_synth_point_current_osc() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r3
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r4
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# Y座標をr3へ、X座標をr2へ設定
	sh2_copy_to_reg_from_reg r3 r2
	sh2_copy_to_reg_from_reg r2 r1

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

# プログラム・チェンジ固有処理
f_synth_proc_progchg() {
	# 変更が発生するレジスタを退避
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r1
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r2
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r13
	# sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r14
	sh2_copy_to_reg_from_pr r0
	sh2_dec_ptr_and_copy_to_ptr_from_reg_long r15 r0

	# 繰り返し使用するアドレスをレジスタへ設定
	# copy_to_reg_from_val_long r14 $a_synth_point_current_osc
	copy_to_reg_from_val_long r13 $a_synth_set_start_addr

	# プログラム番号をデキュー
	copy_to_reg_from_val_long r1 $a_synth_midimsg_deq
	sh2_abs_call_to_reg_after_next_inst r1
	sh2_nop

	# プログラム番号に応じたオシレータ波形アドレスを
	# レジスタへ設定
	## ノコギリ波
	sh2_set_reg r0 $PROGNUM_OSC_SAW
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != ノコギリ波の時、T == 0
	(
		# # カーソル表示
		# sh2_set_reg r1 $OSC_CURSOR_X
		# sh2_set_reg r2 $OSC_CURSOR_Y_SAW
		# sh2_abs_call_to_reg_after_next_inst r14
		# sh2_extend_unsigned_to_reg_from_reg_byte r2 r2

		# r2へオシレータ波形アドレス設定
		copy_to_reg_from_val_long r2 $OSC_PCM_SAW_MC68K_BASE
	) >src/f_synth_proc_progchg.saw.o
	local sz_saw=$(stat -c '%s' src/f_synth_proc_progchg.saw.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_saw - 2) / 2)))
	cat src/f_synth_proc_progchg.saw.o
	## 矩形波
	sh2_set_reg r0 $PROGNUM_OSC_SQU
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != 矩形波の時、T == 0
	(
		# # カーソル表示
		# sh2_set_reg r1 $OSC_CURSOR_X
		# sh2_set_reg r2 $OSC_CURSOR_Y_SQU
		# sh2_abs_call_to_reg_after_next_inst r14
		# sh2_extend_unsigned_to_reg_from_reg_byte r2 r2

		# r2へオシレータ波形アドレス設定
		copy_to_reg_from_val_long r2 $OSC_PCM_SQU_MC68K_BASE
	) >src/f_synth_proc_progchg.squ.o
	local sz_squ=$(stat -c '%s' src/f_synth_proc_progchg.squ.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_squ - 2) / 2)))
	cat src/f_synth_proc_progchg.squ.o
	## サイン波
	sh2_set_reg r0 $PROGNUM_OSC_SIN
	sh2_compare_reg_eq_reg r1 r0
	### プログラム番号 != サイン波の時、T == 0
	(
		# # カーソル表示
		# sh2_set_reg r1 $OSC_CURSOR_X
		# sh2_set_reg r2 $OSC_CURSOR_Y_SIN
		# sh2_abs_call_to_reg_after_next_inst r14
		# sh2_extend_unsigned_to_reg_from_reg_byte r2 r2

		# r2へオシレータ波形アドレス設定
		copy_to_reg_from_val_long r2 $OSC_PCM_SIN_MC68K_BASE
	) >src/f_synth_proc_progchg.sin.o
	local sz_sin=$(stat -c '%s' src/f_synth_proc_progchg.sin.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_sin - 2) / 2)))
	cat src/f_synth_proc_progchg.sin.o

	# 全スロットの波形データ開始アドレスを変更
	sh2_set_reg r1 00
	sh2_set_reg r0 1f
	(
		sh2_abs_call_to_reg_after_next_inst r13
		sh2_nop
		sh2_add_to_reg_from_val_byte r1 01
		sh2_compare_reg_gt_reg_unsigned r1 r0
	) >src/f_synth_proc_progchg.setsa.o
	cat src/f_synth_proc_progchg.setsa.o
	## r1 > 31(0x1f)ならループを抜ける
	local sz_setsa=$(stat -c '%s' src/f_synth_proc_progchg.setsa.o)
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_setsa) / 2)))

	# 退避したレジスタを復帰
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r0 r15
	sh2_copy_to_pr_from_reg r0
	# sh2_copy_to_reg_from_ptr_and_inc_ptr_long r14 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r13 r15
	sh2_copy_to_reg_from_ptr_and_inc_ptr_long r2 r15
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
