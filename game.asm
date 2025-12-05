INCLUDE macro.h  
INCLUDE colortable.h
INCLUDE gamelogic.h
INCLUDE time.h
INCLUDE math.h

.MODEL SMALL
.STACK 2000h

.DATA
    ; ==========================================
    ; 畫面設定常數
    ; ==========================================
    BLOCK_SIZE  EQU 20 ;每個方塊的像素大小
    GAME_X      EQU 220 ;遊戲區域左上角 X 座標
    GAME_Y      EQU 40 ;遊戲區域左上角 Y 座標
    BOARD_W     EQU 10 ;遊戲區域寬度 (以方塊數量計)
    BOARD_H     EQU 20 ;遊戲區域高度 (以方塊數量計)


    ; ==========================================
    ; 核心變數
    ; ==========================================
    cur_x       SWORD 4
    cur_y       SWORD 0
    cur_piece   DB  0
    cur_rot     DB  0

    tmp_x       SWORD 0
    tmp_y       SWORD 0
    tmp_rot     DB  0

    last_timer  DW  0 ;紀錄上次時間
    time_limit  DW  9
    
    game_over   DB  0
    rand_seed   DW  1234h
    board       DB  200 DUP(0)

    draw_color  DB 0
    draw_px     DW 0
    draw_py     DW 0
    
    ; 字串資料 ('$' 字串結尾符號)
    str_exit    DB 'EXIT GAME? (Y/N)$'
    str_over    DB 'GAME OVER!$'
    str_retry   DB 'Press Any Key$'

    ; ==========================================
    ; 方塊形狀定義
    ; ==========================================
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

    piece_colors DB LIGHT_CYAN, LIGHT_BLUE, BROWN, YELLOW, LIGHT_GREEN, LIGHT_MAGENTA, LIGHT_RED

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
    CLOCK_COUNTER last_timer

    ; 主迴圈
    .WHILE 1
        ; 1. 檢查鍵盤輸入
        mov ah, 01h
        int 16h
        
        .IF !ZERO?
            mov ah, 00h
            int 16h
            
            .IF al == 27        ; ESC
                call HandleEsc
                .IF al == 1     ; 回傳 1 表示確認退出
                    .BREAK
                .ENDIF
                
                call RefreshScreen
                CLOCK_COUNTER last_timer 
                
                
            .ELSEIF al == 'q'
                .BREAK
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
        
        ; 2. 檢查重力
        CLOCK_COUNTER ax
        
        sub ax, last_timer
        .IF ax >= time_limit
            CLOCK_COUNTER last_timer
            
            call DoDrop
    
            .IF game_over == 1
                call ShowGameOver
                _PAUSE
                jmp StartGame
            .ENDIF
        .ENDIF
    .ENDW

ExitApp:
    EXIT_TEXT_MODE
    mov ax, 4c00h
    int 21h
main ENDP

; =================================================================
; UI 子程式
; =================================================================


HandleEsc PROC
    call DrawPopupBox
    SetCursor 13,33
    printstr str_exit,YELLOW
    
    ; 等待輸入
    .REPEAT
        mov ah, 00h
        int 16h
        
        .IF al == 'y' || al == 'Y' || al == 27
            mov al, 1
            ret
        .ELSEIF al == 'n' || al == 'N' 
            mov al, 0
            ret
        .ENDIF
    .UNTIL 0
HandleEsc ENDP

ShowGameOver PROC

    call DrawPopupBox
    
    ; 顯示 "GAME OVER" 
    SetCursor 13,35
    printstr str_over,LIGHT_RED
    
    SetCursor 15,33
    printstr str_retry,LIGHT_BLUE

    _PAUSE; 等待按鍵
    ret
ShowGameOver ENDP

DrawPopupBox PROC
    push ax
    push bx
    push cx
    push dx
    
    ; 黑底
    mov draw_color, BLACK
    mov draw_px, 220
    mov draw_py, 180
    
    mov cx, 80
    mov bx, 220
    .WHILE cx > 0
        push cx
        mov cx, 200
        mov draw_px, bx
        .WHILE cx > 0
            DRAW_PIXEL draw_px, draw_py, draw_color
            inc draw_px
            dec cx
        .ENDW
        inc draw_py
        pop cx
        dec cx
    .ENDW
    
    ; 白框
    mov draw_color, WHITE 
    ; 上框
    mov cx, 200
    mov draw_px, 220
    mov draw_py, 180
    .WHILE cx > 0
        DRAW_PIXEL draw_px, draw_py, draw_color
        inc draw_px
        dec cx
    .ENDW
    
    ; 下框
    mov cx, 200
    mov draw_px, 220
    mov draw_py, 260
    .WHILE cx > 0
        DRAW_PIXEL draw_px, draw_py, draw_color
        inc draw_px
        dec cx
    .ENDW
    
    ; 左框
    mov cx, 80
    mov draw_px, 220
    mov draw_py, 180
    .WHILE cx > 0
        DRAW_PIXEL draw_px, draw_py, draw_color
        inc draw_py
        dec cx
    .ENDW
    
    ; 右框
    mov cx, 80
    mov draw_px, 420
    mov draw_py, 180
    .WHILE cx > 0
        DRAW_PIXEL draw_px, draw_py, draw_color
        inc draw_py
        dec cx
    .ENDW
    
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

; =================================================================
; 遊戲邏輯
; =================================================================

DoDrop PROC
    call EraseCurrent

    ; 先準備嘗試下移
    mov ax, cur_x
    mov tmp_x, ax
    mov ax, cur_y
    mov tmp_y, ax
    inc tmp_y
    mov al, cur_rot
    mov tmp_rot, al

    call CheckCollision
    .IF ax == 1        ; 無法下移 → 落地
        call DrawCurrent    ; 畫回原來的位置
        call LockPiece
        call CheckLines
        call SpawnPiece     ; 換新方塊

        ; 檢查新方塊是否一出來就撞
        mov ax, cur_x
        mov tmp_x, ax
        mov ax, cur_y
        mov tmp_y, ax
        mov al, cur_rot
        mov tmp_rot, al
        call CheckCollision

        .IF ax == 1
            mov game_over, 1
        .ENDIF

    .ELSE               ; 可以下移
        inc cur_y
        call DrawCurrent
    .ENDIF

    ret
DoDrop ENDP


InitGame PROC
    mov ax, ds
    mov es, ax
    lea di, board
    mov cx, 200
    mov al, 0
    rep stosb
    mov game_over, 0
    call SpawnPiece
    ret
InitGame ENDP


GetRandom PROC ; 產生隨機數 0~6，使用 BIOS 計時器低位
    push bx
    push cx
    push dx
    CLOCK_COUNTER ax
    add ax, rand_seed
    mov rand_seed, ax
    xor dx, dx ;清0
    mov bx,7
    div bx           
    mov al, dl        ; 餘數在dx
    pop dx
    pop cx
    pop bx
    ret                ; 返回 AL = 0~6
GetRandom ENDP

;----------------------------------------
; 生成方塊
;----------------------------------------
SpawnPiece PROC

    call GetRandom
    mov cur_piece, al   ; 設定當前方塊種類
    mov cur_rot, 0      ; 初始旋轉狀態
    mov cur_x, 4        ; 初始水平位置
    mov cur_y, 0        ; 初始垂直位置
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
    push bx            ; 保存用到的暫存器
    push cx
    push dx
    push si
    push di
    
    GetPieceStatus cur_piece,tmp_rot,si ; 取得形狀資料
    push bx
    lea bx ,shapes 
    add si,bx
    pop bx

    mov cx, 4
    .WHILE cx > 0
         
        ; ========== X 座標：==========
        mov al, [si]    ; 讀取 x（相對座標）
        cbw             ; sign-extend → ax 
        add ax, tmp_x   ; ax = ax + tmp_x
        mov bx, ax      ; bx = 世界座標 X
        
        ; ========== Y 座標： ==========
        mov al, [si+1]  ; 讀取 y（相對座標）
        cbw
        add ax, tmp_y   ; ax = ax + tmp_y
        mov di, ax      ; di = 世界座標 Y
        
        add si, 2       ; 前進到下一組 
        
        ; ----------------------------------------------------
        ; 1) 邊界檢查（X < 0、X >= BOARD_W、Y >= BOARD_H）
        ;    → 直接判斷碰撞
        ; ----------------------------------------------------
        .IF (SWORD PTR bx < 0) || (bx >= BOARD_W) || (SWORD PTR di >= BOARD_H)
            jmp CollisionHit
        .ENDIF
        
        ; ----------------------------------------------------
        ; 2) Y < 0 的情況 → 方塊還在上方未完全出現
        ;    → 不需要做 board[] 檢查，跳過即可
        ; ----------------------------------------------------
        .IF (SWORD PTR di >= 0)
            mov ax, di       ; ax = y

            push si ; 保存 si
            GetBoardIndex bx,ax,si; bx = y*10 + x
            mov al, board[si]  ; 讀取該格子是否有方塊
            pop si
            ; ------------------------------------------------
            ; board[index] != 0 → 表示那格已有固定方塊 → 碰撞
            ; ------------------------------------------------
            .IF al != 0
                jmp CollisionHit
            .ENDIF
        .ENDIF
        
        dec cx              ; 檢查下一個小方格
    .ENDW
    
    ; ============================================
    ; 完整四格皆通過 → 無碰撞
    ; ============================================
    mov ax, 0
    jmp CollisionEnd

; ================================================
; 遇到碰撞點 → 回傳 AX=1
; ================================================
CollisionHit:
    mov ax, 1

