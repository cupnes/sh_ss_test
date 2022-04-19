if [ "${INCLUDE_SS_SH+is_defined}" ]; then
	return
fi
INCLUDE_SS_SH=true

SCREEN_WIDTH=140	# 320
SCREEN_HEIGHT=e0	# 224

SS_VDP1_COMMAND_SIZE=20	# 32 bytes
SS_VDP1_VRAM_ADDR=05c00000
SS_VDP1_TVMR_ADDR=05d00000
SS_VDP1_FBCR_ADDR=05d00002
SS_VDP1_PTMR_ADDR=05d00004
SS_VDP1_EWDR_ADDR=05d00006
SS_VDP1_EWLR_ADDR=05d00008
SS_VDP1_EWRR_ADDR=05d0000a
SS_VDP1_ENDR_ADDR=05d0000c
SS_VDP1_EDSR_ADDR=05d00010
SS_VDP1_MODR_ADDR=05d00016

SS_VDP1_EDSR_BIT_CEF=02

SS_VDP2_TVMD_ADDR=05f80000
SS_VDP2_TVSTAT_ADDR=05f80004
SS_VDP2_BGON_ADDR=05f80020
SS_VDP2_PRISA_ADDR=05f800f0

SS_SMPC_IREG0_ADDR=20100001
SS_SMPC_IREG1_ADDR=20100003
SS_SMPC_IREG2_ADDR=20100005
SS_SMPC_COMREG_ADDR=2010001f
SS_SMPC_OREG0_ADDR=20100021
SS_SMPC_OREG1_ADDR=20100023
SS_SMPC_OREG2_ADDR=20100025
SS_SMPC_OREG3_ADDR=20100027
SS_SMPC_SF_ADDR=20100063

SS_SMPC_COMREG_SNDON=06
SS_SMPC_COMREG_SNDOFF=07
SS_SMPC_COMREG_INTBACK=10
SS_SMPC_PAD_STATE_BIT_RIGHT=80
SS_SMPC_PAD_STATE_BIT_LEFT=40
SS_SMPC_PAD_STATE_BIT_DOWN=20
SS_SMPC_PAD_STATE_BIT_UP=10
SS_SMPC_PAD_STATE_BIT_START=08
SS_SMPC_PAD_STATE_BIT_A=04
SS_SMPC_PAD_STATE_BIT_C=02
SS_SMPC_PAD_STATE_BIT_B=01
SS_SMPC_PAD_STATE_BIT_R=80
SS_SMPC_PAD_STATE_BIT_X=40
SS_SMPC_PAD_STATE_BIT_Y=20
SS_SMPC_PAD_STATE_BIT_Z=10
SS_SMPC_PAD_STATE_BIT_L=08

SS_CD_SECTSIZE_ID_2048=0

# スロット別制御レジスタのワード単位のオフセット
SS_SND_SLOT_OFS_SA_15_0=02

SS_SND_MIOSTAT_BIT_MIEMP=01
SS_SND_MIOSTAT_BIT_MOFULL=10
SS_SND_MCIPDH_BIT_MO=02
SS_SND_MCIPDL_BIT_MI=08

# キャッシュスルーアドレス
SS_CT_CS2_DTR_ADDR=25818000
SS_CT_CS2_HIRQ_ADDR=25890008
SS_CT_CS2_CR1_ADDR=25890018
SS_CT_CS2_CR2_ADDR=2589001C
SS_CT_CS2_CR3_ADDR=25890020
SS_CT_CS2_CR4_ADDR=25890024
SS_CT_SND_CPU_RIISP_ADDR=25A00000
SS_CT_SND_CPU_RIPC_ADDR=25A00004
SS_CT_SND_CPU_AFTER_VEC_ADDR=25A00400
SS_CT_SND_SLOTCTR_S0_ADDR=25B00000
SS_CT_SND_SLOTCTR_S1_ADDR=25B00020
SS_CT_SND_COMMONCTR_ADDR=25B00400
SS_CT_SND_MIOSTAT_ADDR=25B00404
SS_CT_SND_MIBUF_ADDR=25B00405
SS_CT_SND_MOBUF_ADDR=25B00407
SS_CT_SND_SCIEB_ADDR=25B0041E
SS_CT_SND_SCIRE_ADDR=25B00422
SS_CT_SND_MCIPDH_ADDR=25B0042C
SS_CT_SND_MCIPDL_ADDR=25B0042D

SS_CS2_HIRQ_BIT_CMOK=0001
SS_CS2_HIRQ_BIT_EFLS=0200
