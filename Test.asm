; =====================================================================
; 8086 Tetris - Mode 12h (640x480) - High Level Syntax Version
;
; 功能:
;   1. [操作] WASD (移動/旋轉/加速)，W 為順時針旋轉。
;   2. [系統] 按 ESC 跳出 "EXIT GAME? (Y/N)" 確認視窗。
;   3. [邏輯] 堆疊滿時顯示 "GAME OVER"，按鍵後重置遊戲。
;   4. [語法] 大量使用 MASM 高階語法 (.IF, .WHILE) 簡化流程控制。
;
; 編譯: MASM 6.11 / TASM 5.0 + DOSBox
; =====================================================================

.MODEL SMALL
.STACK 200h
.386 

.DATA
    ; --- 畫面設定 ---
    BLOCK_SIZE  EQU 20
    GAME_X      EQU 220
    GAME_Y      EQU 40
    BOARD_W     EQU 10
    BOARD_H     EQU 20

    ; --- 核心變數 ---
    cur_x       DW  4
    cur_y       DW  0
    cur_piece   DB  0
    cur_rot     DB  0

    tmp_x       DW  0
    tmp_y       DW  0
    tmp_rot     DB  0

    last_timer  DW  0
    time_limit  DW  9           ; 速度約 0.5 秒
    
    game_state  DB  0           ; 0=Playing, 1=GameOver
    rand_seed   DW  3344h

    board       DB  200 DUP(0)  ; 遊戲板

    draw_color  DB 0
    draw_px     DW 0
    draw_py     DW 0
    
    ; 字串
    str_exit    DB 'EXIT GAME? (Y/N)$'
    str_over    DB 'GAME OVER!$'
    str_retry   DB 'Press Any Key$'

    ; --- 方塊形狀 (順時針) ---
    shapes      LABEL BYTE
    ; 0: I
    DB -1,0,  0,0,  1,0,  2,0
    DB  0,-1, 0,0,  0,1,  0,2
    DB -1,0,  0,0,  1,0,  2,0
    DB  0,-1, 0,0,  0,1,  0,2
    ; 1: J
    DB -1,-1, -1,0,  0,0,  1,0
    DB  0,-1,  1,-1, 0,0,  0,1
    DB -1,0,   0,0,  1,0,  1,1
    DB  0,-1,  0,0, -1,1,  0,1
    ; 2: L
    DB  1,-1, -1,0,  0,0,  1,0
    DB  0,-1,  0,0,  0,1,  1,1
    DB -1,0,   0,0,  1,0, -1,1
    DB -1,-1,  0,-1, 0,0,  0,1
    ; 3: O
    DB  0,0,  1,0,  0,1,  1,1
    DB  0,0,  1,0,  0,1,  1,1
    DB  0,0,  1,0,  0,1,  1,1
    DB  0,0,  1,0,  0,1,  1,1
    ; 4: S
    DB  0,0,  1,0, -1,1,  0,1
    DB  0,-1, 0,0,  1,0,  1,1
    DB  0,0,  1,0, -1,1,  0,1
    DB  0,-1, 0,0,  1,0,  1,1
    ; 5: T
    DB  0,-1, -1,0,  0,0,  1,0
    DB  0,-1,  0,0,  1,0,  0,1
    DB -1,0,   0,0,  1,0,  0,1
    DB  0,-1, -1,0,  0,0,  0,1
    ; 6: Z
    DB -1,0,  0,0,  0,1,  1,1
    DB  1,-1, 0,0,  1,0,  0,1
    DB -1,0,  0,0,  0,1,  1,1
    DB  1,-1, 0,0,  1,0,  0,1

    piece_colors DB 11, 9, 6, 14, 10, 13, 12

.CODE
main PROC
    mov ax, @data
    mov ds, ax

    mov ax, 0012h
    int 10h

