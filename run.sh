#!/bin/bash
# Assembler le bootloader
nasm -f bin src/boot/boot.asm -o build/boot/boot.bin

# Créer une image de disquette vide de 1,44 Mo
dd if=/dev/zero of=build/floppy.img bs=512 count=2880

# Copier le bootloader dans l'image de disquette
dd if=build/boot/boot.bin of=build/floppy.img conv=notrunc

# Lancer QEMU avec l'image de disquette
qemu-system-x86_64 -drive format=raw,file=build/floppy.img,if=floppy -k fr -monitor stdio

# Lancer BOCHS pour le debug
# source ./debug.sh