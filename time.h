CLOCK_COUNTER MACRO timer_var
    push es
    push dx
    mov dx,40h
    mov es, dx
    mov dx, es:[6Ch]  ; 讀取計時器低位
    mov timer_var, dx
    pop dx
    pop es
ENDM

GET_time MACRO old_time, time_counter
    push cx
    mov ah, 02h
    int 1Ah
;   CH=時, CL=分, DH=秒, DL=1/100 秒
    ;==============================
    .IF old_time != dh
        mov old_time, dh
        inc time_counter
    .ENDIF
    ;==============================
    pop cx
ENDM