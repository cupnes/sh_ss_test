TARGET=039_rail_scroll_4slideshow.iso
TOOLS_PATH=../tools

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
	yabause -a -i $<

clean:
	rm -f *~ *.o *.dat *.bin 0.BIN *.lst map.sh $(TARGET) src/*~	\
	src/*.o include/*~

clean_all: clean
	rm -f IP.BIN

.PHONY: run clean clean_all
