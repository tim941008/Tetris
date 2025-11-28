INCLUDE macro.h

.MODEL SMALL
.STACK 200h


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

    ; 計時器 (9 ticks = 0.5秒)
    last_timer  DW  0
    time_limit  DW  9
    
    game_over   DB  0
    rand_seed   DW  1234h

    ; 遊戲板
    board       DB  200 DUP(0)

    ; 繪圖暫存
    draw_color  DB 0
    draw_px     DW 0
    draw_py     DW 0
    
    ; 字串
    str_exit    DB 'EXIT GAME? (Y/N)$'
    str_over    DB 'GAME OVER!$'
    str_retry   DB 'Press Any Key$'

    ; --- 方塊形狀資料 (順時針) ---
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
    ; 3: O (固定)
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

    INIT_GRAPHICS_MODE

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

MainLoop:
    ; 1. 檢查輸入
    mov ah, 01h
    int 16h
    jz CheckTimer
    
    ; 讀取按鍵
    mov ah, 00h
    int 16h
    
    ; --- 按鍵判斷 (純組合語言邏輯) ---
    cmp al, 27      ; ESC
    je HandleEsc
    cmp al, 'q'
    je ExitApp
    cmp al, 'w'
    je KeyW
    cmp al, 'W'
    je KeyW
    cmp al, 'a'
    je KeyA
    cmp al, 'A'
    je KeyA
    cmp al, 'd'
    je KeyD
    cmp al, 'D'
    je KeyD
    cmp al, 's'
    je KeyS
    cmp al, 'S'
    je KeyS
    
    jmp CheckTimer

HandleEsc:
    call AskExit        ; 呼叫詢問視窗
    cmp al, 1           ; 檢查回傳值: 1=退出
    je ExitApp
    
    ; 若 AL=0 (繼續)，則恢復畫面
    call RefreshScreen
    ; 重置計時器，避免暫停期間時間累積
    mov ax, 0040h
    mov es, ax
    mov di, 006Ch
    mov ax, es:[di]
    mov last_timer, ax
    jmp MainLoop

KeyW:
    call EraseCurrent
    call TryRotate
    call DrawCurrent
    jmp CheckTimer
KeyA:
    call EraseCurrent
    call TryLeft
    call DrawCurrent
    jmp CheckTimer
KeyD:
    call EraseCurrent
    call TryRight
    call DrawCurrent
    jmp CheckTimer
KeyS:
    call DoDrop
    jmp MainLoop

CheckTimer:
    ; 2. 檢查重力
    mov ax, 0040h
    mov es, ax
    mov di, 006Ch
    mov ax, es:[di]
    
    sub ax, last_timer
    cmp ax, time_limit
    jl MainLoop
    
    ; 時間到
    mov ax, es:[di]
    mov last_timer, ax
    
    call DoDrop
    
    cmp game_over, 1
    je GameOver
    
    jmp MainLoop

GameOver:
    call ShowGameOver
    jmp StartGame

ExitApp:
    EXIT_TEXT_MODE
    mov ax, 4c00h
    int 21h
main ENDP

; =================================================================
; UI 子程式
; =================================================================

AskExit PROC
    ; 畫視窗
    call DrawPopupBox
    
    ; 顯示文字
    mov ah, 02h
    mov bh, 0
    mov dh, 14      ; Row
    mov dl, 32      ; Col
    int 10h
    
    mov ah, 09h
    lea dx, str_exit
    int 21h
    
WaitKey_Ask:
    mov ah, 00h
    int 16h
    
    cmp al, 'y'
    je ReturnYes
    cmp al, 'Y'
    je ReturnYes
    
    cmp al, 'n'
    je ReturnNo
    cmp al, 'N'
    je ReturnNo
    cmp al, 27      ; ESC 也可以取消
    je ReturnNo
    
    jmp WaitKey_Ask ; 其他按鍵忽略，繼續等

ReturnYes:
    mov al, 1
    ret
ReturnNo:
    mov al, 0
    ret
AskExit ENDP

ShowGameOver PROC
    call DrawPopupBox
    
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
    
    mov ah, 00h
    int 16h
    ret
ShowGameOver ENDP

DrawPopupBox PROC
    push ax
    push bx
    push cx
    push dx
    
    ; 黑底
    mov draw_color, 0
    mov draw_px, 220
    mov draw_py, 180
    
    mov cx, 80
BoxY:
    push cx
    mov cx, 200
    mov bx, draw_px
BoxX:
    push cx
    push bx
    DRAW_PIXEL bx, draw_py, draw_color
    pop bx
    pop cx
    inc bx
    loop BoxX
    inc draw_py
    pop cx
    loop BoxY
    
    ; 白框
    mov draw_color, 15
    
    mov cx, 200
    mov draw_px, 220
    mov draw_py, 180
