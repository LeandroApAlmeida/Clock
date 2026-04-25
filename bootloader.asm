; ═════════════════════════════════════════════════════════════════════════════
;                                  BOOTLOADER
; ═════════════════════════════════════════════════════════════════════════════
;
; Bootloader para sistemas que utilizam o antigo firmware BIOS. Ele carrega 
; na memória um kernel simples, que fará uma única coisa: mostrar a hora e a
; data do sistema atualizada no monitor.
;
; Nota:
;
; Toda a documentação deste projeto visa a descrição do funcionamento de um
; processador x86 clássico, não um sistema moderno.
;
; ═════════════════════════════════════════════════════════════════════════════

        
[BITS 16]                         ; O bootloader roda em Modo Real (16-bit).

[ORG 0x7C00]                      ; Endereço de memória padrão onde o BIOS 
                                  ; carrega o bootloader (0x7C00).




; =============================================================================
;
; PRIMEIRA INSTRUÇÃO
;
;
; A instrução "jmp short start" é a primeira instrução executada pelo processador 
; quando o controle do programa for entregue para o bootloader. Mas ela não é a
; primeira instrução que o processador executa quando o computador é ligado.
;
; Ao pressionar o botão liga/desliga do computador:
;
;
; 1. A fonte de alimentação é ligada e começa a estabilizar suas tensões. Leva 
;    entre 100ms e 500ms para estabilizar as tensões de 3.3V, 5V e 12V. Durante
;    esse período, o sinal Power Good (PWR_OK) da fonte permanece inativo. Com 
;    PWR_OK inativo, o chipset (ou o controlador de sistema) mantém o sinal de
;    RESET# do processador em 0V (Low). Enquanto o sinal RESET# está em 0V (ativado),
;    o processador é mantido em estado de reset. Ele está ligado, porém "congelado",
;    não executando nenhuma instrução.
;
;    Se o processador tentasse processar dados com uma voltagem instável e abaixo
;    do valor requerido, os transistores poderiam alternar estados de forma errática
;    e ele executaria instruções corrompidas, levando a erros e travamento. Dessa 
;    forma, o sinal RESET# funciona como uma "trava de segurança" elétrica, que
;    impede o processador de executar instruções espúrias devido à baixa tensão 
;    nos circuitos do computador (Brownout).
;
;    O chipset monitora o sinal Power Good. Quando a fonte indica que as tensões
;    estão estáveis, ativando este sinal, após um curto intervalo para estabilização
;    dos osciladores (clock), ele desativa o sinal RESET# (High, uma tensão de 3.3V
;    ou 5V), liberando o processador para executar instruções.
;
;
; 2. O sinal RESET# faz com que o processador entre em um estado inicial definido
;    pela arquitetura x86. Assim que é liberado do reset, o processador:
;
;      > Está em Modo Real (para compatibilidade com o Intel 8086).
;    
;      > Flags (EFLAGS/FLAGS) estão em estados conhecidos:
;
;          IF = 0 → Interrupções mascaráveis desabilitadas.
;          TF = 0 → Sem debug step.
;          DF = 0 → Operações de string incrementam.
;
;        (demais bits em estado definido pelo hardware).
;
;      > Registradores Segmento de Código (CS) e Ponteiro de Instrução (IP) estão
;        com valores pré-definidos:
;
;          CS = 0xF000
;          IP = 0xFFF0
;
;      > Registrador Stack Pointer (SP) está em estado indefinido.
;
;      > Registradores de uso geral (AX, BX, CX, DX), de índice (SI, DI, BP)
;        e de segmento (DS, ES, SS) estão em estado indefinido.
;
;      > Prefetch queue inicia está vazia e é preenchida após o primeiro fetch de
;        instrução.
;
;      Nota: Consulte a documentação de cada processador para verificar os 
;      detalhes exatos da configuração inicial após o reset.
;
;    Com os registradores de Segmento de Código (CS) e Ponteiro de Instrução (IP)
;    configurados como CS = 0xF000 e IP = 0xFFF0, o primeiro endereço lógico
;    executado pelo processador é representado pelo par CS:IP = 0xF000:0xFFF0. 
;
;    Em Modo Real, o acesso à memória física é feito de modo segmentado, sendo
;    o endereço em um segmento calculado pelo par Segment:Offset. Para calcular
;    o endereço apontado pelo par 0xF000:0xFFF0, o processador vai aplicar a
;    seguinte equação: 
;
;                  Physical Address = Segment × 0x10 + Offset
;
;    Onde:
;
;        Physical Address: Endereço físico de memória calculado para o par Segment:Offset. 
;        Este endereço é um valor de 20 bits em Modo Real clássico (8086).
;
;        Segment: Multiplicador utilizado para calcular o endereço físico de um 
;        segmento. No par 0xF000:0xFFF0, ele é o valor de CS (0xF000). Para achar
;        o endereço físico fazemos: 0xF000 × 0x10 = 0xF0000. Neste caso, 0xF0000
;        é o endereço inicial do segmento.
;
;        Offset: É o deslocamento com relação ao endereço inicial do segmento,
;        apontado por Segment. No par 0xF000:0xFFF0, ele é o valor de IP (0xFFF0). 
;        Calculando o endereço físico do offset: 0xF0000 + 0xFFF0 = 0xFFFF0.
;
;            Segment (CS × 0x10)                           Offset (IP)
;            ↓                                             ↓
;        ┌───────┬───────┬───────┬───────┬─   ─┬───────┬───────┬───────┬──                                       
;        │#######│#######│#######│#######│ ... │#######│#######│#######│
;        └───────┴───────┴───────┴───────┴─   ─┴───────┴───────┴───────┴──
;        |0xF0000|0xF0001|0xF0002|0xF0003| ... |0xFFFEF|0xFFFF0|0xFFFF1|
;          
;    Sintetizando o cálculo do par 0xF000:0xFFF0:
;
;        Physical Address = 0xF000 × 0x10 + 0xFFF0
;        Physical Address = 0xF0000 + 0xFFF0
;        Physical Address = 0xFFFF0
;
;    Podemos representar o segmento apontado pelo registrador CS, chamado de Segmento 
;    de Código, em um diagrama. Este segmento contém as instruções que o processador
;    busca e executa (programa).
;
;                               Memória RAM
;                           │                 │
;                           │                 │
;                         ┬ │─────────────────│ 0xFFFFF ← Endereço Final do 
;                         │ │                 │           segmento
;                         │ │                 │      
;                         │ │-----------------│ 0xFFFF0 ← IP (Offset)
;               Segmento  │ │                 │
;               de Código │ │                 │
;                         │ │                 │
;                         │ │                 │
;                         │ │                 │
;                         │ │                 │
;                         │ │                 │
;                         │ │                 │
;                         ┴ │─────────────────│ 0xF0000 ← CS (Endereço inicial 
;                           │                 │           do segmento)
;                           │                 │
;
;
;    O endereço 0xFFFF0 calculado para 0xF000:0xFFF0 é chamado de reset vector,
;    e está localizado próximo ao topo da memória endereçável em Modo Real.
;
;                               Memória RAM
;                       │                         │
;                       │ Free                    │
;                       │                         │
;                       │─────────────────────────│ 0xFFFFF ← Topo da memória
;                       │                         │           endereçável em
;                       │ Reset Vector (16 bytes) │           Modo Real (1MB)
;                       │                         │ 
;                       │-------------------------│ 0xFFFF0 ← IP (Offset 0xFFF0)
;                       │                         │
;                       │ Região Mapeada BIOS ROM │
;                       │                         │
;                       │                         │
;                       │                         │
;                       │                         │
;
;    A partir desse ponto, o processador inicia o primeiro ciclo de fetch (busca
;    de instrução), colocando esse endereço no barramento e solicitando a leitura
;    da memória. Esse endereço não corresponde à RAM, mas sim a uma região mapeada 
;    pela placa-mãe para um chip de memória não volátil (ROM), onde reside o firmware
;    do sistema, conhecido como BIOS (Basic Input/Output System). Esse mapeamento
;    segue o princípio de memória mapeada (memory-mapped), onde dispositivos são 
;    acessados via endereços de memória (semelhante ao MMIO, descrito no código-fonte
;    do Kernel). O chipset da placa-mãe é responsável por decodificar o endereço 
;    colocado no barramento e selecionar a ROM de firmware quando o intervalo 
;    correspondente ao BIOS é acessado.
;
;    A primeira instrução encontrada no endereço 0xFFFF0 é tipicamente uma instrução
;    de salto, por exemplo "jmp far F000:E05B", que redireciona a execução para 
;    outra área dentro da ROM onde o código principal do BIOS está localizado.
;    Isso ocorre porque o espaço disponível no topo da memória (16 bytes) é muito
;    pequeno para conter mais do que um ponto de entrada mínimo.
;
;    Nesse estágio inicial, o processador opera em Modo Real (16-bit), com um 
;    espaço de endereçamento limitado a 1 MB, sem suporte a proteção de memória
;    ou recursos avançados. A memória A RAM ainda não foi testada nem configurada
;    pelo firmware, e não há ainda uma pilha confiável configurada. O código inicial
;    do BIOS é responsável por estabelecer um ambiente mínimo de execução, incluindo
;    a configuração inicial do chipset, a detecção e inicialização da memória RAM
;    e a preparação para a execução de rotinas mais complexas.
;
;
; 3. Após a execução do JMP no reset vector, o processador sai da região mínima
;    de 16 bytes e entra no ponto de entrada real do firmware BIOS na ROM (memória 
;    não volátil mapeada no espaço de endereçamento).
;
;    Nesse momento, o registrador CS já foi recarregado (via far jump), e o cálculo 
;    de endereços volta ao comportamento normal do Modo Real:
;
;                  Physical Address = Segment × 0x10 + Offset
;
;    A primeira ação do BIOS é estabilizar um ambiente mínimo de execução. Isso
;    geralmente inclui a desativação de interrupções (instrução CLI), garantindo
;    controle total do firmware enquanto estruturas críticas são preparadas.
;
;    Embora o estado inicial já venha com IF = 0 após o reset, o uso explícito
;    de CLI reforça a garantia de que nenhuma interrupção mascarável ocorrerá
;    durante essa fase sensível de inicialização.
;
;    Em seguida, o firmware estabelece um contexto mínimo de execução:
;
;      > Reconfigura registradores de segmento (DS, ES, SS), apontando para regiões
;        conhecidas e seguras (RAM baixa ou áreas do próprio firmware)
;
;      > Inicializa uma pilha temporária (stack), etapa essencial para permitir
;        chamadas de função (CALL/RET), uso de interrupções e armazenamento de
;        estados intermediários
;
;    --------------------------------------------------------------------------
;    Nota: O valor inicial de SP após o reset não é confiável, portanto a pilha
;    precisa ser explicitamente definida antes de qualquer uso estruturado.
;    --------------------------------------------------------------------------
;
;    Com o contexto básico estabelecido, o BIOS inicia a configuração do chipset
;    (em arquiteturas clássicas, northbridge/southbridge). Essa etapa envolve:
;
;      > Inicialização de controladores de barramento (ISA, PCI).
;
;      > Configuração preliminar do controlador de memória.
;
;      > Definição de regiões de memória mapeada (incluindo ROM e dispositivos).
;
;    A memória RAM já é eletricamente acessível, mas ainda não foi validada. O
;    BIOS realiza uma configuração inicial suficiente para permitir acessos estáveis,
;    mesmo antes do teste completo.
;
;    Com processador, barramentos e acesso inicial à memória disponíveis, o BIOS entra
;    na fase de POST (Power-On Self-Test).
;
;    O POST consiste em uma sequência estruturada de inicializações e verificações
;    que pode variar entre implementações, mas geralmente inclui:
;
;      > Inicialização do subsistema de temporização (timer do sistema).
;
;      > Configuração do controlador de interrupções (PIC e/ou APIC).
;
;      > Preparação da Interrupt Vector Table (IVT) em 0x0000:0x0000.
;
;      > Inicialização do controlador de memória (Memory Controller / chipset),
;        estabelecendo timings básicos e mapeamento inicial da RAM.
;
;      > Teste básico de memória (Base RAM check), geralmente verificando os primeiros
;        blocos de memória convencional (ex: abaixo de 1 MB).
;
;      > Inicialização da BIOS Data Area (BDA) e Extended BIOS Data Area (EBDA), 
;        incluindo estruturas de estado de hardware.
;
;      > Inicialização do subsistema de vídeo (VGA BIOS / Option ROM), podendo 
;        configurar modo texto (ex: 03h) ou modo gráfico básico.
;
;      > Inicialização do teclado e controlador 8042 (ou equivalente), incluindo
;        teste de presença e reset do estado.
;
;      > Inicialização de dispositivos de armazenamento básicos (controladores 
;        IDE/SATA/ATA legacy), quando aplicável.
;
;      > Enumeração do barramento PCI e detecção de dispositivos conectados.
;
;      > Execução de Option ROMs presentes em dispositivos (ex: GPU, RAID, controladores
;        de rede), permitindo extensão do firmware.
;
;      > Inicialização de dispositivos de entrada/saída básicos (serial, paralela,
;        USB legacy em BIOS mais modernas).
;
;      > Verificação de integridade básica do sistema (checksum de BIOS ROM e testes
;        iniciais de hardware crítico).
;
;      > Configuração de parâmetros de sistema e tabelas de hardware (ex: memória 
;        detectada, mapas de recursos, ACPI tables em sistemas mais novos).
;
;      > Exibição de mensagens de diagnóstico do POST e códigos de erro (beep codes
;        ou POST codes via porta 0x80).
;
;    A ordem e configurações exatas variam conforme a implementação do BIOS, logo,
;    esta lista é apenas uma generalização do processo de POST. Após a conclusão
;    dessas etapas, o firmware transfere controle para o processo de boot.
;
;
; 4. Ao final do POST, com CPU, memória RAM, subsistema de vídeo e controladores
;    básicos devidamente inicializados e validados, o BIOS entra na fase de seleção 
;    de dispositivo de boot. Nessa etapa, o firmware consulta uma lista de prioridade
;    armazenada em memória CMOS/firmware setup, conhecida como boot order, que
;    define a sequência de dispositivos a serem testados como possíveis fontes
;    de inicialização (por exemplo: disquete, disco rígido, CD-ROM, dispositivos
;    USB ou rede em implementações mais avançadas).
;
;    O BIOS então percorre essa lista sequencialmente, enviando comandos básicos
;    de leitura para cada dispositivo através de seus respectivos controladores 
;    (INT 13h no caso de discos em BIOS legado). O objetivo é identificar se o 
;    dispositivo contém uma estrutura válida de inicialização. Em discos com esquema
;    MBR (Master Boot Record), o BIOS realiza a leitura do primeiro setor, chamado
;    de Setor MBR (primeiro setor lógico do dispositivo - LBA 0), que possui exatamente 
;    512 bytes. O setor MBR é então carregado para um endereço fixo de memória
;    RAM, convencionalmente 0x7C00. O BIOS não interpreta o conteúdo desse setor
;    em profundidade. Normalmente, ele apenas verifica se os dois últimos bytes
;    contêm a assinatura de boot válida (Boot Signature), indicando que o dispositivo 
;    é inicializável.
;
;    Uma vez carregado o setor de boot na memória, o BIOS prepara o ambiente mínimo
;    de execução necessário para transferir o controle do programa. Isso inclui
;    garantir que os registradores de segmento estejam em um estado consistente
;    e que a execução continue em modo real, sem mecanismos de proteção ou abstração.
;
;    Por fim, o BIOS realiza o salto para o endereço 0x7C00, transferindo o controle
;    do programa para o código contido no setor de boot. A partir desse momento, 
;    o BIOS deixa de ter controle ativo sobre o fluxo do sistema, e o código do 
;    bootloader assume total controle da próxima etapa do processo de inicialização,
;    que normalmente envolve o carregamento de um bootloader mais complexo (no
;    caso de um bootloader de múltiplos estágios) ou diretamente do kernel do 
;    sistema operacional.
;
; 
; Como descrito acima, há uma série de etapas que são realizadas antes que o
; jump abaixo seja executado pelo processador.
;        
; =============================================================================