CollisionEnd:
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

    ; 1. 計算形狀資料的起始位置
    GetPieceStatus cur_piece,cur_rot,si
    lea bx, shapes 
    add si, bx
    
    ; 2. 取得當前方塊的顏色
    mov bl, cur_piece
    xor bh, bh
    mov al, piece_colors[bx]
    mov dl, al      ; dl = 顏色代碼
    
    ; 3. 迴圈處理 4 個組成方格
    mov cx, 4
    .WHILE cx > 0
        ; --- 計算 X ---
        mov al, [si]
        cbw
        add ax, cur_x
        mov bx, ax  ; BX = 世界座標 X
        
        ; --- 計算 Y ---
        mov al, [si+1]
        cbw
        add ax, cur_y
        mov di, ax  ; DI = 世界座標 Y
        add si, 2
        
        ; --- 鎖定方塊 ---
        .IF (SWORD PTR di >= 0)
            push si             
            GetBoardIndex bx,di,si ; 計算 Index，結果存回 si
            mov board[si], dl   ; 將顏色寫入版面記憶體
            pop si              
        .ENDIF
        dec cx
    .ENDW
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
LockPiece ENDP


CheckLines PROC
    LOCAL temp: WORD
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov dx, 19
    .WHILE (SWORD PTR dx >= 0) ; 從底往上檢查每一行

        GetBoardIndex 0,dx,si ; 計算該行起始 index，結果在 SI

        mov cx, 10 
        mov bl, 0

        .WHILE cx > 0
            .IF board[si] == 0
                mov bl, 1
                .BREAK
            .ENDIF
            inc si
            dec cx
        .ENDW

        .IF bl == 0 ; 找到一整行都滿的
            push dx        
            mov ax, ds
            mov es, ax
            cld ; 確保方向旗標為遞增

            .WHILE dx > 0
                mov temp, dx
                times_ten temp
                mov di, temp
                add di, OFFSET board

                mov si, di
                sub si, 10

                mov cx, 10
                rep movsb
                dec dx
            .ENDW

            lea di, board 
            mov cx, 10
            mov al, 0
            rep stosb

            ; 還原暫存器dx
            pop dx

            call DrawBoardAll
        .ELSE
            dec dx
        .ENDIF
    .ENDW

    call DrawBoardAll

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

    ; 左牆
    mov ax, GAME_X
    sub ax, BLOCK_SIZE
    mov draw_px, ax
    mov cx, BOARD_H
    mov ax, GAME_Y
    mov draw_py, ax
    mov draw_color, DARK_GRAY
    
    .WHILE cx > 0
        push cx
        call DrawRect
        mov ax, draw_py
        add ax, BLOCK_SIZE
        mov draw_py, ax
        pop cx
        dec cx
    .ENDW
    
    ; 右牆
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
    
    .WHILE cx > 0
        push cx
        call DrawRect
        mov ax, draw_py
        add ax, BLOCK_SIZE
        mov draw_py, ax
        pop cx
        dec cx
    .ENDW
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawBackground ENDP

EraseCurrent PROC
    mov draw_color, BLACK
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
    LOCAL temp: WORD
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    GetPieceStatus cur_piece,cur_rot,si
    push bx
    lea bx ,shapes
    add si,bx
    pop bx
    
    mov cx, 4
    .WHILE cx > 0
        mov al, [si]
        cbw
        add ax, cur_x
        mov bx, ax
        
        mov al, [si+1]
        cbw
        add ax, cur_y
        mov dx, ax
        add si, 2
        
        .IF (SWORD PTR dx >= 0)
            mov temp, bx
            times_twenty temp
            mov ax, temp
            add ax, GAME_X
            mov draw_px, ax
            
            mov temp, dx
            times_twenty temp
            mov ax, temp
            add ax, GAME_Y
            mov draw_py, ax
            
            call DrawRect
        .ENDIF
        dec cx
    .ENDW
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawPieceCommon ENDP

DrawBoardAll PROC

    LOCAL temp: WORD
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov dx, 0
    .WHILE dx < BOARD_H
        mov bx, 0
        .WHILE bx < BOARD_W
            
            GetBoardIndex bx,dx,si ; 計算 Index

            mov al, board[si]   ; 使用 SI 作為陣列索引
            mov draw_color, al
    
            mov temp,bx
            times_twenty  temp
            mov ax, temp
            add ax , GAME_X
            mov draw_px, ax

            mov temp,dx
            times_twenty  temp
            mov ax, temp
            add ax, GAME_Y
            mov draw_py, ax
            
            call DrawRect
            
           
            inc bx
        .ENDW
        inc dx
    .ENDW

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
    .WHILE bx > 0
        mov cx, draw_px
        push bx
        mov bx, 19
        .WHILE bx > 0
            DRAW_PIXEL cx, dx, draw_color
            inc cx
            dec bx
        .ENDW
        pop bx
        inc dx
        dec bx
    .ENDW
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawRect ENDP

END main