L1: call PlotPixel
    inc draw_px
    loop L1
    
    mov cx, 200
    mov draw_px, 220
    mov draw_py, 260
L2: call PlotPixel
    inc draw_px
    loop L2
    
    mov cx, 80
    mov draw_px, 220
    mov draw_py, 180
L3: call PlotPixel
    inc draw_py
    loop L3
    
    mov cx, 80
    mov draw_px, 420
    mov draw_py, 180
L4: call PlotPixel
    inc draw_py
    loop L4
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawPopupBox ENDP

RefreshScreen PROC
    call DrawBackground
    call DrawBoardAll
    call DrawCurrent
    ret
RefreshScreen ENDP

PlotPixel PROC
    DRAW_PIXEL draw_px, draw_py, draw_color
    ret
PlotPixel ENDP

; =================================================================
; 遊戲邏輯 (保持 8086 嚴格規範)
; =================================================================

DoDrop PROC
    call EraseCurrent
    
    mov ax, cur_x
    mov tmp_x, ax
    mov ax, cur_y
    mov tmp_y, ax
    inc tmp_y
    
    mov al, cur_rot
    mov tmp_rot, al
    
    call CheckCollision
    cmp ax, 1
    je Landed
    
    inc cur_y
    call DrawCurrent
    ret

Landed:
    call DrawCurrent
    call LockPiece
    call CheckLines
    call SpawnPiece
    
    ; 同步 tmp
    mov ax, cur_x
    mov tmp_x, ax
    mov ax, cur_y
    mov tmp_y, ax
    mov al, cur_rot
    mov tmp_rot, al
    
    ; 畫出新方塊
    call DrawCurrent
    
    ; 檢查是否一出生就死
    call CheckCollision
    cmp ax, 1
    jne DropEnd
    mov game_over, 1
DropEnd:
    ret
DoDrop ENDP

InitGame PROC
    lea di, board
    mov cx, 200
    mov al, 0
    rep stosb
    mov game_over, 0
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
    cmp ax, 0
    jne RotEnd
    mov al, tmp_rot
    mov cur_rot, al
RotEnd:
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
    cmp ax, 0
    jne LeftEnd
    dec cur_x
LeftEnd:
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
    cmp ax, 0
    jne RightEnd
    inc cur_x
RightEnd:
    ret
TryRight ENDP

CheckCollision PROC
    push bx
    push cx
    push dx
    push si
    push di
    
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
    
    cmp bx, 0
    jl IsHit
    cmp bx, BOARD_W
    jge IsHit
    cmp di, BOARD_H
    jge IsHit
    
    cmp di, 0
    jl NextCol
    
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
    
    cmp al, 0
    jne IsHit

NextCol:
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
    push ax
    push bx
    push cx
    push dx
    push si
    push di

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
    
    cmp di, 0
    jl SkipLock
    
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
SkipLock:
    dec cx
    jnz LockLoop
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
LockPiece ENDP

CheckLines PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov dx, 19
CheckLineLoop:
    cmp dx, 0
    jl CheckEnd
    
    mov ax, dx
    push dx
    mov cl, 3
    shl ax, cl
    shl dx, 1
    add ax, dx
    pop dx
    mov si, ax
    
    mov cx, 10
    mov bl, 0
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
    cmp bl, 0
    jne NextRow
    
    push dx
    push es
    push ds
    pop es
    
    cld
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
    ; 不減少 DX，重查當前行
    jmp CheckLineLoop
    
NextRow:
    dec dx
    jmp CheckLineLoop
CheckEnd:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
CheckLines ENDP

DrawBackground PROC
    push ax
    push bx
    push cx
    push dx

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
    mov cl, 2
    shl bx, cl
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
    
    pop dx
    pop cx
    pop bx
    pop ax
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
    push ax
    push bx
    push cx
    push dx
    push si
    push di

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
    
    cmp dx, 0
    jl SkipDP
    
    mov ax, bx
    push cx
    mov cl, 4
    shl ax, cl
    mov cl, 2
    shl bx, cl
    pop cx
    add ax, bx
    add ax, GAME_X
    mov draw_px, ax
    
    mov ax, dx
    push cx
    mov cl, 4
    shl ax, cl
    mov cl, 2
    shl dx, cl
    pop cx
    add ax, dx
    add ax, GAME_Y
    mov draw_py, ax
    
    call DrawRect
SkipDP:
    dec cx
    jnz DPLoop
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawPieceCommon ENDP

DrawBoardAll PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

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
    push cx
    mov cl, 4
    shl ax, cl
    mov cl, 2
    shl bx, cl
    pop cx
    add ax, bx
    add ax, GAME_X
    mov draw_px, ax
    
    pop dx
    push dx
    mov ax, dx
    push cx
    mov cl, 4
    shl ax, cl
    mov cl, 2
    shl dx, cl
    pop cx
    add ax, dx
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
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
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
    DRAW_PIXEL cx, dx, draw_color
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