if [ "${INCLUDE_VDP1_SH+is_defined}" ]; then
	return
fi
INCLUDE_VDP1_SH=true

. include/ss.sh

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
	# 頂点AのX座標 = 49(0x31)
	echo -en '\x00\x31'
	# CMDYA
	# 頂点AのY座標 = 9(0x9)
	echo -en '\x00\x09'
	# CMDXB
	# 頂点BのX座標 = 270(0x10e)
	echo -en '\x01\x0e'
	# CMDYB
	# 頂点BのY座標 = 9(0x9)
	echo -en '\x00\x09'
	# CMDXC
	# 頂点CのX座標 = 270(0x10e)
	echo -en '\x01\x0e'
	# CMDYC
	# 頂点CのY座標 = 230(0xe6)
	echo -en '\x00\xe6'
	# CMDXD
	# 頂点DのX座標 = 49(0x31)
	echo -en '\x00\x31'
	# CMDYD
	# 頂点DのY座標 = 230(0xe6)
	echo -en '\x00\xe6'
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
