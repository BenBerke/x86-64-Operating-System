[bits 16]
[org 0x7c00]

KERNEL_SEG      equ 0x1000          ; 0x1000:0 = physical 0x10000
KERNEL_ADDR     equ 0x10000
CHUNK_SECTORS   equ 32              ; 16 KB per BIOS call

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    mov [boot_drive], dl

    mov ax, 0xB800
    mov fs, ax
    mov word [fs:0x0F00], 0x0F31    ; '1' = bootloader running

    ; Require INT 13h LBA extensions
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    cmp bx, 0xAA55
    jne disk_error

    ; Read the kernel in chunks; the total size comes from the incbin below
    mov word [remaining], (kernel_end - kernel_start) / 512
.read_loop:
    mov ax, CHUNK_SECTORS
    cmp [remaining], ax
    jae .do_read
    mov ax, [remaining]
.do_read:
    mov [dap_count], ax
    mov si, dap
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    mov ax, [dap_count]
    sub [remaining], ax
    add [dap_lba], ax
    shl ax, 5                       ; sectors * 512 / 16 = paragraphs
    add [dap_seg], ax
    cmp word [remaining], 0
    jne .read_loop

    mov word [fs:0x0F02], 0x0F32    ; '2' = kernel loaded

    in al, 0x92                     ; A20
    or al, 2
    out 0x92, al

    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:pm_start

disk_error:
    mov word [fs:0x0F00], 0x4F45    ; white 'E' on red
.halt:
    hlt
    jmp .halt

; Disk Address Packet
align 4
dap:
    db 0x10, 0
dap_count:  dw 0
dap_off:    dw 0
dap_seg:    dw KERNEL_SEG
dap_lba:    dq 1
remaining:  dw 0

; ---------------------------------------------------------------
[bits 32]
pm_start:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    mov word [0xB8F04], 0x0F33      ; '3' = protected mode

    ; Clear 24 KB of page tables at 0x1000..0x6FFF
    mov edi, 0x1000
    xor eax, eax
    mov ecx, 0x6000 / 4
    cld
    rep stosd

    ; PML4[0] -> PDPT; PDPT[0..3] -> four page directories (4 GB total)
    mov dword [0x1000], 0x2003
    mov dword [0x2000], 0x3003
    mov dword [0x2008], 0x4003
    mov dword [0x2010], 0x5003
    mov dword [0x2018], 0x6003

    ; 2048 page directory entries (contiguous 0x3000..0x6FFF), 2 MB each
    mov edi, 0x3000
    mov eax, 0x83                   ; present | writable | 2MB page
    mov ecx, 2048
.fill_pd:
    mov [edi], eax
    add eax, 0x200000
    add edi, 8
    loop .fill_pd

    mov eax, 0x1000
    mov cr3, eax

    mov eax, cr4
    or eax, 1 << 5                  ; PAE
    mov cr4, eax

    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8                  ; LME
    wrmsr

    mov eax, cr0
    or eax, 1 << 31                 ; PG
    mov cr0, eax

    jmp 0x18:long_mode_start

; ---------------------------------------------------------------
[bits 64]
long_mode_start:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov word [0xB8F06], 0x0F34      ; '4' = long mode

    mov rsp, 0x90000
    mov rax, KERNEL_ADDR
    jmp rax

; ---------------------------------------------------------------
align 8
gdt_start:
    dq 0x0000000000000000           ; null
    dq 0x00CF9A000000FFFF           ; 0x08: 32-bit code
    dq 0x00CF92000000FFFF           ; 0x10: data
    dq 0x00AF9A000000FFFF           ; 0x18: 64-bit code
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

boot_drive: db 0

times 510-($-$$) db 0
dw 0xaa55

kernel_start:
    incbin "kernel.bin"
    align 512, db 0
kernel_end: