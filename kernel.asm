; ═════════════════════════════════════════════════════════════════════════════
;                                    Kernel
; ═════════════════════════════════════════════════════════════════════════════
;
; O kernel tem como finalidade exibir na tela do computador a data e a hora do
; sistema atualizadas, no formato HH:MN:SS DD/MM/CCYY, onde:  
;
;                                      
;   ● HH: Dígitos das horas.                                                 
;                                                                             
;   ● MN: Dígitos dos minutos.                                               
;                                                              
;   ● SS: Dígitos dos segundos.                                              
;                                                                             
;   ● DD: Dígitos do dia do mês.                                             
;                                                                             
;   ● MM: Dígitos do mês.                                                    
;                                                                             
;   ● CC: Dígitos do século.                                                 
;                                                                             
;   ● YY: Dígitos do ano.                                                    
;
;                                                                        
; Para mostrar a data e hora atualizadas, o kernel não vai ler o RTC (Real-Time 
; Clock) a todo o momento para obter estes valores. RTC é o componente da placa-mãe 
; que contém a data e hora atualizadas.                            
;                                                                             
; A estratégia de atualização da data e hora na tela será a seguinte:               
; 
;
;   ● Configura o HPET (High Precision Event Timer) para gerar interrupção de 
;     relógio (IRQ0). O HPET é um componente de hardware que fornece uma forma 
;     precisa e consistente de medir o tempo. 
;
;     Ele será programado para emitir um tick de relógio a cada 10 ms, sendo
;     executado um handle para o tratamento da interrupção lançada com este tick.       
;
;
;   ● Usa o TSC (Time Stamp Counter) como contador de tempo do relógio. A cada
;     10 ms, quando a interrupção de IRQ0 for lançada, lê o TSC e calcula se o
;     número de ciclos correspondem a 1 segundo. Se sim, atualiza a data e hora
;     na tela.
;
;     Para que possa calcular quantos ciclos do TSC correspondem a 1 segundo, 
;     faz-se necessário a calibração deste usando o HPET como referência de tempo
;     (calcula-se ticks de TSC/10 ms).
;
;
;   ● Com o HPET configurado para gerar interrupção de IRQ0 e o TSC calibrado,
;     aciona-se a rotina que faz a leitura do RTC (rtc_read_datetime) e que habilita
;     as interrupções mascaráveis (instrução STI) para retomar o tratamento de
;     interrupções desativado no bootloader. Após esta leitura, somente se teclar
;     F5 no teclado que vai ser feita a leitura do RTC novamente.
;
;
; Esta é uma estratégia muito parecida com a que é utilizada em alguns sistemas 
; operacionais práticos. 
;
; ════════════════════════════════════════════════════════════════════════════


[BITS 32]                         ; O kernel roda em Modo Protegido (32-bit).

[ORG 0x7E00]                      ; A imagem do kernel será carregada no endereço
                                  ; 0x7E00 da memória.




; =============================================================================
; 
; ASSINATURA DO KERNEL (KERNEL SIGNATURE)
;
;
; A assinatura constitui os primeiros 32 bytes do binário do kernel na imagem de
; disco. 
;
;
; ┌───────────────────────────────────┬────────────────────────────────────────
; │  Assinatura do Kernel (32 bytes)  │  Instruções e Dados (assembly)
; └───────────────────────────────────┴────────────────────────────────────────
; ├─────────────────────── Imagem do Kernel (5120 bytes) ──────────────────────
;
;
; Quando o kernel estiver carregado na memória, ela ocupará os endereços de 0x7E00
; até 0x7E1F.                     
;
;
; ├────── Assinatura do Kernel ───────┤  0x7E20 (kernel_entry)
; ┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─ ↩ ────────────────────────────────────
; │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │  Memória do Kernel
; └─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴──────────────────────────────────────
; ↪ 0x7E00                            ↪ 0x7E1F
;
;
; =============================================================================


kernel_signature:

	db 0xDE,0xAD,0xBE,0xEF,0x01,0x23,0x45,0x67,0x89,0xAB,0xCD,0xEF,0x10,0x32,
	db 0x54,0x76,0x98,0xBA,0xDC,0xFE,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,
	db 0x99,0xAA,0xBB,0xCC




; =============================================================================
;
; PONTO DE ENTRADA DO KERNEL
;
;
; Configura os seletores de segmento e a pilha do kernel. Em Modo Protegido, os 
; registradores de segmento (DS, ES, SS) não contêm endereços, mas sim "seletores"
; que apontam para descritores de segmento na GDT. O seletor 0x10 aponta para o
; índice do Descritor de Segmento de Dados do Kernel.
;
; Como foi adotado o esquema "Flat Model" (base 0x0, limite 4GB), o endereço linear
; será igual ao valor do offset. Dessa forma, fazendo ESP = 0x200000 (topo da pilha),
; significa que ESP apontará para este endereço linear (que coincide com o físico,
; pois não há paginação).
;
; =============================================================================	


kernel_entry:

    mov ax, 0x10                  ; Carrega o seletor do segmento de dados da GDT
	                              ; em AX.
								  
    mov ds, ax                    ; Copia o seletor no registrador de segmento DS.
	
    mov es, ax                    ; Copia o seletor no registrador de segmento ES.
	
	mov fs, ax                    ; Copia o seletor no registrador de segmento FS.
	
	mov gs, ax                    ; Copia o seletor no registrador de segmento GS.
	
    mov ss, ax                    ; Copia o seletor no registrador de segmento SS 
	                              ; (define o segmento da pilha. A base vem da GDT,
								  ; que em "Flat Model" é 0x00000000). 
	
    mov esp, 0x200000             ; Define o registrador ESP (topo da pilha) no
	                              ; endereço 0x200000 (2MB).
								  
			
	
	
