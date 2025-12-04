GetBoardIndex MACRO x, y, result_index
    ; Input:  AX = y, BX = x
    ; Output: BX = y*10 + x
    push ax
    push bx
    push cx
    push dx
    mov ax, y
    mov bx, x
    mov dx, ax       ; DX = y
    mov cl, 3
    shl ax ,cl           
    shl dx, 1        
    add ax, dx       ; AX = y*8 + y*2 = y*10
    add ax, bx       
    mov result_index, ax
    pop dx
    pop cx
    pop bx
    pop ax
ENDM

GetPieceStatus MACRO piece, rotation, result_offset
    ; Input:  AL = piece, BL = rotation
    ; Output: BX = piece*32 + rotation*8
    push ax
    push bx
    push cx
    xor ax,ax
    xor bx,bx
    mov al, piece
    mov bl, rotation
    mov cl, 5
    shl ax, cl          ; AX = piece*32
    mov cl, 3
    shl bx, cl          ; BX = rotation*8
    add ax, bx          ; AX = piece*32 + rotation*8
    mov result_offset, ax
    pop cx
    pop bx
    pop ax
ENDM