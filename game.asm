INCLUDE macro.h  
INCLUDE colortable.h
INCLUDE gamelogic.h
INCLUDE time.h
INCLUDE math.h
INCLUDE draw.h
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

    Blocks STRUCT
        x      SWORD ?    
        y      SWORD ?
        id      DB    ?    ; 形狀 ID (0-6)
        rot   DB    ?    ; 旋轉 (0-3)
    Blocks ENDS

 
    ; ==========================================
    ; 核心變數
    ; ==========================================

    curBlock  Blocks <4, 0, 0, 0>   ; 當前控制的方塊
    nextBlock  Blocks <0, 0, 0, 0>   ; 下一個方塊
    tmpBlock  Blocks <0, 0, ?, 0>   ; 用於計算碰撞的暫存方塊

    last_timer  DW  0 ;紀錄上次時間
    time_limit  DW  9
    
    game_over   DB  0
    rand_seed   DW  1234h
    board       DB  200 DUP(0)

    draw_color  DB 0
    draw_px     DW 0
    draw_py     DW 0

    exit_game   DB 0 ; 退出遊戲變數

    Block_hit DB 0 ;方塊碰撞標誌
    
    ; 字串資料 ('$' 字串結尾符號)
    str_exit    DB 'EXIT GAME? (Y/N)$'
    str_over    DB 'GAME OVER!$'
    str_retry   DB 'Press Any Key$'
    str_score   DB 'Score: $'
    str_num     DB 5 DUP(0), '$'
    str_highest_score DB 'Highest Score: $'

    combo       DB 0
    score           DW 0
    last_score      DW 0
    highest_score   DW 0
    
    ; ==========================================
    ; 方塊形狀定義
    ; ==========================================
    include shape.h

    ; ==========================================
    ; 標題形狀定義
    ; ==========================================
    include title.h
    

    ; === 新增：遊戲說明文字 ===
    str_title   DB 'TETRIS GAME:$'
    str_Rotate   DB '< W > : Rotate$'
    str_LDR  DB '< A >: Left < S > : Drop < D > : Right$'
    str_quit   DB '< Q > : Quit$'  
    str_esc   DB 'Press < ESC > to Exit$'

.CODE
main PROC
    mov ax, @data
    mov ds, ax
    INIT_GRAPHICS_MODE
    ;==========================================
    ; 封面
    ;==========================================

    DRAW_WORD Word_1,  100,  50, YELLOW ; 俄
    DRAW_WORD Word_2,  190,  50, YELLOW  ; 羅
    DRAW_WORD Word_3,  280,  50, YELLOW ; 斯
    DRAW_WORD Word_4, 370,  50, YELLOW ; 方
    DRAW_WORD Word_5, 460,  50, YELLOW  ; 塊


    call infocontrols
    


    ;==========================================
    ; 開始遊戲
    ;==========================================

StartGame:
    INIT_GRAPHICS_MODE
    call InitGame
    call DrawBackground
    call DrawCurrent
    call DisplayScore

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
                .IF exit_game == 1     ; 回傳 1 表示確認退出
                    .BREAK
                .ENDIF
                
                call ClearpopupBox

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
                .IF game_over == 1
                    call HandleGameover
                    .IF exit_game == 1
                        .BREAK
                    .ELSE
                        jmp StartGame
                    .ENDIF
                .ENDIF
                CLOCK_COUNTER last_timer
            .ENDIF
            call ClearKB
        .ENDIF
        
        
        ; 2. 檢查重力
        CLOCK_COUNTER ax
        
        sub ax, last_timer
        .IF ax >= time_limit
            CLOCK_COUNTER last_timer
            
            call DoDrop
            .IF game_over == 1
                call HandleGameover
                .IF exit_game == 1
                    .BREAK
                .ELSE
                    jmp StartGame
                .ENDIF
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

ClearKB PROC
    push ax
    push es
    mov ax, 40h
    mov es, ax
    cli             ;修改指標前先關閉中斷，避免同時有按鍵進入造成衝突
    mov ax, es:[1Ch]; 讀取 Tail 指標 (偏移量 1Ch)
    mov es:[1Ah], ax; 將 Head 指標 設為與 Tail 相同
    sti             ; 恢復中斷
    pop es
    pop ax
    ret
ClearKB ENDP
HandleGameover PROC
    call ShowGameOver
    _PAUSE
    call HandleEsc
    ret 
HandleGameover ENDP    



