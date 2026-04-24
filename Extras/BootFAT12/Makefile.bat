@echo off


:: ----------------------------------------------------------------------------
:: Seção de constantes
:: ----------------------------------------------------------------------------

set NASM=nasm.exe

set QEMU=qemu-system-i386.exe

set OUTPUT_DIR=bin

set BOOTLOADER_SOURCE=bootloader.asm

set TESTCODE_SOURCE=testcode.asm

set BOOTLOADER_BINARY=%OUTPUT_DIR%\bootloader.bin

set TESTCODE_BINARY=%OUTPUT_DIR%\TESTCODE.BIN

set IMAGE=%OUTPUT_DIR%\bootloader.img

:: Cria o subdiretório bin se este não existe.
if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

:: Exclui todos os arquivos no subdiretório bin.
del /Q /F bin\*


:: ----------------------------------------------------------------------------
:: Montagem de bootloader.asm com o montador NASM
:: ----------------------------------------------------------------------------

echo Montando "bootloader.asm"

%NASM% -f bin -o %BOOTLOADER_BINARY% %BOOTLOADER_SOURCE%

if %errorlevel% neq 0 echo Erro ao gerar %TESTCODE_BINARY% && pause && exit


:: ----------------------------------------------------------------------------
:: Montagem de testcode.asm com o montador NASM
:: ----------------------------------------------------------------------------

echo Montando "testcode.asm"

%NASM% -f bin -o %TESTCODE_BINARY% %TESTCODE_SOURCE%

if %errorlevel% neq 0 echo Erro ao gerar %TESTCODE_BINARY% && pause && exit


:: ----------------------------------------------------------------------------
:: Criação da imagem de disco formatada como FAT-12 com FAT12Formatter.exe.
:: O código-fonte de FAT12Formatter.exe, em linguagem C, está no subdiretório 
:: Extras\FAT12Formatter
:: ----------------------------------------------------------------------------

echo Criando imagem com "FAT12Formatter.exe"

FAT12Formatter.exe %BOOTLOADER_BINARY% %TESTCODE_BINARY% %IMAGE%

if %errorlevel% neq 0 echo Erro ao gerar %IMAGE% && pause && exit

if not exist %IMAGE% (
    echo Erro ao gerar %IMAGE%
    pause
    exit
)


:: ----------------------------------------------------------------------------
:: Teste da imagem como o Quemu
:: ----------------------------------------------------------------------------

echo Iniciando QEMU...

%QEMU% -drive if=floppy,index=0,format=raw,file=%IMAGE% -boot order=a