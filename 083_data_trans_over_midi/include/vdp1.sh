if [ "${INCLUDE_VDP1_SH+is_defined}" ]; then
	return
fi
INCLUDE_VDP1_SH=true

. include/common.sh
. include/ss.sh

VDP1_JP_JUMP_NEXT=0
VDP1_JP_JUMP_ASSIGN=1
VDP1_JP_SKIP_ASSIGN=5

# VDP1 RAM
# - サイズ：4 Mbits = 512 KB = 524288 (0x0008 0000) bytes
# - 領域：0x05C0 0000 - 0x05C7 FFFF
# - メモリマップ：
#   | 05C0 0000 - 05C0 7FFF ( 32 KB) | コマンドテーブル
#   |                 -> 0000 - 005F | - 毎フレーム設定系
#   |                 -> 0060 - 235F | - コンソール用(32 bytes * 280 = 8960 (0x2300) bytes)
#   |                 -> 2360 - 7FFF | - その他
#   | 05C0 8000 - 05C7 EFFF (476 KB) | キャラクタパターンテーブル
#   |             -> 0 8000 - 1 0BFF | - コンソール領域
#   |             -> 1 0C00 - 7 EFFF | - その他
#   | 05C7 F000 - 05C7 FFFF (  4 KB) | カラールックアップテーブル&グーローシェーディングテーブル

VRAM_CT_BASE=$SS_VDP1_VRAM_ADDR
VRAM_CT_CON_BASE=$(calc16_8 "${SS_VDP1_VRAM_ADDR}+00060")
VRAM_CT_OTHER_BASE=$(calc16_8 "${SS_VDP1_VRAM_ADDR}+02360")
# 描画コマンドのCMDLINK設定用
# VDP1 RAM先頭(0x05C00000)からのオフセットを8で割った2バイトの値
VRAM_CT_OTHER_BASE_CMDLINK=$(calc16_4 "(${VRAM_CT_OTHER_BASE}-${SS_VDP1_VRAM_ADDR})/8")
VRAM_CPT_BASE=$(calc16_8 "${SS_VDP1_VRAM_ADDR}+08000")
VRAM_CPT_CON_BASE=$VRAM_CPT_BASE
VRAM_CPT_OTHER_BASE=$(calc16_8 "${SS_VDP1_VRAM_ADDR}+10C00")
VRAM_CPT_OTHER_BASE_CMDSRCA=$(calc16_4 "(${VRAM_CPT_OTHER_BASE}-${SS_VDP1_VRAM_ADDR})/8")
VRAM_CLT_BASE=$(calc16_8 "${SS_VDP1_VRAM_ADDR}+7F000")
# 描画コマンドのCMDCOLR設定用
# VDP1 RAM先頭(0x05C00000)からのオフセットを8で割った2バイトの値
VRAM_CLT_BASE_CMDCOLR=$(calc16_4 "(${VRAM_CLT_BASE}-${SS_VDP1_VRAM_ADDR})/8")

# コマンドテーブルの各コマンドのオフセット
VRAM_CT_OFS_CMDXA=0c

# システムクリッピング座標設定コマンドを標準出力へ出力する
vdp1_command_system_clipping_coordinates() {
	# CMDCTRL
	# 0b0000 0000 0000 1001
	# - JP(b14-12) = 0b000
	echo -en '\x00\x09'
	# CMDLINK
	echo -en '\x00\x00'
	# CMDPMOD
	echo -en '\x00\x00'
	# CMDCOLR
	echo -en '\x00\x00'
	# CMDSRCA
	echo -en '\x00\x00'
	# CMDSIZE
	echo -en '\x00\x00'
	# CMDXA
	echo -en '\x00\x00'
	# CMDYA
	echo -en '\x00\x00'
	# CMDXB
	echo -en '\x00\x00'
	# CMDYB
	echo -en '\x00\x00'
	# CMDXC
	echo -en '\x01\x3f'
	# CMDYC
	echo -en '\x00\xdf'
	# CMDXD
	echo -en '\x00\x00'
	# CMDYD
	echo -en '\x00\x00'
	# CMDGRDA
	echo -en '\x00\x00'
	# dummy
	echo -en '\x00\x00'
}

# ユーザクリッピング座標設定コマンドを標準出力へ出力する
vdp1_command_user_clipping_coordinates() {
	# CMDCTRL
	# 0b0000 0000 0000 1000
	# - JP(b14-12) = 0b000
	echo -en '\x00\x08'
	# CMDLINK
	echo -en '\x00\x00'
	# CMDPMOD
	echo -en '\x00\x00'
	# CMDCOLR
	echo -en '\x00\x00'
	# CMDSRCA
	echo -en '\x00\x00'
	# CMDSIZE
	echo -en '\x00\x00'
	# CMDXA
	echo -en '\x00\x00'
	# CMDYA
	echo -en '\x00\x00'
	# CMDXB
	echo -en '\x00\x00'
	# CMDYB
	echo -en '\x00\x00'
	# CMDXC
	echo -en '\x01\x3f'
	# CMDYC
	echo -en '\x00\xdf'
	# CMDXD
	echo -en '\x00\x00'
	# CMDYD
	echo -en '\x00\x00'
	# CMDGRDA
	echo -en '\x00\x00'
	# dummy
	echo -en '\x00\x00'
}

