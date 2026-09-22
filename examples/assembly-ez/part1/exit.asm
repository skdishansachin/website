; Assembly is ez - Part 1: exit(42)
; The smallest real Linux x86-64 program. Exits with status 42.
;
; Run:
;   nasm -f elf64 exit42.asm -o exit42.o
;   ld exit42.o -o exit42
;   ./exit42 ; echo $?
; Expected: no output, exit code is 42.
; See the kernel do it: strace ./exit42

section .text
    global _start            ; linker needs to know where execution begins

_start:
    ; sys_exit(42)
    ; rax = syscall number (60 = exit), rdi = first arg (status)
    mov rax, 60
    mov rdi, 42
    syscall                 ; ask Linux. Does not return.
