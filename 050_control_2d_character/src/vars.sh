#!/bin/bash

# set -uex
set -ue

. include/memmap.sh

vars() {
	map_file=src/vars_map.sh
	rm -f $map_file

	# キャラクタパターンテーブルデータ
	var_char_pat_tbl_dat=$VARS_BASE
	echo -e "var_char_pat_tbl_dat=$var_char_pat_tbl_dat" >>$map_file
	cat character.lut
	## カラールックアップテーブルを参照する4bits/pixelデータ
}

vars
