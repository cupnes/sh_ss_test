TARGET=022_polygon_1_disable_all_screen.iso

all: $(TARGET)

$(TARGET): 0.BIN
	./iso9660.sh $< >$@

0.BIN:
	src/main.sh >$@

run: $(TARGET)
	yabause -a -i $<

clean:
	rm -f *~ *.o *.bin *.BIN *.lst $(TARGET) src/*~ src/*.o include/*~

.PHONY: run clean
