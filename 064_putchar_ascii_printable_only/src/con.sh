if [ "${SRC_CON_SH+is_defined}" ]; then
	return
fi
SRC_CON_SH=true

. include/sh2.sh
. include/ss.sh
. include/common.sh
. include/con.sh
. src/vars_map.sh

ASCII_PRINTABLE_1ST_CHR=20	# スペース
# 符号拡張されるままにレジスタロードしている
# 無いとは思うが、0x80以上の値に変更する際は、
# この変数をレジスタロードした後、extu.b命令でバイトからゼロ拡張するようにする

ASCII_0=30

# 16進で16を表示する際のASCIIコード
HEX_DISP_A=41
# ここで0x41('A')を指定すれば16進表記は大文字になるし
# ここで0x61('a')を指定すれば16進表記は小文字になる

# 指定された文字(ASCII)を指定された座標に出力(コンソール以外用)
# in  : r1 - ASCIIコード
#     : r2 - X座標
#     : r3 - Y座標
# out : r1 - VDP1 RAMのコマンドテーブルで次にコマンドを配置するアドレス
# work: r0 - 作業用
#     : r4 - 作業用
#     : r5 - 作業用
#     : r6 - 作業用
#     : r7 - 作業用
#     : macl (mulu.wを行う)
f_putchar_xy() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
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
	## macl
	sh2_copy_to_reg_from_macl r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 引数を別のレジスタへコピー
	## r2(X座標)をr5へ退避
	sh2_copy_to_reg_from_reg r5 r2
	## r3(Y座標)をr6へ退避
	sh2_copy_to_reg_from_reg r6 r3

	# 指定された文字の変数領域上のフォントのアドレスをr2へ設定
	## 指定されたASCII文字が最初の表示可能文字から何番目かをr1へ設定
	## r1 = r1 - ASCII_PRINTABLE_1ST_CHR
	sh2_set_reg r0 $ASCII_PRINTABLE_1ST_CHR
	sh2_sub_to_reg_from_reg r1 r0
	## 指定された文字のフォントの
	## フォントデータ先頭からのオフセットをr1へ設定
	## r1 = r1 * CON_FONT_SIZE
	sh2_set_reg r0 $CON_FONT_SIZE
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
	sh2_multiply_reg_by_reg_unsigned_word r1 r0
	sh2_copy_to_reg_from_macl r1
	## 指定された文字のフォントアドレスをr2へ設定
	## r2 = &var_font_dat + r1
	copy_to_reg_from_val_long r2 $var_font_dat
	sh2_add_to_reg_from_reg r2 r1

	# 描画終了を待つ
	## r1へEDSRのアドレスを取得
	copy_to_reg_from_val_long r1 $SS_VDP1_EDSR_ADDR
	(
		# r1の指す先(EDSRの内容)をr0へ取得
		sh2_copy_to_reg_from_ptr_word r0 r1
		# r0とCEFビット(0x02)との論理積をとり、
		# 結果がゼロのときTビットをセット
		# (CEFビットは描画終了状態でセットされるビット)
		sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
	) >src/f_putchar_xy.1.o
	cat src/f_putchar_xy.1.o
	local sz_1=$(stat -c '%s' src/f_putchar_xy.1.o)
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	sh2_nop
	## 論理積結果がゼロのとき、
	## 即ちTビットがセットされたとき、
	## 待つ処理を繰り返す

	# 出力する1文字のキャラクタパターンを
	# キャラクタパターンテーブル(CPT)へロード
	## ロード先のCPTアドレスをr1とr7へ設定
	copy_to_reg_from_val_long r1 $var_next_cp_other_addr
	sh2_copy_to_reg_from_ptr_long r1 r1
	sh2_copy_to_reg_from_reg r7 r1
	## キャラクタパターンのサイズ(1文字のフォントサイズ)をr3へ設定
	sh2_set_reg r3 $CON_FONT_SIZE
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	## f_memcpy()を実行する
	copy_to_reg_from_val_long r4 $a_memcpy
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop

	# 次にキャラクタパターンを配置するアドレス変数を更新
	copy_to_reg_from_val_long r2 $var_next_cp_other_addr
	sh2_copy_to_ptr_from_reg_long r2 r1

	# 定形スプライト描画コマンドを配置
	## VDP1 RAMのCPT上のキャラクタアドレス(r7)/8をr4へ設定
	## ※ VDP1 RAM上でのアドレス指定なので、正確には0x05c00000を
	##    引く必要がある
	##    ただ、下位2バイトしか使わないのでそのような作業は省いている
	### r2へ除算関数のアドレスを設定
	copy_to_reg_from_val_long r2 $a_div_reg_by_reg_long_sign
	### r1へ被除数(r7)を設定
	sh2_copy_to_reg_from_reg r1 r7
	### r0へ除数(8)を設定し関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r0 08
	### 除算結果(r1)をr4へ設定
	sh2_copy_to_reg_from_reg r4 r1
	## VDP1 RAMのコマンドテーブルで次にコマンドを配置するアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_next_vdpcom_other_addr
	sh2_copy_to_reg_from_ptr_long r1 r1
	## 画面上で文字を出力するX座標をr2へ設定
	sh2_copy_to_reg_from_reg r2 r5
	## 定形スプライト配置関数のアドレスをr5へ設定
	copy_to_reg_from_val_long r5 $a_put_vdp1_command_normal_sprite_draw_to_addr
	## Y座標をr3へ設定し関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_copy_to_reg_from_reg r3 r6

	# 次にコマンドを配置するアドレス変数を更新
	copy_to_reg_from_val_long r2 $var_next_vdpcom_other_addr
	sh2_copy_to_ptr_from_reg_long r2 r1

	# 退避したレジスタを復帰しreturn
	## pr
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
	## macl
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_macl_from_reg r0
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

