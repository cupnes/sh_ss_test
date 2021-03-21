TARGET=036_yaw_rotation.iso

all: $(TARGET)

$(TARGET): 0.BIN
	./iso9660.sh $< >$@

0.BIN:
	src/main.sh >$@

run: $(TARGET)
	yabause -a -i $<

clean:
	rm -f *~ *.o *.bin 0.BIN *.lst map.sh $(TARGET) src/*~ src/*.o include/*~

clean_all: clean
	rm -f IP.BIN

.PHONY: run clean clean_all
