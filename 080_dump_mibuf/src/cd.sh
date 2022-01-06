if [ "${SRC_CD_SH+is_defined}" ]; then
	return
fi
SRC_CD_SH=true

. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/common.sh
. include/con.sh

# 以下の想定で動作する
## ディレクトリレコード領域のセクタ数(10進数)
DIRREC_SECTORS_DEC=1
## 0.BINのセクタ数(10進数)
BINFILE_SECTORS_DEC=503
## 画像ファイルが並ぶ領域のLBA(10進数)
IMAGES_LBA_DEC=$((20 + DIRREC_SECTORS_DEC + BINFILE_SECTORS_DEC))
IMAGES_LBA=$(to16 $IMAGES_LBA_DEC)
## 最初の画像のFID
FIRST_IMAGE_FID=3
## 画像1枚のファイルサイズ[バイト]
IMAGE_SIZE_DEC=143360
## 画像1枚のセクタ数
IMAGE_SECTORS_DEC=70
IMAGE_SECTORS=$(to16 $IMAGE_SECTORS_DEC)
## ※ FAD = LBA + 150
##        = (IMAGES_LBA + (IMAGE_SECTORS * (fid - FIRST_IMAGE_FID))) + 150
##        = IMAGES_LBA + (IMAGE_SECTORS * fid) - (IMAGE_SECTORS * FIRST_IMAGE_FID) + 150
##        = (IMAGE_SECTORS * fid) + (IMAGES_LBA - (IMAGE_SECTORS * FIRST_IMAGE_FID) + 150)
##        = (IMAGE_SECTORS * fid) + FID_TO_FAD_PARAM
FID_TO_FAD_PARAM_DEC=$((IMAGES_LBA_DEC - (IMAGE_SECTORS_DEC * FIRST_IMAGE_FID) + 150))
FID_TO_FAD_PARAM=$(to16 $FID_TO_FAD_PARAM_DEC)

# CR1〜CR4を指定された座標にダンプする
# in  : r1 - X座標
#     : r2 - Y座標
# work: r0 - 作業用
#     : r3 - 作業用
#     : r4 - 作業用
#     : r5 - 作業用
#     : r6 - 作業用
f_dump_cr1234_xy() {
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
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# Y座標をr4へコピー
	sh2_copy_to_reg_from_reg r4 r2

	# r2へX座標を設定
	# X座標は変わらないのでずっとこのまま
	sh2_copy_to_reg_from_reg r2 r1

	# 使用する関数のアドレスをレジスタへ設定
	copy_to_reg_from_val_long r5 $a_putreg_xy

	# CR1のアドレスをr6へ設定
	# 以降、4ずつ加算しながらCR2・CR3・CR4とアクセスする
	copy_to_reg_from_val_long r6 $SS_CT_CS2_CR1_ADDR

	# CR1をダンプ
	## r1へCR1の値を設定
	sh2_copy_to_reg_from_ptr_word r1 r6
	## r3へY座標を設定
	sh2_copy_to_reg_from_reg r3 r4
	## 関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_nop

	# CR2をダンプ
	## r1へCR2の値を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_reg_from_ptr_word r1 r6
	## r3へY座標を設定
	sh2_add_to_reg_from_val_byte r4 $CON_FONT_HEIGHT
	sh2_copy_to_reg_from_reg r3 r4
	## 関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_nop

	# CR3をダンプ
	## r1へCR3の値を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_reg_from_ptr_word r1 r6
	## r3へY座標を設定
	sh2_add_to_reg_from_val_byte r4 $CON_FONT_HEIGHT
	sh2_copy_to_reg_from_reg r3 r4
	## 関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_nop

	# CR4をダンプ
	## r1へCR4の値を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_reg_from_ptr_word r1 r6
	## r3へY座標を設定
	sh2_add_to_reg_from_val_byte r4 $CON_FONT_HEIGHT
	sh2_copy_to_reg_from_reg r3 r4
	## 関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_nop

	# 退避したレジスタを復帰しreturn
	## pr
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
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
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# CDコマンドを実行する
# in  : r1 - CR1に使う値
#     : r2 - CR2に使う値
#     : r3 - CR3に使う値
#     : r4 - CR4に使う値
# work: r5 - 作業用(HIRQのアドレス)
#     : r6 - 作業用
f_cd_exec_command() {
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

	# 現在のSRのI3〜I0を退避してNMI以外の全ての割り込みをマスクする
	# TODO

	# HIRQレジスタにCMOKビットがセットされるまで待つ
	copy_to_reg_from_val_long r5 $SS_CT_CS2_HIRQ_ADDR
	(
		sh2_copy_to_reg_from_ptr_word r0 r5
		sh2_test_r0_and_val_byte $(echo $SS_CS2_HIRQ_BIT_CMOK | cut -c3-4)
	) >src/f_cd_exec_command.1.o
	cat src/f_cd_exec_command.1.o
	local sz_1=$(stat -c '%s' src/f_cd_exec_command.1.o)
	## CMOKビットがセットされていなければ(T=1ならば)、繰り返す
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))

	# HIRQのCMOKとその他のユーザー定義フラグをクリアする
	# (0を書くとそのビットに対応するフラグをクリアできる)
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r5 r0

	# CR1〜CR4を設定する
	## CR1のアドレスをr6へ設定
	copy_to_reg_from_val_long r6 $SS_CT_CS2_CR1_ADDR
	## CR1へr1を設定
	sh2_copy_to_ptr_from_reg_word r6 r1
	## CR2へr2を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_ptr_from_reg_word r6 r2
	## CR3へr3を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_ptr_from_reg_word r6 r3
	## CR4へr4を設定
	sh2_add_to_reg_from_val_byte r6 04
	sh2_copy_to_ptr_from_reg_word r6 r4

	# HIRQレジスタにCMOKビットがセットされるまで待つ
	cat src/f_cd_exec_command.1.o
	## CMOKビットがセットされていなければ(T=1ならば)、繰り返す
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))

	# 退避したI3〜I0をSRへ復帰する
	# TODO

	# ウェイト
	copy_to_reg_from_val_long r1 00000200
	sh2_set_reg r2 00
	(
		sh2_add_to_reg_from_val_byte r1 $(two_comp_d 1)
		sh2_compare_reg_eq_reg r1 r2
	) >src/f_cd_exec_command.2.o
	cat src/f_cd_exec_command.2.o
	local sz_2=$(stat -c '%s' src/f_cd_exec_command.2.o)
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_2) / 2)))

	# 退避したレジスタを復帰しreturn
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
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}