# 指定された文字(ASCII)を指定された座標に出力(コンソール用)
# in  : r1 - ASCIIコード
#     : r2 - X座標
#     : r3 - Y座標
# out : r1 - VDP1 RAMのコマンドテーブルで次にコマンドを配置するアドレス
# work: r0 - 作業用
#     : r4 - 作業用
#     : r5 - 作業用
#     : r6 - 作業用
#     : r7 - 作業用
#     : macl (mulu.wを行う)
f_putchar_xy_con() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r2
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r2
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
	## macl
	sh2_copy_to_reg_from_macl r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 引数を別のレジスタへコピー
	## r2(X座標)をr5へ退避
	sh2_copy_to_reg_from_reg r5 r2
	## r3(Y座標)をr6へ退避
	sh2_copy_to_reg_from_reg r6 r3

	# 指定された文字の変数領域上のフォントのアドレスをr2へ設定
	## 指定されたASCII文字が最初の表示可能文字から何番目かをr1へ設定
	## r1 = r1 - ASCII_PRINTABLE_1ST_CHR
	sh2_set_reg r0 $ASCII_PRINTABLE_1ST_CHR
	sh2_sub_to_reg_from_reg r1 r0
	## 指定された文字のフォントの
	## フォントデータ先頭からのオフセットをr1へ設定
	## r1 = r1 * CON_FONT_SIZE
	sh2_set_reg r0 $CON_FONT_SIZE
	sh2_extend_unsigned_to_reg_from_reg_byte r0 r0
	sh2_multiply_reg_by_reg_unsigned_word r1 r0
	sh2_copy_to_reg_from_macl r1
	## 指定された文字のフォントアドレスをr2へ設定
	## r2 = &var_font_dat + r1
	copy_to_reg_from_val_long r2 $var_font_dat
	sh2_add_to_reg_from_reg r2 r1

	# 描画終了を待つ
	## r1へEDSRのアドレスを取得
	copy_to_reg_from_val_long r1 $SS_VDP1_EDSR_ADDR
	(
		# r1の指す先(EDSRの内容)をr0へ取得
		sh2_copy_to_reg_from_ptr_word r0 r1
		# r0とCEFビット(0x02)との論理積をとり、
		# 結果がゼロのときTビットをセット
		# (CEFビットは描画終了状態でセットされるビット)
		sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
	) >src/f_putchar_xy.1.o
	cat src/f_putchar_xy.1.o
	local sz_1=$(stat -c '%s' src/f_putchar_xy.1.o)
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_1) / 2)))
	sh2_nop
	## 論理積結果がゼロのとき、
	## 即ちTビットがセットされたとき、
	## 待つ処理を繰り返す

	# 出力する1文字のキャラクタパターンを
	# キャラクタパターンテーブル(CPT)へロード
	## ロード先のCPTアドレスをr1とr7へ設定
	copy_to_reg_from_val_long r1 $var_next_cp_con_addr
	sh2_copy_to_reg_from_ptr_long r1 r1
	sh2_copy_to_reg_from_reg r7 r1
	## キャラクタパターンのサイズ(1文字のフォントサイズ)をr3へ設定
	sh2_set_reg r3 $CON_FONT_SIZE
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	## f_memcpy()を実行する
	copy_to_reg_from_val_long r4 $a_memcpy
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop

	# 次にキャラクタパターンを配置するアドレス変数を更新
	copy_to_reg_from_val_long r2 $var_next_cp_con_addr
	sh2_copy_to_ptr_from_reg_long r2 r1

	# 定形スプライト描画コマンドを配置
	## VDP1 RAMのCPT上のキャラクタアドレス(r7)/8をr4へ設定
	## ※ VDP1 RAM上でのアドレス指定なので、正確には0x05c00000を
	##    引く必要がある
	##    ただ、下位2バイトしか使わないのでそのような作業は省いている
	### r2へ除算関数のアドレスを設定
	copy_to_reg_from_val_long r2 $a_div_reg_by_reg_long_sign
	### r1へ被除数(r7)を設定
	sh2_copy_to_reg_from_reg r1 r7
	### r0へ除数(8)を設定し関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r2
	sh2_set_reg r0 08
	### 除算結果(r1)をr4へ設定
	sh2_copy_to_reg_from_reg r4 r1
	## VDP1 RAMのコマンドテーブルで次にコマンドを配置するアドレスをr1へ設定
	copy_to_reg_from_val_long r1 $var_next_vdpcom_con_addr
	sh2_copy_to_reg_from_ptr_long r1 r1
	## 画面上で文字を出力するX座標をr2へ設定
	sh2_copy_to_reg_from_reg r2 r5
	## 定形スプライト配置関数のアドレスをr5へ設定
	copy_to_reg_from_val_long r5 $a_put_vdp1_command_normal_sprite_draw_to_addr
	## Y座標をr3へ設定し関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_copy_to_reg_from_reg r3 r6

	# 次にコマンドを配置するアドレス変数を更新
	copy_to_reg_from_val_long r2 $var_next_vdpcom_con_addr
	sh2_copy_to_ptr_from_reg_long r2 r1

	# 退避したレジスタを復帰しreturn
	## pr
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
	## macl
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_macl_from_reg r0
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