StartGame:
    call InitGame
    call DrawBackground
    call DrawCurrent
    
    ; 初始化計時器
    mov ax, 0040h
    mov es, ax
    mov di, 006Ch
    mov ax, es:[di]
    mov last_timer, ax

    ; --- 主遊戲迴圈 ---
    .WHILE 1
        ; 1. 檢查輸入
        mov ah, 01h
        int 16h
        .IF !ZERO?          ; 有按鍵
            mov ah, 00h
            int 16h
            
            .IF al == 27    ; ESC
                call AskExit
                .IF al == 1 ; 1=Exit
                    jmp ExitApp
                .ELSE       ; 0=Resume
                    call RefreshScreen
                    ; 重置計時器避免瞬移
                    mov ax, 0040h
                    mov es, ax
                    mov di, 006Ch
                    mov ax, es:[di]
                    mov last_timer, ax
                .ENDIF
            .ELSEIF al == 'q'
                jmp ExitApp
            .ELSEIF al == 'w' || al == 'W'
                call EraseCurrent
                call TryRotate
                call DrawCurrent
            .ELSEIF al == 'a' || al == 'A'
                call EraseCurrent
                call TryLeft
                call DrawCurrent
            .ELSEIF al == 'd' || al == 'D'
                call EraseCurrent
                call TryRight
                call DrawCurrent
            .ELSEIF al == 's' || al == 'S'
                call DoDrop
            .ENDIF
        .ENDIF

        ; 2. 檢查時間 (重力)
        mov ax, 0040h
        mov es, ax
        mov di, 006Ch
        mov ax, es:[di]
        
        sub ax, last_timer
        .IF ax >= time_limit
            ; 更新計時器
            mov ax, es:[di]
            mov last_timer, ax
            
            call DoDrop
            
            ; 檢查 Game Over
            .IF game_state == 1
                call ShowGameOver
                jmp StartGame
            .ENDIF
        .ENDIF
    .ENDW

ExitApp:
    mov ax, 0003h
    int 10h
    mov ax, 4c00h
    int 21h
main ENDP

; =================================================================
; 視窗與 UI 子程式
; =================================================================

AskExit PROC
    call DrawPopupBox
    
    ; 顯示文字
    mov ah, 02h
    mov bh, 0
    mov dh, 14
    mov dl, 32
    int 10h
    mov ah, 09h
    lea dx, str_exit
    int 21h
    
    ; 等待輸入 loop
    .WHILE 1
        mov ah, 00h
        int 16h
        .IF al == 'y' || al == 'Y'
            mov al, 1   ; Return 1 for Exit
            ret
        .ELSEIF al == 'n' || al == 'N' || al == 27
            mov al, 0   ; Return 0 for Resume
            ret
        .ENDIF
    .ENDW
    ret
AskExit ENDP

ShowGameOver PROC
    call DrawPopupBox
    
    ; 顯示文字
    mov ah, 02h
    mov bh, 0
    mov dh, 13
    mov dl, 35
    int 10h
    mov ah, 09h
    lea dx, str_over
    int 21h
    
    mov ah, 02h
    mov bh, 0
    mov dh, 15
    mov dl, 33
    int 10h
    mov ah, 09h
    lea dx, str_retry
    int 21h
    
    ; 等待任意鍵
    mov ah, 00h
    int 16h
    ret
ShowGameOver ENDP

