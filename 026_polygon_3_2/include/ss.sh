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
SS_VDP1_MODR_ADDR=05d00016

SS_VDP2_TVMD_ADDR=05f80000
SS_VDP2_TVSTAT_ADDR=05f80004
SS_VDP2_BGON_ADDR=05f80020
SS_VDP2_PRISA_ADDR=05f800f0
