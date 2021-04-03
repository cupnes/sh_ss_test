if [ "${RENDER_SH+is_defined}" ]; then
	return
fi
RENDER_SH=true

. include/common.sh
. include/sh2.sh
. include/ss.sh

# 指定された投影面座標(PRJx,PRJy)をゲームスクリーン座標(GSx,GSy)へ変換
# GSx = PRJx + (SCREEN_WIDTH / 2)
# GSy = (SCREEN_HEIGHT - 1) - PRJy
# 第1引数 - PRJx, GSx に使うレジスタ
# 第2引数 - PRJy, GSy に使うレジスタ
# work: r0  - 作業用
transform_to_gs_from_prj() {
	local reg_x=$1
	local reg_y=$2

	# GSx = PRJx + (SCREEN_WIDTH / 2)
	## r0へ(SCREEN_WIDTH / 2)をセット
	sh2_set_reg r0 $(calc16_2 "${SCREEN_WIDTH}/2")
	sh2_and_to_r0_from_val_byte ff
	## reg_xへr0を加算
	sh2_add_to_reg_from_reg $reg_x r0

	# GSy = (SCREEN_HEIGHT - 1) - PRJy
	## r0へ(SCREEN_HEIGHT - 1)をセット
	sh2_set_reg r0 $(calc16_2 "${SCREEN_HEIGHT}-1")
	sh2_and_to_r0_from_val_byte ff
	## r0 - reg_yをr0へセット
	sh2_sub_to_reg_from_reg r0 $reg_y
	## r0をreg_yへ保存
	sh2_copy_to_reg_from_reg $reg_y r0
}

# [メモリ渡し版]
# 指定された投影面座標(PRJx,PRJy)をゲームスクリーン座標(GSx,GSy)へ変換
# GSx = PRJx + (SCREEN_WIDTH / 2)
# GSy = (SCREEN_HEIGHT - 1) - PRJy
# r14 - 対象の投影面座標・ゲームスクリーン座標の領域の先頭アドレス
# in  : r14+0 - PRJx
#     : r14+2 - PRJy
# out : r14+4 - GSx
#     : r14+6 - GSy
# work: r0  - 作業用
#     : r1  - 作業用
#     : r14 - 作業の過程で加算されていく
transform_to_gs_from_prj_mem() {
	# GSx = PRJx + (SCREEN_WIDTH / 2)
	## r1へPRJxをロード
	sh2_copy_to_reg_from_ptr_word r1 r14
	## r0へ(SCREEN_WIDTH / 2)をセット
	sh2_set_reg r0 $(calc16_2 "${SCREEN_WIDTH}/2")
	sh2_and_to_r0_from_val_byte ff
	## r1へr0を加算
	sh2_add_to_reg_from_reg r1 r0
	## r1をGSxへ保存
	sh2_add_to_reg_from_val_byte r14 04
	sh2_copy_to_ptr_from_reg_word r14 r1

	# GSy = (SCREEN_HEIGHT - 1) - PRJy
	## r1へPRJyをロード
	sh2_add_to_reg_from_val_byte r14 $(two_comp_d 2)
	sh2_copy_to_reg_from_ptr_word r1 r14
	## r0へ(SCREEN_HEIGHT - 1)をセット
	sh2_set_reg r0 $(calc16_2 "${SCREEN_HEIGHT}-1")
	sh2_and_to_r0_from_val_byte ff
	## r0 - r1をr0へセット
	sh2_sub_to_reg_from_reg r0 r1
	## r0をGSyへ保存
	sh2_add_to_reg_from_val_byte r14 04
	sh2_copy_to_ptr_from_reg_word r14 r0
}
