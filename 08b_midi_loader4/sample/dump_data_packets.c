#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

#define BULK_UNIT	7

int target_file;
int data_packet_file;
unsigned int target_file_sz;
unsigned int checksum = 0;

void usage(const char *prog_name)
{
	printf("Usage: %s TARGET_FILE DATA_PACKET_FILE\n", prog_name);
}

int write_to_data_packet(const unsigned char data)
{
	ssize_t wrote_bytes;
	do {
		wrote_bytes = write(data_packet_file, &data, 1);
		if (wrote_bytes == -1) {
			perror("write");
			return -1;
		}
	} while (wrote_bytes == 0);
	return 0;
}

int read_from_target(unsigned char *data)
{
	ssize_t read_bytes;
	do {
		read_bytes = read(target_file, data, 1);
		if (read_bytes == -1) {
			perror("read");
			return -1;
		}
	} while (read_bytes == 0);
	return 0;
}

int bulk_transfer(void)
{
	unsigned int bulk_times = target_file_sz / BULK_UNIT;

	if (bulk_times == 0) {
		return 0;
	}

	const unsigned char bulk_status_byte = 0x90;
	if (write_to_data_packet(bulk_status_byte) == -1) {
		fprintf(stderr,
			"Error: Failed to write the bulk status byte(0x%02x) to the data packet file.\n",
			bulk_status_byte);
		return -1;
	}

	for (; bulk_times > 0; bulk_times--) {
		unsigned char supp_byte = 0;
		unsigned char data_byte[BULK_UNIT];
		unsigned char i;
		for (i = 0; i < BULK_UNIT; i++) {
			unsigned char orig_byte;
			if (read_from_target(&orig_byte) == -1) {
				fprintf(stderr,
					"Error: Failed to read data from the target file (bulk).\n");
				return -1;
			}
			supp_byte <<= 1;
			supp_byte |= (orig_byte & 0x80) >> 7;
			data_byte[i] = orig_byte & 0x7f;
			checksum += orig_byte;
		}
		if (write_to_data_packet(supp_byte) == -1) {
			fprintf(stderr,
				"Error: Failed to write the supp byte(0x%02x) to the data packet file (bulk).\n",
				supp_byte);
			return -1;
		}
		for (i = 0; i < BULK_UNIT; i++) {
			if (write_to_data_packet(data_byte[i]) == -1) {
				fprintf(stderr,
					"Error: Failed to write data[%d](0x%02x) to the data packet file (bulk).\n",
					i, data_byte[i]);
				return -1;
			}
		}
	}

	return 0;
}

int remain_transfer(void)
{
	unsigned char remain_bytes = target_file_sz % BULK_UNIT;

	if (remain_bytes == 0) {
		return 0;
	}

	const unsigned char remain_status_byte = 0x90 | remain_bytes;
	if (write_to_data_packet(remain_status_byte) == -1) {
		fprintf(stderr,
			"Error: Failed to write the remain status byte(0x%02x) to the data packet file.\n",
			remain_status_byte);
		return -1;
	}

	unsigned char supp_byte = 0;
	unsigned char data_byte[BULK_UNIT - 1];
	unsigned char i;
	for (i = 0; i < remain_bytes; i++) {
		unsigned char orig_byte;
		if (read_from_target(&orig_byte) == -1) {
			fprintf(stderr,
				"Error: Failed to read data from the target file (remain).\n");
			return -1;
		}
		supp_byte |= (orig_byte & 0x80) >> 7;
		supp_byte <<= 1;
		data_byte[i] = orig_byte & 0x7f;
		checksum += orig_byte;
	}
	unsigned char remain_bits = BULK_UNIT - remain_bytes;
	supp_byte <<= remain_bits;
	if (write_to_data_packet(supp_byte) == -1) {
		fprintf(stderr,
			"Error: Failed to write the supp byte(0x%02x) to the data packet file (remain).\n",
			supp_byte);
		return -1;
	}
	for (i = 0; i < remain_bytes; i++) {
		if (write_to_data_packet(data_byte[i]) == -1) {
			fprintf(stderr,
				"Error: Failed to write data[%d](0x%02x) to the data packet file (remain).\n",
				i, data_byte[i]);
			return -1;
		}
	}
	if ((remain_bytes % 2) == 0) {
		if (write_to_data_packet(0) == -1) {
			fprintf(stderr,
				"Error: Failed to write the pad byte to the data packet file.\n");
			return -1;
		}
	}

	return 0;
}

int dump_checksum(const char *pkt_file_name)
{
	char *sum_file_name = malloc(strlen(pkt_file_name) + 4);
	if (sum_file_name == NULL) {
		perror("malloc");
		exit(EXIT_FAILURE);
	}

	if (sprintf(sum_file_name, "%s.sum", pkt_file_name) < 0) {
		perror("sprintf");
		free(sum_file_name);
		exit(EXIT_FAILURE);
	}

	FILE *sum_file = fopen(sum_file_name, "w");
	if (sum_file == NULL) {
		perror("fopen");
		free(sum_file_name);
		exit(EXIT_FAILURE);
	}
	free(sum_file_name);

	if (fprintf(sum_file, "%X\n", checksum) < 0) {
		perror("fprintf");
		fclose(sum_file);
		exit(EXIT_FAILURE);
	}

	fclose(sum_file);
	return 0;
}

int main(int argc, char *argv[])
{
	if (argc != 3) {
		usage(argv[0]);
		exit(EXIT_FAILURE);
	}

	target_file = open(argv[1], O_RDONLY);
	if (target_file == -1) {
		perror("open(target_file)");
		exit(EXIT_FAILURE);
	}
	struct stat sb;
	if (stat(argv[1], &sb) == -1) {
		perror("stat");
		close(target_file);
		exit(EXIT_FAILURE);
	}
	target_file_sz = sb.st_size;

	data_packet_file = creat(argv[2],
				 S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
	if (data_packet_file == -1) {
		perror("open(data_packet_file)");
		close(target_file);
		exit(EXIT_FAILURE);
	}

	if (bulk_transfer() == -1) {
		close(data_packet_file);
		close(target_file);
		exit(EXIT_FAILURE);
	}

	if (remain_transfer() == -1) {
		close(data_packet_file);
		close(target_file);
		exit(EXIT_FAILURE);
	}

	close(data_packet_file);
	close(target_file);

	if (dump_checksum(argv[2]) == -1) {
		exit(EXIT_FAILURE);
	}

	return 0;
}
