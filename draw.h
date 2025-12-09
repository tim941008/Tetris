; 畫一個點 (Pixel)
; 參數: X_POS (暫存器或常數), Y_POS (暫存器或常數), COLOR (暫存器或常數)
; 使用 INT 10h, AH=0Ch
DRAW_PIXEL MACRO X_POS, Y_POS, COLOR
    push ax
    push bx
    push cx
    push dx
    
    mov ah, 0Ch
    mov al, COLOR
    mov bh, 0       ; Page 0
    mov cx, X_POS   ; CX = X
    mov dx, Y_POS   ; DX = Y
    int 10h
    
    pop dx
    pop cx
    pop bx
    pop ax
ENDM

DrawBlock MACRO _x, _y, _size, _color
    push ax
    push bx
    push cx
    push dx
    
    mov dx, _y           ; 使用傳入的 Y 參數
    mov bx, _size        ; 使用傳入的 尺寸 參數
    
    .WHILE bx > 0
        mov cx, _x       ; 使用傳入的 X 參數
        push bx          ; 保存高度計數
        
        mov bx, _size    ; 重設寬度計數
        .WHILE bx > 0
            DRAW_PIXEL cx, dx, _color
            inc cx
            dec bx
        .ENDW
        
        pop bx           ; 恢復高度計數
        inc dx
        dec bx
    .ENDW
    
    pop dx
    pop cx
    pop bx
    pop ax
ENDM

DRAW_WORD MACRO ADDR, X, Y, COLOR
    local next_row, draw_bits, draw_pixel_here, next_bit
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov si, OFFSET ADDR   ; SI 指向字型資料
    mov dx, Y             ; 畫圖起始 Y 座標
    mov bx, X             ; 畫圖起始 X 座標
    
    mov di, 16            ; 16 rows
    
    next_row:
        ; 讀取兩個 bytes → 16 bits
        mov ah, [si]
        mov al, [si+1]
    
        mov cx, 16            ; 16 bits per row
        mov bp, bx            ; 當前行的 X 座標

    draw_bits:
        shl ax, 1
        jc draw_pixel_here         ; bit=1, cf=1, 畫
        jmp next_bit

        draw_pixel_here:
            DrawBlock  bp, dx, 5, COLOR
            jmp next_bit

        next_bit:
            add bp,5
            loop draw_bits

        add si, 2
        add dx,5
        dec di ;如果di減到0了，zf=0
        jnz next_row
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

ENDM
