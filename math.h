times_ten MACRO value
    push ax
    push bx
    push cx
    mov ax, value
    mov bx, ax
    mov cl ,3
    shl ax, cl        
    shl bx, 1        
    mov value, ax    
    add value, bx  
    pop cx
    pop bx
    pop ax 
ENDM

times_twenty MACRO value
    push ax
    push bx
    push cx
    mov ax, value
    mov bx, ax
    mov cl ,4
    shl ax, cl 
    mov cl ,2       
    shl bx, cl        
    mov value, ax    
    add value, bx
    pop cx
    pop bx
    pop ax
ENDM