jmp short start                   ; O uso deste jump alinha as instruções do 
nop                               ; bootloader. Como a imagem gerada está em
                                  ; RAW Format, não definiremos uma BPB/EBPB
								  ;
								  ; (Veja mais detalhes no final do arquivo)




; =============================================================================
;
; PONTO DE ENTRADA DO BOOTLOADER (OFFSET 0x03)
;
;
; Configura os registradores de segmento e a pilha do bootloader. A pilha utilizará
; a região da memória baixa entre BIOS Data Area e o endereço onde o bootloader
; foi carregado pelo BIOS após o POST (0x7C00). Embora essa região da memória não 
; seja formalmente garantida como livre, ela é geralmente segura para usar como 
; pilha.
;
; Para localizar a região da pilha na memória, veja no diagrama abaixo como esta
; estará organizada no momento em que o bootloader é carregado pelo BIOS e começa
; a executar:
;
;
;                                 Memória RAM
;                         │                         │
;                         │ Free                    │
;                         │─────────────────────────│ 0x100000
;                         │ BIOS                    │
;                         │-------------------------│ 0xC0000
;                         │ Video Memory            │
;                         │-------------------------│ 0xA0000
;                         │ Extended BIOS Data Area │
;                         │─────────────────────────│ 0x9FC00
;                         │ Free (622.080 bytes) ###│
;                         │─────────────────────────│ 0x7E00
;                         │ Bootloader              │          
;                      ┬  │─────────────────────────│ 0x7C00
;                      │  │ Free (30.464 bytes) ####│
;                      ┴  │─────────────────────────│ 0x500
;                         │ BIOS Data Area          │
;                         │-------------------------│ 0x400
;                         │ Interrupt Vector Table  │
;                         └─────────────────────────┘ 0x0
;
;
; Note que há duas regiões livres de memória que podem ser utilizadas para a pilha:
;
;
;   ● Região entre BIOS Data Area e o Bootloader (em destaque): Esta é a região
;     que escolhemos. Ela tem 30.464 bytes. 
;
;
;   ● Região entre Bootloader e Extended BIOS Data Area: Nesta região de memória,
;     ao centro do diagrama, que será carregado o kernel do relógio. Ela tem
;     622.080 bytes (o endereço de início da EBDA é comumente 0x9FC00, mas para
;     ser preciso, esse valor tem de ser lido do endereço de memória 0x040E, dentro
;     da BDA, pois isso pode variar dependendo do BIOS).
;
;
; Para delimitar o segmento de pilha, definiremos o registrador SS (base do segmento)
; como 0x0000 (início da memória) e o SP (topo da pilha) como 0x7C00 (endereço 
; inicial do bootloader). Definindo SP no offset 0x7C00 do segmento, ao empilhar
; os dados (push), eles serão armazenados nos endereços 0x7BFF, 0x7BFE, 0x7BFD,
; 0x7BFC e assim, sucessivamente. 
;
; Ao contrário dos demais segmentos, no segmento de pilha a memória cresce para
; baixo, o que impede que a pilha invada a região de memória do próprio bootloader, 
; carregado no mesmo endereço apontado por SP.
; 
;
;                                Memória RAM
;
;                         │                        │ 
;                         │       Bootloader       │
;                         │                        │
;                      ┬  │────────────────────────│ ← SP (0x7C00)
;                      │  │                        │  (↓ push ↑ pop)
;                Pilha │  │          Free          │  
;                      │  │                        │  
;                      ┴  │────────────────────────│  
;                         │                        │  
;                         │     BIOS Data Area     │  
;                         │                        │  
;                         │────────────────────────│  
;                         │                        │  
;                         │ Interrupt Vector Table │  
;                         │                        │  
;                         └────────────────────────┘ ← SS (0x0000)
;
;
; Teoricamente, a pilha poderia crescer até sobrescrever a BIOS Data Area (BDA)
; e a Interrupt Vector Table (IVT), o que causaria a falha do sistema (Stack  
; corruption). Mas a região livre escolhida para ela ocupar é muitas vezes maior
; que o estimado que o bootloader vai utilizar. Assim, a não ser que se escreva
; no meio do código algo como:
;
;
;     mov eax, 0x10    (Grava o valor 0x10 em EAX)
;
;     push_loop:       (Rótulo para o início do loop)
;
;     push eax         (Empilha o valor de EAX)
;
;     jmp push_loop    (Volta para o início do loop).
;
;
; com o assembly atual será impossível acontecer este tipo de erro.
;
; =============================================================================


start:

	cli                           ; Desabilita as interrupções mascaráveis.

	mov [drive_number], dl        ; Grava o número do drive de boot (0x00: disquete,
                                  ; 0x80: HD, etc) na variável drive_number, fazendo
								  ; a leitura do valor gravado pelo BIOS no registrador
								  ; DL.
	
    xor ax, ax                    ; Zera o registrador AX aplicando uma operação
                                  ; XOR dele com ele mesmo.
									   
    mov ds, ax                    ; Define o valor do registrador de segmento
                                  ; de dados DS como zero.
	
    mov es, ax                    ; Define o valor do registrador de segmento
                                  ; de dados ES como zero.
								  
	mov fs, ax                    ; Define o valor do registrador de segmento
                                  ; de dados FS como zero.
	
	mov gs, ax                    ; Define o valor do registrador de segmento
                                  ; de dados GS como zero.
	
    mov ss, ax                    ; Define o valor do registrador de segmento
	                              ; de pilha SS (base da pilha) como zero.
	
    mov sp, 0x7C00                ; Define o valor do registrador de offset
	                              ; SP (topo da pilha) como 0x7C00. A pilha
								  ; passa a ocupar o segmento 0x0000:0x7C00.
								  
	sti                           ; Reabilita as interrupções mascaráveis.



		