HandleEsc PROC
    call DrawPopupBox
    SetCursor 13,33
    printstr str_exit,YELLOW
    
    ; 等待輸入
    .REPEAT
        mov ah, 00h
        int 16h
        
        .IF al == 'y' || al == 'Y' || al == 27
            mov exit_game, 1
            ret
        .ELSEIF al == 'n' || al == 'N' 
             mov exit_game, 0
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

    ; exit的框框
    DrawBox 220, 420, 180, 260, WHITE
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawPopupBox ENDP
ClearpopupBox PROC
    push bx
    push cx
    push dx
    ; 黑底
    mov draw_color, BLACK
    mov draw_px, 220
    mov draw_py, 180
    
    mov cx, 81
    mov bx, 220
    .WHILE cx > 0
        push cx
        mov cx, 201
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
    call RefreshScreen
    pop dx
    pop cx
    pop bx

    ret
ClearpopupBox   ENDP 
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
    

    ; 先準備嘗試下移
    CopyBlock curBlock,tmpBlock
    inc tmpBlock.y
    call CheckCollision
    .IF Block_hit == 1        ; 無法下移 → 落地
        call LockPiece
        call CheckLines
        call AddPoints
        call DisplayScore
        call SpawnPiece     ; 換新方塊

        ; 檢查新方塊是否一出來就撞
        CopyBlock curBlock,tmpBlock
        call CheckCollision

        .IF Block_hit == 1
            mov game_over, 1
        .ENDIF

    .ELSE               ; 可以下移
        call EraseCurrent
        inc curBlock.y
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
    mov score, 0
    mov time_limit, 9
    mov last_score, 0
    mov last_timer, 0
    call SpawnnextPiece
    call SpawnPiece
    
    DrawBox 20, 120, 100, 200, WHITE; 下一個方塊的白框
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


SpawnPiece PROC; 生成方塊
    mov al, nextBlock.id
    mov curBlock.id, al   ; 設定當前方塊種類
    mov curBlock.rot, 0      ; 初始旋轉狀態
    mov curBlock.x, 4        ; 初始水平位置
    mov curBlock.y, 0        ; 初始垂直位置
    call SpawnnextPiece
    call DrawnextPiece
    ret
SpawnPiece ENDP

SpawnnextPiece PROC
    call GetRandom
    mov nextBlock.id, al   ; 設定當前方塊種類
    ret
SpawnnextPiece ENDP   


DrawnextPiece PROC
    LOCAL temp: WORD
    push ax
    push bx
    push cx
    push dx
    push si
        
    
    ; 清除原本的方塊
    GetPieceStatus curBlock.id,0,si ; 取得形狀資料
    lea bx ,shapes
    add si,bx
    mov cx, 4
    .WHILE cx > 0
        mov al, [si]
        cbw      
        mov bx, ax
        
        mov al, [si+1]
        cbw
        mov dx, ax

        add si, 2
        
        mov temp, bx
        times_twenty  temp
        mov ax, temp
        add ax, 50
        mov draw_px, ax

        mov temp, dx
        times_twenty  temp
        mov ax, temp
        add ax, 130
        mov draw_py, ax

        DrawBlock draw_px, draw_py, BLOCK_SIZE - 1,black 
        
        dec cx  
    .ENDW

    ; 畫出下一個方塊
    mov bl, nextBlock.id
    xor bh, bh
    mov al, piece_colors[bx]
    mov draw_color, al
    
    GetPieceStatus nextBlock.id,0,si
    lea bx ,shapes
    add si,bx
    mov cx, 4
    .WHILE cx > 0
        mov al, [si]
        cbw      
        mov bx, ax
        
        mov al, [si+1]
        cbw
        mov dx, ax

        add si, 2
        
        mov temp, bx
        times_twenty  temp
        mov ax, temp
        add ax, 50
        mov draw_px, ax

        mov temp, dx
        times_twenty  temp
        mov ax, temp
        add ax, 130
        mov draw_py, ax

        DrawBlock draw_px, draw_py, BLOCK_SIZE - 1,draw_color
        
        dec cx  
    .ENDW

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawnextPiece ENDP
TryRotate PROC
    mov ax, curBlock.x
    mov tmpBlock.x, ax
    mov ax, curBlock.y
    mov tmpBlock.y, ax
    
    mov al, curBlock.rot 
    inc al
    and al, 3
    mov tmpBlock.rot, al
    
    call CheckCollision

    .IF Block_hit == 0
        mov al, tmpBlock.rot
        mov curBlock.rot, al
    .ENDIF
    ret
