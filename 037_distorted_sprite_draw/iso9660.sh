#!/bin/bash

# set -uex
set -ue

. include/common.sh

SECTOR_BYTES=2048

usage() {
	echo "$0 - Outputs an ISO image containing the specified BIN file to the standard output." 1>&2
	echo 1>&2
	echo 'Usage:' 1>&2
	echo -e "\t$0 BIN_FILE" 1>&2
	echo -e "\t$0 -h" 1>&2
}

if [ $# -ne 1 ]; then
	usage
	exit 1
fi
if [ "$1" = '-h' ]; then
	usage
	exit 0
fi
BIN_FILE="$1"

# BIN_FILEは1セクタ(2048バイト)以内という制限

# BIN_FILEのバイト数
BIN_FILE_SIZE=$(stat -c '%s' $BIN_FILE)
## 8桁の16進数
BIN_FILE_SIZE_HEX="$(extend_digit $(to16 $BIN_FILE_SIZE) 8)"
## セクタ数
BIN_FILE_NUM_SECTORS=$(((BIN_FILE_SIZE + SECTOR_BYTES - 1) / SECTOR_BYTES))

# ISOファイルサイズをセクタ数で指定する(Both Endian)
# BIN_FILEが1セクタなら合計22(0x16)セクタ
# セクタ数 = 21 + $BIN_FILE_SIZE / $SECTOR_BYTES
ISO_FILE_NUM_SECTORS=$((21 + BIN_FILE_NUM_SECTORS))
## 8桁の16進数
ISO_FILE_NUM_SECTORS_HEX="$(extend_digit $(to16 $ISO_FILE_NUM_SECTORS) 8)"

# Initial Program(IP)
# (ISO9660 Reserved Field)
gen_ip() {
	if [ ! -f IP.BIN ]; then
		wget https://github.com/johannes-fetz/joengine/raw/master/Compiler/COMMON/IP.BIN
	fi
	cat IP.BIN

	local ip_bin_sz=$(stat -c '%s' IP.BIN)
	local padding_sz=$(((SECTOR_BYTES * 16) - ip_bin_sz))
	dd if=/dev/zero bs=1 count=$padding_sz
}

# All Zero Sector
gen_blank_sector() {
	dd if=/dev/zero bs=1 count=$SECTOR_BYTES
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
	dd if=/dev/zero bs=1 count=8
	# 80(0x50) - 87(0x57) Volume Space Size
	# ISOファイルサイズをセクタ数で指定する
	echo_4bytes "$ISO_FILE_NUM_SECTORS_HEX"
	echo_4bytes_be "$ISO_FILE_NUM_SECTORS_HEX"
	# 88(0x58) - 119(0x77) Escape Sequences
	dd if=/dev/zero bs=1 count=$((119 - 88 + 1))
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
	## 0x800 = 2048 bytes
	echo -en '\x00\x08\x00\x00\x00\x00\x08\x00'
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
	dd if=/dev/zero bs=1 count=653
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
	dd if=/dev/zero bs=1 count=$((2047 - 7 + 1))
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
	dd if=/dev/zero bs=1 count=$((SECTOR_BYTES - sz))
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
	dd if=/dev/zero bs=1 count=$((SECTOR_BYTES - sz))
}

gen_dir_root() {
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

		# Length of Directory Record(LEN_DR) (size 1)
		# 0x28 = 40
		echo -en '\x28'
		# Extended Attribute Record Length (size 1)
		echo -en '\x00'
		# Location of Extent (size 8)
		# 21(0x15) セクタ目
		echo -en '\x15\x00\x00\x00\x00\x00\x00\x15'
		# Data Length (size 8)
		echo_4bytes "$BIN_FILE_SIZE_HEX"
		echo_4bytes_be "$BIN_FILE_SIZE_HEX"
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
		echo -en '\x07'
		# File Identifier (size LEN_FI)
		echo -n '0.BIN;1'
		# Padding Field(レコードサイズを偶数にするためのパディング)
		# System Use (size LEN_DRの残り)
	) >dir_root.o
	cat dir_root.o

	# セクタサイズにするためのパディング
	local sz=$(stat -c '%s' dir_root.o)
	dd if=/dev/zero bs=1 count=$((SECTOR_BYTES - sz))
}

gen_file() {
	local f=$1
	local sz=$(stat -c '%s' $f)

	cat $f

	# セクタサイズにするためのパディング
	dd if=/dev/zero bs=1 count=$((SECTOR_BYTES - (sz % SECTOR_BYTES)))
}

main() {
	# sector 0(0x0) - 15(0xf)
	gen_ip
	# sector 16(0x10)
	gen_pvd
	# sector 17(0x11)
	gen_vdt
	# sector 18(0x12)
	gen_lpath_tbl
	# sector 19(0x13)
	gen_mpath_tbl
	# sector 20(0x14)
	gen_dir_root
	# sector 21(0x15)
	gen_file $BIN_FILE

	# total 22(0x16) sectors
	# 22 * 2048 = 45056(0xb000) bytes
}

main
