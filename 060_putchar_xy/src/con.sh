if [ "${SRC_CON_SH+is_defined}" ]; then
	return
fi
SRC_CON_SH=true

. include/sh2.sh
. include/ss.sh
. src/vars_map.sh

ASCII_PRINTABLE_1ST_CHR=20	# スペース
# 符号拡張されるままにレジスタロードしている
# 無いとは思うが、0x80以上の値に変更する際は、
# この変数をレジスタロードした後、extu.b命令でバイトからゼロ拡張するようにする

CON_FONT_SIZE=80	# 128バイト

# 指定された文字(ASCII)を指定された座標に出力
# in  : r1* - ASCIIコード
#     : r2  - X座標
#     : r3  - Y座標
# out : r1  - VDP1 RAMのコマンドテーブルで次にコマンドを配置するアドレス
# work: r0* - 作業用
#     : r4* - 作業用
#     : r5* - 作業用
#     : r6* - 作業用
#     : r7* - 作業用
#     : macl* (mulu.wを行う)
# ※ *が付いているレジスタはこの関数内で変更される
f_putchar_xy() {
	# PRをスタックへ退避
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
	copy_to_reg_from_val_long r1 $var_next_cp_addr
	sh2_copy_to_reg_from_ptr_long r1 r1
	sh2_copy_to_reg_from_reg r7 r1
	## キャラクタパターンのサイズ(1文字のフォントサイズ)をr3へ設定
	sh2_set_reg r3 $CON_FONT_SIZE
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	## f_memcpy()を実行する
	copy_to_reg_from_val_long r4 $a_memcpy
	sh2_abs_call_to_reg_after_next_inst r4
	sh2_nop

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
	copy_to_reg_from_val_long r1 $var_next_vdpcom_addr
	sh2_copy_to_reg_from_ptr_long r1 r1
	## 画面上で文字を出力するX座標をr2へ設定
	sh2_copy_to_reg_from_reg r2 r5
	## 定形スプライト配置関数のアドレスをr5へ設定
	copy_to_reg_from_val_long r5 $a_put_vdp1_command_normal_sprite_draw_to_addr
	## Y座標をr3へ設定し関数呼び出し
	sh2_abs_call_to_reg_after_next_inst r5
	sh2_copy_to_reg_from_reg r3 r6

	# 次にコマンドを配置するアドレス変数を更新
	copy_to_reg_from_val_long r2 $var_next_vdpcom_addr
	sh2_copy_to_ptr_from_reg_long r2 r1

	# PRをスタックから復帰しreturn
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	sh2_return_after_next_inst
	sh2_copy_to_pr_from_reg r0
}