# 指定されたFADの画像(320x224)をVDP1 RAMのother領域へロードし表示する
# in  : r1 - FAD
f_load_img_from_cd_and_view() {
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
	## r8
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r8
	## r9
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r9
	## r10
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r10
	## r11
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r11
	## r12
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r12
	## r13
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r13
	## r14
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r14
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 使用する関数・変数のアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $a_cd_exec_command
	copy_to_reg_from_val_long r12 $SS_CT_CS2_DTR_ADDR
	copy_to_reg_from_val_long r10 $SS_CT_CS2_CR4_ADDR
	copy_to_reg_from_val_long r9 $var_tmp_img_area

	# FADをr6へコピー
	sh2_copy_to_reg_from_reg r6 r1

	# ファイルアクセスの中止
	## AbortFile(0x75)
	## | Reg | [15:8]    | [7:0] |
	## |-----+-----------+-------|
	## | CR1 | cmd(0x75) | -     |
	## | CR2 | -         | -     |
	## | CR3 | -         | -     |
	## | CR4 | -         | -     |

	## r1(CR1) = 0x7500
	sh2_set_reg r1 75
	sh2_shift_left_logical_8 r1

	## r2(CR2) = 0x0000
	sh2_set_reg r2 00

	## r3(CR3) = 0x0000
	sh2_set_reg r3 00

	## r4(CR4) = 0x0000
	sh2_set_reg r4 00

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# CDブロックの初期化
	## InitializeCDSystem(cmd=0x04)
	## | Reg | [15:8]            | [7:0]            |
	## |-----+-------------------+------------------|
	## | CR1 | cmd(0x04)         | initflag         |
	## | CR2 | standbytime[15:8] | standbytime[7:0] |
	## | CR3 | -                 | -                |
	## | CR4 | ecc               | retrycount       |

	## r1(CR1) = 0x0400
	sh2_set_reg r1 04
	sh2_shift_left_logical_8 r1

	## r2(CR2) = 0x0000
	sh2_set_reg r2 00

	## r3(CR3) = 0x0000
	sh2_set_reg r3 00

	## r4(CR4) = 0x040f
	copy_to_reg_from_val_word r4 040f

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# データ転送の終了
	## EndDataTransfer(cmd=0x06)
	## | Reg | [15:8]    | [7:0] |
	## |-----+-----------+-------|
	## | CR1 | cmd(0x06) | -     |
	## | CR2 | -         | -     |
	## | CR3 | -         | -     |
	## | CR4 | -         | -     |

	## r1(CR1) = 0x0600
	sh2_set_reg r1 06
	sh2_shift_left_logical_8 r1

	## r2(CR2) = 0x0000
	sh2_set_reg r2 00

	## r3(CR3) = 0x0000
	sh2_set_reg r3 00

	## r4(CR4) = 0x0000
	sh2_set_reg r4 00

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# すべてのフィルタをリセット
	## ResetSelector(cmd=0x48)
	## | Reg | [15:8]                            | [7:0]      |
	## |-----+-----------------------------------+------------|
	## | CR1 | cmd(0x48)                         | reset flag |
	## | CR2 | -                                 | -          |
	## | CR3 | rsbufno (only if reset flag is 0) | -          |
	## | CR4 | -                                 | -          |

	## r1(CR1) = 0x48fc
	copy_to_reg_from_val_word r1 48fc

	## r2(CR2) = 0x0000
	sh2_set_reg r2 00

	## r3(CR3) = 0x0000
	sh2_set_reg r3 00

	## r4(CR4) = 0x0000
	sh2_set_reg r4 00

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# セクタ長の設定
	## SetSectorLength(cmd=0x60)
	## | Reg | [15:8]         | [7:0]          |
	## |-----+----------------+----------------|
	## | CR1 | cmd(0x60)      | getsectsize_id |
	## | CR2 | putsectsize_id | -              |
	## | CR3 | -              | -              |
	## | CR4 | -              | -              |
	## セクタ長は、SS_CD_SECTSIZE_ID_2048=0 へ設定する

	## r1(CR1) = 0x6000
	sh2_set_reg r1 60
	sh2_shift_left_logical_8 r1

	## r2(CR2) = 0x0000
	sh2_set_reg r2 00

	## r3(CR3) = 0x0000
	sh2_set_reg r3 00

	## r4(CR4) = 0x0000
	sh2_set_reg r4 00

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# パーティション0をリセット
	## ResetSelector(cmd=0x48)
	## | Reg | [15:8]                            | [7:0]      |
	## |-----+-----------------------------------+------------|
	## | CR1 | cmd(0x48)                         | reset flag |
	## | CR2 | -                                 | -          |
	## | CR3 | rsbufno (only if reset flag is 0) | -          |
	## | CR4 | -                                 | -          |

	## r1(CR1) = 0x4800
	sh2_set_reg r1 48
	sh2_shift_left_logical_8 r1

	## r2(CR2) = 0x0000
	sh2_set_reg r2 00

	## r3(CR3) = 0x0000
	sh2_set_reg r3 00

	## r4(CR4) = 0x0000
	sh2_set_reg r4 00

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# フィルタ0へ接続
	## SetCDDeviceConnection(0x30)
	## | Reg | [15:8]        | [7:0] |
	## |-----+---------------+-------|
	## | CR1 | cmd(0x30)     | -     |
	## | CR2 | -             | -     |
	## | CR3 | scdcfilternum | -     |
	## | CR4 | -             | -     |

	## r1(CR1) = 0x3000
	sh2_set_reg r1 30
	sh2_shift_left_logical_8 r1

	## r3(CR3) = 0x0000
	sh2_set_reg r3 00

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# CD再生
	## PlayDisc(cmd=0x10)
	## | Reg | [15:8]       | [7:0]         |
	## |-----+--------------+---------------|
	## | CR1 | cmd(0x10)    | pdspos[23:16] |
	## | CR2 | pdspos[15:8] | pdspos[7:0]   |
	## | CR3 | pdpmode      | pdepos[23:16] |
	## | CR4 | pdepos[15:8] | pdepos[7:0]   |
	## FAD指定の場合、
	## pdspos = 0x800000 | FAD
	## pdepos = 0x800000 | セクタ数

	## r1(CR1) = 0x1080
	copy_to_reg_from_val_word r1 1080

	## r2(CR2) = r6
	sh2_copy_to_reg_from_reg r2 r6

	## r3(CR3) = 0x0080
	sh2_set_reg r3 80
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	## r4(CR4) = 0x0046
	sh2_set_reg r4 46

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 完了したセクタから順に70(0x46)セクタ分を
	# 一時的な配置領域(var_dmp_img_area)へ配置

	## 取得済セクタ数(0)をr11へ設定
	sh2_set_reg r11 00

	## 画像の一時配置領域の先頭アドレスをr8へコピー
	sh2_copy_to_reg_from_reg r8 r9

	(
		(
			# 読み取り済みセクタ数の取得
			## GetSectorNumber(0x51)
			## | Reg | [15:8]    | [7:0] |
			## |-----+-----------+-------|
			## | CR1 | cmd(0x51) | -     |
			## | CR2 | -         | -     |
			## | CR3 | gsnbufno  | -     |
			## | CR4 | -         | -     |

			## r1(CR1) = 0x5100
			sh2_set_reg r1 51
			sh2_shift_left_logical_8 r1

			## r2(CR2) = 0x0000
			sh2_set_reg r2 00

			## r3(CR3) = 0x0000
			sh2_set_reg r3 00

			## r4(CR4) = 0x0000
			sh2_set_reg r4 00

			## CDコマンド実行
			sh2_abs_call_to_reg_after_next_inst r14
			sh2_nop

			# CR4 > 0 ?
			sh2_set_reg r0 00
			sh2_copy_to_reg_from_ptr_word r4 r10
			sh2_compare_reg_gt_reg_signed r4 r0
		) >src/f_load_img_from_cd_and_view.1.o
		cat src/f_load_img_from_cd_and_view.1.o
		local sz_1=$(stat -c '%s' src/f_load_img_from_cd_and_view.1.o)
		## T == 0(CR4 <= 0)なら繰り返す
		sh2_rel_jump_if_false $(two_comp_d $(((sz_1 + 4) / 2)))

		# セクタデータの取り出し&消去
		## GetThenDeleteSectorData(cmd=0x63)
		## | Reg | [15:8]                | [7:0]                |
		## |-----+-----------------------+----------------------|
		## | CR1 | cmd(0x63)             | -                    |
		## | CR2 | gtdsdsectoffset[15:8] | gtdsdsectoffset[7:0] |
		## | CR3 | gtdsdbufno            | -                    |
		## | CR4 | gtdsdsectnum[15:8]    | gtdsdsectnum[7:0]    |
		## gtdsdsectoffset = ロードした先頭位置からのオフセット
		## gtdsdbufno = ロードしたバッファ(セレクタ)番号
		## gtdsdsectnum = 取り出すセクタ数

		## r1(CR1) = 0x6300
		sh2_set_reg r1 63
		sh2_shift_left_logical_8 r1

		## r2(CR2) = 0x0000
		sh2_set_reg r2 00

		## r3(CR3) = 0x0000
		sh2_set_reg r3 00

		## r4(CR4) → GetSectorNumberで取得したセクタ数をそのまま使う

		## CDコマンド実行
		sh2_abs_call_to_reg_after_next_inst r14
		sh2_nop

		# 取得済みセクタ数を更新
		sh2_add_to_reg_from_reg r11 r4

		# 読み取り済みのセクタ数(r4)分をDTRから
		# 一時配置用領域(var_tmp_img_area)へコピー

		## セクタ数(r4)を4バイトリードの回数へ変換する
		## (/ 2048 4.0)512.0 = 0b10 0000 0000 なので、9ビット左シフト
		sh2_shift_left_logical_8 r4
		sh2_shift_left_logical r4

		## r4の回数分、DTRから4バイトリードして、一時配置領域へコピー
		(
			# 4バイト読み出してr0へ格納
			sh2_copy_to_reg_from_ptr_long r0 r12

			# 読み出した4バイトを一時配置領域へコピー
			sh2_copy_to_ptr_from_reg_long r8 r0

			# 一時配置領域のアドレス += 4
			sh2_add_to_reg_from_val_byte r8 04

			# カウンタ--
			sh2_add_to_reg_from_val_byte r4 $(two_comp_d 1)

			# カウンタ == 0 ?
			sh2_set_reg r0 00
			sh2_compare_reg_eq_reg r4 r0
		) >src/f_load_img_from_cd_and_view.2.o
		cat src/f_load_img_from_cd_and_view.2.o
		local sz_2=$(stat -c '%s' src/f_load_img_from_cd_and_view.2.o)
		## カウンタ != 0(T == 0)なら繰り返す
		sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_2) / 2)))

		# データ転送の終了
		## EndDataTransfer(cmd=0x06)
		## | Reg | [15:8]    | [7:0] |
		## |-----+-----------+-------|
		## | CR1 | cmd(0x06) | -     |
		## | CR2 | -         | -     |
		## | CR3 | -         | -     |
		## | CR4 | -         | -     |

		## r1(CR1) = 0x0600
		sh2_set_reg r1 06
		sh2_shift_left_logical_8 r1

		## r2(CR2) = 0x0000
		sh2_set_reg r2 00

		## r3(CR3) = 0x0000
		sh2_set_reg r3 00

		## r4(CR4) = 0x0000
		sh2_set_reg r4 00

		## CDコマンド実行
		sh2_abs_call_to_reg_after_next_inst r14
		sh2_nop

		# 70(0x46) > 取得済みセクタ数 ?
		sh2_set_reg r0 46
		sh2_compare_reg_gt_reg_signed r0 r11
	) >src/f_load_img_from_cd_and_view.3.o
	cat src/f_load_img_from_cd_and_view.3.o
	local sz_3=$(stat -c '%s' src/f_load_img_from_cd_and_view.3.o)
	## 70 > 取得済みセクタ数(T == 1)なら繰り返す
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_3) / 2)))

	# 一時配置領域から143360バイトをVDP1 RAMのその他用のCPT領域へコピー
	## 143360 / 4 = 35840 より、
	## 4バイト単位の読み出し35840(0x8c00)回

	## r1 = 0x8c00
	sh2_set_reg r1 8c
	sh2_shift_left_logical_8 r1
	sh2_extend_unsigned_to_reg_from_reg_word r1 r1

	## r2 = 配置するCPTの先頭アドレス
	copy_to_reg_from_val_long r2 $var_next_cp_other_addr
	sh2_copy_to_reg_from_ptr_long r2 r2

	## r14 = EDSRのアドレス
	copy_to_reg_from_val_long r14 $SS_VDP1_EDSR_ADDR

	(
		# r14の指す先(EDSRの内容)をr0へ取得
		sh2_copy_to_reg_from_ptr_word r0 r14
		# r0とCEFビット(0x02)との論理積をとり、
		# 結果がゼロのときTビットをセット
		# (CEFビットは描画終了状態でセットされるビット)
		sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
	) >src/f_load_img_from_cd_and_view.4.o
	local sz_4=$(stat -c '%s' src/f_load_img_from_cd_and_view.4.o)
	(
		# 描画終了を待つ
		cat src/f_load_img_from_cd_and_view.4.o
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_4) / 2)))
		## 論理積結果がゼロのとき、
		## 即ちTビットがセットされたとき、
		## 待つ処理を繰り返す

		# 一時配置領域から4バイト読み出してr0へ格納
		sh2_copy_to_reg_from_ptr_long r0 r9

		# 読み出した4バイトをCPTへ配置
		sh2_copy_to_ptr_from_reg_long r2 r0

		# 一時配置領域のアドレス += 4
		sh2_add_to_reg_from_val_byte r9 04

		# CPTのアドレス += 4
		sh2_add_to_reg_from_val_byte r2 04

		# カウンタ--
		sh2_add_to_reg_from_val_byte r1 $(two_comp_d 1)

		# カウンタ == 0 ?
		sh2_set_reg r0 00
		sh2_compare_reg_eq_reg r1 r0
	) >src/f_load_img_from_cd_and_view.5.o
	cat src/f_load_img_from_cd_and_view.5.o
	local sz_5=$(stat -c '%s' src/f_load_img_from_cd_and_view.5.o)
	## カウンタ != 0(T == 0)なら繰り返す
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_5) / 2)))

	# 配置したCPTを表示するVDPCOMをVDP RAMへ配置
	## 描画終了を待つ
	cat src/f_load_img_from_cd_and_view.4.o
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_4) / 2)))
	## VDPCOMを配置
	copy_to_reg_from_val_long r14 $a_put_vdp1_command_normal_sprite_draw_rgb_to_addr
	copy_to_reg_from_val_long r1 $VRAM_CT_OTHER_BASE
	copy_to_reg_from_val_word r4 $VRAM_CPT_OTHER_BASE_CMDSRCA
	sh2_set_reg r2 00
	sh2_set_reg r3 00
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_set_reg r5 00
	## 次にコマンドを配置する場所に描画終了コマンドを配置
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r1 r0

	# 退避したレジスタを復帰しreturn
	## pr
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
	## r14
	sh2_copy_to_reg_from_ptr_long r14 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r13
	sh2_copy_to_reg_from_ptr_long r13 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r12
	sh2_copy_to_reg_from_ptr_long r12 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r11
	sh2_copy_to_reg_from_ptr_long r11 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r10
	sh2_copy_to_reg_from_ptr_long r10 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r9
	sh2_copy_to_reg_from_ptr_long r9 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r8
	sh2_copy_to_reg_from_ptr_long r8 r15
	sh2_add_to_reg_from_val_byte r15 04
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
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}