# 指定された文字列を指定された座標に出力
# in  : r1* - 文字列のアドレス
#     : r2* - X座標
#     : r3  - Y座標
# work: r0* - 作業用
#     : r4* - 作業用
#     : r5* - 作業用
#     : r6* - putchar_xy()作業用
#     : r7* - putchar_xy()作業用
#     : r8* - 作業用
#     : r9* - 作業用
#     : r10*- 作業用
#     : macl* (putchar_xy()でmulu.wを行う)
# ※ *が付いているレジスタはこの関数内で変更される
# ※ 折返し無し
f_putstr_xy() {
	# PRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 1文字出力する関数のアドレスをr8へ設定
	copy_to_reg_from_val_long r8 $a_putchar_xy

	# 文字列のアドレス(r1)をr9へコピー
	sh2_copy_to_reg_from_reg r9 r1

	# X座標をr10へコピー
	sh2_copy_to_reg_from_reg r10 r2

	# 次に出力する文字をr1へ設定(*1)
	sh2_copy_to_reg_from_ptr_byte r1 r9	# 2

	# 0x00と比較し、等しければ(T==1なら)、return処理までジャンプ
	sh2_set_reg r0 00	# 2
	sh2_compare_reg_eq_reg r1 r0	# 2
	(
		# 0x00と等しくなかった場合(T==0)の処理

		# X座標をr2へ設定し、1文字出力の関数呼び出し
		sh2_abs_call_to_reg_after_next_inst r8	# 2
		sh2_copy_to_reg_from_reg r2 r10	# 2

		# X座標をフォント幅分進める
		sh2_add_to_reg_from_val_byte r10 $CON_FONT_WIDTH	# 2

		# アドレスを1バイト進め、(*1)までジャンプ
		sh2_rel_jump_after_next_inst $(two_comp_3_d $(((2 * 9) / 2)))	# 2
		sh2_add_to_reg_from_val_byte r9 01	# 2
	) >src/f_putstr_xy.1.o
	local sz_1=$(stat -c '%s' src/f_putstr_xy.1.o)
	sh2_rel_jump_if_true $(two_digits_d $(((sz_1 - 2) / 2)))	# 2
	cat src/f_putstr_xy.1.o

	# PRをスタックから復帰しreturn
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
	sh2_return_after_next_inst
	sh2_nop
}

