#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Formata como um disquete de 1.44MB.

#define DISK_SIZE (1440 * 1024)
#define SECTOR_SIZE 512




// Rever se está correto o cálculo de deslocamento.

void set_fat_entry(unsigned char *disk, int cluster, int value) {
	
    int fat_offset = 1 * SECTOR_SIZE;
    int idx = fat_offset + (3 * cluster) / 2;

    if (cluster % 2 == 0) {
        disk[idx] = (unsigned char)(value & 0xff);
        disk[idx + 1] = (unsigned char)((disk[idx + 1] & 0xf0) | ((value >> 8) & 0x0f));
    } else {
        disk[idx] = (unsigned char)((disk[idx] & 0x0f) | ((value << 4) & 0xf0));
        disk[idx + 1] = (unsigned char)((value >> 4) & 0xff);
    }
    
}




int main(int argc, char *argv[]) {
    
	const char *bootloader_path;
    
	const char *testcode_path;
    
	const char *output_path = "bootloader.img";
    
	unsigned char *disk;
    
    FILE *f;
    
	int i;
    
	long size_read;
    
	int root_dir_offset, data_offset;

    if (argc < 3) {
        printf("Uso: %s <bootloader.bin> <testcode.bin> <output.img>\n", argv[0]);
        return 1;
    }

    bootloader_path = argv[1];
    testcode_path = argv[2];
    
    if (argc > 3) output_path = argv[3];

    disk = (unsigned char *)calloc(DISK_SIZE, 1);
    
    if (!disk) {
        perror("Erro ao alocar memoria para o disco");
        return 1;
    }

    f = fopen(bootloader_path, "rb");
    
    if (f) {
        size_read = fread(disk, 1, DISK_SIZE, f);
        fclose(f);
        memcpy(&disk[498], "TESTCODEBIN", 11);
    } else {
        printf("Bootloader nao encontrado em %s\n", bootloader_path);
    }

    disk[1 * SECTOR_SIZE] = 0xF0;
    disk[1 * SECTOR_SIZE + 1] = 0xFF;
    disk[1 * SECTOR_SIZE + 2] = 0xFF;

    for (i = 2; i < 11; i++) {
        set_fat_entry(disk, i, i + 1);
    }
    
	set_fat_entry(disk, 11, 0xFFF);
    
    root_dir_offset = 19 * SECTOR_SIZE;
    memcpy(&disk[root_dir_offset], "TESTCODEBIN", 11);
    disk[root_dir_offset + 11] = 0x20;
    disk[root_dir_offset + 26] = 0x02;
    disk[root_dir_offset + 27] = 0x00; 
    
    disk[root_dir_offset + 28] = 0x00;
    disk[root_dir_offset + 29] = 0x20;
    
    data_offset = 33 * SECTOR_SIZE;
    f = fopen(testcode_path, "rb");
    if (f) {
        fread(&disk[data_offset], 1, DISK_SIZE - data_offset, f);
        fclose(f);
    } else {
        printf("Codigo de teste nao encontrado em %s\n", testcode_path);
    }
    
    f = fopen(output_path, "wb");
    if (f) {
        fwrite(disk, 1, DISK_SIZE, f);
        fclose(f);
        printf("Imagem '%s' de disco gerada com sucesso!\n", output_path);
    } else {
        perror("Erro ao criar a imagem de disco.");
    }

    free(disk);
    
    return 0;
    
}
