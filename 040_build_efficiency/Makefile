TARGET=040_build_efficiency.iso
TOOLS_PATH=../tools
EMU_YABAUSE=yabause -a -nb -i
EMU=$(EMU_YABAUSE)

all: $(TARGET)

$(TARGET): 0.BIN
	./iso9660.sh $< >$@

0.BIN: sin_coeff_table.dat cos_coeff_table.dat
	src/main.sh >$@

sin_coeff_table.dat:
	$(TOOLS_PATH)/dump_sin_coeff_table.sh >$@

cos_coeff_table.dat:
	$(TOOLS_PATH)/dump_cos_coeff_table.sh >$@

run: $(TARGET)
	$(EMU) $<

clean:
	rm -f *~ *.o *.dat *.bin 0.BIN *.lst map.sh $(TARGET) src/*~	\
	src/*.o include/*~

clean_all: clean
	rm -f IP.BIN

.PHONY: run clean clean_all
