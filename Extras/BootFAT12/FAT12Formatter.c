#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <locale.h>

#define SECTOR_SIZE 512
#define DISK_SIZE (1440 * 1024)
#define FAT_END 0xFFF
#define ROOT_MAX_ENTRIES 224


/* 
 ==============================================================================

 SOBRE O PROJETO


 O código fonte deste gerador de imagem de disco é baseado no projeto de bootloader
 disponível em:
 
 
       https://github.com/kalehmann/SiBoLo/blob/master/bootloader.asm
 
 
 No projeto, o autor desenvolve um bootloader que deve ser gravado numa imagem 
 de disco formatada como FAT12. Ao gravar esta imagem de disco em um dispositivo
 de armazenamento e dar boot com ele, o bootloader vai buscar um programa de teste 
 na mesma imagem, usando o nome do arquivo deste programa no sistema de arquivos
 FAT12 para localizá-lo no disco. Ao localizá-lo nas entradas do diretório raiz
 do FAT12, percorre as entradas na tabela FAT correpondentes ao arquivo e correga 
 os clusters apontados por elas na memória. Após carregar o programa de teste, 
 entrega o controle para o mesmo, que vai mostrar uma frase na tela, e o conteúdo
 de alguns registradores que ele lê. 
 
 Para definir o nome do arquivo do programa de teste, o autor reserva um espaço 
 no bootloader para que o gerador da imagem de disco possa gravá-lo ali. Será
 neste endereço que ele lerá o nome do arquivo para buscá-lo no diretório raiz.
 Neste projeto, o nome que escolhi para o arquivo é TESTCODE.BIN (TESTCODEBIN no
 formato 8:3 do FAT12).
 
                        +-----------------------------+
                        | Jump Instruction            |
                        +-----------------------------+
                        | BPB (BIOS Parameter Block)  |
                        +-----------------------------+
                        | EBPB (Extended BPB)         |
                        |-----------------------------|
						|                             |
						|                             |
						|                             |
                        | Código do Bootloader        |
						|                             |
						|                             |
						|                             |
                        +.............................+ - Área reservada
                        | Nome do programa (11 bytes) | | para o nome do 
                        +.............................+ - arquivo (offsets
						| Assinatura                  |   498 até 508).
                        +-----------------------------+
                  
 
 
 SISTEMA DE ARQUIVOS FAT12
 
 Este programa cria uma imagem de disco formatada como FAT12 (File Allocation Table
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




/*
 ==============================================================================
 
 Essa função:

   > Localiza onde está a entrada FAT12 de um cluster.
   
   > Decide se ele é par ou ímpar.
   
   > Insere os 12 bits corretamente.
   
   > Preserva os bits do cluster vizinho.
   
 ==============================================================================
*/
void set_fat_entry(
    unsigned char *disk,
    uint32_t fat_offset,
    int cluster,
    int value
) {
	
	// FAT12 usa entradas de 12 bits. Aplicando um and bit-a-bit com a máscara 
	// 0x0FFF (0000 1111 1111 1111), garante que apenas os 12 bits menos significativos
	// serão usados, zerando quaisquer bits acima disso. 
	//
	//                     ANTES:  xxxx xxxx xxxx xxxx
	//                     DEPOIS: 0000 xxxx xxxx xxxx
	//
	// Exemplo 1: value = 0x1234
	//    
	//        0001 0010 0011 0100 (0x1234)
	//     &  0000 1111 1111 1111 (0x0FFF)
	//     ----------------------
	//        0000 0010 0011 0100 (0x0234)
	//
	// Exemplo 2: value = 0x0ABC
	//    
	//        0000 1010 1011 1100 (0x0ABC)
	//     &  0000 1111 1111 1111 (0x0FFF)
	//     ----------------------
	//        0000 1010 1011 1100 (0x0ABC)
	
    value &= 0x0FFF;

	// Calcula em qual byte da FAT começa a entrada do cluster. Como cada entrada 
	// ocupa 1,5 bytes (12 bits), então, temos que:
	// 
	//   > 2 entradas = 3 bytes
	//
	//     |--- Entrada1 ---|   |--- Entrada2 ---|
	//     1111   1111   1111   1111   1111   1111
	//     |- Byte1 -|   |- Byte2 -|   |- Byte3 -|
	//
	// Quebrando em partes a equação:
	//
	//   idx = fat_offset + ((cluster * 3) / 2)
	//
	//   (cluster * 3): Multiplica por 3 porque cada 2 clusters ocupam 3 bytes.
	//
	//   /2 : Divide por 2 porque queremos o equivalente a 1.5 byte por cluster.
	//
	//   Resultado: (cluster * 3) / 2 == cluster * 1.5
	//
	// Exemplo 1: cluster = 2
	// 
	//   idx = fat_offset + (2 * 3) / 2
	//       = fat_offset + 6 / 2
	//       = fat_offset + 3
	//   
	//   Resultado: Começa no byte 3.
	//	
	// Exemplo 2: cluster = 3
	// 
	//   idx = fat_offset + (3 * 3) / 2
	//       = fat_offset + 9 / 2
	//       = fat_offset + 4
	//   
	//   Resultado: Começa no byte 4.

    uint32_t idx = fat_offset + ((cluster * 3) / 2);

	// FAT12 armazena duas entradas em 3 bytes:
	// - cluster par usa os 12 bits "baixos"
	// - cluster ímpar usa os 12 bits "altos"
	
    if (cluster % 2 == 0) {
		
		// Caso PAR: 
		// Os 8 bits menos significativos vão direto no primeiro byte.
        
		disk[idx] = value & 0xFF;
		
		// Os 4 bits mais altos (bits 8–11) vão para o nibble baixo do próximo byte. 
		// Precisamos preservar o nibble alto (bits de outro cluster), 
		// então usamos máscara 0xF0.
        
		disk[idx + 1] = (disk[idx + 1] & 0xF0) | ((value >> 8) & 0x0F);
		
    } else {
		
		// Caso ÍMPAR: 
		// Aqui a entrada ocupa os 12 bits "altos" do par de bytes. 
		// Os 4 bits menos significativos do valor vão para o nibble alto 
		// do byte atual (idx). 
		// Precisamos preservar o nibble baixo (de outro cluster).
		
        disk[idx] = (disk[idx] & 0x0F) | ((value << 4) & 0xF0);
		
		// Os 8 bits mais altos do valor (bits 4–11) vão para o próximo byte inteiro.
		
        disk[idx + 1] = (value >> 4) & 0xFF;
		
    }
	
}


