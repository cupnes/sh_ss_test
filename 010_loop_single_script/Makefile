TARGET=010_loop_single_script.iso

all: $(TARGET)

$(TARGET): build.sh
	./build.sh >$@

run: $(TARGET)
	yabause -a -i $<

clean:
	rm -f *~ *.o *.bin *.BIN $(TARGET)

.PHONY: run clean
