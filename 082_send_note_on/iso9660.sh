#!/bin/bash

# set -uex
set -ue

. include/common.sh

SECTOR_BYTES=2048

usage() {
	echo "$0 - Outputs an ISO image containing the specified file(s) to the standard output." >&2
	echo >&2
	echo 'Usage:' >&2
	echo -e "\t$0 FILE [FILE ...]" >&2
	echo -e "\t$0 -h" >&2
}

if [ $# -eq 0 ]; then
	usage
	exit 1
fi
if [ "$1" = '-h' ]; then
	usage
	exit 0
fi
FILE_LIST="$@"

# 中間ファイルの接頭辞
TMP_PREF="${0}.tmp"

# 1つ目のファイルを置く論理ブロックアドレスを事前に知るために、
# ルート直下のディレクトリレコードの領域のセクタ数を算出する
## 第1・2ディレクトリレコード = 各 34 バイト(計 68 バイト)
TOTAL_DIRREC_BYTES_ROOT=68
## 第3以降のディレクトリレコード = 各 33 + LEN_FI + ((LEN_FI + 1) % 2) バイト
## (LEN_FI = ファイル識別子の長さ = ファイル名の長さ + 2 [バイト])
## ※ ディレクトリレコードはセクタをまたがない(パディングが入る)
for f in $FILE_LIST; do
	fn=$(basename $f)
	len_fn=$(echo -n $fn | wc -c)
	len_fi=$((len_fn + 2))
	len_pad=$(((len_fi + 1) % 2))
	len_dr=$((33 + len_fi + len_pad))
	if [ $((TOTAL_DIRREC_BYTES_ROOT / SECTOR_BYTES)) -ne $(((TOTAL_DIRREC_BYTES_ROOT + len_dr) / SECTOR_BYTES)) ]; then
		# 今回のデータレコード配置によりセクタ番目が変わる

		# FIXME 現状では、ディレクトリレコード領域が1セクタを超えるケースでは正しく動作しない
		#       (isoinfo -l -i などでファイルリストを表示させると見えるが、
		#       マウントすると2セクタ目以降のディレクトリレコードが見えない)
		echo "Error: The directory record area has exceeded one sector at \"$f\"." >&2
		exit 1

		# またぐのか？
		mod=$((TOTAL_DIRREC_BYTES_ROOT % SECTOR_BYTES))
		if [ $mod -ne 0 ]; then
			# またぐ(ので、そうならないようにパディングを入れる)
			TOTAL_DIRREC_BYTES_ROOT=$((TOTAL_DIRREC_BYTES_ROOT + (SECTOR_BYTES - mod)))
		fi
	fi
	TOTAL_DIRREC_BYTES_ROOT=$((TOTAL_DIRREC_BYTES_ROOT + len_dr))
done
## セクタサイズの倍数にするためのパディング
mod=$((TOTAL_DIRREC_BYTES_ROOT % SECTOR_BYTES))
if [ $mod -ne 0 ]; then
	TOTAL_DIRREC_BYTES_ROOT=$((TOTAL_DIRREC_BYTES_ROOT + (SECTOR_BYTES - mod)))
fi
## ルート直下のディレクトリレコードの領域のセクタ数
TOTAL_DIRREC_SECTORS_ROOT=$((TOTAL_DIRREC_BYTES_ROOT / SECTOR_BYTES))

# 1つ目のファイルの論理ブロックアドレス(LBA)
LBA_1ST_FILE=$((20 + TOTAL_DIRREC_SECTORS_ROOT))

# Initial Program(IP)
# (ISO9660 Reserved Field)
gen_ip() {
	if [ ! -f IP.BIN ]; then
		wget https://github.com/johannes-fetz/joengine/raw/master/Compiler/COMMON/IP.BIN
	fi

	dd if=IP.BIN bs=1 count=64 status=none
	echo -n "J               "
	dd if=IP.BIN bs=1 ibs=1 skip=$((64 + 16)) status=none

	local ip_bin_sz=$(stat -c '%s' IP.BIN)
	local padding_sz=$(((SECTOR_BYTES * 16) - ip_bin_sz))
	dd if=/dev/zero bs=1 count=$padding_sz status=none
}

# All Zero Sector
gen_blank_sector() {
	dd if=/dev/zero bs=1 count=$SECTOR_BYTES status=none
}

# Primary Volume Descriptor(PVD)
gen_pvd() {
	# 0(0x00) Volume Descriptor Type
	echo -en '\x01'
	# 1(0x01) - 5(0x05) Standard Identifier
	echo -n 'CD001'
	# 6(0x06) Volume Descriptor Version
	echo -en '\x01'
	# 7(0x07) Unused Field
	echo -en '\x00'
	# 8(0x08) - 39(0x27) System identifier
	echo -n 'SEGA SATURN                     '
	# 40(0x28) - 71(0x47) Volume Identifier
	echo -n 'SATURNAPP                       '
	# 72(0x48) - 79(0x4f) Unused Field
	dd if=/dev/zero bs=1 count=8 status=none
	# 80(0x50) - 87(0x57) Volume Space Size
	## IP(16セクタ)・PVD(1セクタ)・VDT(1セクタ)・タイプL/Mパステーブル(各1セクタ)で計20セクタ
	local iso_sectors=20
	## ルート直下のディレクトリレコードによるセクタ数を加算
	local total_dirrec_bytes_root=$(stat -c '%s' ${TMP_PREF}.dir_root.o)
	if [ $((total_dirrec_bytes_root % SECTOR_BYTES)) -ne 0 ]; then
		# この時点で、$total_dirrec_bytes_root が $SECTOR_BYTES の倍数になっていないのはおかしい
		echo "Error: \$total_dirrec_bytes_root(=$total_dirrec_bytes_root) is not a multiple of the sector size." >&2
		exit 1
	fi
	iso_sectors=$((iso_sectors + (total_dirrec_bytes_root / SECTOR_BYTES)))
	## 格納するファイルによるセクタ数を加算
	local total_file_size=0
	local tmp_name
	for f in $FILE_LIST; do
		tmp_name=$(echo $f | sed 's%/%__%g')
		total_file_size=$((total_file_size + $(stat -c '%s' ${TMP_PREF}.${tmp_name}.o)))
	done
	iso_sectors=$((iso_sectors + (total_file_size / SECTOR_BYTES)))
	if [ $((total_file_size % SECTOR_BYTES)) -ne 0 ]; then
		# この時点で、$total_file_size が $SECTOR_BYTES の倍数になっていないのはおかしい
		echo "Error: \$total_file_size(=$total_file_size) is not a multiple of the sector size." >&2
		exit 1
	fi
	## 8桁の16進数へ変換し出力
	local iso_sectors_hex=$(extend_digit $(to16 $iso_sectors) 8)
	echo_4bytes $iso_sectors_hex
	echo_4bytes_be $iso_sectors_hex
	# 88(0x58) - 119(0x77) Escape Sequences
	dd if=/dev/zero bs=1 count=$((119 - 88 + 1)) status=none
	# 120(0x78) - 123(0x7b) Volume Set Size
	echo -en '\x01\x00\x00\x01'
	# 124(0x7c) - 127(0x7f) Volume Sequence Number
	echo -en '\x01\x00\x00\x01'
	# 128(0x80) - 131(0x83) Logical Block Size
	# 0x800 = 2048
	echo -en '\x00\x08\x08\x00'
	# 132(0x84) - 139(0x8b) Path Table Size
	# 10(0xa) bytes
	echo -en '\x0a\x00\x00\x00\x00\x00\x00\x0a'
	# 140(0x8c) - 143(0x8f) Location of Type-L Path Table
	# 18(0x12) セクタ目
	echo -en '\x12\x00\x00\x00'
	# 144(0x90) - 147(0x93) Location of the Optional Type-L Path Table
	echo -en '\x00\x00\x00\x00'
	# 148(0x94) - 151(0x97) Location of Type-M Path Table
	# 19(0x13) セクタ目
	echo -en '\x00\x00\x00\x13'
	# 152(0x98) - 155(0x9b) Location of Optional Type-M Path Table
	echo -en '\x00\x00\x00\x00'
	# 156(0x9c) - 189(0xbd) Directory entry for the root directory
	## Length of Directory Record(LEN_DR) (size 1)
	## 0x22 = 34 bytes
	echo -en '\x22'
	## Extended Attribute Record length (size 1)
	echo -en '\x00'
	## Location of extent (LBA) in both-endian format (size 8)
	## 20(0x14) セクタ目
	echo -en '\x14\x00\x00\x00\x00\x00\x00\x14'
	## Data length (size of extent) in both-endian format (size 8)
	local total_dirrec_bytes_root_hex=$(extend_digit $(to16 $total_dirrec_bytes_root) 8)
	echo_4bytes $total_dirrec_bytes_root_hex
	echo_4bytes_be $total_dirrec_bytes_root_hex
	## Recording date and time (size 7)
	### Number of years since 1900.
	echo -en '\x79'
	### Month of the year from 1 to 12.
	echo -en '\x01'
	### Day of the month from 1 to 31.
	echo -en '\x17'
	### Hour of the day from 0 to 23.
	echo -en '\x06'
	### Minute of the hour from 0 to 59.
	echo -en '\x0f'
	### Second of the minute from 0 to 59.
	echo -en '\x0f'
	### Offset from GMT in 15 minute intervals from -48 (West) to +52 (East).
	echo -en '\x24'
	## File flags (size 1)
	echo -en '\x02'
	## File unit size for files recorded in interleaved mode, zero
	## otherwise (size 1)
	echo -en '\x00'
	## Interleave gap size for files recorded in interleaved mode, zero
	## otherwise (size 1)
	echo -en '\x00'
	## Volume sequence number - the volume that this extent is recorded on,
	## in 16 bit both-endian format (size 4)
	echo -en '\x01\x00\x00\x01'
	## Length of file identifier (file name). This terminates with a ';'
	## character followed by the file ID number in ASCII coded decimal
	## ('1')(LEN_FI) (size 1)
	echo -en '\x01'
	## File identifier (size LEN_FI)
	echo -en '\x00'
	# 190(0xbe) - 317(0x13d) Volume Set Identifier
	echo -n 'SATURNAPP                                                     '
	echo -n '                                                              '
	echo -n '    '
	# 318(0x13e) - 445(0x1bd) Publisher Identifier
	echo -n '                                                              '
	echo -n '                                                              '
	echo -n '    '
	# 446(0x1be) - 573(0x23d) Data Preparer Identifier
	echo -n '                                                              '
	echo -n '                                                              '
	echo -n '    '
	# 574(0x23e) - 701(0x2bd) Application Identifier
	echo -n 'SATURNAPP                                                     '
	echo -n '                                                              '
	echo -n '    '
	# 702(0x2be) - 738(0x2e2) Copyright File Identifier
	echo -n '                                     '
	# 739(0x2e3) - 775(0x307) Abstract File Identifier
	echo -n '                                     '
	# 776(0x308) - 812(0x32c) Bibliographic File Identifier
	echo -n '                                     '
	# 813(0x32d) - 829(0x33d) Volume Creation Date and Time
	echo -n '2021012306151500$'
	# 830(0x33e) - 846(0x34e) Volume Modification Date and Time
	echo -n '2021012306151500$'
	# 847(0x34f) - 863(0x35f) Volume Expiration Date and Time
	echo -en '0000000000000000\x00'
	# 864(0x360) - 880(0x370) Volume Effective Date and Time
	echo -n '2021012306151600$'
	# 881(0x371) File Structure Version
	echo -en '\x01'
	# 882(0x372) Unused
	echo -en '\x00'
	# 883(0x373) - 1394(0x572) Application Used
	for _i in $(seq 512); do
		echo -n ' '
	done
	# 1395(0x573) - 2047(0x7ff) Reserved
	dd if=/dev/zero bs=1 count=653 status=none
}

# Volume Descriptor Set Terminator(VDT)
gen_vdt() {
	# 0(0x00) Type Code
	echo -en '\xff'
	# 1(0x01) - 5(0x05) Standard Identifier
	echo -n 'CD001'
	# 6(0x06) Version
	echo -en '\x01'
	# 7(0x07) - 2047(0x7ff) Unused
	dd if=/dev/zero bs=1 count=$((2047 - 7 + 1)) status=none
}

# Type-L Path Table
gen_lpath_tbl() {
	(
		# size 10 bytes
		# Length of Directory Identifier(LEN_DI) (size 1)
		echo -en '\x01'
		# Extended Attribute Record Length (size 1)
		echo -en '\x00'
		# Location of Extent (size 4)
		# 20(0x14) セクタ目
		echo -en '\x14\x00\x00\x00'
		# Parent Directory Number (size 2)
		echo -en '\x01\x00'
		# File Identifier (size LEN_DI)
		echo -en '\x00'
		# Padding Field(レコードサイズを偶数にするためのパディング)
		echo -en '\x00'
	) >lpath_tbl.o
	cat lpath_tbl.o

	# セクタサイズにするためのパディング
	local sz=$(stat -c '%s' lpath_tbl.o)
	dd if=/dev/zero bs=1 count=$((SECTOR_BYTES - sz)) status=none
}

# Type-M Path Table
gen_mpath_tbl() {
	(
		# size 10 bytes
		# Length of Directory Identifier(LEN_DI) (size 1)
		echo -en '\x01'
		# Extended Attribute Record Length (size 1)
		echo -en '\x00'
		# Location of Extent (size 4)
		# 20(0x14) セクタ目
		echo -en '\x00\x00\x00\x14'
		# Parent Directory Number (size 2)
		echo -en '\x00\x01'
		# File Identifier (size LEN_DI)
		echo -en '\x00'
		# Padding Field(レコードサイズを偶数にするためのパディング)
		echo -en '\x00'
	) >mpath_tbl.o
	cat mpath_tbl.o

	# セクタサイズにするためのパディング
	local sz=$(stat -c '%s' mpath_tbl.o)
	dd if=/dev/zero bs=1 count=$((SECTOR_BYTES - sz)) status=none
}

gen_dir_root() {
	local mod
	(
		# Length of Directory Record(LEN_DR) (size 1)
		# 0x22 = 34
		echo -en '\x22'
		# Extended Attribute Record Length (size 1)
		echo -en '\x00'
		# Location of Extent (size 8)
		# 20(0x14) セクタ目
		echo -en '\x14\x00\x00\x00\x00\x00\x00\x14'
		# Data Length (size 8)
		# 0x800 = 2048
		echo -en '\x00\x08\x00\x00\x00\x00\x08\x00'
		# Recording Date and Time (size 7)
		echo -en '\x79\x01\x17\x06\x0f\x0f\x24'
		# File Flags (size 1)
		# - b7: Multi-Extent
		#       0=ファイルの最終ディレクトリレコードである
		#       1=ファイルの最終ディレクトリレコードでない
		# - b6: Reserved (=0)
		# - b5: Reserved (=0)
		# - b4: Protection
		#       0=許可条件無効 / 1=許可条件有効
		# - b3: Record
		#       0=ファイルがレコード形式を持たない / 1=レコード形式を持つ
		# - b2: Associated File
		#       0=主ファイル / 1=関連ファイル
		# - b1: Directory
		#       0=ファイル / 1=ディレクトリ
		# - b0: Existence
		#       0=可視ファイル / 1=不可視ファイル
		# 0x02 -> Directoryフラグだけセット
		echo -en '\x02'
		# File Unit Size (size 1)
		echo -en '\x00'
		# Interleave Gap Size (size 1)
		echo -en '\x00'
		# Volume Sequence Number (size 4)
		echo -en '\x01\x00\x00\x01'
		# Length of File Identifier(LEN_FI) (size 1)
		echo -en '\x01'
		# File Identifier (size LEN_FI)
		echo -en '\x00'
		# Padding Field(レコードサイズを偶数にするためのパディング)
		# System Use (size LEN_DRの残り)

		# Length of Directory Record(LEN_DR) (size 1)
		# 0x22 = 34
		echo -en '\x22'
		# Extended Attribute Record Length (size 1)
		echo -en '\x00'
		# Location of Extent (size 8)
		echo -en '\x14\x00\x00\x00\x00\x00\x00\x14'
		# Data Length (size 8)
		echo -en '\x00\x08\x00\x00\x00\x00\x08\x00'
		# Recording Date and Time (size 7)
		echo -en '\x79\x01\x17\x06\x0f\x0f\x24'
		# File Flags (size 1)
		echo -en '\x02'
		# File Unit Size (size 1)
		echo -en '\x00'
		# Interleave Gap Size (size 1)
		echo -en '\x00'
		# Volume Sequence Number (size 4)
		echo -en '\x01\x00\x00\x01'
		# Length of File Identifier(LEN_FI) (size 1)
		echo -en '\x01'
		# File Identifier (size LEN_FI)
		echo -en '\x01'
		# Padding Field(レコードサイズを偶数にするためのパディング)
		# System Use (size LEN_DRの残り)

		local len_dir_root=68
		local len_dr_pad
		local lba_f=$LBA_1ST_FILE
		local lba_f_hex
		local sz_f
		local sz_f_hex
		local fn
		local len_fn
		local len_fi
		local fi
		local len_dr
		local sectors_f
		local tmp_name
		for f in $FILE_LIST; do
			lba_f_hex=$(extend_digit $(to16 $lba_f) 8)
			sz_f=$(stat -c '%s' $f)
			sz_f_hex=$(extend_digit $(to16 $sz_f) 8)
			fn=$(basename $f)
			len_fn=$(echo -n $fn | wc -c)
			len_fi=$((len_fn + 2))
			fi="${fn};1"
			tmp_name=$(echo $f | sed 's%/%__%g')

			(
				# Extended Attribute Record Length (size 1)
				echo -en '\x00'
				# Location of Extent (size 8)
				echo_4bytes $lba_f_hex
				echo_4bytes_be $lba_f_hex
				# Data Length (size 8)
				echo_4bytes $sz_f_hex
				echo_4bytes_be $sz_f_hex
				# Recording Date and Time (size 7)
				echo -en '\x79\x01\x17\x06\x0f\x0f\x24'
				# File Flags (size 1)
				echo -en '\x00'
				# File Unit Size (size 1)
				echo -en '\x00'
				# Interleave Gap Size (size 1)
				echo -en '\x00'
				# Volume Sequence Number (size 4)
				echo -en '\x01\x00\x00\x01'
				# Length of File Identifier(LEN_FI) (size 1)
				echo -en "\x$(two_digits $(to16 $len_fi))"
				# File Identifier (size LEN_FI)
				echo -n $fi
				# Padding Field (size (LEN_FI + 1) % 2)
				dd if=/dev/zero bs=1 count=$(((len_fi + 1) % 2)) status=none
			) >${TMP_PREF}.dirrec_${tmp_name}.o

			# データレコードサイズを算出
			len_dr=$(($(stat -c '%s' ${TMP_PREF}.dirrec_${tmp_name}.o) + 1))

			if [ $((len_dir_root / SECTOR_BYTES)) -ne $(((len_dir_root + len_dr) / SECTOR_BYTES)) ]; then
				# 今回のデータレコード配置によりセクタ番目が変わる

				# またぐのか？
				mod=$((len_dir_root % SECTOR_BYTES))
				if [ $mod -ne 0 ]; then
					# またぐ(ので、そうならないようにパディングを入れる)
					len_dr_pad=$((SECTOR_BYTES - mod))
					dd if=/dev/zero bs=1 count=$len_dr_pad status=none
					len_dir_root=$((len_dir_root + len_dr_pad))
				fi
			fi
			# 出力したデータレコードサイズを更新
			len_dir_root=$((len_dir_root + len_dr))

			# データレコードを出力
			## Length of Directory Record(LEN_DR) (size 1)
			echo -en "\x$(two_digits $(to16 $len_dr))"
			## ファイルへダンプしたレコード本体
			cat ${TMP_PREF}.dirrec_${tmp_name}.o

			sectors_f=$((sz_f / SECTOR_BYTES))
			if [ $((sz_f % SECTOR_BYTES)) -ne 0 ]; then
				sectors_f=$((sectors_f + 1))
			fi
			lba_f=$((lba_f + sectors_f))
		done
	) >${TMP_PREF}.gen_dir_root.1.o
	cat ${TMP_PREF}.gen_dir_root.1.o

	# セクタサイズにするためのパディング
	local sz=$(stat -c '%s' ${TMP_PREF}.gen_dir_root.1.o)
	mod=$((sz % SECTOR_BYTES))
	if [ $mod -ne 0 ]; then
		dd if=/dev/zero bs=1 count=$((SECTOR_BYTES - mod)) status=none
	fi
}

gen_file() {
	local f=$1
	local sz=$(stat -c '%s' $f)

	cat $f

	# セクタサイズにするためのパディング
	local mod=$((sz % SECTOR_BYTES))
	if [ $mod -ne 0 ]; then
		dd if=/dev/zero bs=1 count=$((SECTOR_BYTES - mod)) status=none
	fi
}

main() {
	# pre-generation
	local tmp_name
	for f in $FILE_LIST; do
		tmp_name=$(echo $f | sed 's%/%__%g')
		gen_file $f >${TMP_PREF}.${tmp_name}.o
	done
	gen_dir_root >${TMP_PREF}.dir_root.o
	gen_mpath_tbl >${TMP_PREF}.mpath_tbl.o
	gen_lpath_tbl >${TMP_PREF}.lpath_tbl.o
	gen_vdt >${TMP_PREF}.vdt.o
	gen_pvd >${TMP_PREF}.pvd.o
	gen_ip >${TMP_PREF}.ip.o

	# sector 0(0x0) - 15(0xf)
	cat ${TMP_PREF}.ip.o
	# sector 16(0x10)
	cat ${TMP_PREF}.pvd.o
	# sector 17(0x11)
	cat ${TMP_PREF}.vdt.o
	# sector 18(0x12)
	cat ${TMP_PREF}.lpath_tbl.o
	# sector 19(0x13)
	cat ${TMP_PREF}.mpath_tbl.o
	# sector 20(0x14)-
	cat ${TMP_PREF}.dir_root.o
	for f in $FILE_LIST; do
		tmp_name=$(echo $f | sed 's%/%__%g')
		cat ${TMP_PREF}.${tmp_name}.o
	done
}

main
