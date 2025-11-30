; ==========================================
; 1A2B Guess Game 
; 功能：
;   - INT 16h 鍵盤輸入
;   - LCG 隨機數
;   - 自動 4 位數判斷
;   - A 綠色, B 紅色
;   - ESC 離開, F1 顯示答案(黃色字體)
; ==========================================
include print.h

.model small
.stack 100h

;------------------------------------------

;------------------------------------------
.data
msgTitle   db '=== 1A2B Guess Game ===$'
msgInput   db 'Enter 4 digits (0-9): $'
msgResult  db 'Result: $'
msgWin     db 'You got it!$'
msgExit    db 'Exit game.$'
msgAns     db 'Answer: $'
msgInvalid db 'Invalid input, try again.$'

randSeed   dw ?
answer     db 4 dup(?)
guess      db 4 dup(?)

a_count    db 0h
b_count    db 0h

;------------------------------------------
.code
main PROC
    mov ax, @data
    mov ds, ax

Start:
    CLS
    PRINTLN msgTitle
    call InitRandomSeed
    call GenerateAnswer

GameLoop:
    PRINTLN msgInput
    call ReadInput
    cmp al, 1Bh
    je ExitGame

    cmp ah, 3Bh
    je ShowAnswer

    cmp cx, 4
    jne InvalidInput

    call CheckAnswer
    NEWLINE
    PRINTLN msgResult
    call PrintAB
    NEWLINE

    cmp a_count, 4      

    je YouWin
    jmp GameLoop

InvalidInput:
    PRINTLN msgInvalid
    jmp GameLoop

YouWin:
    PRINTLN msgWin
    jmp ExitGame

ShowAnswer:
    PRINTSTR msgAns
    mov si, OFFSET answer
    mov cx, 4
ShowLoop:
    mov al, [si]
    PRINT_COLOR al, 0Eh     ; 黃色答案
    inc si
    loop ShowLoop
    NEWLINE
    

ExitGame:
    PRINTLN msgExit
    mov ah, 4Ch
    int 21h
main ENDP

;------------------------------------------
; === 子程序 ===
;------------------------------------------
; 初始化亂數種子
; 使用 INT 1Ah 取得系統時間（ticks since midnight）
;------------------------------------------
InitRandomSeed PROC
    push ax
    push dx

    mov ah, 00h
    int 1Ah          ; CX:DX = 時鐘計數（每 tick 約 55ms）
    mov randSeed, dx ; 用低位當亂數種子

    pop dx
    pop ax
    ret
InitRandomSeed ENDP

; 線性同餘亂數
RandomNumber PROC
    ; randSeed = (randSeed * 25173 + 13849) mod 65536
    mov ax, randSeed
    mov bx, 25173
    mul bx
    add ax, 13849
    mov randSeed, ax
    ret
RandomNumber ENDP

; 產生不重複 4 位數
GenerateAnswer PROC
    LOCAL table[10]:BYTE

    ; 初始化表為 0
    mov cx, 10
    mov ax,0
clear_table:
    mov si, cx
    dec si
    mov table[si], 0
    loop clear_table

    mov cx, 0     
GenLoop:
    call RandomNumber
    mov ax, randSeed
    mov dx,0
    mov bx, 000Ah
    div bx           
    mov si, dx
    cmp table[si], 1 ; 若已用過
    je GenLoop       ; 再抽一次


    mov table[si], 1 ; 標記已用
    add dl, '0'      ; 轉成 ASCII
    mov si, cx
    mov answer[si], dl
    inc cx
    cmp cx, 4
    jb GenLoop
    ret
GenerateAnswer ENDP


; 讀 4 位數輸入（自動判斷）
ReadInput PROC
    mov cx, 0
    mov si, cx
ReadLoop:
    mov ah, 00h
    int 16h
    cmp al, 1Bh ;ESC
    je EndRead
    cmp ah, 3Bh ;F1
    je EndRead
    cmp al, 08h ;Backspace
    jne check_num
    cmp si, 0
    je ReadLoop
    dec si
    dec cx
    call GetCursorPosition
    dec dl
    call SetCursorPosition
    PRINTCHAR ' '
    call SetCursorPosition

    jmp ReadLoop
    
check_num:
    cmp al, '0'
    jb Ignore
    cmp al, '9'
    ja Ignore
    cmp cx, 4
    jae EndRead
    mov guess[si], al
    inc si
    inc cx
    PRINTCHAR al
    cmp cx, 4
    je EndRead
Ignore:
    jmp ReadLoop
EndRead:
    ret
ReadInput ENDP

; 計算 A 與 B
CheckAnswer PROC
    mov a_count, 0
    mov b_count, 0

    ; --- 1. 計算 A ---
    mov si, 0           ; si = i (index)
CalcALoop:
    cmp si, 4
    jae EndCalcALoop

    mov al, answer[si]
    mov bl, guess[si]

    cmp al, bl
    jne NotA
    inc a_count         ; A + 1
NotA:
    inc si
    jmp CalcALoop
EndCalcALoop:

    ; --- 2. 計算 B ---
    mov si, 0           ; si = i (外層迴圈, for guess)
CalcBLoop_Outer:
    cmp si, 4
    jae EndCalcBLoop
    
    mov di, 0           ; di = j (內層迴圈, for answer)
CalcBLoop_Inner:
    cmp di, 4
    jae NextOuterLoop
    
    cmp si, di          ; if (i == j)
    je SkipB            ; 這是 A 的情況, 跳過
    
    mov al, answer[di]  ; al = answer[j]
    mov bl, guess[si]   ; bl = guess[i]
  
    
    cmp al, bl          ; if (answer[j] == guess[i])
    jne SkipB
    inc b_count         ; B + 1
    
SkipB:
    inc di
    jmp CalcBLoop_Inner

NextOuterLoop:
    inc si
    jmp CalcBLoop_Outer
    
EndCalcBLoop:

    ret
CheckAnswer ENDP

; 顯示 A/B 結果
PrintAB PROC 
    mov al, a_count
    add al, '0'
    PRINT_COLOR al, 07h   
    PRINT_COLOR 'A', 0Ah;紅色

    mov al, b_count
    add al, '0'
    PRINT_COLOR al, 07h   
    PRINT_COLOR 'B', 0Ch ;綠色
    ret
PrintAB ENDP

;取得游標位置
GetCursorPosition PROC
    push ax
    push cx

    mov ah, 03h
    mov bh, 0   
    int 10h
    ; DH = row, DL = column
    pop cx
    pop ax

    ret

GetCursorPosition ENDP
SetCursorPosition PROC
    mov ah, 02h
    mov bh, 0
    int 10h
    ret
SetCursorPosition ENDP
END main