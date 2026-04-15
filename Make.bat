@echo off

set NASM_PATH="NASM\nasm.exe"
set OUTPUT_DIR="bin"
set SRC_DIR="."

if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

del /Q /F bin\*

echo Compilando bootloader.asm...

%NASM_PATH% -f bin %SRC_DIR%\bootloader.asm -o %OUTPUT_DIR%\bootloader.bin

echo.

echo Gerando clock.img...

echo.

copy /b %OUTPUT_DIR%\bootloader.bin %OUTPUT_DIR%\clock.img

echo.


qemu-system-i386 -drive format=raw,file=%OUTPUT_DIR%\clock.img -machine pc,hpet=on -rtc base=localtime,clock=host -cpu max -device isa-debug-exit,iobase=0xf4,iosize=0x04

::qemu-system-i386 -drive format=raw,file=DateTime32.bin -machine pc,hpet=on -rtc base=utc

::pause