DrawPopupBox PROC
    ; 黑底
    mov draw_color, 0
    mov draw_px, 220
    mov draw_py, 180
    
    mov cx, 80
    .WHILE cx > 0
        push cx
        mov cx, 200
        mov bx, draw_px
        .WHILE cx > 0
            push cx
            push bx
            mov ah, 0Ch
            mov al, draw_color
            mov cx, bx
            mov dx, draw_py
            int 10h
            pop bx
            pop cx
            inc bx
            dec cx
        .ENDW
        inc draw_py
        pop cx
        dec cx
    .ENDW
    
    ; 白框
    mov draw_color, 15
    ; 上下左右四條線 (簡單畫法)
    mov cx, 200
    mov draw_px, 220
    mov draw_py, 180
    .WHILE cx > 0
        call PlotPixel
        inc draw_px
        dec cx
    .ENDW
    
    mov cx, 200
    mov draw_px, 220
    mov draw_py, 260
    .WHILE cx > 0
        call PlotPixel
        inc draw_px
        dec cx
    .ENDW
    
    mov cx, 80
    mov draw_px, 220
    mov draw_py, 180
    .WHILE cx > 0
        call PlotPixel
        inc draw_py
        dec cx
    .ENDW
    
    mov cx, 80
    mov draw_px, 420
    mov draw_py, 180
    .WHILE cx > 0
        call PlotPixel
        inc draw_py
        dec cx
    .ENDW
    ret
DrawPopupBox ENDP

RefreshScreen PROC
    call DrawBackground
    call DrawBoardAll
    call DrawCurrent
    ret
RefreshScreen ENDP

PlotPixel PROC
    push ax
    push bx
    push cx
    push dx
    mov ah, 0Ch
    mov al, draw_color
    mov cx, draw_px
    mov dx, draw_py
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PlotPixel ENDP

; =================================================================
; 遊戲邏輯核心
; =================================================================

DoDrop PROC
    call EraseCurrent
    
    ; 嘗試下移
    mov ax, cur_x
    mov tmp_x, ax
    mov ax, cur_y
    mov tmp_y, ax
    inc tmp_y
    
    mov al, cur_rot
    mov tmp_rot, al
    
    call CheckCollision
    .IF ax == 1
        ; 撞底處理
        call DrawCurrent    ; 補畫
        call LockPiece      ; 鎖定
        call CheckLines     ; 消行
        call SpawnPiece     ; 生成新方塊
        
        ; 同步 tmp 變數
        mov ax, cur_x
        mov tmp_x, ax
        mov ax, cur_y
        mov tmp_y, ax
        mov al, cur_rot
        mov tmp_rot, al
        
        ; 檢查新方塊是否死亡
        call CheckCollision
        .IF ax == 1
            mov game_state, 1
        .ELSE
            call DrawCurrent ; 立即畫出新方塊
        .ENDIF
    .ELSE
        ; 沒撞到，正式移動
        inc cur_y
        call DrawCurrent
    .ENDIF
    ret
DoDrop ENDP

InitGame PROC
    lea di, board
    mov cx, 200
    mov al, 0
    rep stosb
    mov game_state, 0
    call SpawnPiece
    ret
InitGame ENDP

SpawnPiece PROC
    mov ax, rand_seed
    add ax, 13
    mov dx, 7
    mul dx
    mov es, ax
    mov ax, 0040h
    mov es, ax
    mov di, 006Ch
    add ax, es:[di]
    mov rand_seed, ax
    
    xor dx, dx
    mov bx, 7
    div bx
    mov cur_piece, dl
    
    mov cur_rot, 0
    mov cur_x, 4
    mov cur_y, 0
    ret
SpawnPiece ENDP

TryRotate PROC
    mov ax, cur_x
    mov tmp_x, ax
    mov ax, cur_y
    mov tmp_y, ax
    
    mov al, cur_rot
    inc al
    and al, 3
    mov tmp_rot, al
    
    call CheckCollision
    .IF ax == 0
        mov al, tmp_rot
        mov cur_rot, al
    .ENDIF
    ret
TryRotate ENDP

TryLeft PROC
    mov ax, cur_x
    mov tmp_x, ax
    dec tmp_x
    mov ax, cur_y
    mov tmp_y, ax
    mov al, cur_rot
    mov tmp_rot, al
    
    call CheckCollision
    .IF ax == 0
        dec cur_x
    .ENDIF
    ret
TryLeft ENDP

