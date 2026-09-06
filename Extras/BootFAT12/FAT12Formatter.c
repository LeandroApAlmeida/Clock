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


/*=============================================================================

 SOBRE O PROJETO


 O código fonte deste gerador de imagem de disco é baseado no projeto de bootloader
 disponível em:
 
 
       https://github.com/kalehmann/SiBoLo/blob/master/bootloader.asm
 
 
 No projeto, o autor desenvolve um bootloader que deve ser gravado numa imagem 
 de disco formatada como FAT12. Ao gravar esta imagem de disco em um dispositivo
 de armazenamento e dar boot com ele, o bootloader vai buscar um programa de teste 
 na mesma imagem, usando o nome do arquivo deste programa no sistema de arquivos
 FAT12 para localizá-lo no disco. Ao localizá-lo nas entradas do diretório raiz
 do FAT12, percorre as entradas na tabela FAT correpondentes ao arquivo e carrega 
 os clusters apontados por elas na memória. Após carregar o programa de teste, 
 entrega o controle para o mesmo, que vai mostrar uma frase na tela, e o conteúdo
 de alguns registradores que ele lê. 
 
 Para definir o nome do arquivo do programa de teste, o autor reserva um espaço
 no bootloader para que o gerador da imagem de disco possa gravá-lo ali. Este
 espaço corresponde aos offsets de 498 à 508. Será nestes endereços que ele lerá 
 o nome do arquivo para buscá-lo no disco FAT12. O nome que escolhi para o arquivo
 é "TESTCODE.BIN" ("TESTCODEBIN" no formato 8:3 do FAT12).
 
 
                          ┌───────────────────────────┐
                          │                           │
                          │                           │
						  │                           │
                          │                           │
                          │                           │
                          │                           │
                          │                           │
                          │                           │
                          │                           │
                          │                           │
                          │                           │
                          │                           │
						  │                           │
						  │                           │
						  │                           │
                          │---------------------------│ ┬ Área reservada para
                          │ Program File Name (11 B)  │ │ o nome do arquivo do 
                          │---------------------------│ ┴ programa de teste 
						  │                           │   (offsets 498 até 508).
                          └───────────────────────────┘
 
  
 SISTEMA DE ARQUIVOS FAT12
 
 
 Este programa cria uma imagem de disco formatada como FAT12 (File Allocation Table
 de 12 bits), um dos sistemas de arquivos mais antigos, utilizado principalmente 
 em disquetes e mídias de pequena capacidade (até cerca de 16 MB).

 A imagem gerada segue o layout clássico de um disquete 3.5 polegadas (1.44 MB), 
 contendo um volume FAT12 diretamente a partir do setor 0. Diferentemente de discos
 rígidos e outros dipositivos de armazenamento com MBR (Master Boot Record), onde
 o setor 0 contém uma tabela de partições e código que localiza a partição ativa, 
 nesta abordagem não há esta tabela. Assim, o BIOS carrega diretamente o setor de
 boot (VBR), simplificando o processo de boot e eliminando a necessidade de localizar
 e encadear o carregamento a partir de uma partição ativa.
 
 O FAT12 organiza o disco em clusters (grupos de setores), e usa uma tabela chamada
 FAT (File Allocation Table) para encadear esses clusters.
 
 Um volume formatado como FAT12 é dividido em regiões fixas:
 
 
                            ┌─────────────────────┐ ┬
                            │ Boot Sector         │ │
                            ├─────────────────────┤ │ Reserved Sectors
						    │                     │ │
                            ├─────────────────────┤ ┴
                            │ FAT #1              │
                            ├─────────────────────┤
                            │ FAT #2 (cópia)      │
                            ├─────────────────────┤
                            │ Root Directory      │
                            ├─────────────────────┤
						    │                     │
						    │                     │
						    │                     │
						    │                     │
                            │ Data Area           │
						    │                     │
						    │                     │
						    │                     │
						    │                     │
                            └─────────────────────┘

 
 ● Boot Sector
 
 
   Primeiro setor de um volume ou partição, com 512 bytes. Pode ser Volume Boot 
   Record (VBR) ou MBR (Master Boot Record), dependendo do tipo de disco.
 
   O diagrama abaixo representa como é o setor de boot da imagem de disco gerada
   por este programa:
 
 
                         ┌────────────────────────────┐
                         │ Jump Instruction           │
                         ├────────────────────────────┤
 					     │ OEM Name                   │
                         ├────────────────────────────┤
                         │ BPB (BIOS Parameter Block) │
                         ├────────────────────────────┤
                         │ EBPB (Extended BPB)        │
                         ├────────────────────────────┤
 					     │                            │
 					     │                            │
						 │                            │
 					     │                            │
						 │                            │
                         │ Bootloader Code            │
 					     │                            │
						 │                            │
						 │                            │
 					     │                            │
 					     │                            │
						 │----------------------------│
                         │ Program File Name          │
                         │----------------------------│
                         │ Boot Signature             │
                         └────────────────────────────┘
   
   
   Onde:


   Jump Instruction:
   -----------------
   
   A instrução jump é a primeira instrução do bootloader. Serve para alinhar as 
   instruções e pular sobre os dados do BPB/EBPB para ir direto ao código do 
   bootloader.
   
   No código-fonte ela é declarada como:
   
     jmp short start
     nop
	
   Os opcodes da instrução ocupam 3 bytes.
 
 
   OEM Name:
   ---------

   O campo OEM Name é um campo textual, com 8 bytes, presente no Boot Sector de 
   sistemas FAT.
 
   Ele serve principalmente como:


     > Identificador do software que formatou o volume.
   
     > Compatibilidade histórica.
   
     > Informação descritiva.
 
 
   BPB/EBPB:
   ---------
   
   O BPB (BIOS Parameter Block)/EBPB (Extended BPB), é uma estrutura de dados no 
   setor de Boot que descreve o layout físico de um volume de armazenamento de 
   dados. Em dispositivos particionados, que usam MBR, como discos rígidos, o BPB 
   descreve a partição do volume, enquanto em dispositivos não particionados, que
   usam VBR, como disquetes (formato desta imagem), ele descreve toda a mídia.
 
   Em sistemas com BIOS legado, o código do bootloader usa as informações do BPB/EBPB
   para:
 
 
     > Localizar a FAT.
 
     > Encontrar arquivos do sistema.
 
     > Carregar o próximo estágio do bootloader.
 
     > Entender a geometria lógica do volume.
 
 
   Sem BPB/EBPB corretos:
 
 
     > O sistema operacional não vai montar o volume.
	  
     > O bootloader não vai localizar arquivos.
	  
     > O disco vai parecer corrompido.
	
	
   Os campos do OEM Label e do BPB/EBPB são:


     ┌────────┬─────────┬──────────────────────────────────┬──────────────────┐
     │ OFFSET │ TAMANHO │ CAMPO                            │ VALOR NO PROJETO │
     ╞════════╪═════════╪══════════════════════════════════╪══════════════════╡
	 │ 0x03   │ 8       │ OEM Label                        │ "mkfs.fat"       │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x0B   │ 2       │ Bytes por setor lógico           │ 512              │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x0D   │ 1       │ Setores lógicos por cluster      │ 1                │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x0E   │ 2       │ Setores lógicos reservados       │ 1                │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x10   │ 1       │ Número de FATs                   │ 2                │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x11   │ 2       │ Entradas do diretório raiz       │ 224              │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x13   │ 2       │ Total de setores lógicos (small) │ 2880             │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x15   │ 1       │ Descritor de mídia               │ 0xF0             │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x16   │ 2       │ Setores lógicos por FAT          │ 9                │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x18   │ 2       │ Setores por trilha               │ 18               │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x1A   │ 2       │ Número de cabeças                │ 2                │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x1C   │ 4       │ Setores ocultos                  │ 0                │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x20   │ 4       │ Total de setores lógicos (large) │ 0                │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x24   │ 2       │ Número do drive                  │ 0                │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x26   │ 1       │ Assinatura (0x29/0x41)           │ 41               │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x27   │ 4       │ Número de série do volume        │ 0                │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x2B   │ 11      │ Rótulo de volume                 │ "sibolo     "    │
	 ├────────┼─────────┼──────────────────────────────────┼──────────────────┤
     │ 0x36   │ 8       │ Tipo de sistema de arquivos      │ "FAT12   "       │
	 └────────┴─────────┴──────────────────────────────────┴──────────────────┘


   Com base nos parâmetros do BPB/EBPB do projeto (última coluna), as estruturas
   da FAT deverão ocupar os seguintes setores na imagem de disco:


     ┌────────────────────────┬───────────────────────┬───────────────────────┐
     │ REGIÃO                 │ NÚMERO DE SETORES     │ SETORES OCUPADOS      │
     ╞════════════════════════╪═══════════════════════╪═══════════════════════╡
     │ Boot Sector (VBR)      │ 1                     │ Setor 0               │
     ├────────────────────────┼───────────────────────┼───────────────────────┤
     │ FAT #1                 │ 9    (1)              │ Setores 1 a 9         │
     ├────────────────────────┼───────────────────────┼───────────────────────┤
     │ FAT #2 (cópia)         │ 9                     │ Setores 10 a 18       │
     ├────────────────────────┼───────────────────────┼───────────────────────┤
     │ Root Directory         │ 14   (2)              │ Setores 19 a 32       │
     ├────────────────────────┼───────────────────────┼───────────────────────┤
     │ Data Area              │ 2847 (3)              │ Setores 33 a 2879     │
     └────────────────────────┴───────────────────────┴───────────────────────┘

     (1) Valor 9 informado no offset 0x16 do BPB.

     (2) (224 * 32) / 512 = 14 setores. O valor 224 é o número de entradas 
	 de Root Directory, informado no offset 0x11 do BPB. O valor 32 corresponde
	 ao tamanho de uma entrada em Root Directory (32 bytes). O valor 512 
	 corresponde ao tamanho de um setor, informado no offset 0x0B do BPB.
	
     (3) (2880 - 14 - 9 - 9 - 1) = 2847 setores. O valor 2880 é o número 
	 total de setores da imagem de disco, informado no offset 0x13 do BPB. 
	 Subtrai-se deste valor o número de setores de Root Directory, FAT #1, 
	 FAT #2 e Boot Sector.
	
	
   Representando a imagem de disco em FAT12 de forma linear:


   [B ][F1][F1][F1][F1][F1][F1][F1][F1][F1][F2][F2][F2][F2][F2][F2][F2][F2][F2]
    0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  16  17  18  
   |1-||----------- 9 setores ------------||----------- 9 setores ------------|

   [RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][RD][DA][DA][DA][DA][DA] 
    19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37
   |--------------------- 14 setores ---------------------||--- 2847 setores --

   [B]  = Boot Sector (1 setor)
   [F1] = FAT #1 (9 setores)
   [F2] = FAT #2 (9 setores)
   [RD] = Root Directory (14 setores)
   [DA] = Data Area (2847 setores)
   
   
   Bootloader Code:
   ----------------
   
   No código do bootloader do projeto de relógio, como a imagem é criada em Raw 
   Format, é utilizado o modo CHS (Cylinder-Head-Sector) para carregar o kernel 
   na memória. O modo CHS era a forma antiga usada pelo BIOS para localizar setores
   em discos rígidos e disquetes antes do uso generalizado do LBA (Logical Block
   Addressing).
   
   Os três componentes do modo CHS são:


     > Cylinder (Cilindro): Representa a trilha física no disco.
	 
     > Head (Cabeça): Representa a face/leitor do disco.
	 
     > Sector (Setor): Representa o setor para a leitura/gravação.


   O BIOS usa esses valores em chamadas da interrupção INT 13h (interrupção de
   disco do BIOS).
   
   O modo CHS exige que se conheça exatamente em que setor o programa do kernel 
   se inicia, e quantos setores ele ocupa no total, para parametrizar corretamente
   a interrupção INT 13h da BIOS.
   
   No código-fonte do bootloader do relógio, o kernel é carregado desta forma na
   rotina "load_kernel_image":
   
   
     mov ah, 0x02                ; Define o valor 0x02 em AH (função Read Sectors
	                             ; From Drive).
	
     mov dl, [drive_number]      ; Lê o número do drive na memória e coloca em
	                             ; DL.
								  
     mov al, 10                  ; Define o número de setores a serem lidos.
	
     mov ch, 0                   ; Define o número do cilindro.
	
     mov dh, 0                   ; Define o número da cabeça.
	
     mov cl, 2                   ; Define o setor inicial a ser lido do disco.
	
     mov bx, bp                  ; Define o endereço inicial na memória onde vai
	                             ; carregar o kernel (valor de bp = 0x7E00).
								  
     int 0x13                    ; Chama a interrupção de disco do BIOS para
	                             ; carregar o kernel na memória.
   
   
   A mesma funcionalidade, aplicando-se o método LBA, ficaria com o seguinte código
   Assembly:
   
   
     dap:                        ; Início da estrutura DAP (Disk Address Packet).

         db 16                   ; Tamanho da estrutura DAP em bytes.

         db 0                    ; Byte reservado (deve ser sempre 0).

         dw 10                   ; Define o número de setores a serem lidos.

         dw 0x7E00               ; Define o endereço de memória de destino.

         dw 0x0000               ; Define o segmento do endereço destino.

         dq 1                    ; LBA inicial do kernel. LBA 1 é o segundo setor
		                         ; do disco (LBA começa em 0).

	 load_kernel:                ; Label da rotina que carrega o kernel.

         mov ah, 0x42            ; Define o valor 0x42 em AH (função Extended 
		                         ; Read Sectors). Leitura usando LBA.

         mov dl, [drive_number]  ; Lê o número do drive na memória e coloca em
		                         ; DL.

         mov si, dap             ; SI recebe o endereço da estrutura DAP. O BIOS 
	                             ; espera: DS:SI -> ponteiro para o DAP.

         int 0x13                ; Chama a interrupção de disco do BIOS para carregar
                                 ; o kernel na memória.
   
   
   No código do bootloader deste projeto, o processo de carregamento do programa
   de teste é muito diferente. O bootloader não precisará conhecer a localização
   exata deste programa no disco. Ele lerá diretamente o arquivo a partir da 
   estrutura do sistema de arquivos FAT12. 
   
   O diagrama abaixo representa o modo como isto é feito:
   
   
                                    BIOS
                                     │
                                     ▼
                         ┌─────────────────────────┐
                         │ Carrega Boot Sector no  │
                	     │ endereço 0x7C00         │
                         └─────────────────────────┘
                                     │
                                     ▼
                         ┌─────────────────────────┐
                         │ Bootloader inicia a     │
                         │ execução em Modo Real   │
                         └─────────────────────────┘
						             │
                                     ▼
                         ┌─────────────────────────┐
                         │ Se realoca do endereço  │
						 │ 0x7C00 para o 0x600     │
                         └─────────────────────────┘
						             │
                                     ▼
                         ┌─────────────────────────┐
                         │ Salta para o código     │
						 │ realocado               │
                         └─────────────────────────┘
                                     │
                                     ▼
                         ┌─────────────────────────┐
                         │ Lê parâmetros do BPB:   │
                         │ Bytes/setor             │
                         │ Setores/FAT             │
                         │ Entradas do root        │
                         │ Setores/cluster         │
                         └─────────────────────────┘
                                     │
                                     ▼
                         ┌─────────────────────────┐
                         │ Calcula as posições de  │
                		 │ Root Directory e FAT e  │
						 │ carrega estas na memória│
                         └─────────────────────────┘
                                     │
                                     ▼
                         ┌─────────────────────────┐
                         │ Lê Root Directory       │
                         └─────────────────────────┘
                                     │
                                     ▼
                         ┌─────────────────────────┐
                         │ Procura pela entrada do │ 
						 │ arquivo "TESTCODEBIN"   │
                         └─────────────────────────┘
                		             │
                                     │ Entrada encontrada?
									 │
                                     ├────────────────────────────┐
                                     │                            │
                                    SIM                          NÃO
                                     │                            │
                                     ▼                            ▼
                         ┌─────────────────────────┐   ┌──────────────────────┐
                         │ Lê o primeiro cluster   │   │ Erro: Bloqueia       │
                         │ do arquivo              │   │                      │
                         └─────────────────────────┘   └──────────────────────┘
                                     │
                                     ▼
                         ┌─────────────────────────┐
        ┌──────────────▶ │ Converte cluster ⇒      │
        │                │ Setor físico            │
        │                └─────────────────────────┘
        │                            │
        │                            ▼
        │                ┌─────────────────────────┐
        │                │ Lê setor(es) do cluster │
        │                │ para a memória RAM      │
        │                └─────────────────────────┘
        │                            │
        │                            ▼
        │                ┌─────────────────────────┐
        │                │ Consulta FAT para obter │
        │                │ o próximo cluster       │
        │                └─────────────────────────┘
        │                            │
        │                            │ Fim da cadeia?
        │                            │
        │              ┌─────────────┴────────────┐
        │              │                          │
        │             NÃO                        SIM
        │              │                          │
        │              ▼                          ▼
        │   ┌──────────────────────┐   ┌──────────────────────┐
        └───│ Lê o próximo cluster │   │ Arquivo totalmente   │
            │                      │   │ carregado na memória │
            └──────────────────────┘   └──────────────────────┘
                                                  │
                                                  ▼
                                       ┌──────────────────────┐
                                       │ Salta para o programa│
								       │ de teste carregado do│
									   │ arquivo em 0x7C00    │
                                       └──────────────────────┘

   
   Como visto no diagrama, o bootloader inicialmente realoca seu próprio código
   para um endereço mais baixo na memória (0x600), para copiar o código do programa
   de teste no endereço 0x7C00 que o BIOS o carregou originalmente. Provavelmente
   o autor usou esta estratégia porque ela era comum em sistemas antigos.
   
   Após realocar seu próprio código, o bootloader localiza na FAT12 Root Directory
   e tabela FAT. Feito isso ele carrega estas estruturas na memória e procura a 
   entrada do arquivo do programa de teste em Root Directory, com base no nome 
   gravado nos offsets 498 a 508 por este gerador de imagem de disco. Encontrado 
   o arquivo, ele percorre o encadeamento na FAT #1 para carregar o conteúdo dos
   clusters do arquivo na memória, na ordem da tabela FAT.
   
   Após carregar o programa no arquivo para a memória, o bootloader salta para a
   execução do mesmo. Este programa vai imprimir um cabeçalho e o conteúdo de 
   alguns registradores na tela. Ele também é de autoria do mesmo dono do perfil 
   no Github de onde baixei o código do bootloader.
   
   
   Program File Name:
   ------------------
   
   Espaço reservado pelo autor para o nome do arquivo do programa de teste. 
   Corresponde aos offsets de 498 a 508 do bootlader. No caso, o programa grava 
   o texto "TESTCODEBIN" neste espaço, que é o nome atribuído ao arquivo do programa
   por este gerador de imagem de disco. 
   
   
   Boot Signature:
   ---------------
   
   O setor de boot deve receber a assinatura 0x55AA (boot signature) nos dois 
   últimos bytes para indicar que é um disco inicializável (disco de boot).
   
      
 ● Reserved Sectors:


   Setores reservados antes do início da primeira FAT. Se a BPB define como 1,
   é reservado apenas o setor para o bootloader (e para a BPB). Assim, as tabelas
   de alocação de arquivo começam logo depois desse setor (setor de boot). Este
   parâmetro é definido no campo no offset 0x0E do BPB.
   
   Neste projeto é definido apenas 1 setor reservado.


 ● FAT #1 (File Allocation Table #1):


   A tabela FAT é basicamente um vetor de entradas que para cada cluster:
	 
	 
     > Indica o próximo cluster da cadeia.
	 
	 ou ...

     > Um marcador especial:
	 
	   * Fim de arquivo.  
       * Cluster livre.
       * Cluster defeituoso.


   ou seja, ela implementa uma lista encadeada de clusters para cada arquivo.
 
   A FAT deste projeto ocupa 9 setores, informado no offset 0x16 do BPB, portanto:
 
 
     9 × 512 = 4608 bytes


   Entrada da Tabela FAT:
   ---------------------- 
 
   Cada entrada na tabela FAT ocupa 12 bits. Como a tabela FAT deste projeto tem
   4608 bytes, então ela pode ter até:
 

     4608 bytes ⇒ 4608 * 8 = 36864 bits ⇒ 36864 / 12 ⇒ 3072 entradas
 	

   Como cada entrada tem 12 bits, duas entradas ocuparão 3 bytes, sendo 1 byte
   "compartilhado" por ambas, com o nibble alto pertencendo a uma entrada e o
   nibble baixo pertencendo à outra.
   
   O diagrama abaixo representa este esquema em que cada entrada ocupa 1,5 bytes:
   
   
                            ┌─────────────────┐
                          0 │             LSB │ FAT[0]
                            ├────────┐        │ FAT[1]
                          1 │    LSB │ MSB    │ 
                            │        └────────┤
                          2 │ MSB             │
                            ├─────────────────┤
						  3 │             LSB │ FAT[2]
							├────────┐        │ FAT[3]
						  4 │    LSB │ MSB    │
							│        └────────┤
						  5 │ MSB             │
							├─────────────────┤
						  6 │             LSB │ FAT[4]
                            ├────────┐        │ FAT[5]
                          7 │    LSB │ MSB    │ 
                            │        └────────┤
                          8 │ MSB             │
                            ├─────────────────┤
						  9 │                 │
   
   
   Observe no diagrama que os bytes 0, 1 e 2 (à esquerda do diagrama) são usados
   pelas entradas FAT[0] e FAT[1] (à direita do diagrama); os bytes 3, 4 e 5 são
   usados pelas entradas FAT[2] e FAT[3]; os bytes 6, 7 e 8 são usados pelas
   entradas FAT[4] e FAT[5], e assim, sucessivamente.
   
   Via de regra, cada par de entradas da tabela FAT compartilham um mesmo byte 
   desta forma:
   
					
                        Byte 0     Byte 1     Byte 2
                     ┌──────────┬──────────┬──────────┐
                     │ AAAAAAAA │ BBBBAAAA │ BBBBBBBB │
                     └──────────┴───│───│──┴──────────┘
                        8 bits      │   │     8 bits
		           				    │   │
									│   │
									│   └──▶ Nibble baixo (4 bits)
									│
									└──────▶ Nibble alto (4 bits)
   
   
   Cada entrada é uma referência para o próximo cluster da cadeia, por exemplo,
   seja a entrada:
   
   
              ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
              │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 1 │ 0 │ 1 │
              └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
   
   
   O valor 000000000101 em binário representa o número 5. Isso significa que o
   próximo cluster do arquivo é o cluster 5.
   
   Uma entrada da FAT pode indicar também cluster livre, cluster defeituoso ou 
   fim da cadeia, de acordo com os valores na tabela abaixo:
   
   
         ┌───────────────┬──────────────────────────────────────────┐
         │VALOR          │ SIGNIFICADO                              │
         ╞═══════════════╪══════════════════════════════════════════╡
         │ 0x000         │ Cluster livre                            │
         ├───────────────┼──────────────────────────────────────────┤
         │ 0x001         │ Reservado                                │
         ├───────────────┼──────────────────────────────────────────┤
         │ 0x002-0xFEF   │ Número do próximo cluster da cadeia      │
         ├───────────────┼──────────────────────────────────────────┤
         │ 0xFF0-0xFF6   │ Reservado                                │
         ├───────────────┼──────────────────────────────────────────┤
         │ 0xFF7         │ Cluster defeituoso                       │
         ├───────────────┼──────────────────────────────────────────┤
         │ 0xFF8-0xFFF   │ Fim da cadeia                            │
         └───────────────┴──────────────────────────────────────────┘
   
   
   Desta tabela, já é possível deduzir que os clusters 0x000 e 0x001 são inacessíveis.
   Clusters válidos começam em 0x002 e vão até 0xFEF.
      
 
 ● FAT #2 (File Allocation Table #2):
 
 
   Cópia de backup da FAT #1, para o caso de esta apresentar algum problema.
 
 
 ● Root Directory:
 
 
   Estrutura do diretório principal.
 


 ● Data Area:
 
 
=============================================================================*/


