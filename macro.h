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