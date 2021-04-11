/*
convert src_image.png -depth 5 depth5.ppm
tail -n +4 depth5.ppm >color_val.dat
のように前処理したcolor_val.datを標準入力に与える
*/

#include <stdio.h>

#define DST_COLOR_RANGE 32

enum COLOR_STATE {
	RED,
	GREEN,
	BLUE
};

int main(void)
{
	enum COLOR_STATE state = RED;
	union {
		unsigned short word;
		unsigned char byte[2];
	} out_color;
	while (1) {
		int color = getchar();
		if (color == EOF) {
			break;
		}
		switch (state) {
		case RED:
			out_color.word = 0x8000 | color;
			state = GREEN;
			break;
		case GREEN:
			out_color.word |= color << 5;
			state = BLUE;
			break;
		case BLUE:
			out_color.word |= color << 10;
			fwrite(&out_color.byte[1], 1, 1, stdout);
			fwrite(&out_color.byte[0], 1, 1, stdout);
			state = RED;
			break;
		}
	}

	return 0;
}