# r1の値を指定された座標に出力
# in  : r1* - 出力する値
#     : r2* - X座標
#     : r3  - Y座標
# work: r0* - 作業用
#     : r4* - 作業用
#     : r5* - putchar_xy()作業用
#     : r6* - putchar_xy()作業用
#     : r7* - putchar_xy()作業用
#     : r8* - 作業用(a_conv_to_ascii_from_hex)
#     : r9* - 作業用(a_putchar_xy)
#     : r10*- 作業用(出力する値(r1))
#     : r11*- 作業用(X座標(r2))
#     : macl* (putchar_xy()でmulu.wを行う)
# ※ *が付いているレジスタはこの関数内で変更される
# ※ 折返し無し
f_putreg_xy() {
	# PRをスタックへ退避
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 作業用変数設定
	## a_conv_to_ascii_from_hexをr8へ設定
	copy_to_reg_from_val_long r8 $a_conv_to_ascii_from_hex
	## a_putchar_xyをr9へ設定
	copy_to_reg_from_val_long r9 $a_putchar_xy
	# 出力する値(r1)をr10へコピー
	sh2_copy_to_reg_from_reg r10 r1
	# X座標(r2)をr11へコピー
	sh2_copy_to_reg_from_reg r11 r2

	# b31-b28
	## 4ビット左ローテート
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	## ASCIIコードへ変換
	sh2_abs_call_to_reg_after_next_inst r8
	sh2_copy_to_reg_from_reg r1 r10
	## 出力
	sh2_abs_call_to_reg_after_next_inst r9
	sh2_nop

	# b27-b24
	## 4ビット左ローテート
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	## ASCIIコードへ変換
	sh2_abs_call_to_reg_after_next_inst r8
	sh2_copy_to_reg_from_reg r1 r10
	## X座標をフォント幅分進めて出力
	sh2_add_to_reg_from_val_byte r11 $CON_FONT_WIDTH
	sh2_abs_call_to_reg_after_next_inst r9
	sh2_copy_to_reg_from_reg r2 r11

	# b23-b20
	## 4ビット左ローテート
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	## ASCIIコードへ変換
	sh2_abs_call_to_reg_after_next_inst r8
	sh2_copy_to_reg_from_reg r1 r10
	## X座標をフォント幅分進めて出力
	sh2_add_to_reg_from_val_byte r11 $CON_FONT_WIDTH
	sh2_abs_call_to_reg_after_next_inst r9
	sh2_copy_to_reg_from_reg r2 r11

	# b19-b16
	## 4ビット左ローテート
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	## ASCIIコードへ変換
	sh2_abs_call_to_reg_after_next_inst r8
	sh2_copy_to_reg_from_reg r1 r10
	## X座標をフォント幅分進めて出力
	sh2_add_to_reg_from_val_byte r11 $CON_FONT_WIDTH
	sh2_abs_call_to_reg_after_next_inst r9
	sh2_copy_to_reg_from_reg r2 r11

	# b15-b12
	## 4ビット左ローテート
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	## ASCIIコードへ変換
	sh2_abs_call_to_reg_after_next_inst r8
	sh2_copy_to_reg_from_reg r1 r10
	## X座標をフォント幅分進めて出力
	sh2_add_to_reg_from_val_byte r11 $CON_FONT_WIDTH
	sh2_abs_call_to_reg_after_next_inst r9
	sh2_copy_to_reg_from_reg r2 r11

	# b11-b8
	## 4ビット左ローテート
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	## ASCIIコードへ変換
	sh2_abs_call_to_reg_after_next_inst r8
	sh2_copy_to_reg_from_reg r1 r10
	## X座標をフォント幅分進めて出力
	sh2_add_to_reg_from_val_byte r11 $CON_FONT_WIDTH
	sh2_abs_call_to_reg_after_next_inst r9
	sh2_copy_to_reg_from_reg r2 r11

	# b7-b4
	## 4ビット左ローテート
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	## ASCIIコードへ変換
	sh2_abs_call_to_reg_after_next_inst r8
	sh2_copy_to_reg_from_reg r1 r10
	## X座標をフォント幅分進めて出力
	sh2_add_to_reg_from_val_byte r11 $CON_FONT_WIDTH
	sh2_abs_call_to_reg_after_next_inst r9
	sh2_copy_to_reg_from_reg r2 r11

	# b3-b0
	## 4ビット左ローテート
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	sh2_rotate_left r10
	## ASCIIコードへ変換
	sh2_abs_call_to_reg_after_next_inst r8
	sh2_copy_to_reg_from_reg r1 r10
	## X座標をフォント幅分進めて出力
	sh2_add_to_reg_from_val_byte r11 $CON_FONT_WIDTH
	sh2_abs_call_to_reg_after_next_inst r9
	sh2_copy_to_reg_from_reg r2 r11

	# PRをスタックから復帰しreturn
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
	sh2_return_after_next_inst
	sh2_nop
}

