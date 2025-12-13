; =====================================================================
; macro.h - 俄羅斯方塊巨集庫
; =====================================================================


; 設定為 VGA 640x480 16色模式 (Mode 12h)
INIT_GRAPHICS_MODE MACRO
    push ax
    mov ax, 0012h
    int 10h
    pop ax
ENDM

; 設定為文字模式 (退出遊戲用)
EXIT_TEXT_MODE MACRO
    push ax
    mov ax, 0003h
    int 10h
    pop ax
ENDM



SetCursor macro row,col	;設定游標位置
    push ax
    push bx
    push dx

    mov dh,row
    mov dl,col
    mov bx,00h
    mov ah,02h
    int 10h

    pop dx
    pop bx
    pop ax
endm

printstr macro string ,color;列印字串
        push si
        push ax
        push bx
        lea si,string
        mov ah,0Eh
        .while byte ptr [si] != '$'
            mov al,[si]
            mov bh,00h
            mov bl,color
            int 10h
            inc si
        .endw
        pop bx
        pop ax
        pop si
endm

printnum macro score, color, str
    push ax
    push bx
    push dx
    push si
    mov ax, score
    mov si, 4
    .Repeat 
        xor dx, dx
        mov bx, 10
        div bx
        add dl, '0'
        mov str[si], dl
        dec si
    .Until ax  == 0 
    printstr str, color

    ;清零
    mov si, 0
    .WHILE si < 5
        mov str[si], 0
        inc si
    .ENDW

    pop si
    pop dx
    pop bx
    pop ax
ENDM


_PAUSE MACRO
    push ax
    mov ah, 00h
    int 16h
    pop ax
ENDM

;---------------------------------------
; AL = 像素顏色
; 參數：
;   CX = X
;   DX = Y
;---------------------------------------
GetPixelColor MACRO x, y, color
    push ax
    push bx
    push cx
    push dx

    mov cx, x
    mov dx, y

    mov ah, 0Dh
    mov bh, 0          ; page 0
    int 10h            ; AL = color

    mov color, al

    pop dx
    pop cx
    pop bx
    pop ax
ENDM

