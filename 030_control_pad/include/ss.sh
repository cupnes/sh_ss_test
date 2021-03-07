if [ "${INCLUDE_SS_SH+is_defined}" ]; then
	return
fi
INCLUDE_SS_SH=true

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

SS_SMPC_COMREG_INTBACK=10
SS_SMPC_PAD_STATE_BIT_RIGHT=80