int get_fat_entry(
    unsigned char *disk,
    uint32_t fat_offset,
    int cluster
) {
	
    uint32_t idx = fat_offset + (cluster * 3) / 2;

    uint16_t val;

    if (cluster % 2 == 0) {
        val = disk[idx] | ((disk[idx + 1] & 0x0F) << 8);
    } else {
        val = ((disk[idx] & 0xF0) >> 4) | (disk[idx + 1] << 4);
    }

    return val & 0x0FFF;

}


int find_free_cluster(
    unsigned char *disk,
    uint32_t fat_offset,
    int max_cluster
) {
	
    for (int c = 2; c <= max_cluster; c++) {
        
		if (get_fat_entry(disk, fat_offset, c) == 0x000) {
            
			return c;
        
		}
		
    }
    
	return -1;

}


void format_83(char *out, const char *in) {
	
    memset(out, ' ', 11);

    int i = 0, j = 0;

    while (in[i] && in[i] != '.' && j < 8) {
        char c = in[i++];
        if (c >= 'a' && c <= 'z') c -= 32;
        out[j++] = c;
    }

    if (in[i] == '.') i++;

    j = 8;

    while (in[i] && j < 11) {
        char c = in[i++];
        if (c >= 'a' && c <= 'z') c -= 32;
        out[j++] = c;
    }
	
}


int set_root_entry(
    unsigned char *disk,
    uint32_t root_offset,
    const char *name,
    uint16_t cluster,
    uint32_t size
) {
	
    if (cluster < 2) return -1;

    for (int i = 0; i < ROOT_MAX_ENTRIES; i++) {

        uint32_t entry = root_offset + (i * 32);

        if (disk[entry] == 0x00 || disk[entry] == 0xE5) {

            memcpy(&disk[entry], name, 11);

            disk[entry + 11] = 0x20;
            disk[entry + 12] = 0x00;

            time_t t = time(NULL);
            
			struct tm *tm = localtime(&t);
            
			if (!tm) return -1;

            uint16_t fat_time =
                (tm->tm_hour << 11) |
                (tm->tm_min << 5) |
                (tm->tm_sec / 2);

            uint16_t fat_date =
                ((tm->tm_year - 80) << 9) |
                ((tm->tm_mon + 1) << 5) |
                tm->tm_mday;

            disk[entry + 13] = 0;

            disk[entry + 14] = fat_time & 0xFF;
            disk[entry + 15] = fat_time >> 8;

            disk[entry + 16] = fat_date & 0xFF;
            disk[entry + 17] = fat_date >> 8;

            disk[entry + 18] = fat_date & 0xFF;
            disk[entry + 19] = fat_date >> 8;

            disk[entry + 22] = fat_time & 0xFF;
            disk[entry + 23] = fat_time >> 8;

            disk[entry + 24] = fat_date & 0xFF;
            disk[entry + 25] = fat_date >> 8;

            disk[entry + 26] = cluster & 0xFF;
            disk[entry + 27] = cluster >> 8;

            disk[entry + 28] = size & 0xFF;
            disk[entry + 29] = (size >> 8) & 0xFF;
            disk[entry + 30] = (size >> 16) & 0xFF;
            disk[entry + 31] = (size >> 24) & 0xFF;

            return 0;
			
        }
		
    }

    return -1;
	
}




/* 
 ==============================================================================

 GERAÇÃO DA IMAGEM DE DISCO EM FORMATO FAT12
 
 
 Esta função cria uma imagem de disco formatada como FAT12 (File Allocation Table
 de 12 bits), um dos sistemas de arquivos mais antigos, utilizado principalmente 
 em disquetes e mídias de pequena capacidade (até cerca de 16 MB).

 ==============================================================================	 
*/

