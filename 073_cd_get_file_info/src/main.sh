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
	copy_to_reg_from_val_long r12 $SS_CT_CS2_TI_ADDR
	copy_to_reg_from_val_long r11 $a_putreg_xy
	copy_to_reg_from_val_long r10 $SS_CT_CS2_CR4_ADDR

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

	# ChangeDirectoryでrootディレクトリへ移動
	## ChangeDirectory(cmd=0x70)
	## | Reg | [15:8]      | [7:0]      |
	## |-----+-------------+------------|
	## | CR1 | cmd(0x70)   | -          |
	## | CR2 | -           | -          |
	## | CR3 | cdfilternum | fid[23:16] |
	## | CR4 | fid[15:8]   | fid[7:0]   |

	## r1(CR1) = 0x7000
	sh2_set_reg r1 70
	sh2_shift_left_logical_8 r1

	## r3(CR3) = 0x00ff
	## - cdfilternum = 0x00
	## - fid[23:16] = 0xff
	sh2_set_reg r3 ff
	sh2_extend_unsigned_to_reg_from_reg_byte r3 r3

	## r4(CR4) = 0xffff
	sh2_set_reg r4 ff

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# ファイル情報を取得する
	## getFileInfo(cmd=0x73)
	## | Reg | [15:8]       | [7:0]         |
	## |-----+--------------+---------------|
	## | CR1 | cmd(0x73)    | -             |
	## | CR2 | -            | -             |
	## | CR3 | -            | gfifid[23:16] |
	## | CR4 | gfifid[15:8] | gfifid[7:0]   |

	## r1(CR1) = 0x7300
	sh2_set_reg r1 73
	sh2_shift_left_logical_8 r1

	## fid==3のファイル情報を取得する
	### r3(CR3) = 0x0000
	sh2_set_reg r3 00
	### r4(CR4) = 0x0003
	sh2_set_reg r4 03

	# ## 全ファイル情報を取得する
	# ### r3(CR3) = 0x00ff
	# sh2_set_reg r3 ff
	# sh2_extend_unsigned_to_reg_from_reg_byte r3 r3
	# ### r4(CR4) = 0xffff
	# sh2_set_reg r4 ff

	## CDコマンド実行
	sh2_abs_call_to_reg_after_next_inst r14
	sh2_nop

	# DTRを読んでみる
	## Cs2Area->transfileinfo[0] = (u8)(Cs2Area->fileinfo[fid].lba >> 24);
	## Cs2Area->transfileinfo[1] = (u8)(Cs2Area->fileinfo[fid].lba >> 16);
	sh2_copy_to_reg_from_ptr_word r1 r12
	sh2_set_reg r2 10
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_set_reg r3 10
	## Cs2Area->transfileinfo[2] = (u8)(Cs2Area->fileinfo[fid].lba >> 8);
	## Cs2Area->transfileinfo[3] = (u8)Cs2Area->fileinfo[fid].lba;
	sh2_copy_to_reg_from_ptr_word r1 r12
	sh2_set_reg r2 a0
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	## Cs2Area->transfileinfo[4] = (u8)(Cs2Area->fileinfo[fid].size >> 24);
	## Cs2Area->transfileinfo[5] = (u8)(Cs2Area->fileinfo[fid].size >> 16);
	sh2_copy_to_reg_from_ptr_word r1 r12
	sh2_set_reg r2 10
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_add_to_reg_from_val_byte r3 $CON_FONT_HEIGHT
	## Cs2Area->transfileinfo[6] = (u8)(Cs2Area->fileinfo[fid].size >> 8);
	## Cs2Area->transfileinfo[7] = (u8)Cs2Area->fileinfo[fid].size;
	sh2_copy_to_reg_from_ptr_word r1 r12
	sh2_set_reg r2 a0
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2
	## Cs2Area->transfileinfo[8] = Cs2Area->fileinfo[fid].interleavegapsize;
	## Cs2Area->transfileinfo[9] = Cs2Area->fileinfo[fid].fileunitsize;
	sh2_copy_to_reg_from_ptr_word r1 r12
	sh2_set_reg r2 10
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_add_to_reg_from_val_byte r3 $CON_FONT_HEIGHT
	## Cs2Area->transfileinfo[10] = (u8) fid;
	## Cs2Area->transfileinfo[11] = Cs2Area->fileinfo[fid].flags;
	sh2_copy_to_reg_from_ptr_word r1 r12
	sh2_set_reg r2 a0
	sh2_abs_call_to_reg_after_next_inst r11
	sh2_extend_unsigned_to_reg_from_reg_byte r2 r2

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
