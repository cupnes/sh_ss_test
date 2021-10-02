if [ "${SRC_VDP_SH+is_defined}" ]; then
	return
fi
SRC_VDP_SH=true

. include/sh2.sh
. include/lib.sh

# VDP1/2の初期化
# work: r0* - 作業用
#     : r1* - 作業用
#     : r3* - 作業用
#     : r4* - 作業用
# ※ *が付いているレジスタはこの関数で書き換えられる
vdp_init() {
	# VDP2のシステムレジスタ設定
	## TVMD
	## - DISP(b15) = 1
	## - BDCLMD(b8) = 1
	## - LSMD(b7-b6) = 0b00
	## - VRESO(b5-b4) = 0b00
	## - HRESO(b2-b0) = 0b000
	copy_to_reg_from_val_long r4 $SS_VDP2_TVMD_ADDR
	sh2_set_reg r0 81
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r4 r0
	## BGON
	sh2_add_to_reg_from_val_byte r4 20
	sh2_set_reg r0 00
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r4 r0
	## PRISA
	sh2_add_to_reg_from_val_byte r4 68
	sh2_add_to_reg_from_val_byte r4 68
	sh2_set_reg r0 06
	sh2_copy_to_ptr_from_reg_word r4 r0

	# VDP1のシステムレジスタ設定
	## TVMR
	## - VBE(b3) = 0
	## - TVM(b2-b0) = 0b000
	copy_to_reg_from_val_long r3 $SS_VDP1_TVMR_ADDR
	sh2_set_reg r0 00
	sh2_copy_to_ptr_from_reg_word r3 r0
	## FBCR(TVMRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_copy_to_ptr_from_reg_word r3 r0
	## PTMR(FBCRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	## PTM(b1-b0) = 0b10
	sh2_set_reg r0 02
	sh2_copy_to_ptr_from_reg_word r3 r0
	## EWDR(PTMRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_set_reg r0 80
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r3 r0
	## EWLR(EWDRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_set_reg r0 00
	sh2_shift_left_logical_8 r0
	sh2_copy_to_ptr_from_reg_word r3 r0
	## EWRR(EWLRの2バイト先)
	sh2_add_to_reg_from_val_byte r3 02
	sh2_set_reg r0 50
	sh2_shift_left_logical_8 r0
	sh2_or_to_r0_from_val_byte df
	sh2_copy_to_ptr_from_reg_word r3 r0
}

# 指定されたアドレスのVDPCOMを指定されたジャンプ形式とCMDLINKへ変更する
# in  : r1 - 変更するVDPCOMのアドレス
#     : r2 - ビット31-16：CMDLINK
#            ビット02-00：ジャンプ形式(JP)
# work: r0 - 作業用
# work: r3 - 作業用
f_update_vdp1_command_jump_mode() {
	# 変更が発生するレジスタを退避
	## r0
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r0
	## r1
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r1
	## r3
	sh2_add_to_reg_from_val_byte r15 $(two_comp_d 4)
	sh2_copy_to_ptr_from_reg_long r15 r3

	# CMDCTRLのJPを変更
	## r2を4ビット左シフトした値をr3へ設定
	sh2_copy_to_reg_from_reg r3 r2
	sh2_shift_left_logical_2 r3
	sh2_shift_left_logical_2 r3
	## CMDCTRLのビット15-8をr0へ取得
	sh2_copy_to_reg_from_ptr_byte r0 r1
	## r0のビット6-4(JP)をクリア
	sh2_and_to_r0_from_val_byte 8f
	## r0 = r0 | r3
	sh2_or_to_reg_from_reg r0 r3
	## r0をCMDCTRLのビット15-8へ設定
	sh2_copy_to_ptr_from_reg_byte r1 r0

	# CMDLINKを変更
	## r1が指すアドレスを2バイト進める
	## (CMDLINKを指すようにする)
	sh2_add_to_reg_from_val_byte r1 02
	## r2を16ビット右シフトした値をr0へ設定
	sh2_copy_to_reg_from_reg r0 r2
	sh2_shift_right_logical_16 r0
	## r0をr1が指す先へ設定
	sh2_copy_to_ptr_from_reg_word r1 r0

	# 退避したレジスタを復帰しreturn
	## r3
	sh2_copy_to_reg_from_ptr_long r3 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r1
	sh2_copy_to_reg_from_ptr_long r1 r15
	sh2_add_to_reg_from_val_byte r15 04
	## r0
	sh2_copy_to_reg_from_ptr_long r0 r15
	sh2_add_to_reg_from_val_byte r15 04
	## return
	sh2_return_after_next_inst
	sh2_nop
}
