CFLAGS = -Wall -Wextra

all: conv_img dump_data_packets

conv_img: conv_img.c
	gcc $(CFLAGS) -o $@ $^

dump_data_packets: dump_data_packets.c
	gcc $(CFLAGS) -o $@ $^

clean:
	rm -f *~ conv_img dump_data_packets

.PHONY: clean
