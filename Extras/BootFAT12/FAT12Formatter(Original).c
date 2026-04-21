#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <locale.h>


// Define o tamanho da imagem como 1.44 MB (disquete 3.5" 1.44MB).
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
 ==============================================================================

 GERAÇÃO DA IMAGEM DE DISCO EM FORMATO FAT12
 
 
 Esta função cria uma imagem de disco formatada como FAT12 (File Allocation Table
 de 12 bits), um dos sistemas de arquivos mais antigos, utilizado principalmente 
 em disquetes e mídias de pequena capacidade (até cerca de 16 MB).

 A imagem gerada segue o layout clássico de um disquete (por exemplo, 1.44 MB), 
 contendo um volume FAT12 diretamente a partir do setor 0. Isso é necessário porque 
 o bootloader foi desenvolvido assumindo esse formato específico, incluindo a 
 geometria típica de disquetes e a ausência de particionamento.

 Diferentemente de discos rígidos e outros dipositivos de armazenamento com MBR 
 (Master Boot Record), onde o setor 0 contém uma tabela de partições e código
 que localiza a partição ativa, nesta abordagem não há esta tabela. Assim, o BIOS 
 carrega diretamente o setor de boot (VBR), simplificando o processo de boot e 
 eliminando a necessidade de localizar e encadear o carregamento a partir de uma 
 partição ativa.
 
 O FAT12 organiza o disco em clusters (grupos de setores), e usa uma tabela chamada
 FAT (File Allocation Table) para encadear esses clusters.
 
 Um volume FAT12 é dividido em regiões fixas:
 
                           +---------------------+
                           | Boot Sector (VBR)   |
                           +---------------------+
                           | FAT #1              |
                           +---------------------+
                           | FAT #2 (cópia)      |
                           +---------------------+
                           | Root Directory      |
                           +---------------------+
                           | Data Area           |
                           +---------------------+
						   
 Onde:
 
    * Boot Sector (VBR - Volume Boot Record): 
	
	Primeiro setor de um volume ou partição, com 512 bytes. O setor de boot contém:
	
		> BPB

		> Código do bootloader
		
		> Assinatura
		
	O código do bootloader é para o caso de um disco inicializável, como a imagem
	de disco que será criada por esta função. Caso seja apenas um disco para armazenar
	arquivos, normalmente é gravado um programa que mostra uma mensagem simples na 
	tela no lugar.
	
	O diagrama abaixo, representa como é o setor de boot da imagem de disco gerada
	por esta função:
	
                        +----------------------------+
                        | Jump Instruction (3 bytes) |
                        +----------------------------+
                        | BPB (BIOS Parameter Block) |
                        +----------------------------+
                        | EBPB (Extended BPB)        |
                        |----------------------------|
						|                            |
						|                            |
						|                            |
                        | Código do Bootloader       |
						|                            |
						|                            |
						|                            |
                        +----------------------------+
                        | Assinatura (2 bytes)       |
                        +----------------------------+
                  
	O BPB (BIOS Parameter Block)/EBPB (Extended BPB) contém parâmetros para descrever
	como o sistema de arquivos está organizado no disco, ou seja, ele define a
	"geometria" do sistema de arquivos (no caso, do FAT12).
	
	Os campos do BPB/EBPB são:

		Offset  Tamanho  Campo
		------  -------  ----------------------------
		0x03    8        OEM Label
		0x0B    2        Bytes por setor
		0x0D    1        Setores por cluster
		0x0E    2        Setores reservados
		0x10    1        Número de FATs
		0x11    2        Entradas root dir
		0x13    2        Total de setores (small)
		0x15    1        Media descriptor
		0x16    2        Setores por FAT
		0x18    2        Setores por trilha
		0x1A    2        Número de cabeças
		0x1C    4        Setores ocultos
		0x20    4        Total de setores (large)

		--- Extended BPB ---

		0x24    2        Número do drive
		0x26    1        Assinatura (0x29/0x41)
		0x27    4        Volume ID
		0x2B    11       Volume Label
		0x36    8        Tipo do sistema
		
	No projeto, foi definido os seguintes parâmetros no BPB (veja no código do
	bootloader):
	
		Offset  Campo                     valor
		------  ------------------------  -----------------------------------
		0x03    OEM Label                 "mkfs.fat"
		0x0B    Bytes por setor           512
		0x0D    Setores por cluster       1 setor (512 bytes por cluster)
		0x0E    Setores reservados        1
		0x10    Número de FATs            2 (FAT primária + cópia)
		0x11    Entradas root dir         224
		0x13    Total de setores (small)  2880 (2880 × 512 = 1.44 MB)
		0x15    Media Descriptor          0xF0 (Disquete 3.5" 1.44MB)
		0x16    Setores por FAT           9
		0x18    Setores por trilha        18
		0x1A    Número de cabeças         2
		0x1C    Setores ocultos           0 (Não há partição anterior)
		0x20    Total de setores (large)  0
		
		--- Extended BPB ---
		
		0x24    Número do driver          0 (0x00 = disquete, 0x80 = HD)
		0x26    Assinatura                41 (0x29 - DOS 4.0+)
		0x27    Volume ID                 0 (Número serial do volume)
		0x2B    Volume Label              "sibolo     " (Nome do volume, 11 bytes)
		0x36    Tipo de sistema           "FAT12   "
	
	Com base nos parâmetros do BPB do projeto, as estruturas da FAT deverão ocupar 
	os seguintes setores na imagem de disco:
	
	    +---------------------+---------------------+---------------------+
	    | REGIÃO              | NÚMERO DE SETORES   | SETORES OCUPADOS    |
        +---------------------+---------------------+---------------------+
        | Boot Sector (VBR)   | 1                   | Setor 0             |
        +---------------------+---------------------+---------------------+
        | FAT #1              | 9    (1)            | Setores 1 a 9       |
        +---------------------+---------------------+---------------------+
        | FAT #2 (cópia)      | 9                   | Setores 10 a 18     |
        +---------------------+---------------------+---------------------+
        | Root Directory      | 14   (2)            | Setores 19 a 32     |
        +---------------------+---------------------+---------------------+
        | Data Area           | 2847 (3)            | Setores 33 a 2879   |
        +---------------------+---------------------+---------------------+

		(1) Valor informado no offset 0x16 do BPB.
	
		(2) (224 * 32 ) / 512 = 14 setores.
		
		    O valor 224 é o número de entradas de Root Directory, informado 
			no offset 0x11 do BPB. O valor 32 corresponde ao tamanho de uma 
			entrada em Root Directory (32 bytes). O valor 512 corresponde 
			ao tamanho de um setor, informado no offset 0x0B do BPB.
		
		(3) (2880 - 14 - 9 - 9 - 1) = 2847 setores.
		
		    O valor 2880 é o número total de setores da imagem de disco, informado
			no offset 0x13 do BPB. Subtrai-se deste valor o número de setores
			de Root Directory, FAT #1, FAT #2 e Boot Sector.
							 
	Representando a imagem de disco em FAT12 de forma linear:
	
	[B ][F1][F1][F1][F1][F1][F1][F1][F1][F1][F2][F2][F2][F2][F2][F2][F2][F2][F2]
     0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  16  17  18  
	|1-||----------- 9 setores ------------||----------- 9 setores ------------|
	  
    [RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][DA..............DA] 
	 19  20  21  22  23  24  25  26  27  28  29  30  31  32  33............2879
	|--------------------- 14 setores ---------------------||-- 2847 setores --|

    [B]  = Boot Sector (1 setor)
    [F1] = FAT #1 (9 setores)
    [F2] = FAT #2 (9 setores)
    [RD] = Root Directory (14 setores)
    [DA] = Data Area (2847 setores)


	* FAT #1 (File Allocation Table):
	
	A tabela FAT é basicamente um vetor que:
	
		Para cada cluster -> Indica o próximo cluster da cadeia.
		
	ou seja, ela implementa uma lista encadeada de clusters para cada arquivo.
	
	Ela ocupa 9 setores, portanto:
	
		9 × 512 = 4608 bytes
	
	Cada entrada na tabela tem 12 bits, então:
	
		4608 bytes = 36864 bits
		36864 / 12 = 3072 entradas
		
	Cada entrada corresponde a um cluster.
	
	Os cluster 0 e 1 são reservados. Clusters válidos começam em 2.
	
 ==============================================================================	 
*/

int create_fat12_disk_image(const char *bootloader_path, const char *testcode_path, 
const char *output_path) {
	
	// Reserva um buffer do tamanho total do disco (1.44 MB). Usar calloc limpa a
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
		// nela. Em FAT12 o nome do arquivo sempre terá 11 bytes. Os 8 primeiros
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
    	
    	printf("Erro: Arquivo de bootloader não encontrado.");
    	
    	free(disk);
    	
    	return 1;
    	
	}
	   
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
			
			set_fat_entry(disk + SECTOR_SIZE * 9, current, next);
        
		}

        time_t t = time(NULL);
        struct tm *tm = localtime(&t);
        
        unsigned short fat_time = 
			(tm->tm_hour << 11) | 
			(tm->tm_min << 5) | 
			(tm->tm_sec / 2);
			
        unsigned short fat_date = 
			((tm->tm_year - 80) << 9) | 
			((tm->tm_mon + 1) << 5) | 
			tm->tm_mday;

        int root_offset = 19 * SECTOR_SIZE;
		
		memset(&disk[root_offset], 0, 32);
        memcpy(&disk[root_offset], "TESTCODEBIN", 11);
      
		disk[root_offset + 11] = 0x20; 
		disk[root_offset + 12] = 0;
		disk[root_offset + 13] = 0;

        disk[root_offset + 14] = (unsigned char)(fat_time & 0xFF); 
        disk[root_offset + 15] = (unsigned char)((fat_time >> 8) & 0xFF);
        disk[root_offset + 16] = (unsigned char)(fat_date & 0xFF);
        disk[root_offset + 17] = (unsigned char)((fat_date >> 8) & 0xFF);
		disk[root_offset + 18] = (unsigned char)(fat_date & 0xFF);
		disk[root_offset + 19] = (unsigned char)((fat_date >> 8) & 0xFF);

        disk[root_offset + 22] = (unsigned char)(fat_time & 0xFF);
        disk[root_offset + 23] = (unsigned char)((fat_time >> 8) & 0xFF);
        disk[root_offset + 24] = (unsigned char)(fat_date & 0xFF);
        disk[root_offset + 25] = (unsigned char)((fat_date >> 8) & 0xFF);

        disk[root_offset + 26] = (unsigned char)(start_cluster & 0xFF);
        disk[root_offset + 27] = (unsigned char)((start_cluster >> 8) & 0xFF);

        disk[root_offset + 28] = (unsigned char)(file_size & 0xFF);
        disk[root_offset + 29] = (unsigned char)((file_size >> 8) & 0xFF);
        disk[root_offset + 30] = (unsigned char)((file_size >> 16) & 0xFF);
        disk[root_offset + 31] = (unsigned char)((file_size >> 24) & 0xFF);
		
		disk[root_offset + 11] |= 0x20;

    } else {
    	
    	printf("Erro: Programa de teste não encontrado.");
    	
    	free(disk);
    	
    	return 1;
    	
	}

    file = fopen(output_path, "wb");
    
    if (file) {
    	
        fwrite(disk, 1, DISK_SIZE, file);
        
		fclose(file);
        
		printf("Imagem '%s' gerada com sucesso (%ld bytes).\n", output_path, DISK_SIZE);
		
    } else {
    	
    	printf("Erro: Arquivo de imagem de disco não gerado.");
    	
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
	
	setlocale(LC_ALL, "");
	
    if (argc < 3) {
        
		printf("Uso: %s <bootloader.bin> <testcode.bin> <output.img>", argv[0]);
        
		return 1;
    
	}

    const char *bootloader_path = argv[1];
    
	const char *testcode_path = argv[2];
    
	const char *output_path = (argc > 3) ? argv[3] : "bootloader.img";

    return create_fat12_disk_image(bootloader_path, testcode_path, output_path);
    
}