; =============================================================================
;
; CONFIGURAÇÃO DO MODO DE TEXTO VGA 3H
;
;
; Configura o modo de texto VGA 3H, com 80 colunas x 25 linhas, 16 cores de texto
; e 8 cores de fundo. Este já é o modo padrão usado pelo BIOS, mas reaplicamos
; a configuração aqui.
;
; Este modo de texto usa a região de memória que inicia no endereço 0xB8000 e
; termina no endereço 0xB8F9F. Cada caractere gravado nesta região ocupa 2 bytes,
; num total de 2.000 caracteres (80 colunas x 25 linhas).
;
; Os bytes que compõem cada caractere no Modo 3h são:
;
;
;   ● Byte baixo: Índice do caractere na tabela Code Page 437.
;
;
;   ● Byte alto: Atributos de cor e estado do caractere.
;
;
; Tomemos como exemplo o caractere 0x1F20 (0b0001111100100000), que será gravado
; na tela para preencher os espaços vazios que não contém a string da hora e data.
; Este caractere é composto pelos bytes:
;
;
;                  Byte alto = 0x1F    Byte baixo = 0x20
;                         ↓                    ↓
;                   0   001   1111          00100000  
;                  |B| |BC | | FC |        | CP437  |
; 
;
;   ● Byte baixo (CP437): Valor 0x20 (0b00100000).
;
;     É o índice na tabela Code Page 437 para o caractere espaço (' ').
;
;     A tabela Code Page 437 contém os seguintes caracteres:
;
;
;     ┌────────────────────────────────────────────────────────────────┐
;     │ Tabela Code Page 437 (CP437)                                   │         
;     ├────────────────────────────────────────────────────────────────┤
;     │                                                                │
;     │  00 ☺    01 ☻    02 ♥    03 ♦    04 ♣    05 ♠    06 •    07 ◘  │
;     │  08 ○    09 ◙    0A ◙    0B ♂    0C ♀    0D ♪    0E ♫    0F ☼  │
;     │  10 ►    11 ◄    12 ↕    13 ‼    14 ¶    15 §    16 ▬    17 ↨  │
;     │  18 ↑    19 ↓    1A →    1B ←    1C ∟    1D ↔    1E ▲    1F ▼  │
;     │  20 ' '  21 !    22 "    23 #    24 $    25 %    26 &    27 '  │
;     │  28 (    29 )    2A *    2B +    2C ,    2D -    2E .    2F /  │
;     │  30 0    31 1    32 2    33 3    34 4    35 5    36 6    37 7  │
;     │  38 8    39 9    3A :    3B ;    3C <    3D =    3E >    3F ?  │
;     │  40 @    41 A    42 B    43 C    44 D    45 E    46 F    47 G  │
;     │  48 H    49 I    4A J    4B K    4C L    4D M    4E N    4F O  │
;     │  50 P    51 Q    52 R    53 S    54 T    55 U    56 V    57 W  │
;     │  58 X    59 Y    5A Z    5B [    5C \    5D ]    5E ^    5F _  │
;     │  60 `    61 a    62 b    63 c    64 d    65 e    66 f    67 g  │
;     │  68 h    69 i    6A j    6B k    6C l    6D m    6E n    6F o  │
;     │  70 p    71 q    72 r    73 s    74 t    75 u    76 v    77 w  │
;     │  78 x    79 y    7A z    7B {    7C |    7D }    7E ~    7F ⌂  │
;     │  80 Ç    81 ü    82 é    83 â    84 ä    85 à    86 å    87 ç  │
;     │  88 ê    89 ë    8A è    8B ï    8C î    8D ì    8E Ä    8F Å  │
;     │  90 É    91 æ    92 Æ    93 ô    94 ö    95 ò    96 û    97 ù  │
;     │  98 ÿ    99 Ö    9A Ü    9B ¢    9C £    9D ¥    9E ₧    9F ƒ  │
;     │  A0 á    A1 í    A2 ó    A3 ú    A4 ñ    A5 Ñ    A6 ª    A7 º  │
;     │  A8 ¿    A9 ⌐    AA ¬    AB ½    AC ¼    AD ¡    AE «    AF »  │
;     │  B0 ░    B1 ▒    B2 ▓    B3 │    B4 ┤    B5 ╡    B6 ╢    B7 ╖  │
;     │  B8 ╕    B9 ╣    BA ║    BB ╗    BC ╝    BD ╜    BE ╛    BF ┐  │
;     │  C0 └    C1 ┴    C2 ┬    C3 ├    C4 ─    C5 ┼    C6 ╞    C7 ╟  │
;     │  C8 ╚    C9 ╔    CA ╩    CB ╦    CC ╠    CD ═    CE ╬    CF ╧  │
;     │  D0 ╨    D1 ╤    D2 ╥    D3 ╙    D4 ╘    D5 ╒    D6 ╓    D7 ╫  │
;     │  D8 ╪    D9 ┘    DA ┌    DB █    DC ▄    DD ▌    DE ▐    DF ▀  │
;     │  E0 α    E1 ß    E2 Γ    E3 π    E4 Σ    E5 σ    E6 µ    E7 τ  │
;     │  E8 Φ    E9 Θ    EA Ω    EB δ    EC ∞    ED φ    EE ε    EF ∩  │
;     │  F0 ≡    F1 ±    F2 ≥    F3 ≤    F4 ⌠    F5 ⌡    F6 ÷    F7 ≈  │
;     │  F8 °    F9 ∙    FA ·    FB √    FC ⁿ    FD ²    FE ■    FF    │
;     │                                                                │
;     └────────────────────────────────────────────────────────────────┘
;
;     * Índice do caractere à esquerda, grifo à direita. 
;
;
;   ● Byte alto (atributos): Valor 0x1F (0b00011111).
;
;     São os atributos de cor e estado.
;
;     O byte alto é dividido em:
;
;     > FC (Foreground Color): Bits 0-3.
;
;       Cor do texto. Valor: 0xF (Branco).
;
;     > BC (Background Color): Bits 4-6.
;
;       Cor de fundo. Valor: 0x1 (Azul).
;   
;     > B (Blink): Bit 7.
;
;       Bit de Piscar. Valor: 0 (desligado). 
;       Se valor = 1, o texto vai piscar. 
; 
;     Os bits de cor de texto e de fundo no modo 3H são índices para a paleta de
;     cores padrão do VGA (Standard VGA Palette):
;     
;
;     ┌─────────────────────────────────────────────────────────────────┐
;     │ Standard VGA Palette                                            │         
;     ├────────────────────────────────┬────────────────────────────────┤
;     │ 0x0  Preto                     │ 0x8  Cinza Escuro              │    
;     │ 0x1  Azul (x)                  │ 0x9  Azul Claro                │    
;     │ 0x2  Verde                     │ 0xA  Verde Claro               │    
;     │ 0x3  Ciano                     │ 0xB  Ciano Claro               │
;     │ 0x4  Vermelho                  │ 0xC  Vermelho Claro            │
;     │ 0x5  Magenta                   │ 0xD  Magenta Claro             │
;     │ 0x6  Marrom                    │ 0xE  Amarelo                   │
;     │ 0x7  Cinza Claro               │ 0xF  Branco (x)                │
;     └────────────────────────────────┴────────────────────────────────┘
;
;     * Os índices destacados com um (x) são os que são utilizados pelo caractere
;       0x1F20 que estamos mostrando como exemplo.
;
;
;     Por padrão, a cor de texto (FC) pode indexar qualquer uma das 16 cores da
;     paleta, pois usa 4 bits para definir este atributo (2^4 = 16). A cor de fundo 
;     (BC), como usa apenas 3 bits (2^3 = 8), pode indexar as cores de 0x0 a 0x7
;     no primeiro quadro (cores escuras).
;
;
; Nota:
;
; É possível alterar a configuração padrão e desativar o bit de blink (B) usando
; a interrupção do BIOS:
;
;
;     mov ax, 0x1003
; 
;     mov bl, 0x00
; 
;     int 0x10
;
;
; Dessa forma, passa a ser possível usar 4 bits para cor de fundo (bits 4-7),
; passando a acessar todos os índices da paleta.
;
; =============================================================================


set_vga_text_mode:

    mov ah, 0x00                  ; Define a função do BIOS como 0x00 (Set Video
	                              ; Mode).
	
    mov al, 0x03                  ; Define o modo de texto como 0x03 (80 colunas
	                              ; 25 linhas). 								  
	
    int 0x10                      ; Executa a interrupção de vídeo do BIOS, para
	                              ; aplicar o modo de vídeo selecionado.


						

; =============================================================================
;
; CARREGAMENTO DO KERNEL
;
;
; Carrega a imagem do kernel na memória. O binário do kernel inicia no segundo 
; setor do disco e ocupa um total de 10 setores (5120 bytes).
;
; O kernel será carregado a partir do endereço 0x7E00, logo adiante do bootloader.
; No diagrama abaixo vemos como fica a memória baixa do computador após ele ser 
; carregado:
;
;
;                                 Memória RAM
;                         │                         │
;                         │ Free                    │
;                         │-------------------------│ 0x100000
;                         │ BIOS                    │
;                         │-------------------------│ 0xC0000
;                         │ Video Memory            │
;                         │-------------------------│ 0xA0000
;                         │ Extended BIOS Data Area │
;                         │-------------------------│ 0x9FC00
;                         │ Free                    │
;                      ┬  │─────────────────────────│ 0x8E00
;                      │  │ Kernel (5120 bytes)     │ 
;                      ┴  │─────────────────────────│ 0x7E00
;                         │ Bootloader              │          
;                         │-------------------------│ 0x7C00
;                         │ Pilha                   │
;                         │-------------------------│ 0x500
;                         │ BIOS Data Area          │
;                         │-------------------------│ 0x400
;                         │ Interrupt Vector Table  │
;                         └─────────────────────────┘ 0x0
;
;
; Os primeiros 32 bytes do binário do kernel é a sua assinatura (kernel Signature). 
; Será feito a verificação se o carregamento teve sucesso validando esta assinatura, 
; desta forma:
;
;
;   ● O bootloader tem uma cópia da assinatura do kernel na variável "kernel_sign",
;     que ele utilizará para comparar com a que está na memória.
;
;
;   ● Antes de carregar o kernel, o bootloader grava 0x0 em todos os 32 bytes entre
;     os endereços 0x7E00 e 0x7E1F. Dessa forma, não haverá o risco de ter valores
;     espúrios na região de memória que receberá a assinatura do kernel.
;
;
;   ● O bootloader executa a função do BIOS que carrega os 10 setores do kernel 
;     para a região vazia de memória começando no endereço 0x7E00 (o kernel ocupará
;     os endereços de 0x7E00 até 0x91FF).
;
;
;   ● Após o carregamento do kernel, o bootloader valida a assinatura, da seguinte
;     forma:
;
;
;     ❂ Passo 1: Byte0 de kernel_sign = Byte no endereço 0x7E00 (Byte0 = Byte[0x7E00])
;
;     ↪ Se sim, passa para a comparação do próximo byte.
;
;     ↪ Se não, as assinaturas não correspondem. Aborta e tenta carregar a imagem 
;       do kernel novamente.
;
;
;     ❂ Passo 2: Byte1 de kernel_sign = Byte no endereço 0x7E01 (Byte1 = Byte[0x7E01])
;
;     ↪ Se sim, passa para a comparação do próximo byte.
;
;     ↪ Se não, as assinaturas não correspondem. Aborta e tenta carregar a imagem
;       do kernel novamente.
;
; 
;     [ ... a comparação dos bytes de 2 a 30 seguem o mesmo processo ... ]
;
;
;     ❂ Passo 32: Byte31 de kernel_sign = Byte no endereço 0x7E1F (Byte31 = Byte[0x7E1F])
;
;     ↪ Se sim, a assinatura do kernel é válida. Continua a execução das próximas
;       etapas.
;
;     ↪ Se não, as assinaturas não correspondem. Aborta e tenta carregar a imagem
;       do kernel novamente.
;
;
;     A assinatura do kernel tem os seguintes bytes:
;
;
;     0xDE 0xAD 0xBE 0xEF 0x01 0x23 0x45 0x67 0x89 0xAB 0xCD 0xEF 0x10 0x32 ...
;     0x54 0x76 0x98 0xBA 0xDC 0xFE 0x11 0x22 0x33 0x44 0x55 0x66 0x77 0x88 ...
;     0x99 0xAA 0xBB 0xCC
;
;
;     Observe no diagrama abaixo que cada byte da cópia da assinatura, gravada na
;     variável kernel_sign, deve ter o mesmo valor que o respectivo byte na memória
;     do kernel, iniciando no endereço 0x7E00 (Assinatura do Kernel).
;
;
;                  ┬ ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬─  
;      Cópia da    │ │ 0xDE │ 0xAD │ 0xBE │ 0xEF │ 0x01 │ 0x23 │ 0x45 │  → Byte   
;     Assinatura   │ └──────┴──────┴──────┴──────┴──────┴──────┴──────┴─  
;    (kernel_sign) │ |Byte0 |Byte1 |Byte2 |Byte3 |Byte4 |Byte5 |Byte6 |  → Posição
;                  ┴
;      
;                  ┬ ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬─  
;     Assinatura   │ │ 0xDE │ 0xAD │ 0xBE │ 0xEF │ 0x01 │ 0x23 │ 0x45 │  → Byte   
;     do Kernel    │ └──────┴──────┴──────┴──────┴──────┴──────┴──────┴─  
;    (Na memória)  │ |0x7E00|0x7E01|0x7E02|0x7E03|0x7E04|0x7E05|0x7E06|  → Endereço
;                  ┴ 
;
;
;     O algoritmo compara o par de bytes, se são iguais (têm os mesmos bits). Se
;     são iguais, campara o próximo par. Se são diferentes, aborta o processo de
;     validação e tenta carregar o kernel novamente. Se no PASSO 32, o 32º par 
;     de bytes forem iguais, a assinatura é válida, o que indica que o kernel foi
;     carregado na memória com sucesso.
;
;
;      Passo  1:  Byte0 = Byte[0x7E00]  ↩  (Se Byte0 ≠ Byte[0x7E00] ⇒ Aborta)           
;      Passo  2:  Byte1 = Byte[0x7E01]  ↩  (Se Byte1 ≠ Byte[0x7E01] ⇒ Aborta)     
;      Passo  3:  Byte2 = Byte[0x7E02]  ↩  (Se Byte2 ≠ Byte[0x7E02] ⇒ Aborta)
;      Passo  4:  Byte3 = Byte[0x7E03]  ↩  (Se Byte3 ≠ Byte[0x7E03] ⇒ Aborta)             
;      Passo  5:  Byte4 = Byte[0x7E04]  ↩  (Se Byte4 ≠ Byte[0x7E04] ⇒ Aborta) 
;      Passo  6:  Byte5 = Byte[0x7E05]  ↩  (Se Byte5 ≠ Byte[0x7E05] ⇒ Aborta)
;      Passo  7:  Byte6 = Byte[0x7E06]  ↩  (Se Byte6 ≠ Byte[0x7E06] ⇒ Aborta)
;                                       ↩
;      ...
;
;      Passo  N:  ByteN = Byte[0x7ENN]  ↩  (Se ByteN ≠ Byte[0x7ENN] ⇒ Aborta)
;                                       ↩
;      ...                                               
;
;      Passo 30:  Byte29 = Byte[0x7E1D] ↩  (Se Byte29 ≠ Byte[0x7E1D] ⇒ Aborta)
;      Passo 31:  Byte30 = Byte[0x7E1E] ↩  (Se Byte30 ≠ Byte[0x7E1E] ⇒ Aborta)
;      Passo 32:  Byte31 = Byte[0x7E1F] ↩  (Se Byte31 ≠ Byte[0x7E1F] ⇒ Aborta)
;                                    
;      ↪ ✅ Assinatura válida                        ❎ Assinatura inválida ↩ 
;
;                                                
;     Caso o kernel não tenha sido carregado pelo BIOS, todos os 32 bytes da 
;     assinatura na memória terão apenas 0x00 gravados neles, e a validação falha
;     já na comparação do primeiro par de bytes.
;
;
;     ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬─
;     │ 0x00 │ 0x00 │ 0x00 │ 0x00 │ 0x00 │ 0x00 │ 0x00 │ 0x00 │ 0x00 │ 0x00 │
;     └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴─
;     |0x7E00|0x7E01|0x7E02|0x7E03|0x7E04|0x7E05|0x7E06|0x7E07|0x7E08|0x7E09|
;
;
;     Afora a situação em que o kernel não foi carregado na memória, a única forma
;     possível de a validação falhar é pela corrupção dos bytes da assinatura no
;     disco. Neste projeto, não faço cálculo de paridade para reverter a eventual 
;     troca de 1 ou mais bits em um byte, portanto, este tipo de erro exigiria a
;     regravação da imagem no disco. Também não vou tratar a situação em que o
;     BIOS pode carregar o kernel parcialmente, não colocando na memória todos
;     os 10 setores. Isso tornaria o código muito complexo para um projeto tão
;     básico.
;
;
; Como pode se verificar no processo de validação da assinatura, se esta falhar,
; é realizada uma nova tentativa de carregar o kernel na memória. Isso é feito
; porque eventualmente pode ocorrer erros na leitura do disco em hardware real.
; Serão feitas até 5 tentativas de carregamento do kernel. Se as 5 falharem, o 
; bootloader aborta a execução, pois provavelmente existe algum defeito no hardware
; do disco.
;
; Com o kernel carregado na memória, não se transfere o controle do programa 
; imediatamente para ele. Antes será necessário mudar o processador para o
; Modo Protegido (32-bit), pois o bootloader roda em Modo Real, e precisa realizar
; esta transição antes de passar o controle definitivamente para o kernel.
;
; =============================================================================


load_kernel_image:

	mov bp, 0x7E00                ; Coloca o endereço 0x7E00 em BP. Este será o 
  	                              ; endereço na memória onde o kernel será 
								  ; carregado.

; -----------------------------------------------------------------------------
; Limpa a região da memória que vai receber a assinatura do kernel, para não fazer 
; a leitura de valores espúrios se o carregamento falhar.
; -----------------------------------------------------------------------------

.clear_signature:
	
	mov di, bp                    ; Copia o endereço de BP para DI. DI vai ser 
	                              ; usado como ponteiro para percorrer a memória 
                                  ;	enquanto limpa os bytes que receberão a
								  ; assinatura.
	
	mov cx, 32                    ; Define CX como 32, que é o número de bytes 
	                              ; ocupados pela assinatura.

.clear_loop:

    mov byte [di], 0x00           ; Grava 0x00 no endereço apontado por DI, o que 
	                              ; limpa o byte na memória.
								  
    inc di                        ; Incrementa DI para apontar para o próximo
	                              ; endereço de memória.
								  
    loop .clear_loop              ; Decrementa o valor de CX e, enquanto CX != 0, 
	                              ; volta para .clear_loop para apagar o próximo
								  ; byte da assinatura.

; -----------------------------------------------------------------------------
; Tenta fazer o carregamento do kernel no endereço 0x7E00. Antes de ler a imagem
; do kernel no disco, faz o reset do mesmo. 
;
; O reset do disco:
;
;   > Reinicializa o controlador.
; 
;   > Limpa erros anteriores de leitura/escrita.
;
;   > Coloca o dispositivo em um estado conhecido.
;
;   > Pode reposicionar o drive (recalibração).
;
;   > Prepara o disco para novas operações.
;
; Após o reset, chama a função de BIOS que carrega os 10 setores do kernel em uma
; única operação. Depois de terminada esta operação, valida a assinatura para 
; garantir que o carregamento ocorreu como o esperado.
; -----------------------------------------------------------------------------

	mov si, 5                     ; Inicializa SI como contador de tentativas de 
	                              ; carregamento do kernel para a memória (faz
								  ; 5 tentativas).

.read_kernel:
								  ; 1. Faz o reset do disco:

	mov ah, 0x00                  ; Define o valor 0x00 em AH (função Reset Disk 
	                              ; Drive).
	
	mov dl, [drive_number]        ; Lê o número do drive na memória e coloca em 
	                              ; DL.
	
	int 0x13                      ; Chama a interrupção de disco do BIOS para fazer
	                              ; o reset.
	
	jc .abort                     ; Testa a Carry Flag (CF) depois do int 13h.
	                              ;
                                  ; > CF = 1: Reset falhou. Salta para a rotina
								  ;   .abort, que tentará carregar o kernel novamente.
								  ;
                                  ; > CF = 0: Reset realizado. Continua.
								  
								  ; 2. Lê o kernel e carrega na memória:

    mov ah, 0x02                  ; Define o valor 0x02 em AH (função Read Sectors 
	                              ; From Drive)            
	
    mov dl, [drive_number]        ; Lê o número do drive na memória e coloca em
	                              ; DL.
								  
    mov al, 10                    ; Define o número de setores a serem lidos.
	
    mov ch, 0                     ; Define o número do cilindro.
	
    mov dh, 0                     ; Define o número da cabeça.
	
    mov cl, 2                     ; Define o setor inicial a ser lido do disco.
	
    mov bx, bp                    ; Define o endereço inicial na memória onde vai
	                              ; carregar o kernel (0x7E00).
								  
    int 0x13                      ; Chama a interrupção de disco do BIOS para
	                              ; carregar o kernel na memória.
								  
.validate_signature:              ; 3. Valida a assinatura do kernel:

    mov di, bp                    ; Copia o endereço inicial de memória da 
	                              ; assinatura do kernel em DI (índice da assinatura).
	
    mov bx, kernel_sign           ; Copia o endereço inicial de memória da cópia 
	                              ; da assinatura do kernel em BX (índice da cópia).
	
    mov dx, 32                    ; Define CX como 32, que será o contador do número
	                              ; de pares de bytes a comparar das assinaturas.

.cmp_bytes_loop:          

    mov al, [bx]                  ; Lê o byte da cópia da assinatura na posição 
	                              ; indicada por BX e coloca em AL.
	
    cmp al, [di]                  ; Compara o byte em AL com o que está na mesma
	                              ; posição relativa na assinatura do kernel
								  ; indicada por DI.
	
    jne .abort                    ; Se os bytes forem diferentes, salta para rotina
	                              ; .abort, que tentará carregar o kernel novamente.
	
    inc di                        ; Inclementa o índice da assinatura do kernel.
	
    inc bx                        ; Inclementa o índice da cópia da assinatura.
	
    dec dx                        ; Decrementa o contador de pares bytes restantes a 
	                              ; comparar.
	
    jnz .cmp_bytes_loop           ; Instrução "Jump if Not Zero". Ele verifica o
	                              ; Zero Flag (ZF):
                                  ; 
                                  ; > ZF = 0: Salto acontece.
                                  ;
								  ; > ZF = 1: Não salta.

    jmp .done                     ; Se a assinatura está correta, salta para .done.

; -----------------------------------------------------------------------------
; Aborta a operação corrente e tenta carregar o kernel novamente. Caso o número 
; de tentativas em SI se torne 0 e não tenha carregado o kernel na memória, salta
; para a rotina de tratamento de erro.
; -----------------------------------------------------------------------------

.abort:

    dec si                        ; Decrementa o contador de tentativas de leitura
	                              ; restantes.
	
    jz disk_error                 ; Se zeraram as tentativas de leitura do kernel 
	                              ; (SI = 0), salta para a rotina de tratamento
                                  ;	de erro.
	
    jmp .read_kernel              ; Se ainda não zeraram as tentativas de leitura
	                              ; do kernel, tenta carregá-lo novamente.

.done:                 



	
; =============================================================================
;
; TRANSIÇÃO PARA O MODO PROTEGIDO (32-BIT)
;
;
; Faz a troca do Modo Real (16-bit) para o Modo Protegido (32-bit) e passa o 
; controle do programa para o kernel. 
;
; Essa é uma etapa fundamental do boot, pois enquanto o processador está rodando
; em Modo Real, possui limitações severas de endereçamento (~1 MB sem extensões 
; como A20). O kernel precisará acessar memória que está acima de 1 MB, para 
; configurar a pilha e acessar hardware MMIO.
;
; O segmento de código do kernel em Modo Protegido foi configurado como 32-bit, 
; fazendo com que as instruções usem operandos de 32 bits por padrão (configuramos 
; isso na GDT). Dessa forma, precisamos fazer um Far Jump ao entregar o controle
; do programa para o kernel, para limpar do pipeline as instruções de 16 bits do
; bootloader e redefinir o registrador de segmento de código (CS) e o ponteiro 
; de instrução (EIP).
;
; O fluxograma abaixo ilustra como funciona esta transição. Antes de executar o 
; Far Jump, o controle do programa está com o bootloader (acima da linha pontilhada).
; Quando executar, o controle vai passar para o kernel (abaixo da linha pontilhada).
;
;
;                       ┌──────────────────────────────┐
;                       │ Desabilita as interrupções   │
;                       │------------------------------│
;                       │ cli                          │
;                       └──────────────┬───────────────┘
;                                      │
;                                      │
;                                      ▼
;                       ┌──────────────────────────────┐
;                       │ Carrega a GDT no GDTR        │
;                       │------------------------------│
;                       │ lgdt [gdt_ptr]               │
;                       └──────────────┬───────────────┘
;                                      │
;                                      │
;                                      ▼
;                       ┌──────────────────────────────┐
;                       │ Ativa o Modo Protegido       │
;                       │------------------------------│
;                       │ mov eax, cr0                 │
;                       │ or  eax, 1                   │
;                       │ mov cr0, eax                 │
;                       └──────────────┬───────────────┘
;                                      │ <---- A CPU ainda pode estar 
;                                      │       executando instruções
;                                      ▼       pré-carregadas (prefetch)
;                       ┌──────────────────────────────┐
;                       │ Executa o Far Jump           │
;                       │------------------------------│
;                       │ jmp 0x08:0x7E20              │
;                       │                              │
;                       │ • Atualiza CS e EIP          │
;                       │ • Limpa o pipeline da CPU    │
;                       │ • CPU passa a executar       │
;                       │   corretamente em Modo       │
;                       │   Protegido                  │
;                       └──────────────┬───────────────┘
;                                      │
;     Bootloader (Modo Real)           │
;                                      │
;    ----------------------------------│----------------------------------
;                                      │
;                                      │           Kernel (Modo Protegido) 
;                                      ▼ 
;                       ┌──────────────────────────────┐
;                       │ Executa kernel_entry (0x7E20)│
;                       │------------------------------│
;                       │ mov ax, 0x10                 │
;                       │ mov ds, ax                   │
;                       │ mov es, ax                   │
;                       │ mov fs, ax                   │
;                       │ mov gs, ax                   │
;                       │ mov ss, ax                   │
;                       │ mov esp, 0x200000            │
;                       └──────────────┬───────────────┘
;                                      │
;                                      │
;                                      ▼
;                        (Executa as demais instruções)
;
;
; A GDT está configurada como Flat Memory Model, em que a base do segmento de código 
; do kernel será no início da memória (0x00000000) e o limite será 4GB (0xFFFFFFFF), 
; com granularidade de 4KB. Isto faz com que o segmento de código do kernel abranja 
; toda a memória endereçável em Modo Protegido, permitindo o acesso à memória de 
; forma linear.
;
; Ao executar a instrução Far Jump em modo protegido:
;
;                              jmp 0x08:0x7E20
;
; passamos o seletor do Descritor do Segmento de Código do Kernel (0x08) e o 
; endereço do ponto de entrada do kernel, kernel_entry (0x7E20). Com base nestes
; parâmetros, o CPU atualiza o registrador de segmento CS e o registrador de 
; instrução EIP, que vai apontar para o endereço de kernel_entry. Quando o controle 
; do programa passar para o kernel, a primeira instrução a ser executada pelo CPU,
; apontada por EIP, será a que está em kernel_entry.
;
; Como os 32 bytes da assinatura do kernel estão em endereços anteriores, apenas 
; as instruções a partir desse ponto são executadas, não havendo o risco de os 
; bytes da assinatura serem confundidos com instruções e fazer o programa falhar.
;
; =============================================================================


enter_pmode_and_jump:

    cli                           ; Desativa as interrupções mascaráveis para a
	                              ; mudança do processador para o Modo Protegido.
	
    lgdt [gdt_ptr]                ; Carrega o endereço da Tabela de Descritores
	                              ; Globais (GDT - Global Descriptor Table) no
								  ; registrador interno GDTR (Global Descriptor
								  ; Table Register) 
									   
    mov eax, cr0                  ; Copia o registrador CR0 (Control Register 0)
	                              ; em EAX. O registrador CR0 controla estados
								  ; fundamentais da CPU.
									   
    or eax, 1                     ; O bit mais à direita em CR0 (o bit menos
	                              ; significativo, índice 0) é chamado de PE 
								  ; (Protection Enable). Se PE = 0, o processador 
							      ; opera em Modo Real. Se PE = 1, o processador
                                  ; ativa o Modo Protegido. O Bitwise OR aplicado
                                  ; a EAX tem a finalidade de trocar este único 
								  ; bit de 0 para 1, mantendo os demais bits
								  ; recuperados do registrador CR0 inalterados.
									   
    mov cr0, eax                  ; Copia o valor de EAX, com o PE ativado, para
                                  ;	CR0.
	
    jmp 0x08:0x7E20               ; Executa um Far Jump (salto longo) para passar
	                              ; o controle do programa para o kernel. O seletor
								  ; 0x08 aponta para o Descritor do Segmento de
								  ; Código do Kernel na GDT, e o endereço 0x7E20 
								  ; para o ponto de entrada do kernel (kernel_entry),  
								  ; onde o ponteiro de instrução (EIP) será posicionado 
								  ; para o CPU começar a execução das instruções
								  ; a partir dele.
			
			
						

; =============================================================================
;
; TRATAMENTO DE ERRO NA LEITURA DO DISCO 
;
;
; Esta rotina é executada se acontecer algum erro na leitura do kernel no disco. 
; Neste caso, exibe uma mensagem informando que houve erro, e também solicitando 
; para teclar ENTER para encerrar a execução e desligar o computador. 
; 
; Como estou usando funções de APM (Advanced Power Management) para desligar, em 
; hardware real não iria funcionar nas máquinas pós anos 1990/2000. Porém no QEMU
; ela funciona. Então, no caso de uma eventual falha no carregamento do kernel 
; pelo QEMU, permite o desligamento da máquina virtual só pressionando a tecla 
; ENTER.
;
; =============================================================================


disk_error:

	mov si, disk_error_str        ; Copia o endereço de memória da string disk_error_str 
	                              ; para SI.
								  
    call print_string             ; Imprime a string disk_error_str.
	
.wait_enter:

	mov ah, 0x00                  ; Define a função 0 da interrupção de teclado 
	                              ; (leitura de tecla).
								  
    int 0x16                      ; Chama a interrupção para ler a tecla pressionada.
	
	cmp al, 0x0D                  ; Compara o valor em AL, que armazena o valor
	                              ; da tecla, com 0x0D (Enter).
								  
    jne .wait_enter               ; Se a tecla pressionada não for Enter, volta 
	                              ; a ler o teclado novamente.

.power_off:

                                  ; 1. Verifica se APM está presente.

    mov ax, 0x5300                ; Define a função 0x5300, que é usada para detectar
	                              ; a presença do APM.
								  
    xor bx, bx                    ; Zera o valor de BX.
	
    int 0x15                      ; Chama a interrupção 0x15, para testar se a
	                              ; APM está presente.
								  
    jc .apm_not_present           ; Se a APM não está presente no sistema, salta
	                              ; para .apm_not_present.

                                  ; 2. Conecta-se à interface APM.

    mov ax, 0x5301                ; Define a função 0x5301, que é usada para conectar-se
	                              ; ao APM.
								  
    xor bx, bx                    ; Zera o valor de BX.
	
    int 0x15                      ; Chama a interrupção 0x15, para realizar a conexão
	                              ; ao APM.
								  
    jc .apm_connection_failed     ; Se não se conectou com a APM, salta para 
	                              ; .apm_connection_failed.

                                  ; 3. Desliga o computador.

    mov ax, 0x5307                ; Define a função APM_SET_POWER_STATE, que altera 
	                              ; o estado de energia do dispositivo.
								  
    mov bx, 0x0001                ; Define o dispositivo-alvo. O valor 0x0001
	                              ; significa todos os dispositivos.
								  
    mov cx, 0x0003                ; Define o estado de energia do dispositivo. O 
	                              ; valor 0x0003 indica Power Off.
								  
    int 0x15                      ; Chama a interrupção 0x15, para executar o comando
	                              ; do BIOS de desligar o computador.

    jmp .failed_shutdown          ; Se o desligamento não foi bem-sucedido, salta
	                              ; para .failed_shutdown.

.apm_not_present:

    mov si, apm_not_found_str     ; Copia o endereço de memória da string 
	                              ; apm_not_found_str para SI.
								  
    call print_string             ; Imprime a string apm_not_found_str.
	
    jmp .hang                     ; Salta para .hang.

.apm_connection_failed:

    mov si, apm_conn_fail_str     ; Copia o endereço de memória da string 
	                              ; apm_conn_fail_str para SI.
								  
    call print_string             ; Imprime a string apm_conn_fail_str.
	
    jmp .hang                     ; Salta para .hang.

.failed_shutdown:

    mov si, shutdown_fail_str     ; Copia o endereço de memória da string 
	                              ; shutdown_fail_str para SI.
								  
    call print_string             ; Imprime a string shutdown_fail_str.
	
    jmp .hang                     ; Salta para .hang.

.hang:

	cli                           ; Interrompe as interrupções mascaráveis.
    
	hlt                           ; Entra em modo de baixo consumo de energia.
	                              ; Não processa mais interrupções mascaráveis,
								  ; pois estas foram desabilitadas.
								  
    jmp .hang
	
	
	

; =============================================================================
;
; IMPRESSÃO DE STRING NO TERMINAL
;
;
; Ao executar esta rotina, imprime uma string no terminal, caractere por caractere, 
; até encontrar o byte nulo 0x00, que denota o final da string.
;
; =============================================================================
	
	
print_string:

    mov ah, 0x0E                  ; Define a função 0x0E da interrupção de vídeo 
	                              ; (exibir caractere).
	
	mov bl, 0x07                  ; Define as cores de fonte e fundo (fundo preto,
	                              ; texto branco).

.next_char:

    lodsb                         ; Carrega o próximo byte da string apontada por 
	                              ; SI para AL, e inclementa SI.
    
	or al, al                     ; Faz uma operação OR de AL com ele mesmo. Se AL 
	                              ; for 0, o resultado será 0.
    
	jz .done                      ; Se AL for 0 (alcançou o fim da string), salta
	                              ; para .done.
    
	int 0x10                      ; Chama a interrupção para imprimir o caractere 
	                              ; armazenado em AL no terminal.
    
	jmp .next_char                ; Retorna ao início do laço .next_char, para
	                              ; processar o próximo caractere.

.done:

    ret                           ; Retorna o controle para o ponto de chamada.	




; =============================================================================
;
; GDT (GLOBAL DESCRIPTOR TABLE)
;
;
; A GDT é uma tabela na memória usada pelo processador x86 em Modo Protegido para 
; gerenciar segmentos de memória. Ela define segmentos que podem ser usados por
; qualquer tarefa, em oposição à LDT (Local Descriptor Table), que tem a mesma
; estrutura, porém contém descritores que são usados por tarefas específicas, que
; não são compartilhadas.
;
; A tabela abaixo reprenta uma GDT com 5 entradas, denominadas de descritores de
; segmento:
;
;
;        ┌──────────────────────────────────────────────────────────────┐
;        │                             GDT                              │
;        ├────────┬────────────────────┬────────────────────────────────┤
;        │ ÍNDICE │ DESCRITOR          │ DESCRIÇÃO                      │
;        ╞════════╪════════════════════╪════════════════════════════════╡ 
;        │ 0x00   │ Null Descriptor    │ Segmento nulo (obrigatório)    │
;        ├────────┼────────────────────┼────────────────────────────────┤
;        │ 0x08   │ Code Segment       │ Segmento de Código (Ring 0)    │
;        ├────────┼────────────────────┼────────────────────────────────┤
;        │ 0x10   │ Data Segment       │ Segmento de Dados  (Ring 0)    │
;        ├────────┼────────────────────┼────────────────────────────────┤
;        │ 0x18   │ User Code Segment  │ Segmento de Código (Ring 3)    │
;        ├────────┼────────────────────┼────────────────────────────────┤
;        │ 0x20   │ User Data Segment  │ Segmento de Dados  (Ring 3)    │
;        └────────┴────────────────────┴────────────────────────────────┘
;
;        * A ordem dos descritores na GDT é definida pelo projetista do 
;          sistema. O processador não impõe uma ordem específica, mas os 
;          seletores dependem dessa organização.
;
;
; DESCRITOR DE SEGMENTO
;
;
; Cada descritor de segmento ocupa 8 bytes (64 bits) na GDT. Ele é acessado pelo
; índice, que é o seu offset nesta estrutura de dados. O índice 0x00 é reservado
; para o Descritor Nulo, obrigatório pela arquitetura x86. Os demais descritores 
; (índices 0x08, 0x10, 0x18, ...) serão declarados conforme as exigências do projeto, 
; até o máximo de 8192 descritores.
;
; Os 64 bits de um descritor compõem os seguintes campos:
;
;
;                   ├ Flags ┤           ├── Access Byte ──┤    
;      63           55  54 53 52      47 45-6 44 43 41-2 40              32
;      ↓             ↓  ↙ ↙ ↙          ↘  ↓  ↙  ↙ ↙↘   ↓               ↓
;      ┌────────────┬─┬─┬─┬─┬───────────┬─┬─┬─┬───────────┬──────────────┐
;      │            │ │D│ │A│           │ │D│ │  Type     │              │
;      │ Base 31:24 │G│/│L│V│ Limite    │P│P│S├─┬───┬───┬─┤  Base 23:16  │
;      │            │ │B│ │L│ 19:16     │ │L│ │E│D/C│R/W│A│              │
;      ├────────────┴─┴─┴─┴─┴───────────┼─┴─┴─┴─┴───┴───┴─┴──────────────┤
;      │                                │                                │
;      │ Base 15:00                     │ Limite 15:00                   │
;      │                                │                                │
;      └────────────────────────────────┴────────────────────────────────┘
;      ↑                                ↑                                ↑
;      31                               15                               0
;
;
; ● Base (Base Address)
;
;   Endereço inicial do segmento, com 32 bits. É formado pela junção dos campos:
;
;     > Base 15:00 (Bits 16–31)
;
;     > Base 23:16 (Bits 32–39)
;
;     > Base 31:24 (Bits 56–63)
;
;   Juntando-se os bits dos três campos, forma-se o endereço da base na memória:
;
;     Base = Base 31:24 << 24 | Base 23:16 << 16 | Base 15:00
;
;   Para calcular o endereço físico usando o endereço de base, aplica-se a função: 
;
;     Endereço físico = Base + Offset
;   
;
; ● Limite (Segment Limit)
;
;   Define o tamanho do segmento, com 20 bits. É formado pela junção dos campos:
;
;     > Limit 15:00 (bits 0–15)
;
;     > Limit 19:16 (bits 48–51)
;
;   Juntando-se os bits dos dois campos, tem-se:
;
;     Limite = Limite 19:16 << 16 | Limite 15:00
;
;   O limite total depende do bit G (bit 55):
;
;     > Se G = 0 (granularidade em bytes), o limite máximo de memória endereçada
;       pelo segmento é ≈ 1MB.
;
;     > Se G = 1 (granularidade em páginas de 4KB), o limite máximo de memória 
;       endereçada pelo segmento é ≈ 4GB (Limite_Real = (Limite << 12) | 0xFFF).
;
;
; ● Tipo (Type)
;
;   O campo Type, com 4 bits (bits 40 (A), 41 (R/W), 42 (D/C), 43 (E)), define 
;   o que o segmento representa e quais operações são permitidas nele. 
;
;   Seu significado depende do bit S (bit 44):
;
;   > Se bit S = 1 (Segmento de código ou dados):
;
;       * Se segmento de dados:
;
;         Bit E = 0: Indica que é segmento de dados.
;
;         Bit D = Direction: Se valor 0 = normal, se 1 = cresce para baixo.
;
;         Bit W = Writable: Se valor 0 = somente leitura, se 1 = leitura + escrita.
;
;         Bit A = Accessed: CPU seta automaticamente quando acessado.
;
;       * Se segmento de código:
;
;         Bit E = 1: Indica que é segmento de código.
;
;         Bit C = Conforming: Permite a execução de níveis de privilégio diferentes.
;
;         Bit R = Readable: Permite leitura do código.
;
;         Bit A = Accessed: CPU seta automaticamente quando acessado.
;
;   > Se bit S = 0 (Segmento de sistema):
;
;       Nesse caso, o campo Type não representa permissões simples, ele define 
;       estruturas especiais do processador:
;
;       Alguns exemplos:
;
;       Type   Significado
;       -----  ---------------
;       0010   LDT
;       1001   TSS (Available)
;       1011   TSS (Busy)
;       1100   Call Gate
;       1110   Interrupt Gate
;       1111   Trap Gate
;
;   * Estes campos fazem parte do Access Byte.
;
;
; ● S (Descriptor Type)
;
;   O campo Descriptor Type, com 1 bit (bit 44), indica se o descritor representa
;   um segmento normal (código ou dados) ou uma estrutura interna do processador:
;
;     > S = 0 → Descritor de sistema (TSS, LDT, gates).
;
;     > S = 1 → Descritor de segmento de código ou dados.
;
;   * Este campo faz parte do Access Byte.
;
;
; ● DPL (Descriptor Privilege Level)
;
;   O campo Descriptor Privilege Level, com 2 bits (Bits 45–46), define o nível 
;   de privilégio mínimo necessário para acessar o descritor:
;
;     > 0 → Máximo privilégio.
;
;     > 1 → Privilégio intermediário.
;
;     > 2 → Privilégio intermediário.
;
;     > 3 → Mínimo privilégio.
;
;   * Este campo faz parte do Access Byte.
;
;
; ● P (Present)
;
;   O campo P (bit 47) indica se o descritor de segmento está válido e disponível
;   na memória física:
;
;     > 1 → O segmento está válido.
;
;       * O descritor pode ser usado normalmente.
;       * A CPU permite o carregamento no registrador de segmento (CS, DS, etc.).
;       * Acesso à memória segue normalmente (respeitando DPL, Type, etc.).
;
;     > 0 → O segmento é considerado inválido.
;
;       * Qualquer tentativa de uso gera a exceção: #NP — Segment Not Present.
;
;   * Este campo faz parte do Access Byte.
;
;
; ● AVL (Available)
;
;   O flag AVL (bit 52), diferente de outros campos (como DPL, P, Type), não afeta
;   o comportamento do hardware. Ele existe como um "espaço reservado" para o uso
;   pelo sistema operacional.
;
;
; ● L (64-bit Code Segment)
;
;   O flag L (bit 53) define se o segmento de código opera em:.
;
;     > 1 → 64-bit:
;
;       * A CPU executa instruções no modo longo.
;       * Registradores de 64 bits são usados (RAX, RBX, etc.).
;       * Endereçamento 64-bit é habilitado.
;
;     > 0 → NÃO 64-bit:
;
;       Segmento funciona como:
;
;       16-bit (modo real/protegido) ou 32-bit (modo protegido).
;
;       O comportamento depende do bit D/B (bit 54).
;
;
; ● D/B (Default Operation Size / Big).
;
;   A flag D/B (bit 54) controla:
;
;     > Tamanho padrão das operações (código).
;
;     > Comportamento da stack e limite (dados).
;
;   Isso depende se o segmento é código ou dados:
;
;     > Segmento de código: Default Operation Size
;
;         0 → 16-bit 
;
;         1 → 32-bit 
;
;       Define o tamanho padrão de:
;
;         * Registradores usados (AX vs EAX).
;         * Operações aritméticas.
;         * Endereçamento de instruções.
;
;     > Segmento de dados: Define o tamanho padrão do stack pointer (SP ou ESP)
;
;         0 → Stack 16-bit: Stack pointer é SP.
;
;         1 → Stack 32-bit: tack pointer é ESP.
;   
;
; ● G (Granularity)
;
;   A flag G (bit 55) define a unidade do campo Limite:
;
;     > 0 → Granularidade em bytes. O Limite é interpretado diretamente em bytes.
;
;     > 1 → Granularidade em páginas. O Limite é contado em páginas de 4 KB.
;
;
; SELETORES DE SEGMENTO
;
;
; Em Modo Protegido, os registradores de segmento (CS, DS, SS, etc.) não armazenam
; mais diretamente o endereço do segmento, como no Modo Real. Em vez disso, eles
; armazenam um seletor de segmento, de 16 bits, que aponta para o índice de um 
; descritor na GDT (ou LDT).
;
; O seletor de segmento é composto pelos campos:
;
;
;       15                                                       2  1  0
;       ┌───────────────────────────────────────────────────────┬──┬──┬──┐
;       │ Index                                                 │TI│ RPL │
;       └───────────────────────────────────────────────────────┴──┴──┴──┘
;
;
; ● RPL (Requested Privilege Level)
;
;   O campo RPL, com 2 bits (Bits 0-1), indica o nível de privilégio solicitado 
;   pelo código ao acessar um segmento:
;
;     > 0 → Máximo privilégio (Kernel).             
;                                              
;     > 1 → Privilégio intermediário.      
;                                           
;     > 2 → Privilégio intermediário.      
;                                        
;     > 3 → Mínimo privilégio (User mode).
;
;
; ● TI (Table Indicator)
;
;   O campo TI, com 1 bit (bit 2), indica qual tabela de descritores será usada:
;
;     > 0 → GDT (Global Descriptor Table).
;
;     > 1 → LDT (Local Descriptor Table).
;
;
; ● Index
;
;   O campo Index (Índice), com 13 bits (bits 3-15), indica diretamente a posição
;   do descritor na GDT/LDT.
;
;   O endereço do descritor é calculado pelo processador como:
;
;                    Endereço = Base da GDT/LDT + (Index × 8)
;
;   A constante 8 corresponde ao tamanho, em bytes, de cada descritor.
;
;   Os 13 bits reservados para o campo Index permite indexar até 2^13 descritores, 
;   o que dá um total de 8192 descritores. Subtraindo o Descritor Nulo, obrigatório,
;   restam 8191 entradas para o projeto.
;
;
; Tomemos como exemplo o seletor 0x08 no Far Jump da rotina enter_pmode_and_jump, 
; definido para obter o descritor do segmento de código do kernel (Kernel Code
; Descriptor) na GDT deste projeto:
;
;
;                                          Seletor (Kernel Code Descriptor)
;                                        ↙
;                                jmp 0x08:0x7E20
; 
;
; Em binário, 0x08 representa 0b0000000000001000. Isolando cada campo do seletor,
; temos:
;
;
;                    ├────────── Index ──────────┼TI ┼ RPL ┤
;                    ┌───────────────────────────┬───┬─────┐
;                    │ 0 0 0 0 0 0 0 0 0 0 0 0 1 │ 0 │ 0 0 │
;                    └───────────────────────────┴───┴─────┘
;
;
;   > RPL: Valor 0. Máximo privilégio de acesso (Kernel - Ring 0).
;
;   > TI: Valor 0. O seletor usa a GDT.
;
;   > Index: Valor 1. Posição do Descritor do Segmento de Código do Kernel na GDT.
;
;     Aplicando a equação para conversão no índice da GDT (offset), temos:
;
;       Índice na GDT = Index × 8 ⇒
;       Índice na GDT = 1 × 8 ⇒
;       Índice na GDT = 8
;
;     Covertendo para hexadecimal: 
;
;       Índice na GDT = 0x08 (2º entrada).
;
;
; DESCRITORES DE SEGMENTO EM FLAT MEMORY MODEL:
;
;
; Neste projeto definimos a GDT em Flat Memory Model (modelo plano). O Flat Model 
; é uma forma simplificada de usar a GDT em que:
;
;   > Todos os segmentos têm base = 0x00000000.
;
;   > O limite cobre toda a memória endereçável em Modo Protegido (≈ 4GB).
;
;   > Código e dados compartilham o mesmo espaço linear.
;
; Nesse modo a segmentação ainda existe, mas é "neutralizada", fazendo o sistema 
; funcionar como se fosse uma memória contínua (linear). Isso simplifica muito
; o uso da memória pelo kernel no modo protegido.
;
;
;           ┌────────────────────────────────────────────────────┐
;           │                  GDT do Projeto                    │
;           ├────────┬───────────────────────────────────────────┤
;           │ ÍNDICE │ DESCRITOR                                 │
;           ╞════════╪═══════════════════════════════════════════╡ 
;           │ 0x00   │ Descritor Nulo                            │
;           ├────────┼───────────────────────────────────────────┤
;           │ 0x08   │ Descritor do Segmento de Código do Kernel │
;           ├────────┼───────────────────────────────────────────┤
;           │ 0x10   │ Descritor do Segmento de Dados do Kernel  │
;           └────────┴───────────────────────────────────────────┘
;
;
; ● Descritor Nulo (Índice 0x00)
;
;   > Bytes do descritor 
;
;     00 00 00 00 00 00 00 00
;
;
; ● Descritor do Segmento de Código do Kernel (Índice 0x08)
;
;   > Bytes do descritor 
; 
;     FF FF 00 00 00 9A CF 00
;
;   > Base:
;
;     Base 15:00 = 0x0000
;     Base 23:16 = 0x00
;     Base 31:24 = 0x00
;
;     Base = Base 31:24 << 24 | Base 23:16 << 16 | Base 15:00 ⇒
;     Base = 0x00 << 24 | 0x00 << 16 | 0x0000 ⇒
;     Base = 0x00000000
; 
;   > Limite:
;
;     Limite 15:00 = 0xFFFF
;     Limite 19:16 = 0xF
;
;     Limite = Limite 19:16 << 16 | Limite 15:00 ⇒
;     Limite = 0xF << 16 | 0xFFFF ⇒
;     Limite = 0xFFFFF
;
;   > Access Byte (0x9A - binário: 10011010):
;
;     P = 1
;     DPL = 00
;     S = 1
;     Type: E=1 D=0 W=1 A=0
;
;   > Flags:
;
;     G = 1
;     D/B = 1
;     L = 0
;     AVL = 0
;
;
; ● Descritor do Segmento de Dados do Kernel (Índice 0x10)
;
;   > Bytes do descritor 
; 
;     FF FF 00 00 00 92 CF 00
;
;   > Base:
;
;     0x00000000 (a mesma do segmento de código)
; 
;   > Limite:
;
;     0xFFFFF (o mesmo do segmento de código)
;
;   > Access Byte (0x92 - binário: 10010010):
;
;     P = 1
;     DPL = 00
;     S = 1
;     Type: E=0 C=0 R=1 A=0
;
;   > Flags:
;
;     (os mesmos do segmento de código)
;
; =============================================================================


gdt_start:                        ; 0x00: Descritor Nulo (Obrigatório)

    dq 0x0000000000000000

gdt_code:                         ; 0x08: Descritor do Segmento de Código do kernel

    dw 0xFFFF                     ; Limite (15:0)
    dw 0x0000                     ; Base (15:0)
    db 0x00                       ; Base (23:16)
    db 0x9A                       ; Access Byte
    db 0xCF                       ; Flags + Limite alto (19:16)
    db 0x00                       ; Base (31:24)

gdt_data:                         ; 0x10: Descritor do Segmento de Dados do Kernel

    dw 0xFFFF                     ; Limite (15:0)
    dw 0x0000                     ; Base (15:0)
    db 0x00                       ; Base (23:16)
    db 0x92                       ; Access Byte 
    db 0xCF                       ; Flags + Limite alto (19:16)
    db 0x00                       ; Base (31:24)

gdt_end:                          ; Fim da tabela. Usado para calcular o tamanho
                                  ; da GDT


gdt_ptr:                          ; Estrutura que aponta para a GDT

    dw gdt_end - gdt_start - 1    ; Tamanho da GDT - 1
    dd gdt_start                  ; Endereço base da GDT




; =============================================================================
;
; SEÇÃO DE DADOS DO BOOTLOADER
;
; =============================================================================
	
	
drive_number:                     ; Variável de 1 byte que guarda o número do
                                  ; drive de boot para operações de Leitura/Escrita
	db 0					      ; de disco.
		
		
disk_error_str:                   ; Mensagem de erro 1.

	db 0x0D, 0x0A
	db 'Erro ao carregar o kernel.'
	db 0x0D, 0x0A, 0x0D, 0x0A
	db 'Tecle ENTER para sair.'
	db 0


apm_not_found_str:                ; Mensagem de erro 2.

	db 'APM BIOS not found!'
	db 0xD, 0xA
	db 0


apm_conn_fail_str:                ; Mensagem de erro 3.

	db 'APM connection failed!'
	db 0xD, 0xA
	db 0


shutdown_fail_str:                ; Mensagem de erro 4.

	db 'Shutdown failed via APM!'
	db 0xD, 0xA
	db 0


kernel_sign:                      ; Cópia da Assinatura do kernel.

	db 0xDE,0xAD,0xBE,0xEF,0x01,0x23,0x45,0x67,0x89,0xAB,0xCD,0xEF,0x10,0x32
	db 0x54,0x76,0x98,0xBA,0xDC,0xFE,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88
	db 0x99,0xAA,0xBB,0xCC

	  


; =============================================================================
;
; AJUSTE DO BINÁRIO E ASSINATURA DO SETOR MBR
;
;
; Neste ponto do código-fonte assembly do bootloader já definimos toda a programação
; necessária para que ele possa carregar o kernel do relógio na memória e entregar 
; o controle do programa para o mesmo, mudando o processador para o Modo Protegido
; antes disso. Agora precisamos fazer os ajustes finais no bootloader para que ele 
; possa ocupar todo o setor MBR do dispositivo de armazenamento quando a imagem
; de disco do relógio for gravada neste. 
;
; O setor MBR (Master Boot Record) é o primeiro setor físico de um disco particionado
; (Setor 0 ou LBA 0)  e tem 512 bytes. Em sistemas com firmware BIOS, para criarmos
; um disco inicializável o bootloader deve, obrigatóriamente, ser gravado neste setor.
;
;
;              ├── MBR ──┤
;              ┌─────────┬─────────┬─────────┬─────────┬─────────┬──
;              │ Setor 0 │ Setor 1 │ Setor 2 │ Setor 3 │ Setor 4 │
;              └─────────┴─────────┴─────────┴─────────┴─────────┴──
;
; 
; O assembly do bootloader foi escrito para o montador NASM (Netwide Assembler).
; NASM é um montador de código aberto e multiplataforma, utilizado para traduzir 
; assembly para linguagem de máquina para arquiteturas x86 (Intel/AMD). Ele pode
; ser usado para escrever programas de 16 bits (Modo Real), 32 bits (Modo Protegido) 
; e 64 bits (Modo Longo).
; 
; Linguagem de máquina é o nível mais baixo de representação de um programa, sendo 
; a única linguagem que o processador consegue entender e executar diretamente.
;
; Suas principais características são:
;
;
;   ● Formato binário: É composta exclusivamente por sequências de bits (0's e 1's). 
;     Esses números representam impulsos elétricos que ativam circuitos específicos
;     dentro do chip.
;
;
;   ● Instruções de hardware: Cada sequência binária, chamada de opcode, corresponde
;     a uma operação física que o processador sabe fazer, como somar dois números, 
;     mover um dado da memória para um registrador e vice-versa ou desviar a execução 
;     para outro ponto.
;
;
;   ● Dependência da arquitetura: Ela é específica para cada arquitetura de processador. 
;     A linguagem de máquina do processador Intel x86 deste programa é um "dialeto"
;     completamente diferente da de um processador Apple M3 (ARM), por exemplo,
;     e um não poderá executar o programa gerado para o outro.
;
;
; Ao traduzir o assembly do bootloader para linguagem de máquina usando o montador 
; NASM, será criado o arquivo binário com as instruções para o processador no diretório
; do projeto (bootloader.bin). Este arquivo binário será copiado no início da imagem 
; de disco, para que quando se gravar esta imagem no dispositivo de armazenamento, 
; ele ocupe todo o espaço do setor MBR deste.
; 
;
;                                 (montador NASM)
;                       ╔═════════════════════════════════╗
;                       ║                                 ▼
;              ┌─────────────────┐               ┌─────────────────┐     
;              │[BITS 16]        │               │EB 01 90 FA 88 16│     
;              │[ORG 0x7C00]     │               │EF 7C 31 C0 8E D8│     
;              │                 │               │8E C0 8E E0 8E E8│     
;              │jmp short start  │               │8E D0 BC 00 7C FB│     
;              │nop              │               │B4 00 B0 03 CD 10│    
;              │                 │               │BD 00 7E 89 EF B9│     
;              │start:           │               │20 00 C6 05 00 47│     
;              │  cli            │               │E2 FA BE 05 00 B4│     
;              │  mov [drive], dl│               │00 8A 16 EF 7C CD│     
;              │  xor ax, ax     │               │13 72 27 B4 02 8A│     
;              │  mov ds, ax     │               │16 EF 7C B0 0A B5│     
;              │  mov es, ax     │               │00 B6 00 B1 02 89│     
;              └─────────────────┘               └─────────────────┘    
;                 bootloader.asm                    bootloader.bin      
;
;
; Para gerar o arquivo binário a partir do código-fonte assembly, passamos os 
; seguintes parâmetros para o montador NASM no prompt de comandos do Windows: 
;
;
;               nasm -f bin "bootloader.asm" -o "bootloader.bin"
;
;
; Se traduzíssemos o código-fonte só até este ponto na seção de dados do arquivo, 
; sem traduzir o assembly restante após este comentário, seria gerado um binário
; com os seguintes bytes em linguagem de máquina:
;
;
;               EB 01 90 FA 88 16 EF 7C 31 C0 8E D8 8E C0 8E E0 
;               8E E8 8E D0 BC 00 7C FB B4 00 B0 03 CD 10 BD 00 
;               7E 89 EF B9 20 00 C6 05 00 47 E2 FA BE 05 00 B4 
;               00 8A 16 EF 7C CD 13 72 27 B4 02 8A 16 EF 7C B0 
;               0A B5 00 B6 00 B1 02 89 EB CD 13 89 EF BB 71 7D 
;               BA 20 00 8A 07 3A 05 75 07 47 43 4A 75 F5 EB 05 
;               4E 74 17 EB CA FA 0F 01 16 E9 7C 0F 20 C0 66 83 
;               C8 01 0F 22 C0 EA 20 7E 08 00 BE F0 7C E8 43 00 
;               B4 00 CD 16 3C 0D 75 F8 B8 00 53 31 DB CD 15 72
;               16 B8 01 53 31 DB CD 15 72 15 B8 07 53 BB 01 00 
;               B9 03 00 CD 15 EB 10 BE 27 7D E8 16 00 EB 10 BE 
;               3D 7D E8 0E 00 EB 08 BE 56 7D E8 06 00 EB 00 FA 
;               F4 EB FC B4 0E B3 07 AC 08 C0 74 04 CD 10 EB F7 
;               C3 00 00 00 00 00 00 00 00 FF FF 00 00 00 9A CF
;               00 FF FF 00 00 00 92 CF 00 17 00 D1 7C 00 00 00 
;               0D 0A 45 72 72 6F 20 61 6F 20 63 61 72 72 65 67 
;               61 72 20 6F 20 6B 65 72 6E 65 6C 2E 0D 0A 0D 0A
;               54 65 63 6C 65 20 45 4E 54 45 52 20 70 61 72 61 
;               20 73 61 69 72 2E 00 41 50 4D 20 42 49 4F 53 20 
;               6E 6F 74 20 66 6F 75 6E 64 21 0D 0A 00 41 50 4D 
;               20 63 6F 6E 6E 65 63 74 69 6F 6E 20 66 61 69 6C 
;               65 64 21 0D 0A 00 53 68 75 74 64 6F 77 6E 20 66 
;               61 69 6C 65 64 20 76 69 61 20 41 50 4D 21 0D 0A 
;               00 DE AD BE EF 01 23 45 67 89 AB CD EF 10 32 54 
;               76 98 BA DC FE 11 22 33 44 55 66 77 88 99 AA BB 
;               CC
;                ↖
;                  401º byte
;
;
; Estas instruções carregam o kernel na memória e entregam o controle do programa
; para ele, que é a função para qual este bootloader foi projetado, portanto, o 
; programa que o processador vai executar está completo no arquivo.
; 
; Mesmo o programa estando completo, sem fazer os ajustes finais no arquivo binário, 
; o bootloader ainda não vai funcionar. O binário deve preencher todos os 512 bytes 
; do setor MBR e faltam ainda 111 bytes para conseguir este alinhamento (512-401=111). 
; Além disso, o setor MBR deve receber uma assinatura (Boot Signature) nos dois 
; bytes finais. Sem fazer estes ajustes, o BIOS é incapaz de carregar o programa
; do bootloader após a etapa de POST (Power-On Self-Test).
;
; As duas linhas finais do assembly após este comentário, portanto, instruem o 
; montador a fazer os ajustes necessários no arquivo binário do bootloader. Cada
; linha executa uma etapa do processo:
;
;
;   ● Etapa 1: times 510-($-$$) db 0 → 
;     
;     Nesta etapa, o montador vai inflar o arquivo com bytes 0 até ele ficar com 
;     510 bytes. Os bytes 0 adicionados pelo montador não são instruções ou dados
;     do programa do bootloader. Eles apenas ajustam o tamanho do arquivo binário 
;     para se alinhar com o tamanho do setor MBR.
;
;
;   ● Etapa 2: dw 0xAA55 → 
;
;     Nesta etapa o montador grava os bytes da assinatura do setor MBR no final
;     do arquivo (offsets 510 e 511). É uma exigência dos sistemas com firmware 
;     BIOS que os discos inicializáveis sejam assinados com os bytes 55 AA (Boot
;     Signature) nos dois bytes finais do setor MBR. Se não fizermos isso, mesmo 
;     que tenhamos configurado corretamente a sequência de boot no setup para buscar 
;     primeiro o dispositivo que vamos testar, e o programa do bootloader esteja
;     correto, o BIOS ignorará que aquele é um disco inicializável e exibirá o 
;     erro "No bootable device found", ou pulará para o próximo dispositivo na 
;     sequência de boot, se houver algum, para tentar inicializar o sistema a partir
;     dele. 
;
;
; Depois que o montador NASM executar as etapas de ajuste, o arquivo binário do 
; bootloader terá os seguintes bytes em linguagem de máquina:
;
;
;               EB 01 90 FA 88 16 EF 7C 31 C0 8E D8 8E C0 8E E0 
;               8E E8 8E D0 BC 00 7C FB B4 00 B0 03 CD 10 BD 00 
;               7E 89 EF B9 20 00 C6 05 00 47 E2 FA BE 05 00 B4 
;               00 8A 16 EF 7C CD 13 72 27 B4 02 8A 16 EF 7C B0 
;               0A B5 00 B6 00 B1 02 89 EB CD 13 89 EF BB 71 7D 
;               BA 20 00 8A 07 3A 05 75 07 47 43 4A 75 F5 EB 05 
;               4E 74 17 EB CA FA 0F 01 16 E9 7C 0F 20 C0 66 83 
;               C8 01 0F 22 C0 EA 20 7E 08 00 BE F0 7C E8 43 00 
;               B4 00 CD 16 3C 0D 75 F8 B8 00 53 31 DB CD 15 72
;               16 B8 01 53 31 DB CD 15 72 15 B8 07 53 BB 01 00 
;               B9 03 00 CD 15 EB 10 BE 27 7D E8 16 00 EB 10 BE 
;               3D 7D E8 0E 00 EB 08 BE 56 7D E8 06 00 EB 00 FA 
;               F4 EB FC B4 0E B3 07 AC 08 C0 74 04 CD 10 EB F7 
;               C3 00 00 00 00 00 00 00 00 FF FF 00 00 00 9A CF
;               00 FF FF 00 00 00 92 CF 00 17 00 D1 7C 00 00 00 
;               0D 0A 45 72 72 6F 20 61 6F 20 63 61 72 72 65 67 
;               61 72 20 6F 20 6B 65 72 6E 65 6C 2E 0D 0A 0D 0A
;               54 65 63 6C 65 20 45 4E 54 45 52 20 70 61 72 61 
;               20 73 61 69 72 2E 00 41 50 4D 20 42 49 4F 53 20 
;               6E 6F 74 20 66 6F 75 6E 64 21 0D 0A 00 41 50 4D 
;               20 63 6F 6E 6E 65 63 74 69 6F 6E 20 66 61 69 6C 
;               65 64 21 0D 0A 00 53 68 75 74 64 6F 77 6E 20 66 
;               61 69 6C 65 64 20 76 69 61 20 41 50 4D 21 0D 0A 
;               00 DE AD BE EF 01 23 45 67 89 AB CD EF 10 32 54 
;               76 98 BA DC FE 11 22 33 44 55 66 77 88 99 AA BB 
;               CC 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
;               00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
;               00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
;               00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
;               00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
;               00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
;               00 00 00 00 00 00 00 00 00 00 00 00 00 00 55 AA
;
;
; Agora o bootloader está completamente alinhado com o setor MBR, para que quando 
; a imagem de disco do relógio for gravada no dispositivo de armazenamento, ele 
; seja copiado corretamente para aquele setor. O MBR também está assinado, indicando 
; para o BIOS que o dispositivo de armazenamento que receber aquela imagem de disco 
; é um dispositivo inicializável.
;
; Para decifrar o significado de cada byte do código de máquina gravado pelo montador 
; NASM no arquivo binário do bootloader, a partir da tradução do código-fonte deste 
; arquivo, é preciso entender o que é a linguagem assembly, e como ela gera as 
; instruções para o processador. 
;
; Cada instrução em assembly, representada por mnemônicos como jmp, nop, mov, xor, 
; é convertida pelo montador em uma ou mais instruções de máquina, compostas por 
; opcodes e possíveis operandos codificados em binário durante a tradução. O montador 
; analisa o código assembly, resolve símbolos como rótulos (labels) e variáveis,
; e então gera os bytes correspondentes no arquivo binário, respeitando a organização
; das seções e o layout do programa. 
;
; Quando encontra definições de dados, como drive_number db 0, ele insere diretamente
; os valores especificados no binário. Já os rótulos são substituídos pelos endereços 
; ou deslocamentos apropriados, dependendo dos tipos das instruções que os utilizam. 
; Durante este processo, o montador pode realizar múltiplas passagens para resolver
; referências e calcular corretamente os endereços antes de gerar o código final
; em linguagem de máquina.
;
;                            start:
;                            ┆
;   "jmp short start"  "nop" ┆ "cli"   "mov [drive_number], dl"  ← Texto Assembly
;  ├────────────────┤ ├─────┤┆├─────┤ ├────────────────────────┤
; ┌────────↓─────────┬───↓───┬───↓───┬────────────↓─────────────┬──
; │ EB 01            │ 90    │ FA    │ 88 16 EF 7C              │   ← opcodes
; └──────────────────┴───────┴───────┴──────────────────────────┴──   
;
;
; A linguagem assembly em si é apenas uma representação textual "amigável" das
; instruções em binário que o processador executa, criada para seres humanos lerem 
; e escreverem programas de forma mais intuitiva. Mas o processador não entende
; nem tampouco executa assembly. É preciso que o montador NASM traduza de uma
; linguagem para a outra (Assembly → Linguagem de Máquina).
;
; Diferentemente de linguagens de alto nível, como C e C++, em que o compilador
; gera os opcodes para instruções como "if", "while", "for" de modo transparente
; para o programador, em "bare metal", a tradução do assembly é muito mais direta 
; e previsível: o montador gera os bytes correspondentes às instruções especificadas 
; no código-fonte, respeitando a ordem lógica em que elas foram escritas, e grava 
; na mesma sequência no arquivo binário. 
;
; Então, quando o montador lê a sequência de instruções assembly no começo deste
; arquivo:
;
; 
;   jmp short start
;   nop
;   start:
;     cli
;     mov [drive_number], dl
;
;
; Ele vai produzir como saída a sequência de bytes correspondente em linguagem
; de máquina:
;
;
;   EB 01 90 FA 88 16 EF 7C
;
;
; Onde:
;
;
;   EB → Opcode para a instrução jump relativo curto (jmp short).
;
;   01 → Operando para o opcode EB. Diz quantos bytes o ponteiro de instruções 
;   deve saltar à frente para executar o programa a partir daquele ponto. Neste
;   caso, saltará 1 byte (salta a instrução "nop").
;
;   90 → Opcode para a instrução No Operation (nop). Esta instrução ocupa 1 byte 
;   de espaço e não altera registradores. No caso, eu utilizo ela no código apenas
;   para manter o alinhamento da primeira instrução útil do bootloader (label start:)
;   no offset 0x03.
;
;   FA → Opcode para a instrução Clear Interrupt Flag (cli). Esta instrução desabilita
;   as instruções mascaráveis (mouse, teclado, timer, disco, etc). Ela faz isso alterando 
;   a flag IF (bit 9) do registrador EFLAGS para 0. 
;
;   88 → Opcode para a instrução MOV r/m8, r8. Esta instrução move um valor de 8
;   bits (1 byte) entre um registrador e a memória.
;
;   16 → Modo de endereçamento da instrução MOV (ModR/M). Este valor indica que
;   vai mover o valor no registrador DL (8 bits) para a memória, no endereço que
;   será fornecido a seguir.
;
;   EF → Parte baixa (Low Byte) do endereço de memória que irá receber o valor 
;   em DL pela instrução mov (byte 0xEF do endereço 0x7CEF).
;
;   EF → Parte alta (High Byte) do endereço de memória (byte 0x7C do endereço 0x7CEF).
;
;
; Representando os mesmos bytes acima em formato binário, que é o formato "natural"
; que o processador interpleta a linguagem de máquina, temos:
;
;
;   11101011 00000001 10010000 11111010 10001000 00010110 11101111 01111100
;
;
; Não vou entrar em maiores detalhes sobre como estas instruções são executadas bit a 
; bit pelos circuitos do processador x86 dentro do ciclo Fetch-Decode-Execute (Busca-
; Decodificação-Execução), porque isto foge ao escopo deste projeto. Mas quem tiver
; curiosidade, faça uma consulta aprofundada sobre o tema, que é um assunto muito 
; relevante, e coloca o interessado dentro das "entranhas" da máquina. Particularmente, 
; tenho enorme fixação neste assunto, pois no passado, fui um entusiasta de eletrônica 
; digital. 
;
; Com base no que foi explicado até aqui, fica fácil deduzir que poderíamos abrir 
; um editor hexadecimal e digitar os opcodes, operandos e endereços no arquivo 
; binário do bootloader sem escrever uma única linha em assembly. Fazendo-se dessa 
; forma, não precisaríamos do montador NASM, pois já escreveríamos o programa diretamente 
; na linguagem de máquina que o processador entende.
;
; Esta, seguramente, seria uma tarefa extremamente tediosa e nem um pouco intuitiva,
; que faria a programação de um computador moderno muito semelhante à dos computadores
; de primeira geração das décadas de 1940 e 1950, como ENIAC (1945), EDVAC (1949), 
; IBM 701 (1952), com a diferença que naqueles computadores primordiais, as sequências
; de 0's e 1's era determinada diretamente no hardware, com a reconfiguração de
; cabos e chaves, e não pela escrita de um arquivo em disco.
;
; A tabela abaixo mostra como o montador NASM traduz as primeiras instruções deste
; código-fonte em assembly em seus respectivos opcodes em linguagem de máquina:
;
;
;                               ┌───────────────────────────────────────┐
;                               │              Opcode(s)                │
;    ┌──────────────────────────┼───────────────────┬───────────────────┤
;    │ Assembly                 │ Hexadecimal       │ Binário           │         
;    ╞══════════════════════════╪═══════════════════╪═══════════════════╡
;    │ jmp short start          │ EB 01             │ 11101011 00000001 │    
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ nop                      │ 90                │ 10010000          │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ start:                   │ Pseudo-instrução  │ Pseudo-instrução  │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ cli                      │ FA                │ 11111010          │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ mov [drive_number], dl   │ 88 16 EF 7C       │ 10001000 00010110 │
;    │                          │                   │ 11101111 01111100 │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ xor ax, ax               │ 31 C0             │ 00110001 11000000 │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ mov ds, ax               │ 8E D8             │ 10001110 11011000 │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ mov es, ax               │ 8E C0             │ 10001110 11000000 │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ mov fs, ax               │ 8E E0             │ 10001110 11100000 │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ mov gs, ax               │ 8E E8             │ 10001110 11101000 │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ mov ss, ax               │ 8E D0             │ 10001110 11010000 │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ mov sp, 0x7C00           │ BC 00 7C          │ 10111100 00000000 │
;    │                          │                   │ 01111100          │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ sti                      │ FB                │ 11111011          │
;    └──────────────────────────┴───────────────────┴───────────────────┘
;
;    * Observe que o código assembly para NASM contém pseudo-instruções que não 
;      geram opcodes para o processador. A label start:, por exemplo, apenas demarca
;      o endereço de uma instrução (cli), servindo como uma espécie de marcador no
;      código, que o montador converterá num endereço ou deslocamento, dependendo
;      da instrução que a utiliza (jmp short transforma em deslocamento). Outras 
;      pseudo-instruções que aparecem neste assembly são: times, db, dw, dd, dq. 
;      Todas elas não geram opcodes, apenas instruem o montador a gravar bytes no 
;      binário, no sentido de alocar espaço com alguma função (servir como "variável"
;      ou para inflar o arquivo).
;
;
; Os opcodes desta tabela correspondem ao código de alinhamento e à rotina "start:" 
; no assembly, que grava o número do drive de boot na variável drive_number na 
; memória, configura os registradores de segmento e a pilha do bootloader.
;
; Creio que agora ficou bem mais fácil construir a tabela da rotina seguinte à
; start:, a rotina set_vga_text_mode:, que configura o modo de texto VGA 3H,
; e também as outras rotinas restantes:
;
;
;                               ┌───────────────────────────────────────┐
;                               │              Opcode(s)                │
;    ┌──────────────────────────┼───────────────────┬───────────────────┤
;    │ Assembly                 │ Hexadecimal       │ Binário           │         
;    ╞══════════════════════════╪═══════════════════╪═══════════════════╡
;    │ set_vga_text_mode:       │ Pseudo-instrução  │ Pseudo-instrução  │    
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ mov ah, 0x00             │ B4 00             │ 10110100 00000000 │    
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ mov al, 0x03             │ B0 03             │ 10110000 00000011 │
;    ├──────────────────────────┼───────────────────┼───────────────────┤
;    │ int 0x10                 │ CD 10             │ 11001101 00010000 │
;    └──────────────────────────┴───────────────────┴───────────────────┘
;
;
; (Para mais informações sobre o formato do arquivo binário consultar 
;  https://www.nasm.us/doc/nasm09.html#section-9.1.1)
;
; =============================================================================


	times 510-($-$$) db 0         ; Etapa 1: Completa com bytes 0 até offset 509.

	dw 0xAA55                     ; Etapa 2: Assina o setor de boot com o Boot
                                  ; Signature (bytes 55-AA) nos offsets 510 e
								  ; 511.


					  
						  
; =============================================================================
;
; IMAGEM DE DISCO EM RAW FORMAT 
;
;
; https://github.com/kalehmann/SiBoLo/blob/master/bootloader.asm
; =============================================================================


; Referências:
;
; https://en.wikipedia.org/wiki/Reset_vector
;
; https://en.wikipedia.org/wiki/Master_boot_record#SIG
;
; https://www.nasm.us/doc/
;
; https://en.wikipedia.org/wiki/Volume_boot_record
;
; https://en.wikipedia.org/wiki/File_Allocation_Table
;
; https://en.wikipedia.org/wiki/Bootloader
;
; https://en.wikipedia.org/wiki/BIOS
;