; =============================================================================
;
; INICIALIZAÇÃO DAS VARIÁVEIS
;
;
; Sendo didático, em assembly não há variáveis como em linguagens de programação
; de alto nível como C ou Java, mas sim endereços de memória que serão utilizados
; pelo kernel e que são rotulados. O montador NASM resolve o rótulo (label) para
; o endereço ou deslocamento correspondente durante a geração do código binário.
; Na prática, isto se assemelha tanto com variáveis que tratei ambos os conceitos
; indistintamente.
;
; As variáveis inicializadas nesta rotina são:
;
;
;   ● hpet_addr: Endereço da região de memória mapeada (MMIO) para o componente 
;     HPET. Neste projeto, será adotado o endereço padrão 0xFED00000, por uma
;     questão de simplificação do código-fonte assembly.
;
;     Embora seja comum que o HPET seja mapeado neste endereço, isto não é uma 
;     regra fixa. O endereço pode variar dependendo de:
;
;
;       > Chipset.
;
;       > Firmware.
;
;       > Virtualização.
;
;       > Emuladores.
;
;       > Plataformas x86 embarcadas.
;
;
;     O chipset oferece uma gama limitada de opções para o mapeamento do HPET,
;     que normalmente são os seguintes endereços:
;
;
;       > 0xFED00000 (Padrão).
;
;       > 0xFED01000.
;
;       > 0xFED02000.
;
;       > 0xFED03000.
;
;
;     Em um sistema prático é necessário fazer uma busca via ACPI para resolver
;     em qual destes endereços o HPET está mapeado de fato, e não assumir que ele
;     está no endereço padrão, como feito neste código.
;
;     ACPI (Advanced Configuration and Power Interface) é o padrão usado pelo 
;     firmware para descrever o hardware para o sistema operacional. Ele define
;     como o sistema operacional vai controlar:
;
;
;       > Energia (soneca, hibernação, desligamento).
;
;       > Descoberta/configuração de hardware.
;
;       > Eventos do sistema.
;
;       > Timers.
;
;       > CPUs.
;
;       > Baterias.
;
;       > Dispositivos embarcados.
;
;
;     Para encontrar o endereço do HPET via ACPI, a busca será feita pelas seguintes
;     estruturas de dados:
;
;
;       > RSDP (Root System Description Pointer): É uma estrutura de dados definida
;         pela especificação ACPI que fornece um ponto de entrada central que lista 
;         e referencia outras tabelas.
;
;         A RSDP aponta para:
;
;
;           * RSDT (Root System Description Table (32-bit)).
;
;           * XSDT (Extended System Description Table (64-bit)).
;
;
;       > RSDT/XSDT: Estas tabelas existem basicamente para listar onde estão todas
;         as outras tabelas ACPI na memória física. Em sistemas de 32 bits, a RSDT
;         armazena endereços de 32 bits. Com a transição para arquiteturas de 64 
;         bits, a XSDT foi introduzida para suportar endereços de 64 bits e maior
;         compatibilidade com hardware moderno. Muitos firmwares mantêm ambas as
;         tabelas para compatibilidade retroativa.
;
;         A RSDT/XSDT contém ponteiros para diversas tabelas ACPI, como:
;
;
;           * FADT.
;
;           * MADT.
;
;           * HPET.
;
;           * MCFG.
;
;           * etc...
;
;
;         O endereço do HPET que vamos salvar em hpet_addr será encontrado na tabela 
;         HPET. 
;
;
;       > HPET: A tabela HPET da ACPI é a estrutura de dados usada pelo firmware 
;         para informar ao sistema operacional:
;
;
;           * Que existe um HPET.
;
;           * Onde ele está mapeado.
;
;           * Capacidades básicas do timer.
;
;           * Informações de bootstrap.
;
;
;         Ela é uma tabela estática (não contém código executável AML) e serve
;         como um mapa informativo para o kernel. Foi introduzida no ACPI 2.0 e
;         sua assinatura é "HPET".
;         
;         A tabela HPET é composta pelos seguintes campos:
;
;
;           * Header: Cabeçalho padrão presente em todas as tabelas ACPI.
;
;
;           * EventTimerBlockID: Esse campo descreve:
;
;               # Capacidades do HPET.
;               # Fabricante.
;               # Número de timers.
;               # Suporte 64-bit.
;
;             Ele corresponde ao registrador General Capabilities and ID Register
;             do hardware do HPET.
;
;
;           * BaseAddress: Este é o campo mais importante da tabela. Ele informa
;             onde o HPET está mapeado na memória física. Num sistema prático,
;             seria neste campo que o kernel encontraria o valor a ser gravado
;             na variável hpet_addr.
;
;
;           * HPETNumber: Identifica qual HPET está sendo descrito. É útil em 
;             sistemas com múltiplos HPETs.
;
;
;           * MinimumTick: Indica o período mínimo do clock em fentossegundos 
;             (10^-15 segundos). Isso define o menor intervalo seguro de programação
;             periódica.
;
;             Se o sistema operacional programar interrupções muito rápidas:
;
;               # O hardware pode perder ticks.
;               # Comparators podem falhar.
;               # IRQs podem sumir.
;
;
;           * PageProtection: Define proteções de paginação para o MMIO do HPET.
;             Na prática, muitos sistemas operacionais ignoram este campo e muitos 
;             firmwares o colocam como 0, onde:
;
;               0 → Sem proteção.
;               1 → Proteção 4 KB.
;               2 → Proteção 64 KB.
;
;
;         Em linguagem C, a tabela HPET poderia ser representada com a seguinte
;         struct:
;
;
;           struct ACPI_HPET_TABLE {
;               ACPI_SDT_HEADER  header;
;               uint32_t         event_timer_block_id;
;               GAS              base_address;
;               uint8_t          hpet_number;
;               uint16_t         minimum_tick;
;               uint8_t          page_protection;
;           };
;
;
;         Onde:
;
;
;           ACPI_SDT_HEADER: Struct que representa o cabeçalho padrão das tabelas
;           ACPI.
;
;             struct ACPI_SDT_HEADER {
;                 char      signature[4];
;                 uint32_t  length;
;                 uint8_t   revision;
;                 uint8_t   checksum;
;                 char      oem_id[6];
;                 char      oem_table_id[8];
;                 uint32_t  oem_revision;
;                 uint32_t  creator_id;
;                 uint32_t  creator_revision;
;             };
;
;
;           GAS (Generic Address Structure): Estrutura genérica definida pela ACPI
;           para descrever endereços de registradores ou regiões de hardware. No
;           caso da tabela HPET, ela descreve o endereço físico base do MMIO do 
;           HPET.
;
;             struct GAS {
;                 uint8_t   address_space_id;
;                 uint8_t   register_bit_width;
;                 uint8_t   register_bit_offset;
;                 uint8_t   access_size;
;                 uint64_t  address;
;             };
;
;
;         Um exemplo real de HPET pode ser visto abaixo:
;
;
;           Signature          = "HPET"
;           Length             = 56
;           Revision           = 1
;           Checksum           = 0xA7
;           OEMID              = "INTEL "
;           OEMTableID         = "HPET    "
;           OEMRevision        = 1
;           CreatorID          = "INTL"
;           CreatorRevision    = 0x20201112
;           
;           EventTimerBlockID  = 0x8086A201
;           
;           BaseAddress:
;               SpaceID        = 0
;               BitWidth       = 64
;               BitOffset      = 0
;               AccessSize     = 0
;               Address        = 0xFED00000
;           
;           HPETNumber         = 0
;           
;           MinimumTick        = 0x80
;           
;           PageProtection     = 0
;
;
;     Um diagrama que ilustra as estruturas de dados da ACPI envolvidas na busca
;     pelo endereço do HPET pode ser visto na figura abaixo:
;
;
;       ┌──────────┐
;       │   RSDP   │
;       └─┬────────┘     
;         │  32 bit
;         │  ┌──────────┐
;         ├──┤   RSDT   ├──┐
;         │  └──────────┘  │
;         │  64 bit        │
;         │  ┌──────────┐  │
;         └──┤   XSDT   ├──┤
;            └──────────┘  │
;                          │  ┌──────────┐
;                          ├──┤   FADT   │
;                          │  └──────────┘
;                          │  ┌──────────┐
;                          ├──┤   SSDT   │
;                          │  └──────────┘  │ Header
;                          │  ┌──────────┐  │ EventTimerBlockID
;                          ├──┤   HPET   ├──┤ BaseAddress ← (campo pesquisado)
;                          │  └──────────┘  │ HPETNumber
;                          │  ┌──────────┐  │ MinimumTick
;                          ├──┤   MADT   │  │ PageProtection
;                          │  └──────────┘
;                          .
;                          .
;                          .
;
;
;     O endereço da estrutura RSDP na memória também não é fixo. Para encontrá-lo,
;     é necessário fazer uma busca na estrutura do EBDA (Extended BIOS Data Area)
;     ou na região de memória alta entre 0x000E0000 e 0x000FFFFF (se não encontrado
;     na EBDA).
;
;     Outro detalhe importante com relação ao HPET é a configuração do cacheamento
;     da região de memória deste via MTRR e PAT.
;
;     MTRR (Memory Type Range Registers) são um conjunto de registradores da 
;     arquitetura x86 (MSRs - Model-Specific Registers) que permitem ao sistema
;     operacional definir como o processador trata regiões de memória física em 
;     termos de cache e comportamento de acesso. Permite dizer ao processador que
;     o intervalo de endereços físicos deve ser tratado como de um determinado
;     tipo de memória
;
;     Os tipos de memória suportados incluem:
;
;
;       > Uncached (UC): Todos os acessos são feitos diretamente na memória
;         física ou no dispositivo MMIO, sem utilização de cache interno da CPU.
;         Leituras e escritas sempre atingem o hardware imediatamente. Utilizado
;         para dispositivos como HPET, APIC e registradores MMIO críticos.
;
;
;       > Write-Through (WT): Leituras podem ser armazenadas em cache, porém
;         escritas são feitas simultaneamente no cache e na memória física. Garante 
;         consistência imediata entre cache e memória ao custo de menor desempenho
;         de escrita.
;
;
;       > Write-Combining (WC): Escritas podem ser temporariamente agrupadas em
;         buffers internos da CPU antes de serem enviadas para a memória/dispositivo.
;         Melhora desempenho em escritas sequenciais grandes, como framebuffers 
;         de GPU. Leituras normalmente não são cacheadas.
;
;
;       > Write-Back (WB): Leituras e escritas utilizam totalmente os caches internos
;         do processador. Escritas podem permanecer apenas no cache temporariamente
;         e serem propagadas para a memória física posteriormente. É o modo mais
;         rápido e normalmente utilizado para RAM convencional.
;
;
;       > Write-Protect (WP): Leituras podem ser cacheadas, porém escritas não 
;         utilizam cache write-back e são propagadas diretamente para a memória
;         física. É pouco utilizado na prática e depende da implementação da CPU.
;
;
;     PAT (Page Attribute Table) é um mecanismo introduzido nas arquiteturas x86
;     mais modernas que permite definir o tipo de memória diretamente nas entradas
;     das tabelas de paginação, oferecendo controle mais fino sobre o comportamento
;     de cache de páginas individuais.
;
;     Diferentemente dos MTRRs, que operam sobre intervalos físicos grandes de
;     memória (range), o PAT funciona em nível de página virtual mapeada, permitindo
;     que diferentes regiões utilizem políticas distintas de cacheamento mesmo
;     dentro de um mesmo intervalo físico contínuo.
;
;     O PAT é configurado através do registrador MSR IA32_PAT, que contém uma
;     tabela com até 8 tipos de memória selecionáveis. As entradas das tabelas
;     de paginação (PTE/PDE/PDPTE) utilizam combinações dos bits PCD, PWT e PAT
;     para selecionar uma dessas entradas.
;
;     Os principais tipos de memória suportados pelo PAT incluem:
;
;
;       > Uncached (UC): Todos os acessos atingem diretamente o hardware sem 
;         utilização de cache interno da CPU. Leituras e escritas são sempre
;         realizadas imediatamente no dispositivo físico.
;
;
;       > Write-Combining (WC): Escritas consecutivas podem ser agrupadas 
;         temporariamente antes de serem enviadas ao hardware. Muito utilizado 
;         em framebuffers e memória de vídeo para melhorar throughput de escrita.
;
;
;       > Write-Through (WT): Leituras podem utilizar cache, porém escritas são
;         propagadas simultaneamente para o cache e para a memória física.
;
;
;       > Write-Back (WB): Leituras e escritas utilizam plenamente os caches internos
;         da CPU, permitindo máximo desempenho.
;
;
;       > Uncacheable Minus (UC-): Similar ao modo UC, porém permitindo algumas 
;         otimizações internas e acessos especulativos controlados dependendo da
;         implementação da CPU.
;
;
;     Em sistemas modernos, o PAT normalmente é utilizado em conjunto com os MTRRs,
;     oferecendo granularidade por página virtual, enquanto os MTRRs continuam
;     definindo atributos globais para intervalos de memória física. O tipo efetivo
;     de memória observado pela CPU resulta da combinação entre PAT, MTRRs e outros
;     mecanismos. Caso exista conflito entre configurações, a CPU aplica regras
;     de precedência definidas pela arquitetura x86.
;
;     A faixa de endereços mapeada para o HPET deve, obrigatóriamente, ser definida
;     como uncached, ou seja, memória sem cache com acesso direto ao hardware. Isso
;     é necessário porque:
;
;
;       > Precisa refletir hardware imediatamente.
;
;       > Cache poderia fazer leituras retornarem valores desatualizados do contador.
;
;       > A escrita deve ser imediata no dispositivo.
;
;
;     Representando a faixa de endereços mapeada do HPET pelo tipo de memória em
;     um diagrama, considerando que ele esteja mapeado em 0xFED00000:
;
;
;                                   Memória RAM
;                               │                 │
;                               │                 │
;                               │                 │
;                               │                 │      
;             ----------------- │-----------------│ 0xFED003FF 
;             ┌┴─┴─┴─┴─┴─┴─┴─┴┐ │                 │    
;             │     HPET      │ │    Uncached     │
;             └┬─┬─┬─┬─┬─┬─┬─┬┘ │                 │
;             ----------------- │-----------------│ 0xFED00000
;                               │                 │  
;                               │                 │
;                               │                 │
;                               │                 │
;                               │                 │
;                               │                 │
;
;
;     O BIOS já faz essa configuração básica durante o POST e neste projeto ela
;     será mantida.
;
;     Adiante no código será feito o acesso ao componente para configurá-lo como
;     gerador da interrupção de relógio (IRQ0) e para calibrar o TSC para a
;     contagem do tempo.
;
;
;   ● vga_addr: Endereço da região de memória de vídeo do adaptador VGA. Diferentemente
;     do HPET, este é um endereço fixo para o adaptador, e faz parte da arquitetura
;     histórica do PC. Portanto, não é necessário (nem possível) fazer uma busca
;     via ACPI para resolver o endereço deste dispositivo.
;
;     Em sistemas com firmware BIOS, a memória de vídeo VGA é dividida em 3 regiões:
;
;
;              Memória RAM                     / │                    │
;      │                         │            /  │--------------------│ 0xC0000
;      │ Free                    │           /   │                    │
;      │-------------------------│ 0x100000 /    │ Color Text Buffer  │
;      │ BIOS                    │         /     │                    │
;      │─────────────────────────│ 0xC0000/      │--------------------│ 0xB8000
;      │ Video Memory            │               │                    │
;      │─────────────────────────│ 0xA0000       │ Monochrome Text    │
;      │ Extended BIOS Data Area │        \      │ Buffer             │
;      │-------------------------│ 0x9FC00 \     │--------------------│ 0xB0000
;      │ Free                    │          \    │                    │
;      │-------------------------│ 0x7E00    \   │ VGA Graphics Memory│
;      │ Bootloader              │            \  │                    │
;      │-------------------------│ 0x7C00      \ │--------------------│ 0xA0000
;      │ Free                    │               │                    │      
;      │-------------------------│ 0x500         
;      │ BIOS Data Area          │              
;      │-------------------------│ 0x400
;      │ Interrupt Vector Table  │
;      └─────────────────────────┘ 0x0
;
;
;     Onde:
;
;
;       VGA Graphics Memory: Endereços de 0xA0000 a 0xAFFFF. 
;
;       É utilizada pelo modo gráfico (pixels). Podem ser configurados diversos
;       modos gráficos como VGA 13h (320 x 200 pixels, com 256 cores), VGA 12h
;       (640 x 480 pixels, com 16 cores), VGA 10h (640 × 350 pixels, com 16 cores).
;       Todos estes modos usam a janela 0xA0000-0xAFFFF.
;
;       
;       Monochrome Text Buffer: Endereços de 0xB0000 a 0xB7FFF. 
;
;       É utilizada para dar suporte ao MDA (Monochrome Display Adapter), uma das
;       primeiras placas de vídeo oficiais do IBM PC, lançado em 1981. 
;
;       Exibe texto monocromático com 80 colunas × 25 linhas. Cada caractere ocupa
;       2 bytes. O primeiro byte representa o caractere, o segundo byte o atributo
;       monocromático (texto normal, sublinhado, etc).
;
;
;       Color Text Buffer: Endereços de 0xB8000 a 0xBFFFF. 
;
;       É a região de memória usada pelos adaptadores CGA, EGA e VGA para exibir
;       texto colorido na tela. O modo mais comum, e o que estamos utilizando
;       neste projeto, é o Modo 3h (80 colunas × 25 linhas). Mas há diversos
;       outros modos de texto colorido como 00h (40 colunas × 25 linhas, colorido),
;       02h (80 colunas × 25 linhas, monocromático, usando o buffer colorido em
;       0xB8000). Todos estes modos usam a janela 0xB8000-0xBFFFF
;
;       Para uma descrição mais detalhada do modo de texto VGA 3h, vá ao código-fonte
;       do bootloader e leia a documentação da rotina set_vga_text_mode.
;
;
;     Embora existam três regiões distintas (0xA0000, 0xB0000 e 0xB8000), elas 
;     não correspondem necessariamente a três áreas físicas diferentes de memória.
;     Em um adaptador VGA, estas regiões são normalmente janelas de acesso para 
;     recursos internos do mesmo controlador de vídeo, mantidas por razões de 
;     compatibilidade com os adaptadores MDA, CGA e EGA.
;
;     Assim como com o HPET, o BIOS faz a configuração básica de MTTR para esta
;     região durante o POST, definindo-a como Uncached, e vamos manter esta 
;     configuração.
;
; =============================================================================

init_vars:

	mov dword [hpet_addr], 0xFED00000 ; Coloca o endereço MMIO padrão do HPET 
	                                  ; na variável hpet_addr.

	mov dword [vga_addr],  0xB8000    ; Coloca o endereço do video VGA na variável
	                                  ; vga_addr.




; =============================================================================
;
; PREENCHIMENTO DO BUFFER DE VÍDEO EM MODO VGA 3h
;
;
; O objetivo desta rotina é preencher todo o buffer de vídeo em modo VGA 3h com
; o caractere 0x1F20 (0b0001111100100000). Este é o caractere de espaço, com cor
; de texto branca e fundo azul (consulte a documentação da rotina set_vga_text_mode
; no código-fonte do bootloader para mais informações sobre o modo de texto VGA 
; 3h e sobre este caractere específico). Isso fará com que toda a tela mostre um 
; fundo azul, sem grifos visíveis.
;
; Na sequência, é impresso o texto com as instruções ("Esc=Sair F5=Atualizar")
; no canto direito, segunda linha da tela. Com isso, se define a parte estática, 
; do buffer, que não é alterada quando imprimir a data e hora do sistema.
;
;
;  ├───────────────────────── Color Text Buffer ── ... ───────────────────┤
;  ┌────────┬────────┬────────┬────────┬────────┬──   ──┬────────┬────────┐
;  │ 0x1F20 │ 0x1F20 │ 0x1F20 │ 0x1F20 │ 0x1F20 │  ...  │ 0x1F20 │ 0x1F20 │
;  └────────┴────────┴────────┴────────┴────────┴──   ──┴────────┴────────┘
;  |0xB8000 |0xB8001 |0xB8002 |0xB8003 |0xB8004 |  ...  |0xB8F9E |0xB8F9F |
;
;
; Quando for atualizada a data e a hora, vai mudar apenas os caracteres 
; refentes ao relógio na segunda linha, por exemplo, "21:50:00 30/05/2026".
; Isso se faz reescrevendo apenas os 19 primeiros caracteres naquela linha,
; sem alterar os demais caracteres no buffer de vídeo VGA, definidos nesta
; rotina.
;
; =============================================================================


fill_vga_buffer:

    mov edi, [vga_addr]           ; Define o endereço da memória de vídeo VGA em 
	                              ; EDI.
								  
    mov ecx, 2000                 ; Define o número de caracteres a serem escritos
	                              ; no buffer de vídeo em ECX. Como a tela contém
								  ; 80x25 caracteres, então serão gravados 2.000 
								  ; caracteres.
								  
    mov ax, 0x1F20                ; Define o valor do caractere a ser gravado no
                                  ; buffer em AX.
	
    cld                           ; Define o bit "Direction Flag" (DF) no registro
                                  ; de EFLAGS como 0.
	
    rep stosw                     ; A instrução rep stosw vai gravar os 2000 
	                              ; caracteres de espaço na memória de vídeo, 
								  ; iniciando no endereço apontado por ES:EDI 
								  ; (com EDI = 0xB8000).
								  
	mov si, screen_message        ; Mensagem com os atalhos de teclado à direita
	                              ; da tela na segunda linha ("Esc=Sair F5=Atualizar").
	
    call print_2nd_line           ; Imprime a mensagem na segunda linha.
	
	
	
	
; =============================================================================
;
; OCULTAÇÃO DO CURSOR
;
;
; Oculta o cursor de texto no prompt do relógio usando I/O port-mapped I/O (PMIO).
;
; Esta rotina está acessando os seguintes registradores internos do adaptador VGA:
;
;
;   > 0x0A: Cursor Start Register.
;
;   > 0x0B: Cursor End Register.
;
;
; Esses registradores controlam:
;
;
;   > Visibilidade do cursor.
;
;   > Formato (linha inicial/final).
;
;   > blink vs disable.
;
;
; Nota:
;
; O VGA clássico mistura o dois tipos de acesso: MMIO e PMIO.
;
; =============================================================================


