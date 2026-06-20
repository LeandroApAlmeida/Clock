<h3>Relógio digital em Assembly "Bare Metal" para arquitetura x86</h3> 

<br>

Este programa em assembly "bare metal" implementa um relógio digital que mostra a hora e a data do sistema, sem opções de ajuste do horário (apenas lê os valores gravados pelo sistema operacional hospedeiro). Ele foi escrito para arquiteturas x86 e firmware BIOS, utilizando o montador NASM.

O programa implementa um bootloader simples e um kernel rudimentar. O bootloader tem a tarefa de carregar o kernel na memória. Assim que o kernel inicializa, ele executa as seguintes etapas:

<br>

  * Define o HPET (High Precision Event Timer) como gerador de interrupção de relógio (IRQ0) no lugar do PIT (Programmable interval timer).

  * Calibra o TSC usando o HPET para funcionar como um contador de tempo muito preciso.
    
  * Lê a hora atual do sistema no RTC (Real-Time Clock).

  * Ativa as interrupções de hardware (IRQ0 e IRQ1) para o relógio funcionar.

  * Atualiza a hora e data na tela a cada 1 segundo.

<br>

O código-fonte do programa para o montador NASM se encontra nos arquivos:

<br>

  * "bootlader.asm": Código-fonte do bootloader.
  
  * "kernel.asm": Código-fonte do kernel do relógio.

<br>

Como complemento ao projeto, foram implementados outros projetos auxiliares. Eles estão no subdiretório "Extras" e são:

<br>

  * "\Extras\BootFAT12\": Neste diretório está o código-fonte de um bootloader de terceiro que espera um arquivo de imagem formatado como FAT-12.
  
  * "\Extras\WriteDiskImage\": Neste diretório está o código-fonte de um gravador de imagem de disco que permite gravar as imagens geradas em uma pendrive, HD Externo ou outra mídia removível para testar o relógio em um hardware real.

<br>

Consulte a documentação no código-fonte para entender como cada projeto funciona.

<br>

https://github.com/user-attachments/assets/47b50cfc-2d6f-4adc-832f-d3c7abd86384
