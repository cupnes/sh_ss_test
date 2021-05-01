NAME=040_build_efficiency
TARGETs=$(NAME).iso $(NAME).cue
TOOLS_PATH=../tools
RUN_YABAUSE=yabause -a -i $(NAME).iso -nb
RUN_MEDNAFEN=mednafen -psx.dbg_level 0 -video.fs 0 -cheats 1 $(NAME).cue
RUN_CMD=$(RUN_MEDNAFEN)

all: $(TARGETs)

$(NAME).cue: $(NAME).iso
	$(TOOLS_PATH)/make_cue.sh $< >$@

$(NAME).iso: 0.BIN
	./iso9660.sh $< >$@

0.BIN: sin_coeff_table.dat cos_coeff_table.dat
	src/main.sh >$@

sin_coeff_table.dat:
	$(TOOLS_PATH)/dump_sin_coeff_table.sh >$@

cos_coeff_table.dat:
	$(TOOLS_PATH)/dump_cos_coeff_table.sh >$@

run: $(TARGETs)
	$(RUN_CMD)

clean:
	rm -f *~ *.o *.dat *.bin 0.BIN *.lst map.sh $(TARGETs) src/*~	\
	src/*.o include/*~

clean_all: clean
	rm -f IP.BIN

.PHONY: run clean clean_all