/**
 * 
 * Esta função:
 * 
 *   > Localiza onde está a entrada FAT12 de um cluster.
 * 
 *   > Decide se ele é par ou ímpar.
 * 
 *   > Insere os 12 bits corretamente.
 * 
 *   > Preserva os bits do cluster vizinho.
 * 
 * @param disk Buffer do disco na memória.
 * 
 * @param fat_offset Offset da entrada na FAT.
 * 
 */
void set_fat_entry(unsigned char *disk, uint32_t fat_offset, int cluster, int value) {
	
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


int get_fat_entry(unsigned char *disk, uint32_t fat_offset, int cluster) {
	
    uint32_t idx = fat_offset + (cluster * 3) / 2;

    uint16_t val;

    if (cluster % 2 == 0) {
        val = disk[idx] | ((disk[idx + 1] & 0x0F) << 8);
    } else {
        val = ((disk[idx] & 0xF0) >> 4) | (disk[idx + 1] << 4);
    }

    return val & 0x0FFF;

}


int find_free_cluster(unsigned char *disk, uint32_t fat_offset, int max_cluster) {
	
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


int set_root_entry(unsigned char *disk, uint32_t root_offset, const char *name,
uint16_t cluster, uint32_t size) {
	
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

int create_fat12_disk_image(const char *bootloader_path, const char *testcode_path,
const char *output_path) {
	
    unsigned char *disk = calloc(DISK_SIZE, 1);
    
	if (!disk) return 1;

    FILE *file = fopen(bootloader_path, "rb");
    
	if (!file) { 
		free(disk); 
		return 1; 
	}

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

    const uint32_t root_offset = (reserved_sectors + fats * sectors_per_fat) * SECTOR_SIZE;

    const uint32_t root_size_bytes = root_entries * 32;

    const uint32_t data_offset = ((root_offset + root_size_bytes + SECTOR_SIZE - 1) / SECTOR_SIZE) * SECTOR_SIZE;

    uint32_t total_sectors = DISK_SIZE / SECTOR_SIZE;
	
    uint32_t data_sectors = total_sectors - (reserved_sectors + fats * sectors_per_fat + (root_size_bytes / SECTOR_SIZE));
    
	uint32_t max_cluster = data_sectors + 1;

    memset(&disk[fat1_offset], 0, sectors_per_fat * SECTOR_SIZE);
    memset(&disk[fat2_offset], 0, sectors_per_fat * SECTOR_SIZE);

    disk[fat1_offset] = 0xF0;
    disk[fat1_offset + 1] = 0xFF;
    disk[fat1_offset + 2] = 0xFF;

    file = fopen(testcode_path, "rb");
	
    if (!file) { 
		free(disk); 
		return 1; 
	}

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