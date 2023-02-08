#!/bin/bash
nasm -I include/ -o boot/mbr.bin boot/mbr.S
nasm -I include/ -o boot/loader.bin boot/loader.S
dd if=/bochs/bin/boot/mbr.bin of=/bochs/bin/hd60M.img  bs=512 count=1 conv=notrunc
dd if=/bochs/bin/boot/loader.bin of=/bochs/bin/hd60M.img  bs=512 count=4 conv=notrunc seek=2

nasm -f elf -o build/print.o lib/kernel/print.S
nasm -f elf -o build/kernel.o kernel/kernel.S 
gcc -I lib/kernel/ -I lib/ -I kernel/ -m32 -c -fno-builtin -o build/interrupt.o kernel/interrupt.c -fno-stack-protector
gcc -I lib/kernel/ -I lib/ -I kernel/ -m32 -c -fno-builtin -o build/main.o kernel/main.c -fno-stack-protector
gcc -I lib/kernel/ -I lib/ -I kernel/ -m32 -c -fno-builtin -o build/init.o kernel/init.c -fno-stack-protector
ld -m elf_i386 -Ttext 0xc0001500 -e main -o kernel/kernel.bin build/*.o

dd if=/bochs/bin/kernel/kernel.bin of=/bochs/bin/hd60M.img  bs=512 count=200 conv=notrunc seek=9