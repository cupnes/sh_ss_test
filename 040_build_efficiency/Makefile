NAME=040_build_efficiency
TARGETS=$(NAME).iso $(NAME).cue
OBJS=src/f_div_reg_by_reg_long_sign.o
TOOLS_PATH=../tools
EMU_YABAUSE=yabause -a -nb -i
EMU_MEDNAFEN=mednafen -psx.dbg_level 0 -video.fs 0 -cheats 1

all: $(TARGETS)

$(NAME).cue: $(NAME).iso
	$(TOOLS_PATH)/make_cue.sh $< >$@

$(NAME).iso: 0.BIN
	./iso9660.sh $< >$@

0.BIN: src/main.sh sin_coeff_table.dat cos_coeff_table.dat $(OBJS)
	./$< >$@

sin_coeff_table.dat:
	$(TOOLS_PATH)/dump_sin_coeff_table.sh >$@

cos_coeff_table.dat:
	$(TOOLS_PATH)/dump_cos_coeff_table.sh >$@

%.o: %.sh
	./$< >$@

run_yabause: $(NAME).iso
	$(EMU_YABAUSE) $<

run_mednafen: $(NAME).cue
	$(EMU_MEDNAFEN) $<

run: run_yabause

clean:
	rm -f *~ *.o *.dat *.bin 0.BIN *.lst map.sh $(TARGETS) src/*~	\
	src/*.o include/*~

clean_all: clean
	rm -f IP.BIN

.PHONY: run_yabause run_mednafen run clean clean_all
