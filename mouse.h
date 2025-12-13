MUS_RESET macro		
	push ax
	push cx
	push dx
	;滑鼠重置
	mov ax,0000h
	int 33h
	;AX=07h：設定 X 軸可移動範圍
	mov ax, 07h
	mov cx, 0         ; 左邊界 (pixel)
	mov dx, 620       ; 右邊界 (pixel)
	int 33h
	;AX=08h：設定 Y 軸可移動範圍
	mov ax, 08h
	mov cx, 0        ; 上邊界
	mov dx, 479       ; 下邊界 (Mode 12h)
	int 33h
	pop dx
	pop cx
	pop ax
endm


MUS_SHOW	macro 		;顯示滑鼠游標
	push ax
	mov ax,0001h
	int 33h
	pop ax
endm
			
MUS_HIND	macro 		;隱藏滑鼠游標
	push ax
	mov ax,0002h
	int 33h
	pop  ax
endm

MUS_GET03 macro 		;取得滑鼠狀態與游標位置
	push ax
	mov ax,0003h
	int 33h
	pop ax
endm
MUS_SET_POS macro x, y
	push ax
	push cx
	push dx
	mov ax, 0004h
    mov cx, x      ; X 座標
    mov dx, y      ; Y 座標
    int 33h
	pop dx
	pop cx
	pop ax
endm
