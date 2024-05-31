; Public domain, 2017, 2018, 2020 Konstantin Tcholokachvili

;                                           ----------------------------------
;                                                          Multiboot constants
;=============================================================================
[bits 32]

; Setting up the Multiboot header - see GRUB docs for details
MBALIGN     equ 1<<0              ; align loaded modules on page boundaries
MEMINFO     equ 1<<1              ; provide memory map
FLAGS       equ MBALIGN | MEMINFO ; this is the Multiboot 'flag' field
MAGIC       equ 0x1BADB002        ; 'magic number' lets bootloader find the header
CHECKSUM    equ -(MAGIC + FLAGS)  ; checksum required to prove that we are multiboot
STACK_SIZE  equ 0x2000            ; stack size is 8 KiB

;                                           -----------------------------------
;                                                                     MULTIBOOT
;==============================================================================
section .multiboot

; The multiboot header must come first.

; Multiboot header must be aligned on a 4-byte boundary
align 4

multiboot_header:
dd MAGIC
dd FLAGS
dd -(MAGIC + FLAGS)

;                                           ----------------------------------
;                                                                          BSS
;=============================================================================
section .bss nobits align=4
; Reserve initial kernel stack space
stack:          resb STACK_SIZE ; reserve 8 KiB stack
multiboot_info: resd 1          ; we will use this in kernel's main
magic:          resd 1          ; we will use this in kernel's main

;-----------------------------------------------------------------------------
;                                                                         DATA
;=============================================================================
section .data

global stack_bottom
stack_bottom:
    dd stack
stack_top:

; Pointer to the Global Descriptor Table
align 8
gdtr:
    dw gdt_end-gdt-1
    dd gdt

; Global Descriptor Table
gdt:
    dd 0x00000000, 0x00000000 ; null
    dd 0x0000FFFF, 0x00CF9A00 ; code
    dd 0x0000FFFF, 0x00CF9200 ; data

gdt_end:

; Interrupts Descriptor Table
align 8
idtr:
    dw idt_end-idt-1
    dd idt

idt:
    times 256 dd 0x00000000, 0x00000000

idt_end:

VGA_MEMORY: dd 0xb8000
VGA_COLUMN: db 0
VGA_ROW:    db 0

keymap:
    times 2 db 0
    db '1', '2', '3','4','5','6','7','8','9','0','-','^'
    times 2 db 0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '@'
    times 3 db 0
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', ':'
    times 3 db 0
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/'
    times 7 db 0
    db ' '

;                                           ----------------------------------
;                                                                         CODE
;=============================================================================
section .text

; Setup the multiboot
global multiboot_entry
multiboot_entry:
    mov esp, stack + STACK_SIZE ; set up the stack
    mov [magic], ebx            ; multiboot magic number
    mov [multiboot_info], eax   ; multiboot data structure

    cli                         ; disable interrupts

; Setup GDT and update the segment registers.
    mov ecx, gdtr
    lgdt [ecx]

; Prepare for protected mode
    mov eax, cr0
    or  al, 1                   ; set 'Protection Enable' bit
    mov cr0, eax                ; in CR0 to enable protected mode
    jmp 0x08:protected_mode     ; code segment

protected_mode:
    mov ecx, 0x10               ; data segment
    mov ds, cx                  ; load ds, es, fs, gs, ss segments
    mov es, cx
    mov fs, cx
    mov gs, cx
    mov ss, cx
    mov esp, stack_top
    xor ecx, ecx

    call initialization

;                                           ----------------------------------
;                                                              System routines
;=============================================================================
set_cursor:
    pushf
    push eax
    push ebx
    push ecx
    push edx

    ; uint16_t position = (row * 80) + col;
    ; AX will contain 'position'
    mov ax, bx
    and ax, 0x0ff		; set AX to 'row'
    mov cl, 80
    mul cl			; row * 80

    mov cx, bx
    shr cx, 8			; set CX to 'col'
    add ax, cx			; + col
    mov cx, ax			; store 'position' in CX

    ;cursor LOW port to vga INDEX register
    mov al, 0x0f
    mov dx, 0x3d4		; VGA port 3D4h
    out dx, al

    mov ax, cx			; restore 'postion' back to AX
    mov dx, 0x3d5		; VGA port 3D5h
    out dx, al			; send to VGA hardware

    ;cursor HIGH port to vga INDEX register
    mov al, 0x0e
    mov dx, 0x3d4		; VGA port 3D4h
    out dx, al

    mov ax, cx			; restore 'position' back to AX
    shr ax, 8			; get high byte in 'position'
    mov dx, 0x3d5		; VGA port 3D5h
    out dx, al			; send to VGA hardware

    pop edx
    pop ecx
    pop ebx
    pop eax
    popf

    ret

update_xy:
    mov byte [VGA_COLUMN], 0
    inc byte [VGA_ROW]
    ret

; Args:
;     al: character
display_symbol:
    mov ebx, [VGA_MEMORY]
    mov byte [ebx], al          ; Display character
    mov byte [ebx+1], 0x7       ; VGA attributes
    add word [VGA_MEMORY], 2

    cmp byte [VGA_COLUMN], 79	; 80 columns (0-79)
    je update_xy

    inc byte [VGA_COLUMN]

    mov byte bl, [VGA_ROW]
    mov byte bh, [VGA_COLUMN]
    call set_cursor

    ret

keyboard_handler:
    ; Send EOI
    mov al, 0x20
    out 0x20, al

    ; Read keyboard status port
    in al, 0x64
    test al, 0x01
    jz .no_data
    ; Get the keycode from keyboard's data port
    xor eax, eax
    in byte al, 0x60
    cmp al, 0
    jl .no_data

    mov byte al, [keymap + eax] ; keymap -> character
    call display_symbol
.no_data:
    iretd

keyboard_interrupt_setup:
    mov ecx, keyboard_handler
    and ecx, 0x0000ffff       ; bits 0..15  (offset low)
    or  ecx, 0x00080000       ; bits 16..31 (segment selector) <- 8
    mov [idt + 33 * 8], ecx   ; set low32

    mov ecx, keyboard_handler
    and ecx, 0xffff0000       ; bits 48..63 (offset high)
    or  ecx, 0x00008e00       ; bits 32..39 (unused)      <- 00000000
                              ; bits 40..43 (gate type)   <- 1110
                              ; bits 44 (storage segment) <- 0
                              ; bits 45, 46 (dpl)         <- 00
                              ; bits 47 (present)         <- 1
                              ; Result: 0b1000111000000000 = 0x8e00

    mov [idt + 33 * 8 + 4], ecx ; Set high32 into IDT array
    ret

idt_setup:                  ; Setup IDT
    mov ecx, idtr
    lidt [ecx]
    ret

; Setup PIC
pic_setup:
    ; Remap the PIC so that IRQs start at 32
    mov al, 0x11
    out 0x20, al            ; 0x20 is for PIC master command
    out 0xa0, al            ; 0xa0 is for PIC slave command

    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xa1, al

    mov al, 0x0
    out 0x21, al
    mov al, 0x0
    out 0xa1, al

    mov al, 0x1
    out 0x21, al
    out 0xa1, al

    mov al, 0xff
    out 0x21, al
    mov al, 0xff
    out 0xa1, al
    ret

initialization:
    call pic_setup
    call idt_setup
    call keyboard_interrupt_setup

    ; Enable IRQ1 (keyboard)
    mov al, 0xfd
    out 0x21, al

    sti

loop:
    hlt
    jmp loop
