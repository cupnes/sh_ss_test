#!/bin/bash

# set -uex
set -ue

. include/sh2.sh
. include/lib.sh
. include/ss.sh
. include/vdp1.sh
. include/memmap.sh
. include/charcode.sh
. src/vars_map.sh
. src/funcs_map.sh
. src/vdp.sh
. src/con.sh

INIT_SP=06004000
PROGRAM_ENTRY_ADDR=06004000

# 出力する座標
OUTPUT_X1=10
OUTPUT_Y1=10
OUTPUT_X2=10
OUTPUT_Y2=20

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
# work: r0*  - copy_to_reg_from_val_long,setup_vram_command_table,
#              setup_vram_color_lookup_table,この中の作業用
#     : r1*  - setup_vram_command_table,setup_vram_color_lookup_table,
#              この中の作業用
#     : r2*  - setup_vram_command_table,この中の作業用
#     : r3*  - vdp_initの作業用
#     : r4*  - vdp_initの作業用
# ※ *が付いているレジスタはこの関数で書き換えられる
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

	# 使用する関数・変数のアドレスをレジスタへ設定
	copy_to_reg_from_val_long r14 $a_cd_exec_command
	copy_to_reg_from_val_long r13 $SS_CT_CS2_HIRQ_ADDR
	copy_to_reg_from_val_long r12 $SS_CT_CS2_DTR_ADDR
	copy_to_reg_from_val_long r11 $a_putreg_xy
	copy_to_reg_from_val_long r10 $SS_CT_CS2_CR4_ADDR
	copy_to_reg_from_val_long r9 $a_dump_cr1234_xy
	copy_to_reg_from_val_long r8 $var_next_cp_other_addr
	copy_to_reg_from_val_long r7 $SS_VDP1_EDSR_ADDR

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

	## r2(CR2) = 0x02a2
	copy_to_reg_from_val_word r2 02a2

	## r3(CR3) = 0x0080
	sh2_set_reg r3 80
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	## r4(CR4) = 0x0046
	sh2_set_reg r4 46

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# 70(0x46)セクタの読み取りが完了するまで待つ
	## 読み取り済みセクタ数の取得
	### GetSectorNumber(0x51)
	### | Reg | [15:8]    | [7:0] |
	### |-----+-----------+-------|
	### | CR1 | cmd(0x51) | -     |
	### | CR2 | -         | -     |
	### | CR3 | gsnbufno  | -     |
	### | CR4 | -         | -     |

	### r1(CR1) = 0x5100
	sh2_set_reg r1 51
	sh2_shift_left_logical_8 r1

	### r2(CR2) = 0x0000
	sh2_set_reg r2 00

	### r3(CR3) = 0x0000
	sh2_set_reg r3 00

	### r4(CR4) = 0x0000
	sh2_set_reg r4 00

	(
		# CDコマンド実行
		sh2_abs_call_to_reg_after_next_inst r14
		sh2_nop

		# CR4 == 0x46 ?
		sh2_copy_to_reg_from_ptr_word r0 r10
		sh2_compare_r0_eq_val 46
	) >src/main.1.o
	cat src/main.1.o
	local sz_1=$(stat -c '%s' src/main.1.o)
	## T == 0(CR != 0x46)なら繰り返す
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

	## r4(CR4) = 0x0046
	sh2_set_reg r4 46

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# DTRから70セクタ分をVDP1 RAMのその他用のCPT領域へコピー
	## 70セクタ = 70 * 2048 = 143360 バイト
	## 143360 / 4 = 35840 より、
	## 4バイト単位の読み出し35840(0x8c00)回

	## r1 = 0x8c00
	sh2_set_reg r1 8c
	sh2_shift_left_logical_8 r1
	sh2_extend_unsigned_to_reg_from_reg_word r1 r1

	## r2 = 配置するCPTの先頭アドレス
	sh2_copy_to_reg_from_ptr_long r2 r8

	(
		# r7の指す先(EDSRの内容)をr0へ取得
		sh2_copy_to_reg_from_ptr_word r0 r7
		# r0とCEFビット(0x02)との論理積をとり、
		# 結果がゼロのときTビットをセット
		# (CEFビットは描画終了状態でセットされるビット)
		sh2_test_r0_and_val_byte $SS_VDP1_EDSR_BIT_CEF
	) >src/main.2.o
	local sz_2=$(stat -c '%s' src/main.2.o)
	(
		# 描画終了を待つ
		cat src/main.2.o
		sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_2) / 2)))
		## 論理積結果がゼロのとき、
		## 即ちTビットがセットされたとき、
		## 待つ処理を繰り返す

		# 4バイト読み出してr3へ格納
		sh2_copy_to_reg_from_ptr_long r3 r12

		# 読み出した4バイトをCPTへ配置
		sh2_copy_to_ptr_from_reg_long r2 r3

		# CPTのアドレス += 4
		sh2_add_to_reg_from_val_byte r2 04

		# カウンタ--
		sh2_add_to_reg_from_val_byte r1 $(two_comp_d 1)

		# カウンタ == 0 ?
		sh2_set_reg r0 00
		sh2_compare_reg_eq_reg r1 r0
	) >src/main.3.o
	cat src/main.3.o
	local sz_3=$(stat -c '%s' src/main.3.o)
	## カウンタ != 0(T == 0)なら繰り返す
	sh2_rel_jump_if_false $(two_comp_d $(((4 + sz_3) / 2)))

	# 配置したCPTを表示するVDPCOMをVDP RAMへ配置
	## 描画終了を待つ
	cat src/main.2.o
	sh2_rel_jump_if_true $(two_comp_d $(((4 + sz_2) / 2)))
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

	# 無限ループ
	infinite_loop
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
