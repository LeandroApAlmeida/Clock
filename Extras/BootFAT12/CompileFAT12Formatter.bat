@echo off


:: ----------------------------------------------------------------------------
:: Compilação do código-fonte em C do FAT12 Formatter
:: ----------------------------------------------------------------------------

echo Compilando o codigo-fonte...

gcc.exe FAT12Formatter.c -o FAT12Formatter.exe

if %errorlevel% equ 0 (
    echo Compilacao bem-sucedida.
) else (
	pause
    exit
)