TryRight PROC
    mov ax, cur_x
    mov tmp_x, ax
    inc tmp_x
    mov ax, cur_y
    mov tmp_y, ax
    mov al, cur_rot
    mov tmp_rot, al
    
    call CheckCollision
    .IF ax == 0
        inc cur_x
    .ENDIF
    ret
TryRight ENDP

CheckCollision PROC
    push bx
    push cx
    push dx
    push si
    push di
    
    ; 計算形狀資料指標
    xor ax, ax
    mov al, cur_piece
    mov cl, 5
    shl ax, cl
    mov bx, ax
    
    xor ax, ax
    mov al, tmp_rot
    mov cl, 3
    shl ax, cl
    
    lea si, [shapes + bx]
    add si, ax
    
    mov cx, 4
ColLoop:
    mov al, [si]
    cbw
    add ax, tmp_x
    mov bx, ax
    
    mov al, [si+1]
    cbw
    add ax, tmp_y
    mov di, ax
    add si, 2
    
    ; 邊界
    .IF bx < 0 || bx >= BOARD_W || di >= BOARD_H
        jmp IsHit
    .ENDIF
    
    ; 佔用
    .IF di >= 0
        mov ax, di
        push cx
        mov cl, 3
        shl ax, cl
        shl di, 1
        add ax, di
        pop cx
        add ax, bx
        
        push bx
        mov bx, ax
        mov al, board[bx]
        pop bx
        
        .IF al != 0
            jmp IsHit
        .ENDIF
    .ENDIF
    
    dec cx
    jnz ColLoop
    
    mov ax, 0
    jmp ColEnd
IsHit:
    mov ax, 1
ColEnd:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
CheckCollision ENDP

LockPiece PROC
    xor ax, ax
    mov al, cur_piece
    mov cl, 5
    shl ax, cl
    mov bx, ax
    
    xor ax, ax
    mov al, cur_rot
    mov cl, 3
    shl ax, cl
    
    lea si, [shapes + bx]
    add si, ax
    
    mov bl, cur_piece
    xor bh, bh
    mov al, piece_colors[bx]
    mov dl, al
    
    mov cx, 4
LockLoop:
    mov al, [si]
    cbw
    add ax, cur_x
    mov bx, ax
    
    mov al, [si+1]
    cbw
    add ax, cur_y
    mov di, ax
    add si, 2
    
    .IF di >= 0
        mov ax, di
        push cx
        mov cl, 3
        shl ax, cl
        shl di, 1
        add ax, di
        pop cx
        add ax, bx
        
        push bx
        mov bx, ax
        mov board[bx], dl
        pop bx
    .ENDIF
    dec cx
    jnz LockLoop
    ret
LockPiece ENDP

CheckLines PROC
    mov dx, 19
CheckLineLoop:
    .WHILE dx >= 0
        ; 檢查該行
        mov ax, dx
        push dx
        mov cl, 3
        shl ax, cl
        shl dx, 1
        add ax, dx
        pop dx
        mov si, ax
        
        mov cx, 10
        mov bl, 0       ; 0=Full
    ScanRow:
        cmp board[si], 0
        je NotFull
        inc si
        dec cx
        jnz ScanRow
        jmp FullFound
    NotFull:
        mov bl, 1
        
    FullFound:
        .IF bl == 0
            ; 消行
            push dx
            push es
            push ds
            pop es
            
            cld         ; 確保方向
        MoveLines:
            cmp dx, 0
            je ClearTop
            
            mov ax, dx
            push dx
            mov dx, 10
            mul dx
            pop dx
            mov di, ax
            add di, OFFSET board
            
            mov si, di
            sub si, 10
            mov cx, 10
            rep movsb
            
            dec dx
            jmp MoveLines
            
        ClearTop:
            lea di, board
            mov cx, 10
            mov al, 0
            rep stosb
            
            pop es
            pop dx
            
            call DrawBoardAll
            ; 重新檢查當前行
        .ELSE
            dec dx
        .ENDIF
    .ENDW
    ret