int create_fat12_disk_image(
    const char *bootloader_path,
    const char *testcode_path,
    const char *output_path
) {
	
    unsigned char *disk = calloc(DISK_SIZE, 1);
    
	if (!disk) return 1;

    FILE *file = fopen(bootloader_path, "rb");
    
	if (!file) { free(disk); return 1; }

    if (fread(disk, 1, SECTOR_SIZE, file) != SECTOR_SIZE) {
        fclose(file);
        free(disk);
        return 1;
    }
	
    fclose(file);

    char filename[11];
	
    format_83(filename, "TESTCODE.BIN");

    memcpy(&disk[498], filename, 11);

    const uint16_t reserved_sectors = 1;
    const uint8_t fats = 2;
    const uint16_t sectors_per_fat = 9;
    const uint16_t root_entries = ROOT_MAX_ENTRIES;

    const uint32_t fat1_offset = reserved_sectors * SECTOR_SIZE;
    const uint32_t fat2_offset = fat1_offset + sectors_per_fat * SECTOR_SIZE;

    const uint32_t root_offset =
        (reserved_sectors + fats * sectors_per_fat) * SECTOR_SIZE;

    const uint32_t root_size_bytes = root_entries * 32;

    const uint32_t data_offset =
        ((root_offset + root_size_bytes + SECTOR_SIZE - 1) / SECTOR_SIZE)
        * SECTOR_SIZE;

    uint32_t total_sectors = DISK_SIZE / SECTOR_SIZE;
    uint32_t data_sectors =
        total_sectors - (reserved_sectors + fats * sectors_per_fat + (root_size_bytes / SECTOR_SIZE));
    uint32_t max_cluster = data_sectors + 1;

    memset(&disk[fat1_offset], 0, sectors_per_fat * SECTOR_SIZE);
    memset(&disk[fat2_offset], 0, sectors_per_fat * SECTOR_SIZE);

    disk[fat1_offset] = 0xF0;
    disk[fat1_offset + 1] = 0xFF;
    disk[fat1_offset + 2] = 0xFF;

    file = fopen(testcode_path, "rb");
    if (!file) { free(disk); return 1; }

    if (fseek(file, 0, SEEK_END) != 0) { 
        fclose(file);
        free(disk);
        return 1;
    }

    long file_size = ftell(file);
    rewind(file);

    if (file_size <= 0) {
        fclose(file);
        free(disk);
        return 1;
    }

    unsigned char *buffer = malloc(file_size);
	
    if (!buffer) {
        fclose(file);
        free(disk);
        return 1;
    }

    if (fread(buffer, 1, file_size, file) != (size_t)file_size) {
        fclose(file);
        free(buffer);
        free(disk);
        return 1;
    }

    fclose(file);

    uint32_t num_clusters = (file_size + SECTOR_SIZE - 1) / SECTOR_SIZE;

    int clusters[4096];
    int count = 0;

    for (uint32_t i = 0; i < num_clusters; i++) {

        if (count >= 4096) { 
            free(buffer);
            free(disk);
            return 1;
        }

        int c = find_free_cluster(disk, fat1_offset, max_cluster);

        if (c < 0) {
            free(buffer);
            free(disk);
            return 1;
        }

        clusters[count++] = c;
		
        set_fat_entry(disk, fat1_offset, c, FAT_END);
		
    }

    for (int i = 0; i < count - 1; i++) {
        set_fat_entry(disk, fat1_offset, clusters[i], clusters[i + 1]);
    }

    set_fat_entry(disk, fat1_offset, clusters[count - 1], FAT_END);

    uint32_t current = clusters[0];

    for (uint32_t i = 0; i < num_clusters; i++) {

        uint32_t offset = data_offset + (current - 2) * SECTOR_SIZE;

        uint32_t copy_size = SECTOR_SIZE;

        if ((i + 1) * SECTOR_SIZE > (uint32_t)file_size) {
            copy_size = file_size - i * SECTOR_SIZE;
        }

        memcpy(&disk[offset], &buffer[i * SECTOR_SIZE], copy_size);

        if (i < num_clusters - 1) {
            current = clusters[i + 1];
        }
		
    }

    free(buffer);

    memcpy(&disk[fat2_offset], &disk[fat1_offset], sectors_per_fat * SECTOR_SIZE);

    if (set_root_entry(disk, root_offset, filename, clusters[0], file_size) != 0) {
        free(disk);
        return 1;
    }

    FILE *out = fopen(output_path, "wb");
	
    if (!out) {
        free(disk);
        return 1;
    }

    fwrite(disk, 1, DISK_SIZE, out);
	
    fclose(out);

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
        printf("Uso: %s <bootloader.bin> <testcode.bin> <output.img>\n", argv[0]);
        return 1;
    }
	
    const char *bootloader_path = argv[1];
    const char *testcode_path = argv[2];
    const char *output_path = (argc > 3) ? argv[3] : "bootloader.img";

    return create_fat12_disk_image(bootloader_path, testcode_path, output_path);
	
}