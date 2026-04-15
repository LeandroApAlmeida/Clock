Este programa em assembly "bare metal" implementa um relógio digital que mostra a hora e a data atualizada do sistema. Foi escrito para arquiteturas x86 e firmware BIOS.

O programa implementa um bootloader simples e um kernel rudimentar. O bootloader tem a tarefa de carregar o kernel na memória. Assim que o kernel inicializa, ele executa as seguintes instruções:

  * Configura o hardware em Modo Protegido (32-bit).

  * Define o HPET (High Precision Event Timer) como gerador de interrupção de relógio (IRQ0) no lugar do PIT (Programmable interval timer).

  * Calibra o TSC usando o HPET para funcionar como um contador de tempo muito preciso.

  * Lê a hora atual do sistema no RTC (Real-Time Clock).

  * Ativa as interrupções de hardware para o relógio funcionar.

  * Entra em loop para "escutar" as interrupções e imprimir a hora e data na tela a cada 1 segundo.

O código-fonte do programa se encontra no arquivo "DateTime32.asm". Nele eu comentei cada passo do funcionamento do relógio, com alguns apontamentos sobre o hardware em Modo Protegido (arquitetua x86).

https://github.com/user-attachments/assets/04728317-d0d1-494b-af46-d76b9a60ff95
