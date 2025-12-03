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