CheckLines ENDP

; =================================================================
; 繪圖子程式
; =================================================================

DrawBackground PROC
    mov ax, GAME_X
    sub ax, BLOCK_SIZE
    mov draw_px, ax
    mov cx, BOARD_H
    mov ax, GAME_Y
    mov draw_py, ax
    mov draw_color, 8
LW: push cx
    call DrawRect
    mov ax, draw_py
    add ax, BLOCK_SIZE
    mov draw_py, ax
    pop cx
    loop LW
    
    mov ax, BOARD_W
    mov cl, 4
    shl ax, cl
    mov bx, BOARD_W
    shl bx, 2
    add ax, bx
    add ax, GAME_X
    mov draw_px, ax
    
    mov cx, BOARD_H
    mov ax, GAME_Y
    mov draw_py, ax
    mov draw_color, 8
RW: push cx
    call DrawRect
    mov ax, draw_py
    add ax, BLOCK_SIZE
    mov draw_py, ax
    pop cx
    loop RW
    ret
DrawBackground ENDP

EraseCurrent PROC
    mov draw_color, 0
    call DrawPieceCommon
    ret
EraseCurrent ENDP

DrawCurrent PROC
    mov bl, cur_piece
    xor bh, bh
    mov al, piece_colors[bx]
    mov draw_color, al
    call DrawPieceCommon
    ret
DrawCurrent ENDP

DrawPieceCommon PROC
    xor ax, ax
    mov al, cur_piece
    mov cl, 5
    shl ax, cl
    mov bx, ax
    
    xor ax, ax
    mov al, cur_rot
    mov cl, 3
    shl ax, cl
    
    lea si, [shapes + bx]
    add si, ax
    
    mov cx, 4
DPLoop:
    mov al, [si]
    cbw
    add ax, cur_x
    mov bx, ax
    
    mov al, [si+1]
    cbw
    add ax, cur_y
    mov dx, ax
    add si, 2
    
    .IF dx >= 0
        ; ScreenX
        mov ax, bx
        push cx
        mov cl, 4
        shl ax, cl
        shl bx, 2
        add ax, bx
        add ax, GAME_X
        mov draw_px, ax
        
        ; ScreenY
        mov ax, dx
        mov cl, 4
        shl ax, cl
        shl dx, 2
        add ax, dx
        add ax, GAME_Y
        mov draw_py, ax
        pop cx
        
        call DrawRect
    .ENDIF
    dec cx
    jnz DPLoop
    ret
DrawPieceCommon ENDP

DrawBoardAll PROC
    mov dx, 0
DBY:
    mov bx, 0
DBX:
    mov ax, dx
    push dx
    push bx
    
    mov si, dx
    mov cl, 3
    shl si, cl
    shl dx, 1
    add si, dx
    pop bx
    add si, bx
    mov al, board[si]
    mov draw_color, al
    
    mov ax, bx
    mov cl, 4
    shl ax, cl
    shl bx, 2
    add ax, bx
    add ax, GAME_X
    mov draw_px, ax
    
    pop dx
    push dx
    mov ax, dx
    mov cl, 4
    shl ax, cl
    mov bx, dx
    shl bx, 2
    add ax, bx
    add ax, GAME_Y
    mov draw_py, ax
    
    call DrawRect
    
    pop dx
    inc bx
    cmp bx, BOARD_W
    jl DBX
    inc dx
    cmp dx, BOARD_H
    jl DBY
    ret
DrawBoardAll ENDP

DrawRect PROC
    push ax
    push bx
    push cx
    push dx
    
    mov dx, draw_py
    mov bx, 19
R_Loop:
    mov cx, draw_px
    push bx
    mov bx, 19
C_Loop:
    mov ah, 0Ch
    mov al, draw_color
    int 10h
    inc cx
    dec bx
    jnz C_Loop
    pop bx
    inc dx
    dec bx
    jnz R_Loop
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawRect ENDP

END main