# 相対座標設定コマンドを標準出力へ出力する
vdp1_command_local_coordinates() {
	# CMDCTRL
	# 0b0000 0000 0000 1010
	# - JP(b14-12) = 0b000
	echo -en '\x00\x0a'
	# CMDLINK
	echo -en '\x00\x00'
	# CMDPMOD
	echo -en '\x00\x00'
	# CMDCOLR
	echo -en '\x00\x00'
	# CMDSRCA
	echo -en '\x00\x00'
	# CMDSIZE
	echo -en '\x00\x00'
	# CMDXA
	echo -en '\x00\x00'
	# CMDYA
	echo -en '\x00\x00'
	# CMDXB
	echo -en '\x00\x00'
	# CMDYB
	echo -en '\x00\x00'
	# CMDXC
	echo -en '\x00\x00'
	# CMDYC
	echo -en '\x00\x00'
	# CMDXD
	echo -en '\x00\x00'
	# CMDYD
	echo -en '\x00\x00'
	# CMDGRDA
	echo -en '\x00\x00'
	# dummy
	echo -en '\x00\x00'
}

vdp1_command_polygon_draw() {
	local ax=$1
	local ay=$2
	local bx=$3
	local by=$4
	local cx=$5
	local cy=$6
	local dx=$7
	local dy=$8
	local col=$9

	# CMDCTRL
	# 0b0000 0000 0000 0100
	# - JP(b14-b12) = 0b000
	echo -en '\x00\x04'
	# CMDLINK
	echo -en '\x00\x00'
	# CMDPMOD
	# 0b0000 1000 1100 0000
	# - MON(b15) = 0 (VDP2の機能を使わない)
	# - Pclp(b11) = 1 (クリッピングが必要かどうかの座標計算無効)
	# - Clip(b10) = 0 (ユーザクリッピング座標に従わない)
	# - Cmod(b9) = 0 (Clip=0なので無効)
	# - Mesh(b8) = 0 (メッシュ無効)
	# - 色演算(b2-b0) = 0b000 (色演算は全て無効)
	echo -en '\x08\xc0'
	# CMDCOLR
	# RGB Color
	# - MSB(b15) = 1
	# - Blue(b14-b10) = 0x1f
	# - Green(b9-b5) = 0x1e
	# - Red(b4-b0) = 0x1f
	echo -en "\x$(echo $col | cut -c1-2)\x$(echo $col | cut -c3-4)"
	# CMDSRCA
	echo -en '\x00\x00'
	# CMDSIZE
	echo -en '\x00\x00'
	# CMDXA
	# 頂点AのX座標
	echo -en "\x$(echo $ax | cut -c1-2)\x$(echo $ax | cut -c3-4)"
	# CMDYA
	# 頂点AのY座標
	echo -en "\x$(echo $ay | cut -c1-2)\x$(echo $ay | cut -c3-4)"
	# CMDXB
	# 頂点BのX座標
	echo -en "\x$(echo $bx | cut -c1-2)\x$(echo $bx | cut -c3-4)"
	# CMDYB
	# 頂点BのY座標
	echo -en "\x$(echo $by | cut -c1-2)\x$(echo $by | cut -c3-4)"
	# CMDXC
	# 頂点CのX座標
	echo -en "\x$(echo $cx | cut -c1-2)\x$(echo $cx | cut -c3-4)"
	# CMDYC
	# 頂点CのY座標
	echo -en "\x$(echo $cy | cut -c1-2)\x$(echo $cy | cut -c3-4)"
	# CMDXD
	# 頂点DのX座標
	echo -en "\x$(echo $dx | cut -c1-2)\x$(echo $dx | cut -c3-4)"
	# CMDYD
	# 頂点DのY座標
	echo -en "\x$(echo $dy | cut -c1-2)\x$(echo $dy | cut -c3-4)"
	# CMDGRDA
	echo -en '\x00\x00'
	# dummy
	echo -en '\x00\x00'
}

vdp1_command_draw_end() {
	# CMDCTRL
	# 0b0000 0000 0000 0100
	# - END(b15) = 1
	echo -en '\x80\x00'
	# CMDLINK
	echo -en '\x00\x00'
	# CMDPMOD
	echo -en '\x00\x00'
	# CMDCOLR
	echo -en '\x00\x00'
	# CMDSRCA
	echo -en '\x00\x00'
	# CMDSIZE
	echo -en '\x00\x00'
	# CMDXA
	echo -en '\x00\x00'
	# CMDYA
	echo -en '\x00\x00'
	# CMDXB
	echo -en '\x00\x00'
	# CMDYB
	echo -en '\x00\x00'
	# CMDXC
	echo -en '\x00\x00'
	# CMDYC
	echo -en '\x00\x00'
	# CMDXD
	echo -en '\x00\x00'
	# CMDYD
	echo -en '\x00\x00'
	# CMDGRDA
	echo -en '\x00\x00'
	# dummy
	echo -en '\x00\x00'
}
