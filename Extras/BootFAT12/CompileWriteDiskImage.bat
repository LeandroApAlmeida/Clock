@echo off


:: ----------------------------------------------------------------------------
:: Seção de constantes
:: ----------------------------------------------------------------------------

set PATH=C:\mingw64\bin;%PATH%


:: ----------------------------------------------------------------------------
:: Compilação do código-fonte em C do FAT12 Formatter
:: ----------------------------------------------------------------------------

echo Compilando o codigo-fonte...

gcc WriteDiskImage.c -o WriteDiskImage.exe

if %errorlevel% equ 0 (
    echo Compilacao bem-sucedida.
) else (
	pause
    exit
)