hide_cursor:
    
	mov dx, 0x3D4                 ; Coloca o endereço do registrador de controle
	                              ; do CRT (CRTC Index) em DX. A porta de I/O 
								  ; 0x3D4 seleciona qual registrador interno do 
								  ; CRT acessar.       
    
	mov al, 0x0A                  ; Seleciona o registrador de cursor alto (Cursor
	                              ; Start Register) na porta 0x3D4. Este registrador
								  ; controla o início do cursor e outros bits 
								  ; relacionados.
    
	out dx, al                    ; Envia o índice do registrador (0x0A) para o 
	                              ; CRT através da porta 0x3D4. O CRT agora sabe
								  ; que o próximo valor que será escrito na porta
								  ; 0x3D5 será para o registrador 0x0A.
    
	mov al, 0x20                  ; Valor que será escrito no registrador 0x0A.
                                  ; O bit 5 = 1 desativa o cursor (Cursor Disable).
    
	inc dx                        ; Incrementa DX para apontar para 0x3D5, a porta
	                              ; de dados do CRT. 
    
	out dx, al                    ; Escreve o valor 0x20 no registrador 0x0A do
	                              ; CRT. Isso desativa o cursor na tela.

    mov dx, 0x3D4                 ; Coloca o endereço do registrador de controle
	                              ; do CRT (CRTC Index) em DX. Vamos manipular o 
								  ; registrador 0x0B agora.        
    
	mov al, 0x0B                  ; Seleciona o registrador de cursor baixo (Cursor
	                              ; End Register) na porta 0x3D4. Este registrador 
								  ; define a linha final do cursor (Cursor End
								  ; Scanline) e parâmetros relacionados à sua forma.   
    
	out dx, al                    ; Envia o índice 0x0B para o CRT através da porta 
	                              ; 0x3D4. Dessa forma o CRT sabe que o próximo
								  ; valor na porta de dados será para o registrador
								  ; 0x0B.
    
	mov al, 0x00                  ; Valor que será escrito no registrador 0x0B. 
								  ; Define o final do cursor como linha 0.     
    
	inc dx                        ; Incrementa DX para apontar para 0x3D5, a porta
	                              ; de dados do CRT.
    
	out dx, al                    ; Escreve o valor 0x00 no registrador 0x0B 
	                              ; (configuração da forma do cursor).




; =============================================================================
;
; Configura a tabela IDT. Serão mapeados apenas 2 tratadores de interrupção
; neste kernel (handlers), ficando o restante das entradas da tabela UDT sem 
; tratadores definidos. 
;
;
;   > Handler da interrupção de relógio (IRQ0), mapeado na entrada 32 (gate 32).
;
;
;   > Handler da interrupção de teclado (IRQ1), mapeado na entrada 33 (gate 33).
;
;
; Os bytes que serão gravados em cada entrada serão os seguintes:
;
;
;   Byte    Conteúdo    Descrição
;   ------  ----------  -------------------------------------------------------
;   0-1     AX (low)    Parte baixa do endereço da rotina.
;
;   2-3     0x08        Seletor de código da GDT (índice 1, <<3, TI=0, RPL=0).
;
;   4       0x0         Byte reservado.
;
;   5       0x8E        Atributos (Presente=1, DPL=0, Tipo=Interrupt Gate 
;                       32-bit).
;
;   6-7     AX (High)   Parte alta do endereço da rotina (little-endian).
;
; =============================================================================


init_idt:

    lidt [idt_ptr]                ; Carrega o registrador interno da CPU (IDTR)
                                  ; com a localização e o tamanho da tabela IDT.
                                  ; Com isso o processador sabe para onde pular
								  ; quando o hardware sinalizar uma interrupção 
								  ; de relógio (IRQ0), teclado (IRQ1) ou uma 
								  ; exceção.				

; -----------------------------------------------------------------------------
; Configura a entrada 32 (gate 32) da IDT para apontar para o handler do relógio 
; (irq0_handler). Dessa forma, quando o HPET/PIT gerar a interrupção, o processador 
; executará o código deste handler.
; -----------------------------------------------------------------------------

set_gate_32:

    mov eax, irq0_handler         ; Copia o endereço de memória da rotina de 
	                              ; tratamento da interrupção de relógio em 
								  ; EAX.
								  
    mov edi, idt_table + (32 * 8) ; Copia o endereço de memória da entrada 32 na 
	                              ; tabela IDT em EDI. Multipliquei por oito,
								  ; pois cada entrada na IDT tem 8 bytes.
								  
	mov word [edi + 0], ax        ; Grava os 16 bits menos significativos do
                                  ; endereço da rotina (offset baixo) na
                                  ; entrada da IDT.  
								  
    mov word [edi+2], 0x08        ; Define o Seletor de Segmento na entrada 32
	                              ; da IDT. O valor 0x08 aponta para o segmento
								  ; de código na GDT (índice 1, deslocado 3 bits,
								  ; sem bits de TI ou RPL).
								  
	mov byte [edi + 4], 0         ; Define o byte reservado da entrada da IDT
                                  ; como zero, conforme exigido pela arquitetura.     
	
	mov byte [edi + 5], 0x8E      ; Define os atributos da entrada:
	                              ;
                                  ; > P = 1 (presente)
								  ;
								  ; > DPL = 0 (nível 0)
								  ;
                                  ; > Tipo = 1110 (Interrupt Gate 32-bit).      						 
								  
    shr eax, 16                   ; Desloca o endereço da rotina em EAX para a
	                              ; direita, para pegar os 16 bits superiores
								  ; do endereço em AX. Agora AX contém os 16 bits
								  ; altos do endereço.
								  
	mov word [edi+6], ax          ; Grava os 16 bits mais significativos do
                                  ; endereço da rotina (offset alto) na entrada
                                  ; da IDT, completando o ponteiro de 32 bits.
								  
; -----------------------------------------------------------------------------
; Configura a entrada 33 (gate 33) da IDT para apontar para o handler do teclado 
; (irq1_handler). Desta forma, toda vez que uma tecla for pressionada, executa
; o código deste handler.
; -----------------------------------------------------------------------------

set_gate_33:

    mov eax, irq1_handler         ; Copia o endereço de memória da rotina de 
	                              ; tratamento da interrupção de teclado em 
								  ; EAX.   
                                  
    mov edi, idt_table + (33 * 8) ; Copia o endereço de memória da entrada 33 na 
	                              ; tabela IDT em EDI.
                                  
    mov word [edi + 0], ax        ; Grava os 16 bits menos significativos do
                                  ; endereço da rotina (offset baixo) na
                                  ; entrada da IDT.     
								  
    mov word [edi + 2], 0x08      ; Define o Seletor de Segmento na entrada 33
	                              ; da IDT. O valor 0x08 aponta para o segmento
								  ; de código na GDT (índice 1, deslocado 3 bits,
								  ; sem bits de TI ou RPL).   
								  
    mov byte [edi + 4], 0         ; Define o byte reservado da entrada da IDT
                                  ; como zero, conforme exigido pela arquitetura.       
								  
    mov byte [edi + 5], 0x8E      ; Define os atributos da entrada:
	                              ;
                                  ; > P = 1 (presente)
								  ;
								  ; > DPL = 0 (nível 0)
								  ;
                                  ; > Tipo = 1110 (Interrupt Gate 32-bit).    
								  
    shr eax, 16                   ; Desloca o endereço da rotina em EAX para a
	                              ; direita, para pegar os 16 bits superiores
								  ; do endereço em AX. Agora AX contém os 16 bits
								  ; altos do endereço.               
								  
    mov word [edi + 6], ax        ; Grava os 16 bits mais significativos do
                                  ; endereço da rotina (offset alto) na entrada
                                  ; da IDT, completando o ponteiro de 32 bits.     




; =============================================================================
;
; Faz o remapeamento do PIC (Programmable Interrupt Controller). Por padrão, o 
; BIOS configura o PIC para que as IRQs usem as entradas de 0x08 a 0x0F (PIC 
; Mestre) e de 0x70 a 0x77 (PIC Escravo) da IVT. Mas em Modo Protegido não usa a
; IVT, e a Intel reservou as entradas de 0 a 31 da IDT para tratamento de exceções
; da CPU (como Divisão por Zero ou Falha de Página).
;
; Se não remapearmos as IRQs no Modo Protegido, quando o HPET disparar o relógio
; (IRQ0) ao habilitarmos de novo as interrupções mascaráveis, a CPU vai achar que
; ocorreu uma "Double Fault", pois o PIC estará usando os vetores gravados pelo 
; BIOs para a IVT, e como vai ter apenas 0x0 na entrada 0x08 da IDT, o processador 
; entra em Triple Fault e reinicia o computador. O mesmo ocorre se houver uma
; interrupção de teclado. Por isso remapearemos as IRQs para começarem a partir
; da entrada 32 (gate 32) da IDT, pois como vimos, entradas de 0 a 31 são utilizadas
; pela Intel para tratamento de exceções do processador.
;
; O PIC é configurado através de ICWs (Initialization Command Words). Serão 4 os
; comandos enviados em sequência para as portas de I/O do PIC (Mestre e Escravo):
;
; > ICW1: Envia o bitmask 0x11 para ambos os PICs (Mestre e Escravo). Isso diz a
;   eles para esperar mais 3 palavras de controle (ICW2, ICW3 e ICW4) e que estará
;   operando em modo cascata (SNGL = 0).
;
; > ICW2: Resolve o conflito com a Intel (faz o remapeamento das IRQs para a entrada
;   32 e adiante da IDT).
;
; > ICW3: O PIC Escravo está conectado fisicamente a um pino do Mestre. Este comando
;   sincroniza os dois chips para trabalharem juntos, em cascata.
;
; > ICW4: Define o modo de ambiente para x86.
;
; Nota:
;
; Por ser um kernel sem nenhuma função prática, não vou criar tratadores para
; interrupções espúrias (Spurious Interrupts). Como o teste será em máquinas 
; virtuais, não há a preocupação de tratar estas questões de ruídos no hardware.
; As interrupções espúrias aparecerão nos vetores 39 (PIC Mestre) e 47 (PIC 
; Escravo), conforme o remapeamento, devido a ruído elétrico ou timing. Num
; sistema prático, deveria-se associar uma rotina de tratamento destas interrupções,
; mesmo que elas contivessem apenas uma instrução ret (retornar).
;
; =============================================================================


remap_pic:				
				
; -----------------------------------------------------------------------------
; Comando ICW1:
; -----------------------------------------------------------------------------

    mov al, 0x11                  ; Carrega o valor 0x11 (binário 00010001) em
                                  ; AL. Este bitmask indica para o PIC esperar 
								  ; por ICW2, ICW3 e ICW4, que está em modo cascata
								  ; e para usar ativação por borda.
								  
    out 0x20, al                  ; Envia o comando de configuração para a porta
	                              ; de comando do PIC Mestre (porta 0x20).
								  
    out 0xA0, al                  ; Envia o comando de configuração para a porta 
	                              ; de comando do PIC Escravo (porta 0xA0).
								  
; -----------------------------------------------------------------------------
; Comando ICW2:
; -----------------------------------------------------------------------------	
							  
    mov al, 0x20                  ; Define o endereço base como 32 (0x20), gravando
	                              ; o valor em AL.
								  
    out 0x21, al                  ; Envia o endereço base para a porta de dados do
                                  ; PIC Mestre (porta 0x21). Agora, a IRQ0 (timer) 
								  ; será a interrupção 32, a IRQ1 (teclado) será
								  ; a 33, e assim por diante. O PIC Mestre controla
								  ; as IRQs 0 a 7. Elas dispararão as interrupções 
								  ; 32 a 39 na IDT.
								  
    mov al, 0x28                  ; Define o endereço base como 40 (0x28), gravando
	                              ; o valor em AL.
								  
    out 0xA1, al                  ; Envia o endereço base para a porta de dados do
                                  ; PIC Escravo (porta 0xA1). O PIC Escravo controla
								  ; as IRQs 8 a 15. Elas dispararão as interrupções 
								  ; 40 a 47 na IDT.
								  						  
; -----------------------------------------------------------------------------
; Comando ICW3:
; -----------------------------------------------------------------------------
								  
    mov al, 0x04                  ; Grava o valor 0x04 em AL. O valor 0x04 em 
	                              ; binário é 00000100. Ele indica que o bit 2
								  ; está ligado. Bit 2 ligado indica que o PIC 
								  ; escravo está conectado à linha IRQ2 do Mestre.
								  
    out 0x21, al                  ; Envia o bitmask para a porta de dados do PIC
	                              ; Mestre. Isso diz a ele que existe um PIC 
								  ; Escravo conectado na sua linha IRQ 2.
								  
    mov al, 0x02                  ; Grava o valor 0x02 em AL. O valor 0x02 é o
	                              ; ID numérico da linha. Em Intel/IBM, o PIC 
								  ; Escravo é mais simples que o PIC Mestre. 
								  ; Ele recebe o número da linha de conexão com
								  ; o Mestre.
								  
    out 0xA1, al                  ; Envia o valor 0x02 para a porta de dados do
	                              ; PIC Escravo. Isso diz ao Escravo que sua 
								  ; saída está ligada especificamente à linha 
								  ; física IRQ 2 do PIC Mestre.

; -----------------------------------------------------------------------------
; Comando ICW4:
; -----------------------------------------------------------------------------
						  
    mov al, 0x01                  ; Grava o valor 0x01 em AL. Este valor define
	                              ; o modo 8086/88 (x86) (este modo é compatível
								  ; com todas as CPUS modernas). Não vou usar
								  ; Auto-EOI (0x03) porque quero ter mais controle
								  ; das interrupções e vou fazer isto diretamente
								  ; no código.
								  
    out 0x21, al                  ; Envia o valor 0x01 para a porta de dados do
	                              ; PIC Mestre. Isso informa para ele operar no 
								  ; protocolo x86.
								  
    out 0xA1, al                  ; Envia o valor 0x01 para a porta de dados do
	                              ; PIC Escravo. Isso informa para ele operar no 
								  ; protocolo x86.




