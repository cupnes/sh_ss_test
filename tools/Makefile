CFLAGS = -Wall -Wextra

all: conv_img

conv_img: conv_img.c
	gcc $(CFLAGS) -o $@ $^

clean:
	rm -f *~ conv_img

.PHONY: clean
