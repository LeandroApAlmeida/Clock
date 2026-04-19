@echo off


:: ----------------------------------------------------------------------------
:: Seção de constantes
:: ----------------------------------------------------------------------------

set NASM_PATH=NASM\nasm.exe

set OUTPUT_DIR=bin

set BOOTLOADER_SOURCE=bootloader.asm

set KERNEL_SOURCE=kernel.asm

set BOOTLOADER_BINARY=%OUTPUT_DIR%\bootloader.bin

set KERNEL_BINARY=%OUTPUT_DIR%\kernel.bin

set IMAGE=%OUTPUT_DIR%\clock.img

:: Cria o subdiretório bin se este não existe.
if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

:: Exclui todos os arquivos no subdiretório bin.
del /Q /F bin\*


:: ----------------------------------------------------------------------------
:: Compilação de bootloader.asm com o montador NASM
:: ----------------------------------------------------------------------------

echo Compilando "bootloader.asm"

%NASM_PATH% -f bin %BOOTLOADER_SOURCE% -o %BOOTLOADER_BINARY%

if %errorlevel% neq 0 echo Erro ao gerar %BOOTLOADER_BINARY% && pause && exit


:: ----------------------------------------------------------------------------
:: Compilação de kernel.asm com o montador NASM
:: ----------------------------------------------------------------------------

echo Compilando "kernel.asm"

%NASM_PATH% -f bin %KERNEL_SOURCE% -o %KERNEL_BINARY%

if %errorlevel% neq 0 echo Erro ao gerar %KERNEL_BINARY% && pause && exit


:: ----------------------------------------------------------------------------
:: Criação da imagem de disco em RAW FORMAT
:: ----------------------------------------------------------------------------

echo Gerando "clock.img"

copy /b %BOOTLOADER_BINARY%+%KERNEL_BINARY% %IMAGE%

if %errorlevel% neq 0 echo Erro ao gerar %IMAGE% && pause && exit


:: ----------------------------------------------------------------------------
:: Teste da imagem como o Quemu
:: ----------------------------------------------------------------------------

qemu-system-i386 -drive format=raw,file=%IMAGE% -machine pc,hpet=on -rtc base=localtime,clock=host -cpu max -device isa-debug-exit,iobase=0xf4,iosize=0x04