; =============================================================================
;
; Por padrão, a interrupção de relógio do sistema (IRQ0) era gerada pelo PIT 
; (Programmable Interval Timer) em computadores mais antigos. Em 2005 a Intel e
; a Microsoft introduziram o HPET para substituí-lo. Este componente oferece 
; frequências muito mais altas e maior precisão.
;
; Nesta etapa, vamos configurar o HPET, e definí-lo como o gerador de interrupção 
; de relógio para o kernel. Como discutido anteriormente, vamos admitir que ele
; está mapeado no endereço de memória padrão (0xFED00000), para evitar uma busca
; nas tabelas ACPI, o que deixaria o código Assembly mais complexo. Logo, todos
; os registradores serão calculados com base neste endereço de base.
;
; O HPET possui um conjunto de registradores de 64 bits. Os principais deles são:
;
; GCAP_ID (General Capabilities and ID): Offsets: 0x000 (Low) e 0x004 (High).
; Registrador apenas leitura. Indica a versão, o número de comparadores (timers)
; disponíveis e o período do clock principal (Main Counter).
; 
;   > Bits 0-7 (REV_ID): Versão do hardware HPET.
;
;   > Bits 8-12 (NUM_TIM_CAP): Quantidade de comparadores (timers) disponíveis. 
;     O HPET possui de 3 a 32 timers (também chamados de canais), dependendo da
;     implementação do chipset (Intel, AMD, etc.)
; 
;   > Bit 13 (COUNT_SIZE_CAP): Se este bit é 1, o Main Counter é de 64 bits, se 
;     0, é de 32 bits.
; 
;   > Bit 15 (LEG_RT_CAP): Se este bit é 1, o HPET suporta o "Legacy Replacement
;     Route" (substituir o PIT e RTC), se 0, não suporta.
; 
;   > Bits 16-31 (VENDOR_ID): Identificação do fabricante.
;
;   > Bits 32-63 (Offset 0x004 - COUNTER_CLK_PERIOD): Indica o período de um "tick"
;     do HPET em fentosegundos (10^-15s).
;
; GEN_CONF (General Configuration): Offset: 0x010. Permite habilitar o contador 
; principal e configurar o modo de interrupção (Legacy Replacement).
; 
;   > Bit 0 (ENABLE_CNF): Se este bit é 0, o Main Counter para e não incrementa,
;     se 1, o Main Counter começa a contar.
;
;   > Bit 1 (LEG_RT_CNF): Se este bit é 0, usa Interrupções normais via APIC, se
;     é 1, ativa o "Legacy Replacement Route". Ativando este modo, o Timer 0 assume
;     a IRQ 0 (PIT) e o Timer 1 assume a IRQ 8 (RTC).
;
;   > Bits 2-63: Bits reservados.
;
; MAIN_CNT (Main Counter Value): Offset: 0x0F0 (Low) e 0x0F4 (High). Contador de
; 64 bits que incrementa continuamente.
;
;   > Bits 0-63: É um contador crescente.
;
; T0_CONFIG_CAP (Timer 0 Configuration and Capabilities): Offset: 0x100. Configura
; o comportamento do Timer 0.
;
;   > Bit 1 (TN_INT_TYPE_CNF): 0 para interrupção por borda (Edge), 1 para nível 
;     (Level).
;
;   > Bit 2 (TN_INT_ENB_CNF): Se este bit é 1, habilita a geração de interrupções
;     para este timer.
;
;   > Bit 3 (TN_TYPE_CNF): Se este bit é 1, define modo periódico. Neste modo o
;     timer recarrega automaticamente. Se for 0, define o modo One-shot.
;
;   > Bit 4 (TN_PER_INT_CAP) (Read Only): Indica se este timer suporta modo
;     periódico.
;
;   > Bit 5 (TN_SIZE_CAP)(Read Only): Se este bit é 1, o comparador é de 64 bits.
;
;   > Bit 6 (TN_VAL_SET_CNF): Se este bit é 1, permite escrever diretamente no
;     acumulador do comparador para sincronização.
;
;   > Bit 8 (TN_32MODE_CNF): Força o timer a operar em 32 bits mesmo se for 64.
;
;   > Bits 9-13 (TN_INT_ROUTE_CNF): Seleciona para qual IRQ do I/O APIC a
;     interrupção será enviada.
;
;   > Bit 14 (TN_FSB_EN_CNF): Habilita entrega via FSB (MSI) em vez de pinos de
;     IRQ.
;
;   > Bit 15 (TN_FSB_INT_DEL_CAP)(Read Only): Indica se suporta MSI.
;
;   > Bits 16-31 (TN_INT_ROUTE_CAP): Campo de apenas leitura. Ele é um "mapa de 
;     bits" que indica para quais IRQs do I/O APIC este timer específico pode 
;     ser roteado.
;
;   > Bits 32-63: Bits reservados.
;
; T0_COMPARATOR (Timer 0 Comparator Value): Offset: 0x108 (Low) e 0x10C (High).
; 
;   > Bits 0-63: Contém o valor de "alvo". Quando MAIN_CNT igualar a este valor,
;     o Timer0 dispara a interrupção (e no modo periódico, ele adiciona este
;     intervalo ao valor atual para o próximo disparo).
;
; =============================================================================
	
	
setup_hpet:

						
	push esi                      ; Guarda o valor de ESI na pilha do kernel.

    mov esi, [hpet_addr]          ; Copia o endereço MMIO do HPET na memória para
	                              ; ESI. Com isso, ESI passa a ser o endereço base
								  ; do HPET.

; -----------------------------------------------------------------------------
; Testa se o HPET está mapeado e respondendo corretamente.
; -----------------------------------------------------------------------------

    mov eax, [esi + 0x00]         ; Lê o registrador General Capabilities and ID
	                              ; e coloca o valor em EAX. 
    
	cmp eax, 0xFFFFFFFF           ; Compara o valor em EAX com 0xFFFFFFFF.
    
	je .hpet_fail                 ; Se EAX = 0xFFFFFFFF, significa que:
                                  ;	
	                              ; > O dispositivo não existe naquele endereço.
								  ; > O endereço está errado.
								  ; > A região não está mapeada corretamente.
								  ; > O hardware não respondeu à leitura.
								  ; > A leitura caiu em um “buraco” de memória.
								  ;
								  ; Neste caso, salta para .hpet_fail.
    
	test eax, eax                 ; Executa um AND lógico entre EAX e ele mesmo.
	                              ; Se EAX = 0, faz a flag ZF = 1. Isso significa
								  ; que o registrador veio zerado.
    
	je .hpet_fail                 ; Se EAX == 0 é outro sinal de hardware inválido 
	                              ; ou não inicializado. Salta para .hpet_fail.

    mov eax, [esi + 0x10]         ; Lê o valor do registrador General Configuration
                                  ; e coloca em EAX.
    
	or eax, 1                     ; Faz um OR bit a bit de EAX com 1. Isso seta 
	                              ; o Bit 0 (ENABLE_CNF). Bit 0 = 1 liga o contador
								  ; principal (Main Counter) do HPET.
    
	mov [esi + 0x10], eax         ; Escreve o valor de EAX de volta no registrador.
	                              ; Isso ativa o HPET.

    mov ecx, 10000                ; Define ECX como 10000. Este valor vai ser usado
	                              ; como contador de delay.

.delay1:

    loop .delay1                  ; Decrementa o valor em ECX. Enquanto ECX != 0,
	                              ; salta para .delay1. Isso cria um pequeno atraso 
								  ; (busy-wait) para o HPET começar a contar.

    mov eax, [esi + 0xF0]         ; Lê o Main Counter (parte baixa, 32 bits).

    mov ebx, eax                  ; Copia o valor de EAX para EBX, para comparação
	                              ; subsequente.

    mov ecx, 50000                ; Define ECX como 50000. Esse valor vai ser usado
                                  ; em outro delay, que dá tempo suficiente para
								  ; o contador principal mudar.

.delay2:

    loop .delay2                  ; Decrementa o valor em ECX. Enquanto ECX != 0,
	                              ; salta para .delay2.

    mov eax, [esi + 0xF0]         ; Lê novamente o Main Counter (parte baixa, 32 
	                              ; bits).

    cmp eax, ebx                  ; Compara o valor atual de Main Counter em EAX
	                              ; com o valor antigo em EBX.

    je .hpet_fail                 ; Se o valor antigo e o atual forem iguais, houve
	                              ; falha ao ativar o contador. Isso significa que:
								  ;
								  ; > O HPET não está contando. 
								  ; > O HPET não foi habilitado.
								  ; > A leitura MMIO falhou.
								  ;
								  ; Neste caso, salta para .hpet_fail.

    jmp .hpet_ok                  ; Se chegou até este ponto, o HPET está funcionando.
	                              ; Salta para .hpet_ok.

.hpet_fail:

	jmp .hpet_error               ; Salto incondicional para .hpet_error em caso
	                              ; de falha.

.hpet_ok:

; -----------------------------------------------------------------------------
; Desativa o contador principal para a configuração do Timer0 do HPET, que gerará
; a interrupção de relógio para o kernel (IRQ0).
; -----------------------------------------------------------------------------

    mov eax, [esi+0x10]           ; Copia o valor do registrador General Configuration
	                              ; do HPET em EAX.
	
    and eax, ~1                   ; Desliga o bit 0 (ENABLE_CNF), mantendo os 
	                              ; demais bits inalterados. Desligar o ENABLE_CNF
								  ; faz Main Counter parar.
	
    mov [esi+0x10], eax           ; Escreve o valor modificado de volta em General
	                              ; Configuration para aplicar a configuração.

; -----------------------------------------------------------------------------
; Mede um intervalo de 10 milissegundos, que é o tempo de "disparo" do Timer0 do
; HPET para a interrupção de IRQ0. O HPET conta o tempo em femtosegundos (fs) 
; que equivale a 10^-15 segundos.
;
; Convertendo 10 milissegundos em unidades de femtosegundos, temos: 
;
;   10 ms = 10.000.000.000.000 fs (10^13)
;
; Como o número 10.000.000.000.000 (9184E72A000 em hexadecimal) não cabe em um 
; registrador de 32 bits, o Assembly o divide entre o par de registradores EDX:EAX.
; O registrador EDX recebe a parte alta do número e o EAX recebe a parte baixa, 
; formando juntos o valor de 64 bits: 
;
;   > EDX (parte alta): Recebe o valor 0x00000918 deslocado para a esquerda.
; 
;   > EAX (parte baixa): Recebe o valor 0x4E72A000
;
; Na sequência é feita a leitura do valor de Main Counter Tick Period (duração de
; 1 tick em fs) do registrador General Capabilities and ID do HPET e aplicada a 
; seguinte equação:
;
;   ticks_10ms = 10.000.000.000.000/Valor 1 Tick
;
; O resultado da divisão, que vai para o registrador EAX, é o número que deve
; carregar no comparador do Timer0 para que ele dispare a interrupção de IRQ0
; quando passarem 10ms.
; -----------------------------------------------------------------------------

    mov edx, 0x00000918           ; Coloca a parte alta de 10^13 em EDX.
	
    mov eax, 0x4E72A000           ; Coloca a parte baixa de 10^13 em EAX.
	
    mov ebx, [esi + 0x04]         ; Lê o valor de Main Counter Tick Period (duração
	                              ; de 1 tick em fs) do registrador General Capabilities
								  ; and ID e copia em EBX.
								  
    test ebx, ebx                 ; Verifica se o período lido é válido (não zero).
	
    jz .hpet_error                ; Se EBX for zero, o hardware falhou ou é incompatível.
                                  ; Neste caso, pula para a rotina de tratamento
								  ; de erro. Caso contrário, passa para a próxima
								  ; linha.
								  
    div ebx                       ; Divide o valor de 64 bits em EDX:EAX (10ms) 
	                              ; pelo período em EBX. O quociente da divisão 
								  ; (número de ticks/10ms) é salvo em EAX, e o 
								  ; resto em EDX.
	
    mov [hpet_ticks_10ms], eax    ; Salva o número de ticks/10ms na memória.
	
    mov [hpet_remainder], edx     ; Salva o resto da divisão na memória.
	
    mov [hpet_divisor], ebx       ; Salva o divisor para o acumulador.

; -----------------------------------------------------------------------------
; Configura o Timer 0, que será o gerador de interrupções de relógio (IRQ0) do 
; kernel.
; -----------------------------------------------------------------------------

    mov dword [esi+0x100], 0x006C ; Configura o registrador T0_CONFIG_CAP 
	                              ; (Timer 0):
	                              ; 
	                              ; O valor 0x006C em binário ativa:
								  ;
	                              ; > Bit 2 (TN_INT_ENB_CNF): habilita interrupções.
								  ;
	                              ; > Bit 3 (TN_TYPE_CNF): modo periódico.
								  ;
	                              ; > Bit 6 (TN_VAL_SET_CNF): permite escrita no 
								  ;   acumulador
	                              ;
	                              ; Os demais bits permanecem desativados.
								  
    mov eax, [hpet_ticks_10ms]    ; Lê da memória o valor hpet_ticks_10ms e carrega no
	                              ; registrador EAX. Este valor representa quantos
								  ; "ticks" do HPET equivalem a 10 milissegundos.
								  
    mov [esi+0x108], eax          ; Escreve na parte baixa (Bits 0-31) do comparador.
                                  ; O registrador Tn_COMP (Timer n Comparator) inicia
                                  ; em 0x108. Como o HPET opera em 64 bits e a 
                                  ; CPU em 32 bits, enviamos primeiro os 32 bits 
                                  ; menos significativos do valor hpet_ticks_10ms.
								  
    mov [esi+0x108], eax          ; Escreve novamente o valor na parte baixa do 
	                              ; comparador. Em alguns hardwares HPET, é 
								  ; necessário escrever duas vezes para garantir
	                              ; a atualização correta do registrador.
								  
    mov dword [esi+0x10C], 0      ; Escreve na parte alta (Bits 32-63) do comparador.
                                  ; O deslocamento 0x10C aponta para os 4 bytes 
                                  ; seguintes do mesmo registrador de 64 bits.
								  ; Como o valor hpet_ticks_10ms cabe nos 32 bits da
								  ; parte baixa do registrador, grava-se zeros
								  ; para garantir que não se tenha lixo na memória,
								  ; o que impediria o disparo, pois formaria um
								  ; número muito grande.

