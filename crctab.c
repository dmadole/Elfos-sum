#include <stdio.h>
#include <stdlib.h>
#include <string.h>


unsigned short Crc16Ccitt(char *bytes) {

    char *c, *s;
    unsigned short i, j, k;
    unsigned short crc, poly;
    unsigned short table[256];

    poly = 0x8408;
    for (i = 0; i < 256; i++) {
        k = i;
        for (j = 0; j < 8; j++) {
            k = (k >> 1) ^ ((k & 1) ? poly : 0);
        }
        table[i] = k;
    }

    crc = 0x0000;
    for (i = 0; i < strlen(bytes); ++i) {
        j = (crc & 0xff) ^ bytes[i];
        crc = (crc >> 8) ^ table[j];
    } 

    for (i = 0; i < 32; i++) {
        printf("%-9s  db    ", i ? "" : "crctablo:");
        for (j = 0; j < 8; j++) {
            printf("0%02xh%s", table[j + i * 8] & 0xff, j < 7 ? ", " : "");
        }
        printf("\n");
    }

    printf("\n");

    for (i = 0; i < 32; i++) {
        printf("%-9s  db    ", i ? "" : "crctabhi:");
        for (j = 0; j < 8; j++) {
            printf("0%02xh%s", table[j + i * 8] >> 8, j < 7 ? ", " : "");
        }
        printf("\n");
    }

    return crc;
}

int main(int argc, char **argv) {

    char * data = "CRC16TESTDATA";
    unsigned short result = Crc16Ccitt(data);

    if (result != 0x3416) {
        fprintf(stderr, "result = 0x%04x, should be 0x3416\n", result);
        exit(1);
    }

    exit(0);
}

