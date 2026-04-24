@echo off


:: ----------------------------------------------------------------------------
:: Compilação do código-fonte em C do FAT12 Formatter
:: ----------------------------------------------------------------------------

echo Compilando o codigo-fonte...

gcc.exe WriteDiskImage.c -o WriteDiskImage.exe

if %errorlevel% equ 0 (
    echo Compilacao bem-sucedida.
) else (
	pause
    exit
)

