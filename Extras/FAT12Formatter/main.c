#include <stdio.h>
#include <stdlib.h>
#include <string.h>


// Define o tamanho da imagem como 1,44 MB (disquete).
#define DISK_SIZE (1440 * 1024)

// Define o tamanho de um setor de disco.
#define SECTOR_SIZE 512


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


/*
 
 Esta função cria a imagem de disco, formatada como FAT-12.
 
*/
int create_fat12_disk_image(const char *bootloader_path, const char *testcode_path, 
const char *output_path) {
	
	// Reserva um buffer do tamanho total do disco (1.44 MB). O calloc limpa a
	// memória com zeros, o que é essencial para um sistema de arquivos.
	
	unsigned char *disk = (unsigned char *)calloc(DISK_SIZE, 1);
    
	if (!disk) return 1;
	
	FILE *file;
	
    file = fopen(bootloader_path, "rb");
    
    if (file) {
    	
    	// Copia o binário do bootloader para a área do setor MBR no buffer da
		// imagem de disco.
    		
        fread(disk, 1, SECTOR_SIZE, file);
        
        fclose(file);
        
        // Escreve o nome do programa de teste dentro da área reservada no setor
		// MBR.
		//
		// No código-fonte do bootloader, localize esta linha (linha 427):
		//
		//     FileName times FilenameSize db 0x32
        //
        // Estes 11 bytes foram reservados pelo autor para que a ferramenta que
		// for criar a imagem de disco possa gravar o nome do programa de teste
		// nela. Em FAT-12 o nome do arquivo sempre terá 11 bytes. Os 8 primeiros
		// bytes são o nome e os 3 últimos a extensão do arquivo (no exemplo abaixo, 
		// TESTCODE.BIN).
        //
        // Analizando o arquivo da imagem de disco, podemos localizar o nome do,
		// arquivo nos offsets de 498 até 508, conforme destacado abaixo:
        //
		//        EB 3C 90 6D 6B 66 73 2E 66 61 74 00 02 01 01 00 
		//        02 E0 00 40 0B F0 09 00 12 00 02 00 00 00 00 00 
		//        00 00 00 00 00 00 29 00 00 00 00 73 69 62 6F 6C 
		//        6F 20 20 20 20 20 46 41 54 31 32 20 20 20 FA FC 
		//        B8 C0 07 8E D8 31 F6 B8 60 00 8E C0 31 FF B9 00 
		//        01 F3 A5 EA 58 00 60 00 8E D8 B8 80 00 8E D0 BC 
		//        00 10 89 E5 FB 88 16 D5 01 31 C0 A0 10 00 F7 26 
		//        16 00 03 06 0E 00 A2 E3 01 B8 20 00 F7 26 11 00 
		//        F7 36 0B 00 A3 E1 01 F7 26 0B 00 05 00 22 A3 DF
		//        01 A1 E1 01 31 DB 8A 1E E3 01 B9 00 22 E8 10 00
		//        A1 16 00 BB 01 00 8B 0E DF 01 E8 03 00 E8 D0 00 
		//        55 89 E5 83 EC 08 89 46 FE 89 5E FC 89 4E FA C7
		//        46 F8 05 00 30 E4 8A 16 D5 01 CD 13 8B 46 FC 31 
		//        D2 F7 36 18 00 42 88 D1 31 D2 F7 36 1A 00 88 D6 
		//        88 C5 8B 5E FA 8A 16 D5 01 B8 01 02 CD 13 73 0B 
		//        FF 4E F8 75 CF BE D6 01 E8 CD 00 FF 4E FE 74 10 
		//        FF 46 FC A1 0B 00 01 46 FA C7 46 F8 05 00 EB B4 
		//        83 C4 08 5D C3 55 89 E5 83 EC 04 89 46 FE 89 5E 
		//        FC 8B 46 FE 83 E8 02 31 C9 8A 0E 0D 00 F7 E1 02 
		//        06 E3 01 03 06 E1 01 89 C3 31 C0 A0 0D 00 8B 4E
		//        FC E8 6C FF 31 C0 A0 0D 00 8B 0E 0B 00 F7 E1 01 
		//        46 FC 8B 46 FE 89 C1 89 C2 D1 E8 01 C1 8B 1E DF 
		//        01 01 CB 8B 07 F7 C2 01 00 75 05 25 FF 0F EB 03
		//        C1 E8 04 89 46 FE 3D FF 0F 75 A6 83 C4 04 5D C3
		//        89 E5 83 EC 04 A1 11 00 89 46 FE C7 46 FC 00 22 
		//        8B 46 FC E8 0F 00 83 46 FC 20 FF 4E FE 75 F1 BE 
		//        E7 01 E8 23 00 B9 0B 00 89 C6 BF F2 01 F3 A6 74 
		//        01 C3 8B 44 0F BB C0 07 8E C3 31 DB E8 56 FF 8A 
		//        16 D5 01 EA 00 00 C0 07 B4 0E 31 DB AC CD 10 84 
		//        C0 75 F9 EB FE 00 49 4F 20 65 72 72 6F 72 00 00 
		//        00 00 00 00 00 00 00 4E 6F 74 20 66 6F 75 6E 64 
		//        3A 20 54 45 53 54 43 4F 44 45 42 49 4E 00 55 AA
		//             |--------------------------------|
		//
		// Estes valores na tabela CP437 correspondem a:
		//
		//     54 = 'T', 45 = 'E', 53 = 'S', 54 = 'T', 43 = 'C'
		//     4F = 'O', 44 = 'D', 45 = 'E', 42 = 'B', 49 = 'I'
		//     4E = 'N'
		//
		// Exatamente o texto: TESTCODEBIN.
			
	    memcpy(&disk[498], "TESTCODEBIN", 11);
        
    } else {
    	
    	printf("Erro: Arquivo de bootloader nao encontrado.");
    	
    	free(disk);
    	
    	return 1;
    	
	}

    // Inicialia a FAT (File Allocation Table). Os bytes abaixo marcam o início 
	// da tabela para indicar ao bootloader qual é o tipo de mídia e que os 
	// primeiros clusters estão ocupados/reservados.
	//
	// No FAT-12, a tabela começa no Setor 1 (logo após o setor MBR, que é o 
	// Setor 0). As entradas estão organizadas em grupos de 12 bits (1,5 bytes).
	// As duas primeiras entradas da tabela são sempre reservadas.
	//
	// O primeiro byte (Media Descriptor) define o tipo de hardware que está 
	// sendo usado. O valor 0xF0 é o código padrão para um disquete de 1.44 MB 
	// (3.5 polegadas, dupla face, 18 setores por trilha), que é o modelo de
	// disco que estamos simulando.
	//
	// Os dois bytes seguintes (0xFF, 0xFF) são bytes reservados. Eles completam 
	// as duas primeiras entradas da FAT (Entry 0 e Entry 1). No formato FAT12, 
	// essas entradas não representam arquivos, elas servem apenas para indicar
	// o estado da mídia e preencher o espaço inicial.
	//
	// Juntos, esses 3 bytes formam o valor 0xFFFFFF na memória, indicando que
	// os "clusters" 0 e 1 estão fora de uso (reservados). Sem essas três linhas,
	// o disco seria considerado corrompido.
	//
	   
    disk[SECTOR_SIZE] = 0xF0;
    disk[SECTOR_SIZE + 1] = 0xFF;
    disk[SECTOR_SIZE + 2] = 0xFF;

    file = fopen(testcode_path, "rb");
    
	if (file) {
    
        fseek(file, 0, SEEK_END);
    
	    long file_size = ftell(file);
    
	    fseek(file, 0, SEEK_SET);

        int num_clusters = (file_size + SECTOR_SIZE - 1) / SECTOR_SIZE;
        
		int start_cluster = 2;

        int data_offset = 33 * SECTOR_SIZE;
        
		fread(&disk[data_offset], 1, file_size, file);
        
		fclose(file);
        
        int i;

        for ( i = 0; i < num_clusters; i++) {
        
		    int current = start_cluster + i;
        
		    int next = (i == num_clusters - 1) ? 0xFFF : current + 1;
        
		    set_fat_entry(disk, current, next);
        
		}


        int root_offset = 19 * SECTOR_SIZE;
        memcpy(&disk[root_offset], "TESTCODEBIN", 11);
        disk[root_offset + 11] = 0x20; 
        
        disk[root_offset + 26] = (unsigned char)(start_cluster & 0xFF);
        disk[root_offset + 27] = (unsigned char)((start_cluster >> 8) & 0xFF);

        disk[root_offset + 28] = (unsigned char)(file_size & 0xFF);
        disk[root_offset + 29] = (unsigned char)((file_size >> 8) & 0xFF);
        disk[root_offset + 30] = (unsigned char)((file_size >> 16) & 0xFF);
        disk[root_offset + 31] = (unsigned char)((file_size >> 24) & 0xFF);

    } else {
    	
    	printf("Erro: Arquivo de teste nao encontrado.");
    	
    	free(disk);
    	
    	return 1;
    	
	}

    file = fopen(output_path, "wb");
    
    if (file) {
    	
        fwrite(disk, 1, DISK_SIZE, file);
        
		fclose(file);
        
		printf("Imagem '%s' gerada com sucesso (%ld bytes).\n", output_path, DISK_SIZE);
		
    } else {
    	
    	printf("Erro: Arquivo de bootloader nao encontrado.");
    	
    	free(disk);
    	
    	return 1;
    	
	}

    free(disk);
    
    return 0;
	
}


/*

 A função main espera 3 parâmetros:

	argv[1]: Path do arquivo binário do bootloader.
    
	argv[2]: Path do arquivo binário do programa de teste que será carregado pelo
	bootloader.

	argv[3]: Path do arquivo de imagem de disco a ser gerado.
	
 Se o terceiro parâmetro não for passado, nomeia o arquivo de imagem como "bootloader.img".

*/

int main(int argc, char *argv[]) {
	
    if (argc < 3) {
        
		printf("Uso: %s <bootloader.bin> <testcode.bin> <output.img>", argv[0]);
        
		return 1;
    
	}

    const char *bootloader_path = argv[1];
    
	const char *testcode_path = argv[2];
    
	const char *output_path = (argc > 3) ? argv[3] : "bootloader.img";

    return create_fat12_disk_image(bootloader_path, testcode_path, output_path);
    
}