; -----------------------------------------------------------------------------
; Zera o contador principal (Main Counter), e prepara o HPET para gerar as 
; interrupções de relógio (IRQ0) no lugar do PIT.								  
; -----------------------------------------------------------------------------

    mov dword [esi+0xF0], 0       ; Zera a parte baixa do registrador Main Counter. 
	
    mov dword [esi+0xF4], 0       ; Zera a parte alta do registrador Main Counter, 
	                              ; completando o reset.
    
	mov eax, [esi+0x10]           ; Lê o valor atual do registrador General Configuration
	                              ; em EAX.
    
	and eax, ~1                   ; Garante que o bit ENABLE_CNF (bit 0) esteja limpo,
	                              ; assegurando que o contador esteja parado antes
	                              ; de reconfigurar ou reiniciar.
    
	or eax, 1                     ; Ativa o bit ENABLE_CNF (bit 0), habilitando o
	                              ; contador principal do HPET para iniciar a contagem.
    
	mov edi, eax                  ; Copia o valor de EAX em EDI, para ativação
	                              ; do HPET em um momento posterior durante
								  ; a calibração do TSC.
								  
	jmp .hpet_done                ; Salto incondicional para .hpet_done .
	
.hpet_error:

	pop esi	                      ; Restaura o valor anterior de ESI guardado na
	                              ; pilha.				

    call hpet_fallback            ; Chama a rotina para tratamento de erro na
	                              ; configuração do HPET.

.hpet_done:

	pop esi                       ; Restaura o valor anterior de ESI guardado na
	                              ; pilha.
								 



; =============================================================================
;
; Faz a calibração do TSC (Time Stamp Counter). O TSC é um registrador de 64 bits
; interno de cada núcleo da CPU. Ele funciona como um contador de ciclos de clock.
;
; Existem dois tipos de TSC:
;
; > Variant TSC (Antigo): A frequência do TSC muda se a CPU entrar em modo de 
;   economia de energia. Isso torna a calibração inútil se o clock cair.
;
; > Invariant TSC (Moderno): O TSC incrementa  em uma frequência constante, 
;   independentemente do estado de energia da CPU. Este é o tipo utilizado neste
;   código, pois permite que o tempo seja medido de forma confiável.
;
; =============================================================================	


setup_tsc:

    mov eax, 1
    cpuid
    bt edx, 4
    jnc .no_tsc

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000007
    jb .not_invariant

    mov eax, 0x80000007
    cpuid
    bt edx, 8
    jc .invariant

.not_invariant:
	
	jmp .done

    call tsc_inv_fallback

.invariant:

    jmp .done

.no_tsc:

    call tsc_fallback

.done:


; -----------------------------------------------------------------------------
; Calibra o TSC usando o HPET.								  
; -----------------------------------------------------------------------------

	push esi                      ; Guarda o valor de ESI na pilha do kernel.

    mov esi, [hpet_addr]          ; Copia o endereço MMIO do HPET na memória para
	                              ; ESI. Com isso, ESI passa a ser o endereço base
								  ; do HPET.

    cpuid                   

    rdtsc                   

    mov [last_tsc_low], eax 

    mov [last_tsc_high], edx
	
	mov [esi+0x10], edi

    mov eax, [esi+0xF0]  

    mov ebx, eax         

    mov eax, [esi+0xF4]  

    mov ecx, eax         

    mov eax, [hpet_ticks_10ms]   

    mov edx, 0                   

.wait_10ms:

    mov eax, [esi+0xF0]  

    sub eax, ebx         

    mov edx, [esi+0xF4]  

    sbb edx, ecx         

    cmp edx, 0

    ja .wait_10ms        

    jb .measure_tsc      

    cmp eax, [hpet_ticks_10ms]

    jb .wait_10ms            

.measure_tsc:
    
	cpuid
    
	rdtsc
    
	sub eax, [last_tsc_low] 
    
	sbb edx, [last_tsc_high]
    
	mov [tsc_per_10ms_low], eax
    
	mov [tsc_per_10ms_high], edx
	
	pop esi
	



; =============================================================================
;
; Habilita as interrupções mascaráveis novamente para que o kernel possa processar
; as interrupções de relógio geradas pelo HPET e interrupções do teclado. No 
; bootloader o programa tinha desabilitado estas interrupções.
;
; Nota:
;
; As interrupções serão habilitadas, de fato, na rotina rtc_read_datetime, que 
; lê a data e hora atual do RTC e coloca na memória.
;
; =============================================================================


enable_interrupts:
    
    in al, 0x21                   ; Lê a máscara atual do PIC Mestre. O PIC controla
	                              ; quais IRQs podem chegar à CPU.
								  
    and al, 0xFC                  ; Aplica uma máscara AND com 0xFC (11111100). 
	                              ; Com isso, zera os Bits 0 e 1, que correspondem
                                  ;	à IRQ0 (Timer do Sistema) e IRQ1 (teclado),
								  ; habilitando-as. As demais IRQs não ficarão
								  ; habilitadas.
								  
    out 0x21, al                  ; Escreve a nova máscara de volta no PIC.
	
	call rtc_read_datetime        ; Chama a função que lê a data e a hora no RTC.
	



; =============================================================================
;
; Loop principal do kernel, que controla a impressão da data e hora do sistema
; atualizadas a cada 1 segundo. Ao ser "acordado" por uma interrupção, a rotina
; verifica o valor em second_flag:
; 
; > Se second_flag = 0, indica que a interrupção que acordou a CPU não foi a da 
;   "virada de segundo". Com isso, volta a executar a instrução hlt, para voltar
;   a "dormir", esperando pela próxima interrupção de relógio (IRQ0).
;
; > Se second_flag = 1, indica que um segundo completo se passou. Neste caso,
;   faz o reset de second_flag, imprime a hora atualizada na tela e volta a 
;   "dormir", esperando pela próxima interrupção de relógio.
;
; O valor de second_flag é alterado para 1 em irq0_handler quando 1 segundo 
; completo de ciclos de CPU transcorreu (obtidos pela leitura do TSC).
;
; =============================================================================


main_loop:

    hlt                           ; Instrução HALT. Coloca o processador em estado
	                              ; de baixo consumo de energia até que uma interrupção
								  ; ocorra. Como configuramos somente a interrupção
								  ; de relógio (IRQ0), gerada pelo HPET, esta 
								  ; instrução será executada a cada 10ms.
	
    cmp byte [second_flag], 1     ; Verifica se o valor armazenado na variável 
	                              ; second_flag é 1. 
    
	jne main_loop                 ; Instrução JUMP IF NOT EQUAL. Ela lê o valor
	                              ; de EFLAGS, alterado com a execução da instrução
								  ; anterior. Se o valor não for 1, significa que
								  ; a interrupção que acordou a CPU não foi a de
								  ; "virada de segundo". Nesse caso, volta para
								  ; o hlt.
    
	mov byte [second_flag], 0     ; Faz o reset de second_flag para 0.
    
	call print_date_time          ; Chama a rotina que escreve no buffer de vídeo
                                  ; a data e hora atualizadas.
    
	jmp main_loop                 ; Salto incondicional de volta ao início do loop
                                  ; para "dormir" no hlt e aguardar a próxima 
								  ; interrupção.
								 



; =============================================================================
;
; Tratador (handler) da interrupção de relógio (IRQ0)
;
; Este handler implementa um mecanismo de temporização de alta precisão baseado 
; no TSC (Time Stamp Counter), evitando depender exclusivamente da frequência das 
; interrupções do hardware, que pode sofrer jitter ou atrasos. A interrupção de
; relógio (IRQ0), configurada para ser gerada pelo HPET, disparará a cada 10ms.
;
; Funcionamento:
;
; > Lê o valor atual do TSC (contador de ciclos da CPU).
;
; > Calcula a quantidade de ciclos decorridos desde a última interrupção:
;
;   delta = TSC_atual - TSC_anterior
;
; > Acumula esses ciclos em um contador de 64 bits:
;
;   acumulador = acumulador + delta
;
; > Quando o acumulador atinge ou ultrapassa a quantidade de ciclos equivalente 
;   a 10 ms (tsc_per_10ms), o handler:
;
;   * Subtrai esse valor do acumulador:
;
;     acumulador = acumulador - tsc_per_10ms
;
;   * Incrementa o contador de tempo (ms_counter).
;
; O TSC avança continuamente, independente das interrupções. Portanto, uma única
; IRQ pode representar mais de 10 ms de tempo real. Nesse caso, o handler processa
; múltiplos "ticks" de 10 ms em um loop, consumindo o acumulador até que o tempo
; restante seja menor que 10 ms.
;
; Exemplo:
;
; Se 25 ms se passaram desde a última IRQ:
;
;   > 2 ticks de 10 ms são processados.
;
;   > 5 ms permanecem acumulados.
;
; A cada 100 ticks de 10 ms (1 segundo), o handler:
;
;   > Faz o reset do contador de milissegundos.
;
;   > Seta a flag second_flag = 1, indicando que 1 segundo completo se passou. 
;
;   > Chama a rotina para atualizar a hora/data do sistema na memória.
;
; O handler também aplica uma correção de erro (drift) usando valores derivados
; da calibração com HPET, garantindo maior precisão ao longo do tempo.
;
; =============================================================================


irq0_handler:

    pushad

    ; -----------------------------
    ; 1. Lê TSC atual
    ; -----------------------------
    cpuid
    rdtsc

    ; Salva TSC atual em registradores temporários
    mov ebx, eax            ; low
    mov esi, edx            ; high

    ; Calcula delta desde a última interrupção
    mov eax, ebx
    sub eax, [last_tsc_low]
    mov edx, esi
    sbb edx, [last_tsc_high]

    ; Atualiza último TSC com o valor atual (não o delta!)
    mov [last_tsc_low], ebx
    mov [last_tsc_high], esi

    ; -----------------------------
    ; 2. Acumula delta
    ; -----------------------------
    add dword [tsc_accumulator_low], eax
    adc dword [tsc_accumulator_high], edx

    ; -----------------------------
    ; 3. Converte tempo acumulado em múltiplos de 10ms
    ; -----------------------------
    mov eax, [tsc_per_10ms_low]
    mov edx, [tsc_per_10ms_high]

.check_10ms:
    ; Compara acumulador com tsc_per_10ms
    cmp [tsc_accumulator_high], edx
    ja .process_tick
    jb .eoi
    cmp [tsc_accumulator_low], eax
    jb .eoi

.process_tick:
    ; Subtrai 10ms de ciclos do acumulador
    sub dword [tsc_accumulator_low], eax
    sbb dword [tsc_accumulator_high], edx

    ; Incrementa contador de ms
    inc byte [ms_counter]

    ; Se 100 * 10ms passaram, incrementa segundo
    cmp byte [ms_counter], 100
    jb .check_10ms

    mov byte [ms_counter], 0
    mov byte [second_flag], 1
    call update_date_time_buffer

    ; Continua verificando se ainda há mais ticks acumulados
    jmp .check_10ms

.eoi:
    ; End of Interrupt
    mov al, 0x20
    out 0x20, al

    popad
    iretd            




; =============================================================================
;
; Atualiza a hora e a data na memória do computador. Aqui que as "engrenagens"
; do "relógio" serão movimentadas. A cada 1 segundo será executada esta rotina.
; Inicialmente a hora e a data são lidas do RTC durante o boot e carregadas na
; memória. Depois esta data e hora vão sendo atualizadas a cada segundo. Como não 
; é feita a leitura do RTC novamente, e temos o TSC calculando o tempo de um 
; segundo de modo preciso, serão feitos os seguintes cálculos nesta rotina, com
; base na data atualizada na memória no segundo anterior:
; 
;   > Inclementa os segundos. Caso chegue a 60 segundos...
; 
;   > Zera os segundos e inclementa os minutos. Caso chegue a 60 minutos...
;
;   > Zera os minutos e inclementa as horas. Caso chegue a 24 horas...
;
;   > Zera as horas e inclementa o dia do mês. Caso ultrapasse o último dia do
;     mês...
;
;   > Faz o reset do dia para 1 e inclementa o mês. Caso o mês ultrapasse 12
;     (dezembro)...
;
;   > Faz o reset do mês para 1 (janeiro) e inclementa o ano . Se o ano chegar a
;     100...
;
;   > Faz o reset do ano para 0 e inclementa o século.
;
; Nota:
;
; Se o mês for fevereiro, e for ano bissexto, é adicionado um dia a mais ao
; último dia do mês, passando de 28 para 29 dias. 
;
; O cálculo para ano bissexto leva em consideração a regra:
;
;   > Se o ano é divisível por 4 ->
;
;     > Se não é divisível por 100 -> É ano bissexto.
;
;     > Se é divisível por 100, mas não por 400 -> NÃO é ano bissexto.
;
;     > Se é divisível por 100 e também por 400 -> É ano bissexto.
;
; Resumindo:
;
; Ano bissexto = (divisível por 4 E não por 100) OU (divisível por 400)
;
; =============================================================================


