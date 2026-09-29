[bits 16]
[org 0x7c00]

start:
    mov ah, 0x0e
    mov al, 'B'
    int 0x10
    mov al, 'o'
    int 0x10
    mov al, 'o'
    int 0x10
    mov al, 't'
    int 0x10

halt:
    jmp halt

times 510-($-$$) db 0
dw 0xaa55