NAME=040_set_clear_color
TARGETS=$(NAME).iso $(NAME).cue
TOOLS_PATH=../tools
EMU_YABAUSE=yabause -a -nb -i
EMU_MEDNAFEN=mednafen -psx.dbg_level 0 -video.fs 0 -cheats 1

all: $(TARGETS)

$(NAME).cue: $(NAME).iso
	$(TOOLS_PATH)/make_cue.sh $< >$@

$(NAME).iso: 0.BIN
	./iso9660.sh $< >$@

0.BIN: src/main.sh src/vars.o src/vars_map.sh src/funcs.o src/funcs_map.sh
	./$< >$@

src/vars.o src/vars_map.sh: src/vars.sh
	src/vars.sh >src/vars.o

src/funcs.o src/funcs_map.sh: src/funcs.sh src/vars_map.sh
	src/funcs.sh >src/funcs.o

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