update_date_time_buffer:

    inc byte [time_data + 2]      ; Incrementa os segundos em 1.
	
    cmp byte [time_data + 2], 60  ; Verifica se os segundos chegaram a 60.
	
    jne .done                     ; Se segundos < 60, termina a rotina.

    mov byte [time_data + 2], 0   ; Faz o reset dos segundos para 0.
	
    inc byte [time_data + 1]      ; Incrementa os minutos em 1.

    cmp byte [time_data + 1], 60  ; Verifica se os minutos chegaram a 60.
	
    jne .done                     ; Se minutos < 60, termina a rotina.

    mov byte [time_data + 1], 0   ; Faz  o reset dos minutos para 0.
	
    inc byte [time_data + 0]      ; Incrementa as horas em 1. 

    cmp byte [time_data + 0], 24  ; Verifica se horas chegaram a 24.
	
    jne .done                     ; Se horas < 24, termina a rotina.

    mov byte [time_data + 0], 0   ; Faz o reset das horas para 0.
	
    inc byte [date_data + 0]      ; Incrementa o dia em 1.

    movzx eax, byte [date_data + 1] ; Lê o mês atual.
	
    dec eax                       ; Ajusta índice para 0-base (0 = janeiro).
	
    mov bl, [days_in_month + eax] ; Lê a quantidade máxima de dias no mês.

    cmp byte [date_data + 1], 2   ; Verifica se o mês é fevereiro (mês 2).
	
    jne .check_day                ; Se o mês não for fevereiro, pula a verificação
	                              ; de bissexto

    movzx eax, byte [date_data + 2] ; Lê o ano.
	
    movzx ebx, byte [century_data]  ; Carrega o século atual em EBX.
	
    imul ebx, 100                 ; Multiplica o século por 100 para obter o início 
	                              ; do século em anos.
								  
    add eax, ebx                  ; Soma o início do século e o ano para obter o
	                              ; ano atual em EAX.

    mov edx, 0                    ; Limpa EDX antes da divisão.
	
    mov ecx, 4                    ; Divisor = 4 em ECX.
	
    div ecx                       ; Divide EDX:EAX por 4. EAX = ano/4, EDX = ano%4
	
    test edx, edx                 ; Testa se o resto da divisão (EDX) é zero.
	
    jnz .check_day                ; Se resto != 0, não é múltiplo de 4, portanto,
	                              ; não bissexto.

    mov edx, 0                    ; Limpa EDX antes da divisão.
	
    mov ecx, 100                  ; Divisor = 100 em ECX.
	
    div ecx                       ; Divide EDX:EAX por 100. EAX = ano/100, 
	                              ; EDX = ano%100.
								  
    test edx, edx                 ; Testa se o resto da divisão (EDX) é zero.
	
    jz .check_400                 ; Se resto = 0, é múltiplo de 100, portanto, 
	                              ; precisa checar se é múltiplo de 400.

    jmp .add_one_day              ; Ano múltiplo de 4 mas não de 100 é ano bissexto.

.check_400:

    mov edx, 0                    ; Limpa EDX antes da divisão.
	
    mov ecx, 400                  ; Divisor = 400 em ECX.
	
    div ecx                       ; Divide EDX:EAX por 400. EAX = ano/400, 
	                              ; EDX = ano%400
	
    test edx, edx                 ; Testa se resto da divisão (EDX) é zero.
	
    jnz .check_day                ; Se resto != 0, é múltiplo de 100 mas não de 
	                              ; 400, portanto, não é ano bissexto.

.add_one_day:

    inc bl                        ; Fevereiro bissexto. Soma 1 dia (29 dias).

.check_day:

    cmp [date_data + 0], bl       ; Verifica se dia atual ultrapassou o máximo
	                              ; do mês.
	
    jbe .done                     ; Se ainda está dentro, termina a rotina.

    mov byte [date_data + 0], 1   ; Faz o reset do dia para 1.
	
    inc byte [date_data + 1]      ; Incrementa o mês em 1.

    cmp byte [date_data + 1], 13  ; Verifica se o mês é maior do que 12.
	
    jne .done                     ; Se mês <= 12, termina a rotina.

    mov byte [date_data + 1], 1   ; Faz o reset do mês para janeiro.
	
    inc byte [date_data + 2]      ; Incrementa ano em 1.
    
    cmp byte [date_data + 2], 100 ; Verifica se o ano é menor do que 100.
	
    jne .done                     ; Se o ano < 100, termina a rotina.

    mov byte [date_data + 2], 0   ; Faz o reset do ano para 0.
	
    inc byte [century_data]       ; Incrementa século em 1.

.done:

    ret                           ; Retorna ao chamador (irq0_handler).




; =============================================================================
;
; Tratador (handler) da interrupção de teclado (IRQ1)
;
; =============================================================================

irq1_handler:

    pushad                        
    
    in al, 0x60                   

    cmp al, 0x01                  

    je .shutdown

    cmp al, 0x3F                  

    je .read_rtc

    jmp .eoi                      

.read_rtc:
	
    call rtc_read_datetime
	
    jmp .eoi
	
.shutdown:

    call acpi_poweroff

    jmp .eoi

.eoi:

    mov al, 0x20               
    out 0x20, al               

    popad
	
    iretd
	
	
	
	
; =============================================================================
;
; Lê a hora atual do sistema no RTC. A hora do sistema no RTC estará gravada no 
; formato BCD (Binary Coded Decimal), que é uma forma de armazenar números decimais
; usando o sistema binário.
;
; Diferente do binário puro, onde os bits representam potências de 2 (1, 2, 4, 8,
; ...), no BCD cada grupo de 4 bits (um nibble) representa exatamente um dígito 
; decimal. Tomemos como exemplo o número 25. Em binário ele é representado como 
; 00011001 (16 (1*2^4) + 8 (1*2^3) + 1 (1*2^0) = 25). Em BCD o computador divide
; o byte ao meio. Os primeiros 4 bits guardam o "dígito 2" e os últimos 4 bits 
; guardam o "dígito 5". Isso resulta em 2 (0010) + 5 (0101) = 0010 0101. Se olhar
; este valor em um editor hexadecimal, consegue ler o número decimal diretamente 
; (0x25). Logo, se o RTC diz que são 0x59 segundos, em BCD são exatamente 59 
; segundos. Se fosse binário puro, 0x59 seria 89 em decimal, o que não faz sentido
; para os segundos (que vão de 0 até 59).
;
; O RTC têm 14 registradores de 1 byte (índices de 0 a 13). Os que são de interesse
; para este kernel são os 10 primeiros (índices de 0 ao 9), que contém os campos
; de hora e calendário.
;
; Estes registradores são:
;
;   Índice  Função       Intervalo BCD     Descrição
;   ------  ---------    -------------     ---------------------------------
;   0x00    Segundos     00 a 59           Segundos atuais.
;
;   0x02    Minutos      00 a 59           Minutos atuais.
;
;   0x04    Horas        00 a 23/          Hora atual (Depende se o RTC está
;                        00 a 12           em modo 24h ou 12h).
;
;   0x07    Dia do mês   01 a 31           Dia atual do mês.
;                             
;   0x08    Mês          01 a 12           Mês atual.
;
;   0x09    Ano          00 a 99           Os dois últimos dígitos do ano.
;
; * Não existe um registrador para o século no RTC. Em alguns sistemas específicos 
;   é possível obter esta informação no índice 0x32. Como o QEMU implementa este
;   esquema, usarei este índice para obter o ano da data, e não inferir que é o
;   século XXI. Em sistemas modernos, existe um registrador de "século" definido
;   na tabela FADT (Fixed ACPI Description Table) da ACPI que aponta para o índice
;   deste registrador no RTC. Mas para evitar uma busca via ACPI, e como o QEMU
;   adota esta porta para o século, vamos deixar neste índice mesmo. O BIOS/UEFI
;   lê o valor de dois dígitos do RTC (índice 0x09) para o ano e usa esse campo 
;   extra do século para completar a data.
;
; Nota:
;
; A porta 70 do RTC é utilizada também para o sinal de NMI (Non-Maskable Interrupt)
; que chega à CPU. Por isso, toda vez que for escrever na porta 70, será necessário
; também desabilitar o NMI. Voltamos a habilitar o sinal ao final do processo de
; leitura do RTC.
;
; =============================================================================


rtc_read_datetime:
	
	cli                           ; Desabilita as interrupções mascaráveis.
		
