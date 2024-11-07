#!/bin/bash


target=$1

mkdir -p executables/$target-executables
for file in $(find generated_asm/$target -name "*.S"); do
    bname=$(basename $file)
    fname=${bname%.*}.exe
    echo "compiling $file into executables/$target-executables/$fname"
    riscv64-unknown-elf-gcc -march=rv64gcv -mabi=lp64d $file -o executables/$target-executables/$fname
done
tar -czvf executables/$target-executables.tar.gz executables/$target-executables
