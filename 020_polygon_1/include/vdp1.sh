if [ "${INCLUDE_VDP1_SH+is_defined}" ]; then
	return
fi
INCLUDE_VDP1_SH=true

. include/ss.sh

vdp1_command_polygon_draw() {
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
	echo -en '\xff\xdb'
	# CMDSRCA
	echo -en '\x00\x00'
	# CMDSIZE
	echo -en '\x00\x00'
	# CMDXA
	# 頂点AのX座標 = 193(0xc1)
	echo -en '\x00\xc1'
	# CMDYA
	# 頂点AのY座標 = 20(0x14)
	echo -en '\x00\x14'
	# CMDXB
	# 頂点BのX座標 = 193(0xc1)
	echo -en '\x00\xc1'
	# CMDYB
	# 頂点BのY座標 = 204(0xcc)
	echo -en '\x00\xcc'
	# CMDXC
	# 頂点CのX座標 = 127(0x7f)
	echo -en '\x00\x7f'
	# CMDYC
	# 頂点CのY座標 = 204(0xcc)
	echo -en '\x00\xcc'
	# CMDXD
	# 頂点DのX座標 = 127(0x7f)
	echo -en '\x00\x7f'
	# CMDYD
	# 頂点DのY座標 = 20(0x14)
	echo -en '\x00\x14'
	# CMDGRDA
	echo -en '\x00\x00'
}
