.model small
.stack 100h

.data
boxX    dw 300
boxY    dw 220
boxSize dw 20
boxCol  db 4      ; ����
hitCol  db 2      ; ���

.code
start:
    ; �i�J VGA Mode 12h
    mov ax, 0012h
    int 10h

    ; ��l�Ʒƹ�
    mov ax, 0
    int 33h

    ; �]�w�ƹ��d��
    mov ax, 7
    mov cx, 0
    mov dx, 639
    int 33h

    mov ax, 8
    mov cx, 0
    mov dx, 479
    int 33h

    ; �ƹ��m��
    mov ax, 4
    mov cx, 320
    mov dx, 240
    int 33h

    ; ��ܷƹ�
    mov ax, 1
    int 33h

    ; �e��l���
    call DrawBox

MainLoop:
    ; Ū�ƹ�
    mov ax, 3
    int 33h

    ; ����H
    test bx, 1
    jz MainLoop

    ; --- Hit Test ---
    cmp cx, boxX
    jb  MainLoop
    cmp cx, boxX
    add ax, boxSize
    cmp cx, ax
    jae MainLoop

    cmp dx, boxY
    jb  MainLoop
    mov ax, boxY
    add ax, boxSize
    cmp dx, ax
    jae MainLoop

    ; �I��F �� ���C��
    mov al, hitCol
    mov boxCol, al
    call DrawBox

    jmp MainLoop

; -----------------------------
; �e��ߤ��
; -----------------------------
DrawBox PROC
    push ax 
    push bx 
    push cx 
    push dx 
    push si 
    push di

    mov cx, boxX
    mov dx, boxY
    mov si, boxSize

YLoop:
    push cx
    mov di, boxSize

XLoop:
    mov ah, 0Ch
    mov al, boxCol
    mov bh, 0
    int 10h
    inc cx
    dec di
    jnz XLoop

    pop cx
    inc dx
    dec si
    jnz YLoop

    pop di 
    pop si
    pop dx
    pop cx 
    pop bx 
    pop ax
    ret
DrawBox ENDP

end start