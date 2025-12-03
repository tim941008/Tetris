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
    add bx, ax       ; output -> BX
    mov result_index, bx
    pop dx
    pop cx
    pop bx
    pop ax
ENDM