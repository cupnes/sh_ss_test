if [ "${INCLUDE_CON_SH+is_defined}" ]; then
	return
fi
INCLUDE_CON_SH=true

CON_FONT_SIZE=80	# 128バイト
CON_FONT_WIDTH=10	# 16px
CON_FONT_HEIGHT=10	# 16px

# コンソール領域
## 座標
CON_AREA_X=00
CON_AREA_Y=08
## 幅/高さ
CON_AREA_WIDTH_CH=14	# 20文字分
CON_AREA_HEIGHT_CH=0d	# 13文字分
CON_AREA_WIDTH_PX=$(four_digits $(calc16 "${CON_FONT_WIDTH}*${CON_AREA_WIDTH_CH}"))
CON_AREA_HEIGHT_PX=$(four_digits $(calc16 "${CON_FONT_HEIGHT}*${CON_AREA_HEIGHT_CH}"))
CON_AREA_LAST_CH_OF_LINE_X=$(four_digits $(calc16 "${CON_AREA_X}+${CON_AREA_WIDTH_PX}-${CON_FONT_WIDTH}"))
## 座標+幅/高さ
CON_OUTSIDE_X=$(four_digits $(calc16 "${CON_AREA_X}+${CON_AREA_WIDTH_PX}"))
CON_OUTSIDE_Y=$(four_digits $(calc16 "${CON_AREA_Y}+${CON_AREA_HEIGHT_PX}"))
