[bits 16]

; --- Entry Point ---
bios_entry:
    cli
    cld

    ; Zero out segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Set up Video (INT 10h) and Disk (INT 13h) vectors in the IVT
    mov word [0x0010 * 4], int10_handler
    mov word [0x0010 * 4 + 2], 0xf000

    mov word [0x0013 * 4], int13_handler
    mov word [0x0013 * 4 + 2], 0xf000

    sti

    ; Print startup line
    mov si, msg_init
    call print

    ; Read sector 0 from disk into 0x7C00
    call read_disk

    ; Validate 0xAA55 signature at 0x7DFE
    cmp word [0x7dfe], 0xaa55
    jne boot_failed

    ; Pass boot drive ID in DL (0x80 = First Hard Disk)
    mov dl, 0x80
    jmp 0x0000:0x7c00

boot_failed:
    mov si, msg_err
    call print

hang:
    cli
    hlt
    jmp hang

; --- Minimal Print Function ---
print:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    mov bh, 0x00
    int 0x10
    jmp print
.done:
    ret

; --- Basic Interrupt Handlers ---
int10_handler:
    pushf
    push ax
    cmp ah, 0x0e
    jne .out
    ; Simple VGA teletype fallback
.out:
    pop ax
    popf
    iret

int13_handler:
    pushf
    cmp ah, 0x00    ; Reset disk
    je .success
    cmp ah, 0x02    ; Read sector
    je .read
    cmp ah, 0x42    ; LBA Read
    je .read

    mov ah, 0x01    ; Invalid command
    stc
    popf
    iret

.read:
    pusha
    call read_disk
    popa
.success:
    xor ah, ah
    clc
    popf
    iret

; --- Direct IDE Disk Read ---
read_disk:
    mov dx, 0x1f6
    mov al, 0xe0
    out dx, al

    mov dx, 0x1f2
    mov al, 1
    out dx, al

    mov dx, 0x1f3
    mov al, 0
    out dx, al

    mov dx, 0x1f4
    mov al, 0
    out dx, al

    mov dx, 0x1f5
    mov al, 0
    out dx, al

    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

.wait:
    in al, dx
    test al, 0x08
    jz .wait

    mov cx, 256
    mov dx, 0x1f0
    mov di, 0x7c00
    rep insw
    ret

; --- Strings ---
msg_init db "STB loaded...", 0x0d, 0x0a, 0
msg_err  db "Boot failed: No valid signature.", 0x0d, 0x0a, 0

; --- Pad up to Reset Vector ---
times 65520 - ($ - $$) db 0x90

reset_vector:
    jmp 0xf000:bios_entry

times 65536 - ($ - $$) db 0