TryRotate ENDP

TryLeft PROC
    CopyBlock curBlock,tmpBlock
    dec tmpBlock.x
    call CheckCollision
    .IF Block_hit == 0
        dec curBlock.x
    .ENDIF
    ret
TryLeft ENDP

TryRight PROC
    CopyBlock curBlock,tmpBlock
    inc tmpBlock.x
    call CheckCollision
    .IF Block_hit == 0
        inc curBlock.x
    .ENDIF
    ret
TryRight ENDP

CheckCollision PROC
    push bx            ; 保存用到的暫存器
    push cx
    push dx
    push si
    push di
    
    GetPieceStatus curBlock.id,tmpBlock.rot,si ; 取得形狀資料
    push bx
    lea bx ,shapes 
    add si,bx
    pop bx

    mov cx, 4
    .WHILE cx > 0
         
        ; ========== X 座標：==========
        mov al, [si]    ; 讀取 x（相對座標）
        cbw             ; sign-extend → ax 
        add ax, tmpBlock.x   ; ax = ax + tmp_x
        mov bx, ax      ; bx = 世界座標 X
        
        ; ========== Y 座標： ==========
        mov al, [si+1]  ; 讀取 y（相對座標）
        cbw
        add ax, tmpBlock.y   ; ax = ax + tmp_y
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
    mov Block_hit, 0
    jmp CollisionEnd


CollisionHit:
    mov Block_hit, 1

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
    GetPieceStatus curBlock.id,curBlock.rot,si
    lea bx, shapes 
    add si, bx
    
    ; 2. 取得當前方塊的顏色
    mov bl, curBlock.id
    xor bh, bh
    mov al, piece_colors[bx]
    mov dl, al      ; dl = 顏色代碼
    
    ; 3. 迴圈處理 4 個組成方格
    mov cx, 4
    .WHILE cx > 0
        ; --- 計算 X ---
        mov al, [si]
        cbw
        add ax, curBlock.x
        mov bx, ax  ; BX = 世界座標 X
        
        ; --- 計算 Y ---
        mov al, [si+1]
        cbw
        add ax, curBlock.y
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
            inc combo
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
        DrawBlock draw_px, draw_py, BLOCK_SIZE - 1,draw_color
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
    mov draw_color, DARK_GRAY
    
    .WHILE cx > 0
        push cx
        DrawBlock draw_px, draw_py, BLOCK_SIZE - 1,draw_color
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
    mov bl, curBlock.id
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

    GetPieceStatus curBlock.id,curBlock.rot,si
    push bx
    lea bx ,shapes
    add si,bx
    pop bx
    
    mov cx, 4
    .WHILE cx > 0
        mov al, [si]
        cbw
        add ax, curBlock.x
        mov bx, ax
        
        mov al, [si+1]
        cbw
        add ax, curBlock.y
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
            
            DrawBlock draw_px, draw_py, BLOCK_SIZE - 1,draw_color
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

            DrawBlock draw_px, draw_py, BLOCK_SIZE - 1,draw_color
        
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

InfoControls PROC
    SetCursor 20,12
    printstr str_title,LIGHT_CYAN

    SetCursor 22,24
    printstr str_Rotate,RED

    SetCursor 23,12
    printstr str_LDR,LIGHT_BLUE

    
    SetCursor 24,24
    printstr str_quit,BROWN

    SetCursor 26,12
    printstr str_esc,LIGHT_MAGENTA

    SetCursor 28,12
    printstr str_retry,YELLOW

    ; 需要等待的輸入
    _PAUSE
    ret
InfoControls ENDP

DisplayScore PROC
    SetCursor 0, 0
    printstr str_score,WHITE ;'Score:'
    printnum score, WHITE, str_num
    ret
DisplayScore ENDP

AddPoints PROC
    .IF combo == 1
        add score, 50
    .ELSEIF combo == 2
        add score, 200    
    .ELSEIF combo == 3
        add score, 400
    .ELSEIF combo == 4
        add score, 800
    .ENDIF
    mov combo, 0
    ;時間限制調整
    mov ax, last_score      ;ax算分數增加差超過50要加速 & 進入real life func
    add ax, 1000
    .IF score >= ax
        .IF time_limit >= 3
            sub time_limit, 1
            add last_score, 1000
        .ENDIF
    .ENDIF
    ret
AddPoints ENDP
END main