# コンソールの初期化
# work: r0 - 作業用
#     : r1 - 作業用
#     : r2 - 作業用
f_con_init() {
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

	# カーソル座標をリセット
	## X
	sh2_set_reg r1 $CON_AREA_X
	sh2_extend_unsigned_to_reg_from_reg_byte r1 r1
	copy_to_reg_from_val_long r2 $var_con_cur_x
	sh2_copy_to_ptr_from_reg_word r2 r1
	## Y
	sh2_set_reg r1 $CON_AREA_Y
	sh2_extend_unsigned_to_reg_from_reg_byte r1 r1
	copy_to_reg_from_val_long r2 $var_con_cur_y
	sh2_copy_to_ptr_from_reg_word r2 r1

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

# カーソルを1文字分進める
# work: r0 - 作業用
#     : r1 - 作業用
#     : r2 - 作業用
#     : r3 - 作業用
#     : r4 - 作業用
#     : r5 - 作業用
f_forward_cursor() {
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

	# カーソルX座標の変数のアドレスをr1へ取得
	copy_to_reg_from_val_long r1 $var_con_cur_x

	# カーソルX座標をr2へ取得
	sh2_copy_to_reg_from_ptr_word r2 r1
	sh2_extend_unsigned_to_reg_from_reg_word r2 r2

	# r2 += CON_FONT_WIDTH
	sh2_add_to_reg_from_val_byte r2 $CON_FONT_WIDTH

	# r2 >= CON_OUTSIDE_X ?
	copy_to_reg_from_val_long r3 $(extend_digit $CON_OUTSIDE_X 8)
	sh2_compare_reg_ge_reg_unsigned r2 r3
	(
		# r2 >= CON_OUTSIDE_X の場合

		# 変更が発生するレジスタを退避
		## r4
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r4
		## r5
		sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
		sh2_copy_to_ptr_from_reg_long r15 r5

		# r2 = CON_AREA_X
		sh2_set_reg r2 $CON_AREA_X
		sh2_extend_unsigned_to_reg_from_reg_byte r2 r2

		# カーソルY座標の変数のアドレスをr3へ取得
		copy_to_reg_from_val_long r3 $var_con_cur_y

		# カーソルY座標をr4へ取得
		sh2_copy_to_reg_from_ptr_word r4 r3
		sh2_extend_unsigned_to_reg_from_reg_word r4 r4

		# r4 += CON_FONT_HEIGHT
		sh2_add_to_reg_from_val_byte r4 $CON_FONT_HEIGHT

		# r4 >= CON_OUTSIDE_Y ?
		copy_to_reg_from_val_long r5 $(extend_digit $CON_OUTSIDE_Y 8)
		sh2_compare_reg_ge_reg_unsigned r4 r5
		(
			# r4 >= CON_OUTSIDE_Y の場合

			# 変更が発生するレジスタを退避

			# r4 = CON_AREA_Y
			sh2_set_reg r4 $CON_AREA_Y
			sh2_extend_unsigned_to_reg_from_reg_byte r4 r4

			# コンソール領域をクリアする
			## TODO コンソール領域をクリアする関数を実装し
			##      ここで呼び出す

			# 退避したレジスタを復帰
		) >src/f_forward_cursor.2.o
		## T == 0 なら r4 >= CON_OUTSIDE_Y の場合の処理を飛ばす
		local sz_2=$(stat -c '%s' src/f_forward_cursor.2.o)
		sh2_rel_jump_if_false $(two_digits_d $(((sz_2 - 2) / 2)))
		cat src/f_forward_cursor.2.o

		# r4をカーソルY座標の変数へ設定
		sh2_copy_to_ptr_from_reg_word r3 r4

		# 退避したレジスタを復帰
		## r5
		sh2_copy_to_reg_from_ptr_long r5 r15
		sh2_add_to_reg_from_val_byte r15 04
		## r4
		sh2_copy_to_reg_from_ptr_long r4 r15
		sh2_add_to_reg_from_val_byte r15 04
	) >src/f_forward_cursor.1.o
	## T == 0 なら r2 >= CON_OUTSIDE_X の場合の処理を飛ばす
	local sz_1=$(stat -c '%s' src/f_forward_cursor.1.o)
	sh2_rel_jump_if_false $(two_digits_d $(((sz_1 - 2) / 2)))
	cat src/f_forward_cursor.1.o

	# r2をカーソルX座標の変数へ設定
	sh2_copy_to_ptr_from_reg_word r1 r2

	# 退避したレジスタを復帰しreturn
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

# 1文字出力しカーソル座標を1文字分進める
# in  : r1 - ASCIIコード
# work: r0 - 作業用
#     : r2 - 作業用
#     : r3 - 作業用
#     : r4 - 作業用
f_putchar() {
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
	## pr
	sh2_copy_to_reg_from_pr r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0

	# 現在のカーソル座標へ1文字出力
	## 現在のカーソルX座標をr2へ設定
	copy_to_reg_from_val_long r2 $var_con_cur_x
	sh2_copy_to_reg_from_ptr_word r2 r2
	sh2_extend_unsigned_to_reg_from_reg_word r2 r2
	## 現在のカーソルY座標をr3へ設定
	copy_to_reg_from_val_long r3 $var_con_cur_y
	sh2_copy_to_reg_from_ptr_word r3 r3
	sh2_extend_unsigned_to_reg_from_reg_word r3 r3
	## 1文字出力
	copy_to_reg_from_val_long r4 $a_putchar_xy
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop

	# カーソルを1文字分進める
	copy_to_reg_from_val_long r1 $a_forward_cursor
	sh2_abs_call_to_reg_after_next_inst r1
	sh2_nop

	# 退避したレジスタを復帰しreturn
	## pr
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_copy_to_pr_from_reg r0
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
