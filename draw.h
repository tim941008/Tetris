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


DRAW_WORD MACRO ADDR, X, Y, COLOR, size
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
            DrawBlock  bp, dx, size, COLOR
            jmp next_bit

        next_bit:
            add bp,size
            loop draw_bits

        add si, 2
        add dx, size
        dec di ;如果di減到0了，zf=0
        jnz next_row
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

ENDM

DRAW_WORD_32x32_16BIT MACRO ADDR, X, Y, COLOR, size
    local next_row, draw_bits_left, draw_bits_right, draw_pixel_here, draw_pixel_here_2, next_bit, next_bit_2
    
    ; 儲存暫存器 (使用 16 位元)
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp 
    
    mov si, OFFSET ADDR     ; SI 指向字型資料
    mov dx, Y               ; 畫圖起始 Y 座標
    mov bx, X               ; 畫圖起始 X 座標
    
    mov di, 32              ; **改動 1: 32 行 (rows)**
    
next_row:
    mov bp, bx              ; 當前行的 X 座標 (BP 記錄 X 座標)
    
    ; --- 步驟 1: 處理左側 16 位元 (高位) ---
    mov ah, [si]            ; 讀取 Byte 3
    mov al, [si+1]          ; 讀取 Byte 2
    
    mov cx, 16              ; 16 bits
    
draw_bits_left:
    shl ax, 1               ; 將 AX 左移 1 位，最高位進入 CF
    jc draw_pixel_here      ; bit=1, cf=1, 畫
    jmp next_bit

    draw_pixel_here:
        ; DrawBlock BP (X), DX (Y), size, COLOR
        DrawBlock bp, dx, size, COLOR 
        jmp next_bit

next_bit:
    add bp, size            ; X 座標增加
    loop draw_bits_left     ; 減少 CX，繼續處理左側 16 位元
    
    ; --- 步驟 2: 處理右側 16 位元 (低位) ---
    mov ah, [si+2]          ; 讀取 Byte 1
    mov al, [si+3]          ; 讀取 Byte 0
    
    mov cx, 16              ; 重設計數器，處理後 16 bits
    ; X 座標 BP 已經從上次的循環結果繼承下來
    
draw_bits_right:
    shl ax, 1               ; 將 AX 左移 1 位，最高位進入 CF
    jc draw_pixel_here_2    ; bit=1, cf=1, 畫
    jmp next_bit_2

    draw_pixel_here_2:
        DrawBlock bp, dx, size, COLOR 
        jmp next_bit_2

next_bit_2:
    add bp, size            ; X 座標增加
    loop draw_bits_right    ; 減少 CX，繼續處理右側 16 位元

    ; --- 準備下一行 ---
    add si, 4               ; **改動 2: SI 增加 4 bytes (下一行資料)**
    add dx, size            ; Y 座標增加 (下一行)
    dec di 
    jnz next_row
    
    ; 恢復暫存器
    pop bp 
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

ENDM

Draw_VLine MACRO X_POS, Y_START, Y_END, COLOR
    push bx
    push cx
    push dx

    mov bx, Y_END
    sub bx, Y_START
    inc bx              

    mov cx, X_POS
    mov dx, Y_START

    .WHILE bx > 0
        DRAW_PIXEL cx, dx, COLOR
        inc dx
        dec bx
    .ENDW

    pop dx
    pop cx
    pop bx
ENDM

Draw_HLine MACRO X_START, X_END, Y_POS, COLOR
    push bx
    push cx
    push dx

    mov bx, X_END
    sub bx, X_START
    inc bx              

    mov cx, X_START
    mov dx, Y_POS

    .WHILE bx > 0
        DRAW_PIXEL cx, dx, COLOR
        inc cx
        dec bx
    .ENDW

    pop dx
    pop cx
    pop bx

ENDM

DrawBox MACRO X_START, X_END, Y_START, Y_END, COLOR
    push ax
    push bx
    push cx
    push dx

    Draw_VLine X_START, Y_START, Y_END, COLOR
    Draw_VLine X_END, Y_START, Y_END, COLOR
    Draw_HLine X_START, X_END, Y_START, COLOR
    Draw_HLine X_START, X_END, Y_END, COLOR

    pop dx
    pop cx
    pop bx
    pop ax
ENDM