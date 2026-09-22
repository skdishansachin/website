+++
title = "Assembly is ez - Part 1"
date = 2026-09-22
description = "Your first NASM program on Linux x86-64."
draft = false
+++

This series covers [NASM](https://www.nasm.us/) on Linux x86-64 using Intel syntax. The code for this part is in [examples/assembly-ez/part1/](https://github.com/skdishansachin/website/tree/main/examples/assembly-ez/part1).

Why learn assembly? You're the one reading this, so you tell me. Unlike other languages, we are not writing a "Hello, World!", not because it's hard, but because it needs moving parts we'll cover later. Instead we write something that runs and exits.

This is not for someone just starting programming. This is for someone with a specific need or doing this for fun. I won't spell out every single thing - if something is unclear, break it and look it up yourself.

## The program

Save the following as `exit.asm` -

```asm
section .text
    global _start

_start:
    mov rax, 60
    mov rdi, 42
    syscall
```

Then -

```sh
nasm -f elf64 exit.asm -o exit.o
ld exit.o -o exit
strace ./exit
```

You won't see any program output. The program just exits. `strace` shows what happened - a single `exit` system call with argument 42, something like `exit(42)` followed by `+++ exited with 42 +++`. Control never returns after that call.

## What each line does

The line `section .text` marks the following bytes as code. Later parts use `section .data` for initialized bytes and `section .bss` for zero-initialized bytes that take no space in the file. Ignore them for now.

The line `global _start` exports the label `_start` so the linker can find it. By default the linker starts execution at `_start`, so you can think of this as telling it where the assembly entry point is. You can use a different name, but then you must tell the linker explicitly with `ld -e <name>`.

The line `_start` with a trailing colon defines that label. A label is a name for an address.

The line `mov rax, 60` copies the number 60 into register `rax`. Register `rax` holds the system call number. Number 60 is `exit` on Linux x86-64. You can find the full number table in `arch/x86/entry/syscalls/syscall_64.tbl` in the kernel source, or in the installed headers such as `/usr/include/x86_64-linux-gnu/asm/unistd_64.h` (often symlinked as `/usr/include/asm/unistd_64.h`).

The line `mov rdi, 42` copies the number 42 into register `rdi`. Register `rdi` holds the first argument. For `exit`, the argument is the status. Only the low 8 bits are visible to the parent process, but 42 fits safely.

The line `syscall` transfers control to the kernel. The kernel reads the number in `rax` and the arguments in `rdi`, `rsi`, `rdx`, `r10`, `r8` and `r9`. Then it performs the requested operation. For `exit`, control never returns. It clobbers `rcx` and `r11`. Remember that for later.

On 64-bit Linux the trap instruction is `syscall`. The older `int 0x80` mechanism belongs to 32-bit code and uses different numbers and registers, so 32-bit examples will not work here.

## Next

Part 2 explains registers, data sizes, and the `mov` instruction in detail.