; -----------------------------------------------------------------------------
; Garante a leitura consistente da hora no RTC. Faz isso testando o bit UIP 
; (Update In Progress). Quando está atualizando o segundo, o RTC liga este bit
; para indicar a atualização. Neste caso, a leitura pode ser inconsistente. 
;
; Se UIP = 1, fica no loop .wait_rtc até o RTC trocar para 0, para obter valores
; consistentes.
;
; Observação: Estou fazendo apenas um controle básico. Em kernels reais isso
; deve ser melhorado.
; -----------------------------------------------------------------------------

    mov al, 0x8A                  ; Copia o valor 0x8A em AL (0x0A (Reg A) + 0x80 
	                              ; (NMI Disable bit). O registrador no índice 0x0A 
								  ; do RTC contém informações sobre o estado de 
								  ; atualização do relógio.
	
    out 0x70, al                  ; Envia o valor 0x8A para a porta de controle 
	                              ; do RTC (0x70)
								  
.wait_rtc:
    
    in al, 0x71                   ; Lê o byte do registrador 0x0A na porta de 
	                              ; dados do RTC (0x71) e o coloca em AL.           
    
    test al, 0x80                 ; Realiza uma operação lógica AND entre o valor
	                              ; lido em AL e a máscara binária 0x80 (10000000),
								  ; sem alterar o valor de AL.
								  ;
                                  ; O valor 0x80 em binário tem apenas o Bit 7 
								  ; ligado. Se o Bit 7 de AL estiver desligado (0),
								  ; o resultado do test será 0 e o Zero Flag (ZF) 
								  ; será 1 e vice-versa.     
    
    jnz .wait_rtc                 ; "Jump if Not Zero" (Pule se não for zero). 
	                              ; Se o teste anterior resultou em "não zero", 
								  ; o processador volta para o rótulo .wait_rtc,
								  ; para testar novamente o UIP.

; -----------------------------------------------------------------------------
; Lê os registradores de data e calendário do  RTC e copia os valores, convertidos
; do formato BCD para binário, para o buffer de destino (buffer de hora, data e
; século).
; -----------------------------------------------------------------------------
    
	mov edi, time_data            ; Copia o endereço de memória do buffer de 
                                  ; destino em EDI.
	
    mov esi, rtc_regs             ; Copia o endereço de memória da tabela de índices
                                  ; do RTC em ESI.
    
	mov ecx, 7                    ; Copia o número de itens da tabela de índices
	                              ; do RTC em ECX.
    
	cld                           ; Define o bit "Direction Flag" (DF) no registro
                                  ; de EFLAGS como 0.
	
.read_rtc:

    lodsb                         ; A instrução lodsb quando é executada faz duas
                                  ; coisas:
                                  ;
                                  ; > Vai até o endereço de memória apontado por
                                  ;   ESI (definido em: mov esi, rtc_regs), lê
                                  ;   o byte que está lá na tabela de índices do
								  ;   RTC, e o coloca em AL. 
                                  ;
                                  ; > Incrementa o registrador ESI automaticamente
                                  ;   para que, na próxima vez que o loop rodar,
                                  ;   ele aponte para o próximo índice da tabela
                                  ;   de índices do RTC.
								  
	or al, 0x80                   ; Define o Bit 7 como 1 para DESABILITAR o NMI
	                              ; (Non-Maskable Interrupt).
	
    out 0x70, al                  ; Seleciona o registrador do RTC na porta de
                                  ; comando pelo índice copiado em AL.
    
	in al, 0x71                   ; Lê o valor bruto (em formato BCD) do registrador
	                              ; na porta de dados do RTC e copia em AL.
    
	call bcd_to_bin               ; Converte o valor em AL de BCD para binário para
	                              ; facilitar os cálculos e a exibição na tela.
    
	stosb                         ; A instrução stosb quando é executada faz duas
                                  ; coisas:
                                  ;
                                  ; > Lê o valor que está em AL, já convertido 
								  ;   do formato BCD para o binário pela subrotina
                                  ;   bcd_to_bin e o escreve no endereço de memória
                                  ;   apontado por EDI (definido em: mov edi,
								  ;   time_data), que aponta para o buffer de destino.
								  ;   Isto fará escrever 3 bytes em time_data,
								  ;   3 bytes em date_data e 1 byte em century_data
								  ;   ao longo das 7 interações do loop.
                                  ;
                                  ; > Incrementa o registrador EDI automaticamente.
                                  ;   Dessa forma, na próxima volta do loop, o 
								  ;   próximo valor não apaga o anterior, e é gravado
								  ;   logo na sequência no buffer.
    
	loop .read_rtc                ; Repete o processo até ler todos os 7 itens
                                  ; da tabela de índices do RTC, cada item 
								  ; correspondendo ao índice de um registrador
								  ; de interesse do RTC (incluindo o índice 0x32).

	mov al, 0x00                  ; Índice 0 (segundos) com o Bit 7 = 0.
	
    out 0x70, al                  ; Ao enviar 0 para o Bit 7, reabilita o NMI
	                              ; na porta 70.
    
	in al, 0x71                   ; Leitura para estabilizar o barramento.
	
	cpuid                         ; Serializa para garantir que instruções anteriores
	                              ; terminaram.

    rdtsc                         ; Lê o TSC uma última vez para fazer o reset da 
	                              ; referência de tempo que o Kernel usará daqui
								  ; para frente.
	
	mov [last_tsc_low], eax       ; Atualiza a referência global com o valor de
	                              ; agora (baixo).
	
    mov [last_tsc_high], edx      ; Atualiza a referência global com o valor de
	                              ; agora (alto).
								  
	call print_date_time          ; Chama a rotina que escreve no buffer de vídeo
                                  ; a data e hora atualizadas.
								  
	sti                           ; Set Interrupt Flag. Habilita novamente as 
	                              ; interrupções mascaráveis.

	ret                           ; Retorna para o chamador
	
	

	
; =============================================================================
;
; Desliga o computador via ACPI. Funciona em máquinas com firmware BIOS (legado) 
; operando em modo protegido.
;
; O processo de desligamento segue a especificação ACPI e ocorre em etapas:
;
; 1. Localiza a estrutura RSDP (Root System Description Pointer) varrendo a 
;    memória entre 0xE0000 e 0xFFFFF em busca da assinatura "RSD PTR ". A RSDP 
;    é o ponto de entrada para acessar as tabelas ACPI.
;
; 2. A partir da RSDP, obtém-se o endereço da RSDT (Root System Description 
;    Table), que contém uma lista de ponteiros para outras tabelas ACPI.
;
; 3. Percorre as entradas da RSDT até encontrar a FADT (Fixed ACPI Description 
;    Table). A FADT contém:
;    
;    > Os endereços das portas PM1a_CNT e PM1b_CNT
;      
;    > O endereço da DSDT (Differentiated System Description Table)
;
; 4. A DSDT é analisada em busca do objeto AML "_S5_", que define o estado de 
;    energia S5 (soft-off). Esse objeto contém os valores SLP_TYPa e SLP_TYPb,
;    necessários para solicitar o desligamento ao hardware.
;
; 5. Os valores SLP_TYP são posicionados corretamente e combinados com o bit 
;    SLP_EN. Em seguida, são escritos nas portas PM1a_CNT (e PM1b_CNT, se 
;    disponível), instruindo o chipset a entrar no estado S5.
;
; 6. Ao receber esse comando, o hardware executa o desligamento completo da 
;    máquina (soft power-off).
;
; Caso qualquer uma das etapas falhe (RSDP, FADT ou _S5_ não encontrados), 
; executa-se a rotina qemu_fallback, que tenta encerrar a execução em ambiente 
; virtual (QEMU). Caso isso não funcione, o sistema entra em estado de halt.
;
; =============================================================================


acpi_poweroff:

	jmp .qemu_fallback            ; 


    call .find_rsdp               ; Chama rotina que procura a RSDP na memória. 
	
    test eax, eax                 ; Verifica o endereço da RSDP retornado em EAX. 
                                  ; Se EAX = 0, a RSDP não foi encontrada.
    
	jz .qemu_fallback             ; Se EAX = 0 (não encontrou RSDP), salta para 
	                              ; o fallback do QEMU.    

    call .find_fadt               ; Chama a rotina que procura a tabela FADT. FADT
	                              ; contém endereços das portas que controlam o
								  ; desligamento do PC (PM1a e PM1b) e o endereço 
								  ; do DSDT.
    
	test eax, eax                 ; Verifica o endereço da FADT retornado em EAX. 
                                  ; Se EAX = 0, a FADT não foi encontrada.
								  
    
	jz .qemu_fallback             ; Se EAX = 0 (não encontrou FADT), salta para 
	                              ; o fallback do QEMU.

    mov ebx, eax                  ; Salva o endereço da FADT em EBX. Será usado
	                              ; para ler informações de porta e DSDT. 

    mov dx, [ebx + 0x40]          ; Lê da FADT a porta PM1a_CNT_BLK (16 bits) e 
	                              ; coloca em DX. Essa porta controla sinais de
								  ; desligamento ACPI.  
    
	mov edi, [ebx + 0x44]         ; Lê da FADT a porta PM1b_CNT_BLK (16 bits) e 
	                              ; coloca em EDI. PM1b é opcional. Se for 0, 
								  ; significa que só PM1a será usada.
    
	mov esi, [ebx + 0x2C]         ; Lê da FADT o endereço do DSDT (Differentiated
	                              ; System Description Table). DSDT contém o código 
								  ; AML que define objetos como _S5_ (modo desligamento).

    call .find_s5_universal       ; Chama a rotina que procura o objeto _S5_ no DSDT.
                                  ; _S5_ indica como desligar o computador de 
								  ; forma “soft-off”.
    
	test eax, eax                 ; Verifica o endereço de _S5_ retornado em EAX. 
                                  ; Se EAX = 0, _S5_ não foi encontrado.                 
    
	jz .qemu_fallback             ; Se EAX = 0 (não encontrou _S5_), salta para 
	                              ; o fallback do QEMU.         

    mov esi, eax                  ; Salva o endereço de _S5_ em ESI leitura do
	                              ; pacote AML.

    call .read_s5_package         ; Lê o pacote AML _S5_. Esse pacote contém valores
	                              ; SLP_TYPa e SLP_TYPb. Esses valores dizem quais
								  ; bits ativar para desligar o PC.

    shl cx, 10                    ; Move SLP_TYPa para os bits corretos do registrador
	                              ; PM1a (desloca 10 bits).             

    or cx, 1 << 13                ; Liga o bit SLP_EN (habilita o desligamento
	                              ; via ACPI).            

    mov ax, cx                    ; Copia o valor que será enviado para a porta
	                              ; para AX.

    out dx, ax                    ; Envia o valor em AX para a porta PM1a. Esse
	                              ; comando inicia o desligamento via ACPI.          

    test edi, edi                 ; Verifica se PM1b existe (EDI != 0). Se EAX = 0,
	                              ; PM1b não existe.

    jz .shutdown_done             ; Se PM1b não existir, pula para o final do
	                              ; desligamento.

    mov dx, di                    ; Copia o endereço da porta PM1b para DX.

    mov ax, bx                    ; Copia SLP_TYPb para AX. Esse valor é necessário 
	                              ; para PM1b.

    shl ax, 10                    ; Desloca os bits do SLP_TYPb para posição correta.

    or ax, 1 << 13                ; Liga o bit SLP_EN para ativar o desligamento
	                              ; via PM1b.

    out dx, ax                    ; Envia o valor em AX para PM1b, completando o
	                              ; desligamento.               

.shutdown_done:
    
	ret                           ; Sai da rotina. Se tudo funcionou, o PC estará
	                              ; desligando.

;------------------------------------------------------------------------------
; Busca o endereço do RSDP (Root System Description Pointer).
;------------------------------------------------------------------------------

.find_rsdp:

    mov edi, 0x000E0000           ; Começa a busca do RSDP no endereço 0xE0000
	                              ; da memória. Esse endereço é uma região da
								  ; memória convencional reservada pelo BIOS em 
								  ; PCs antigos e modernos compatíveis com ACPI.
								  ; O RSDP deve estar entre 0xE0000 e 0xFFFFF na 
								  ; memória real-mode segundo a especificação ACPI 
								  ; 1.0 e posteriores. É onde a BIOS mapeia tabelas
								  ; de sistema e firmware.    

    mov ecx, 0x20000              ; Tamanho da área a ser verificada (128KB).          

.rsdp_loop:

    cmp dword [edi], 0x20445352   ; Compara os 4 primeiros bytes no endereço com
	                              ; a string "RSD ".

    jne .rsdp_next                ; Se não for igual, avança o cursor para o próximo
	                              ; bloco.

    cmp dword [edi+4], 0x20525450 ; Compara os próximos 4 bytes adiante com a
	                              ; string "TP  ".

    jne .rsdp_next                ; Se não for igual, vai para o próximo bloco.

    mov eax, edi                  ; O RSDP foi encontrado. Armazena o endereço
	                              ; em EAX.

    ret                           ; Retorna para o chamador.

.rsdp_next:

    add edi, 16                   ; Avança para o próximo bloco, 16 bytes adiante,
                                  ; para a próxima tentativa de encontrar a assinatura
								  ; do RSDP.

    loop .rsdp_loop               ; Decrementa ECX e repete o loop se ECX != 0.

    xor eax, eax                  ; Se não encontrou a assinatura do RSDP, retorna
	                              ; 0 em EAX.

    ret                           ; Retorna para o chamador.

;------------------------------------------------------------------------------
; Busca a tabela FADT via RSDT.
;------------------------------------------------------------------------------

.find_fadt:


    mov esi, [eax + 16]           ; Salva o endereço da RSDT em ESI. Na especificação
	                              ; ACPI, o RSDP aponta para a RSDT (Root System
								  ; Description Table) num campo a 16 bytes do 
								  ; início do RSDP.

    mov eax, [esi + 4]            ; O segundo campo da RSDT (offset +4) é o tamanho
	                              ; total da tabela RSDT em bytes. Esse número 
								  ; nos diz quantos bytes precisamos percorrer para
								  ; ler todas as tabelas.         

    sub eax, 36                   ; A RSDT começa com um cabeçalho de 36 bytes.
	                              ; É preciso descontar esses 36 bytes, porque
								  ; o loop vai percorrer apenas os endereços das
								  ; tabelas, que vêm depois do cabeçalho.

    shr eax, 2                    ; Ajusta para o número real de tabelas. Cada
	                              ; entrada da RSDT tem 4 bytes (um endereço de
								  ; tabela). A instrução shr eax, 2 = divide EAX
								  ; por 4, assim obtê-se o número de tabelas listadas
								  ; na RSDT.

    mov ecx, eax                  ; Salva o número de tabelas em ECX para controlar
	                              ; o loop .fadt_loop.

    add esi, 36                   ; Ajusta o valor em ESI para apontar para o início
	                              ; das entradas das tabelas, pulando o cabeçalho
								  ; de 36 bytes da RSDT. ESI então aponta para o
								  ; primeiro endereço de tabela ACPI listado na
								  ; RSDT.

.fadt_loop:

    mov edi, [esi]                ; Copia 4 bytes da RSDT em EDI. ESI É o endereço
	                              ; de uma tabela ACPI (FACP, MADT, etc). 

    cmp dword [edi], 0x50434146   ; Compara o valor em EDI com a assinatura "FACP"
	                              ; (FADT)

    je .fadt_found                ; Se o valor em EDI for "FACP", encontrou a tabela
	                              ; FADT.

    add esi, 4                    ; Caso não seja a tabela FADT, avança para a 
	                              ; próxima entrada da RSDT.

    loop .fadt_loop               ; Decrementa ECX e repete o loop se ECX != 0.

    xor eax, eax                  ; Se não encontrou a assinatura da FADT, retorna
	                              ; 0 em EAX.

    ret                           ; Retorna para o chamador.

.fadt_found:

    mov eax, edi                  ; Retorna endereço da FADT em EAX.

    ret                           ; Retorna para o chamador.

;------------------------------------------------------------------------------
; Busca _S5_ na tabela FADT.
;------------------------------------------------------------------------------

.find_s5_universal:

    mov ecx, 0x40000              ; ECX será usado como contador do loop. O valor
	                              ; 0x40000 = 256 KB. A rotina vai procurar _S5_
								  ; em até 256 KB de memória, começando do endereço
								  ; em ESI.

.s5_search_loop:

    mov eax, [esi]                ; Lê 4 bytes a partir do endereço em ESI e coloca
	                              ; em EAX.
	
    cmp eax, 0x5F355F             ; Compara o valor em EAX com a assinatura "_S5_".
	
    jne .next_byte                ; Se não for igual, avança o cursor para o próximo
	                              ; byte.

    mov al, [esi+4]               ; Copia o próximo byte em AL.
	
    cmp al, 0x12                  ; Compara o byte em AL com 0x12 (opcode AML Package).
	
    jne .next_byte                ; o byte em AL for diferente de 0x12, significa
	                              ; que _S5_ não é um pacote válido. Dessa forma,
								  ; avança o cursor para o próximo byte.

    mov eax, esi                  ; Se achou "_S5_" e 0x12, retorna o endereço
	                              ; em EAX. 
								  
    ret                           ; Retorna para o chamador.

.next_byte:

    inc esi                       ; Incrementa ESI em 1. Com isso passa para o
	                              ; próximo byte da memória para continuar procurando
								  ; por _S5_.
	
    loop .s5_search_loop          ; Decrementa ECX.
	                              ;
                                  ; Se ECX > 0, volta para .s5_search_loop.
								  ;
                                  ; Se ECX = 0, significa que a busca terminou 
								  ; e não encontrou _S5_.

    xor eax, eax                  ; Se achou "_S5_" e 0x12, retorna o valor 0
	                              ; em EAX.
								  
    ret                           ; Retorna para o chamador.

;------------------------------------------------------------------------------
; Lê o pacote AML _S5_.
;------------------------------------------------------------------------------

.read_s5_package:

    add esi, 6                    ; Faz ESI apontar para o início do pacote _S5_.
                                  ;	Pula:
								  ;
								  ; > 4 bytes de "_S5_".
								  ;
								  ; > 1 byte opcode Package (0x12).
								  ;
								  ; > 1 byte de comprimento do pacote AML.

    mov al, [esi]                 ; Lê o primeiro elemento do pacote (SLP_TYPa)
	                              ; no endereço apontado por ESI.

    mov ah, 0                     ; Limpa AH (parte alta de AX) para garantir que
	                              ; AX seja 16 bits limpos. Isso é necessário
								  ; porque ACPI espera valores de 16 bits para
								  ; SLP_TYPa e SLP_TYPb.

    mov cx, ax                    ; Copia o valor em AX para CX. CX agora contém
	                              ; SLP_TYPa pronto para ser usado no comando de
								  ; desligamento.

    inc esi                       ; Incrementa ESI para apontar para o próximo
	                              ; elemento do pacote, que pode ser SLP_TYPb 
								  ; (opcional).

    cmp byte [esi], 0             ; Verifica se o próximo byte é 0. Se for 0, 
	                              ; significa que SLP_TYPb não existe (algumas
								  ; placas ACPI têm apenas SLP_TYPa).

    je .done_s5                   ; Se o byte for 0, pula para .done_s5 e termina
	                              ; a função. BX permanece inalterado ou 0, porque
								  ; não há SLP_TYPb.

    mov al, [esi]                 ; Se o byte for diferente de 0, lê o segundo
	                              ; elemento do pacote (SLP_TYPb) em AL.

    mov ah, 0                     ; Limpa AH novamente para garantir que AX seja
	                              ; um valor limpo de 16 bits.

    mov bx, ax                    ; Copia o valor de AX para BX. BX agora contém
	                              ; SLP_TYPb.

.done_s5:

    ret                           ; Retorna para o chamador.

;------------------------------------------------------------------------------
; Fallback para QEMU.
;------------------------------------------------------------------------------

.qemu_fallback:

    mov eax, 0x2000               ; Coloca o valor 0x2000 (8192 em decimal) no 
	                              ; registrador EAX.

    out 0xF4, eax                 ; Envia o valor de EAX para a porta de I/O 0xF4.

.qemu_hang:

	mov si, power_error_str
	
    call print_2nd_line

	cli

    hlt                           ; Coloca a CPU em estado de halt (parada).

    jmp .qemu_hang	
	
	
	
	
; =============================================================================
;
; Imprime a data e a hora atualizadas na tela, conforme valores lidos no buffer 
; de memória, atualizados pela rotina update_date_time_buffer.
;
; O texto da data será impresso na segunda linha do terminal, iniciando na
; primeira coluna. Ele terá o seguinte formato:
;
;   HH:mm:ss dd/MM/CCYY
;
; Onde:
;
;   HH: Dígitos da hora (2 dígitos).
;
;   mm: Dígitos do minuto (2 dígitos).
;
;   ss: Dígitos do segundo (2 dígitos).
;
;   dd: Dígitos do dia (2 dígitos).
;
;   MM: Dígitos do mês (2 dígitos).
;
;   CC: Dígitos do século (2 dígitos).
;
;   YY: Dígitos do ano (2 dígitos).
;
; Ao todo, a string da hora/data terá 19 caracteres. Cada caractere da String 
; deverá ter a cor de texto branca e cor de fundo azul, mantendo o estilo dos 
; espaços que foram utilizados para preencher a tela na inicialização do kernel. 
; Portanto, não iremos substituir todos os bytes da memória do modo texto 80x25, 
; apenas os que são necessários para atualizar a string de tamanho fixo que compõe
; os dígitos da hora/data, mantendo os demais como foram escritos na inicialização.
;
; =============================================================================


print_date_time:

	mov edi, [vga_addr]           ; Armazena o valor do endereço inicial da memória
	                              ; de video VGA.

    add edi, 162                  ; Pula 162 bytes a partir do endereço inicial
	                              ; da memória de vídeo (80 colunas x 2 bytes). 
	                              ; Isso faz como que imprima a hora/data na 
								  ; segunda linha da tela.
								  
    mov al, [time_data + 0]       ; Armazena as horas em AL.
	
    call .print_two_digits        ; Chama print_two_digits para escrever na tela 
	                              ; os dois dígitos das horas.
								  
    mov word [edi], 0x1F3A        ; Escreve ":" na tela:
	                              ;
								  ; > 0x3A = ASCII ":"
								  ;
								  ; > 0x1F = atributo de cor (fundo azul, texto 
								  ; branco).
	
    add edi, 2                    ; Avança o ponteiro para a próxima posição na
	                              ; memória de vídeo.
	
    mov al, [time_data + 1]       ; Armazena os minutos em AL.
    
    call .print_two_digits        ; Chama print_two_digits para escrever na tela 
	                              ; os dois dígitos dos minutos.
	
    mov word [edi], 0x1F3A        ; Escreve ":" na tela.
	
    add edi, 2                    ; Avança o ponteiro para a próxima posição na
	                              ; memória de vídeo.
	
    mov al, [time_data + 2]       ; Armazena os segundos em AL.
    
    call .print_two_digits        ; Chama print_two_digits para escrever na tela 
	                              ; os dois dígitos dos segundos.
	
    mov word [edi], 0x1F20        ; Escreve um espaço " " entre hora e data:
	                              ; 
								  ; > 0x20 = ASCII espaço.
								  ;
								  ; > 0x1F = atributo de cor (fundo azul, texto 
								  ; branco).
								  
    add edi, 2                    ; Avança o ponteiro para a próxima posição na
	                              ; memória de vídeo.
								  
    mov al, [date_data + 0]       ; Armazena o dia do mês em AL. 
	
    call .print_two_digits        ; Chama print_two_digits para escrever na tela 
	                              ; os dois dígitos do dia do mês.
	
    mov word [edi], 0x1F2F        ; Escreve "/" separando dia e mês:
	                              ;
								  ; > 0x2F = ASCII "/".
								  ;
                                  ; > 0x1F = atributo de cor (fundo azul, texto 
								  ; branco).
								  
    add edi, 2                    ; Avança o ponteiro para a próxima posição na
	                              ; memória de vídeo.
								  
    mov al, [date_data + 1]       ; Armazena o mês em AL.
	
    call .print_two_digits        ; Chama print_two_digits para escrever na tela 
	                              ; os dois dígitos do mês.
	
    mov word [edi], 0x1F2F        ; Escreve "/" separando mês do ano.
	
    add edi, 2                    ; Avança o ponteiro para a próxima posição na
	                              ; memória de vídeo.
	
    mov al, [century_data]        ; Armazena o século em AL.
	
    call .print_two_digits        ; Chama print_two_digits para escrever na tela 
	                              ; os dois dígitos do século.
	
    mov al, [date_data + 2]       ; Armazena o ano do século em AL.
    
    call .print_two_digits        ; Chama print_two_digits para escrever na tela 
	                              ; os dois dígitos do ano.

    ret                           ; Retorna ao chamador (main_loop).

.print_two_digits:

    movzx ax, al                  ; AL contém o número que será exibido (0–99).
	                              ; "movzx ax, al" copia AL para AX e zera os 8 
								  ; bits altos de AX. AX agora tem o número em 16 
								  ; bits, necessário para a divisão posterior.
	
    mov bl, 10                    ; Prepara o divisor 10 em BL, porque precisa
	                              ; separar as dezenas e unidades do número.
    
	div bl                        ; Divide AX por BL (divisão de 16 bits por 8
	                              ; bits):
								  ;
								  ; > AL recebe o resto da divisão (unidades 0 a 9).
								  ;
								  ; > AH recebe o quociente da divisão (dezenas 0 a 9).
	
    add ax, 0x3030                ; Converte os números extraídos da divisão em ASCII:
	                              ;
								  ; > ASCII de '0' = 0x30
								  ;
								  ; > Multiplicando por 1 e somando 0x30, 0–9 vira 
								  ;   '0'–'9'.
								  ;
								  ; O registrador AH contém a dezena em ASCII, e
								  ; o registrador AL contém a unidade em ASCII.
	
    mov [edi], al                 ; Escreve o primeiro caractere (unidade) na memória
	                              ; de vídeo.
	
    mov byte [edi+1], 0x1F        ; Escreve o atributo de cor do primeiro caracter
	                              ; na memória de vídeo (0x1F = fundo azul, texto
								  ; branco).
								  
    mov [edi+2], ah               ; Escreve o segundo caractere (dezena) na próxima
	                              ; posição da memória de vídeo.
	
    mov byte [edi+3], 0x1F        ; Escreve o atributo de cor do segundo caracter
	                              ; na memória de vídeo (0x1F = fundo azul, texto
								  ; branco).
								  
    add edi, 4                    ; Atualiza EDI para apontar para a próxima posição
	                              ; da memória de vídeo, pulando os 2 caracteres 
								  ; recém-escritos + atributos.

    ret                           ; Retorna para o chamador (print_date_time) para
	                              ; continuar a impressão.
	
	
	
	
print_2nd_line:

	pushad
	
	mov ebp, [vga_addr]

.clear_line:

    mov edi, 1            
    mov ebx, 80
    imul edi, ebx
    shl edi, 1
    add edi, ebp

    mov ah, 0x1F          
    mov al, ' '           

    mov ecx, 58           

.loop:

    mov [edi], ax         
    add edi, 2
    loop .loop

    mov edi, 1            
    mov ebx, 80           
    imul edi, ebx         
    shl edi, 1            
    add edi, ebp      

    mov ah, 0x1F          

.next_char:

    lodsb                 
    test al, al
    jz .done              

    mov [edi], al         
    mov [edi+1], ah       
    add edi, 2            
    jmp .next_char

.done:

	popad
    
    ret
	
	
	
	
wait_enter:

.wait_key:

    in al, 0x64           

    test al, 1            

    jz .wait_key          

    in al, 0x60           

    cmp al, 0x1C          

    jne .wait_key         

    ret
	
	
	

; =============================================================================
;
; Converte o número em formato BCD no registrador AL para o formato binário
; padrão.
;
; =============================================================================


bcd_to_bin:

    mov dl, al                    ; Copia o valor de AL para DL. Com isso, têm-se
                                  ; uma cópia do BCD para separar os 4 bits das
								  ; unidades na sequência.

    shr al, 4                     ; Instrução "shift right" 4 bits para a direita
	                              ; em AL. Com isso, isola os 4 bits das dezenas
								  ; do BCD.
								  ;
								  ; Por exemplo:
								  ;
								  ; Se AL = 0x42
								  ;
								  ; > Antes:  0100 0010
								  ;
                                  ; > Depois: 0000 0100 (apenas a dezena, 4).

    mov bl, 10                    ; Multiplicador 10 em BL.
	
    mul bl                        ; AL × BL -> AX (resultado de 16 bits. AL contém
	                              ; a parte baixa)

    and dl, 0x0F                  ; Aplica máscara para pegar somente os 4 bits 
	                              ; baixos (unidades) do BCD original em DL.
								  ;
								  ; Por exemplo: 
								  ;
								  ; DL = 0x42 
								  ; 
								  ; DL & 0x0F = 0x02 (binário: 0000 0010)

    add al, dl                    ; Como o número final é (dezena × 10) + unidade,
	                              ; soma-se DL e AL. O resultado vai para AL.
								  ;
								  ; Por exemplo: 
								  ;
								  ; AL(42) = AL(40) + DL(2)
								  ;
								  ; Em binário: 
								  ;
								  ; 00101010 = 00101000 + 00000010

    ret                           ; Retorna ao chamador.




; =============================================================================
;
; Tratador de erro na configuração do HPET.
;
; =============================================================================


hpet_fallback:

	mov si, hpet_error_str
	
    call print_2nd_line
	
	call wait_enter

    call acpi_poweroff
	
	
tsc_fallback:

	mov si, tsc_error_str
	
    call print_2nd_line
	
	call wait_enter

    call acpi_poweroff
	
	
tsc_inv_fallback:

	mov si, tsc_inv_error_str
	
    call print_2nd_line
	
	call wait_enter

    call acpi_poweroff
	
	
	
	
; =============================================================================
;
; IDT (Interrupt Descriptor Table)
;
; A IDT é uma tabela na memória com 256 entradas (gates), cada entrada com 8 bytes
; em Modo Protegido. Ela permite que o processador saiba o que fazer quando ocorre
; uma interrupção ou exceção (ex.: teclado, timer, erro de divisão por zero, etc.).
;
; Cada entrada (gate) da IDT em Modo Protegido tem os seguintes campos:
;
;   Bits  0..15  -> offset_low     (parte baixa do endereço do handler)
;
;   Bits 16..31  -> selector       (selector de segmento de código no GDT)
;
;   Bits 32..39  -> zero           (sempre 0)
;
;   Bits 40..47  -> type_attr      (tipo + privilégios + presente)
;
;   Bits 48..63  -> offset_high    (parte alta do endereço do handler)
;
; Como usamos "dq 0", todas as entradas estão inicialmente zeradas:
;
;   > Offset = 0
;
;   > Selector = 0
;
;   > Flags = 0
;
; Isso significa que, no estado atual:
;
;   > Nenhuma interrupção possui handler válido.
;
;   > Qualquer interrupção/exceção causará falha.
;
; Notas:
;
; Na inicialização do kernel, configuramos a entrada 32 (gate 32) para tratamento
; da interrupção de relógio (IRQ0). As demais interrupções (teclado, mouse, etc)
; não serão habilitadas para este kernel.
;
; Em Modo Protegido O PIC vai ser remapeado para que as IRQs apontem para as
; entradas de 32 adiante da IDT. As entradas de 0 a 31 são utilizadas pela
; Intel para interrupções do processador, logo, mapeamos para que as IRQS do PIC 
; Mestre o do Pic Escravo usem as entradas imediatamente adiante destas.
;
; =============================================================================

idt_table:

    times 256 dq 0  

idt_table_end:


idt_ptr:

    dw idt_table_end - idt_table - 1
    dd idt_table




; =============================================================================
;
; Variáveis utilizadas pelo kernel.
;
; =============================================================================

rtc_regs:                         ; Tabela de índices de registradores do RTC 
                                  ; com informações de data e calendário.

	db 4, 2, 0, 7, 8, 9, 0x32


time_data:                        ; Buffer da hora (horas/minutos/segundos).
	
	db 0, 0, 0

date_data:                        ; Buffer da data (dia/mês/ano).
	
	db 0, 0, 0

century_data:                     ; Buffer do século.

	db 0

days_in_month:                    ; Números de dias em cada mês do ano (em ordem).

	db 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

hpet_ticks_10ms:                  ; Número de ticks do HPET em 10 ms.

	dd 0

hpet_remainder:                   ; Resto da divisão do número de ticks do HPET.

	dd 0  
          
hpet_divisor:                     ; Divisor do número de ticks do HPET.

	dd 0  
          
error_accumulator:                ; Acumulador de erro.

	dd 0 
          
ms_counter:                       ; Contador de ticks/10ms em tempo real.

	db 0

second_flag:                      ; Flag para controle da impressão da hora/data.

	db 0

last_tsc_low:                     ; Valor lido do TSC (parte baixa).

	dd 0

last_tsc_high:                    ; Valor lido do TSC (parte alta).

	dd 0
       
tsc_per_10ms:                     ; Número de ticks do TSC em 10 ms. 

	dq 0
       
tsc_accumulator:                  ; Acumulador de ticks do TSC. 

	dq 0
	
tsc_accumulator_low:              ; acumulador de ciclos TSC (parte baixa).

	dd 0
    
tsc_accumulator_high:             ; acumulador de ciclos TSC (parte alta).

	dd 0

tsc_per_10ms_low:

	dd 0
	
tsc_per_10ms_high:

	dd 0

entry_size:

	db 0

cursor:

	dd 0
	
hpet_addr:

	dd 0

vga_addr:
	
	dd 0
    
hpet_error_str:

	db 'Erro ao configura o HPET. Tecle ENTER para sair.', 0

tsc_error_str:

	db 'Erro ao fonfigurar o TSC. Tecle ENTER para sair.', 0

tsc_inv_error_str:

	db 'O TSC nao e invariante. Tecle ENTER para sair.', 0

power_error_str:

	db 'Erro ao desligar. Faça manualmente.', 0

screen_message:

    times 58 db ' '
    db "ESC=Sair F5=Atualizar", 0
		  



; =============================================================================
;
; Ajuste do binário.
;
; =============================================================================

times 5120 - ($ - $$) db 0        ; Completa com zeros os bytes restantes não
                                  ; usados por instruções do programa, até
								  ; completar os 8 setores.