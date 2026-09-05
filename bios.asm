[bits 16]

; Entry point
bios_entry:
    cli                     ; Disable interrupts during setup
    cld                     ; Clear direction flag

    ; Zero out segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Set primary drive as default
    mov byte [boot_drive], 0x80

    ; Hook IVT vectors
    mov word [0x0010 * 4], int10_handler
    mov word [0x0010 * 4 + 2], 0xf000

    mov word [0x0013 * 4], int13_handler
    mov word [0x0013 * 4 + 2], 0xf000

    mov word [0x0016 * 4], int16_handler
    mov word [0x0016 * 4 + 2], 0xf000

    sti                     ; Re-enable interrupts

    ; Clear video screen
    mov ax, 0x0003
    int 0x10

    mov si, msg_init
    call print
    mov si, msg_esc_prompt
    call print

    ; Poll for ESC keypress
    mov cx, 0xffff
.check_key:
    in al, 0x64
    test al, 0x01
    jz .no_key

    in al, 0x60
    cmp al, 0x01            ; ESC scancode
    je bios_menu

.no_key:
    loop .check_key

    ; Attempt default boot if no ESC
    call boot_selected_drive

boot_failed:
    mov si, msg_err
    call print

hang:
    cli
    hlt
    jmp hang

; BIOS setup menu
bios_menu:
    mov ax, 0x0003
    int 0x10

    mov si, msg_menu_header
    call print

menu_loop:
    mov si, msg_prompt
    call print

    ; Wait for key input
    mov ah, 0x00
    int 0x16

    ; Echo key
    mov ah, 0x0e
    int 0x10

    cmp al, '1'
    je .option_boot_primary
    cmp al, '2'
    je .option_boot_secondary
    cmp al, '3'
    je .option_info
    cmp al, '4'
    je .option_reboot

    mov si, msg_invalid
    call print
    jmp menu_loop

.option_boot_primary:
    mov byte [boot_drive], 0x80
    mov si, msg_boot_primary
    call print
    call boot_selected_drive
    jmp boot_failed

.option_boot_secondary:
    mov byte [boot_drive], 0x81
    mov si, msg_boot_secondary
    call print
    call boot_selected_drive
    jmp boot_failed

.option_info:
    mov si, msg_time_prefix
    call print
    call print_rtc_time
    mov si, msg_info
    call print
    jmp menu_loop

.option_reboot:
    mov si, msg_reboot
    call print
    mov al, 0xfe            ; Trigger keyboard controller reset
    out 0x64, al
    jmp hang

; Fetch RTC time from CMOS
print_rtc_time:
    mov al, 0x04            ; Hours
    call read_cmos_register
    call print_bcd_byte

    mov al, ':'
    call print_char

    mov al, 0x02            ; Minutes
    call read_cmos_register
    call print_bcd_byte

    mov al, ':'
    call print_char

    mov al, 0x00            ; Seconds
    call read_cmos_register
    call print_bcd_byte
    ret

; Read byte from CMOS port 0x71
read_cmos_register:
    out 0x70, al
    in al, 0x71
    ret

; Convert and print BCD byte
print_bcd_byte:
    push ax
    shr al, 4
    add al, '0'
    call print_char
    pop ax
    and al, 0x0f
    add al, '0'
    call print_char
    ret

; Print single character via teletype
print_char:
    mov ah, 0x0e
    mov bh, 0x00
    int 0x10
    ret

; Load boot sector into memory and jump
boot_selected_drive:
    mov dl, [boot_drive]
    call read_disk
    cmp word [0x7dfe], 0xaa55
    jne .failed
    mov dl, [boot_drive]
    jmp 0x0000:0x7c00
.failed:
    ret

; IDE drive read routine
read_disk:
    mov dl, [boot_drive]
    cmp dl, 0x81
    je .secondary_drive
    mov al, 0xe0            ; Master drive
    jmp .select_drive

.secondary_drive:
    mov al, 0xf0            ; Slave drive

.select_drive:
    mov dx, 0x1f6
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

; String printing helper
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

; Dummy video handler
int10_handler:
    iret

; Disk service handler
int13_handler:
    pushf
    cmp ah, 0x00
    je .success
    cmp ah, 0x02
    je .read
    cmp ah, 0x42
    je .read

    mov ah, 0x01
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

; Keyboard service handler
int16_handler:
    pushf
    cmp ah, 0x00
    je .wait_key
    popf
    iret

.wait_key:
    in al, 0x64
    test al, 0x01
    jz .wait_key
    in al, 0x60
    popf
    iret

; Data
boot_drive      db 0x80

msg_init        db "Custom BIOS v1.0", 0x0d, 0x0a, 0
msg_esc_prompt  db "Press [ESC] to enter Setup...", 0x0d, 0x0a, 0
msg_err         db 0x0d, 0x0a, "Boot failed.", 0x0d, 0x0a, 0

msg_menu_header db "BIOS Setup", 0x0d, 0x0a
                db "1. Primary Disk (0x80)", 0x0d, 0x0a
                db "2. Secondary Disk (0x81)", 0x0d, 0x0a
                db "3. System Time", 0x0d, 0x0a
                db "4. Reboot", 0x0d, 0x0a, 0

msg_prompt         db 0x0d, 0x0a, "> ", 0
msg_invalid        db 0x0d, 0x0a, "Invalid option.", 0x0d, 0x0a, 0
msg_boot_primary   db 0x0d, 0x0a, "Booting 0x80...", 0x0d, 0x0a, 0
msg_boot_secondary db 0x0d, 0x0a, "Booting 0x81...", 0x0d, 0x0a, 0
msg_reboot         db 0x0d, 0x0a, "Rebooting...", 0x0d, 0x0a, 0
msg_time_prefix    db 0x0d, 0x0a, "RTC Time: ", 0
msg_info           db 0x0d, 0x0a, 0

; Pad file to 64KB
times 65520 - ($ - $$) db 0x90

; x86 CPU reset vector (0xFFFFFFF0)
reset_vector:
    jmp 0xf000:bios_entry

times 65536 - ($ - $$) db 0
