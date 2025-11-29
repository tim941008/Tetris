INCLUDE macro.h ; 包含外部定義的巨集 (假設包含 INIT_GRAPHICS_MODE 和 DRAW_PIXEL)

.MODEL SMALL
.STACK 200h

.DATA
    ; ==========================================
    ; 畫面設定常數
    ; ==========================================
    BLOCK_SIZE  EQU 20      ; 每個方格的像素寬度/高度
    GAME_X      EQU 220     ; 遊戲區在螢幕上的左上角 X 座標
    GAME_Y      EQU 40      ; 遊戲區在螢幕上的左上角 Y 座標
    BOARD_W     EQU 10      ; 遊戲板寬度 (10格)
    BOARD_H     EQU 20      ; 遊戲板高度 (20格)

    ; ==========================================
    ; 核心變數
    ; ==========================================
    ; 當前掉落中的方塊資訊
    cur_x       DW  4       ; 當前 X 格座標 (0-9)
    cur_y       DW  0       ; 當前 Y 格座標 (0-19)
    cur_piece   DB  0       ; 當前方塊類型 (0-6，對應 shapes)
    cur_rot     DB  0       ; 當前旋轉狀態 (0-3)

    ; 暫存變數 (用於移動/旋轉前的碰撞測試)
    tmp_x       DW  0
    tmp_y       DW  0
    tmp_rot     DB  0

    ; 計時器控制 (利用 BIOS Timer 0040h:006Ch)
    last_timer  DW  0       ; 上一次記錄的時間點
    time_limit  DW  9       ; 下降速度 (9 ticks 約等於 0.5秒，因為 18.2 ticks = 1秒)
    
    game_over   DB  0       ; 遊戲結束旗標 (0:進行中, 1:結束)
    rand_seed   DW  1234h   ; 隨機數種子

    ; 遊戲板記憶體陣列 (10寬 x 20高 = 200 bytes)
    ; 0 表示空，非 0 表示有方塊(顏色代碼)
    board       DB  200 DUP(0)

    ; 繪圖暫存變數
    draw_color  DB 0        ; 當前繪畫顏色
    draw_px     DW 0        ; 螢幕像素 X
    draw_py     DW 0        ; 螢幕像素 Y
    
    ; 字串資料 ('$' 為 DOS 字串結尾符號)
    str_exit    DB 'EXIT GAME? (Y/N)$'
    str_over    DB 'GAME OVER!$'
    str_retry   DB 'Press Any Key$'

    ; ==========================================
    ; 方塊形狀定義 (Offset Table)
    ; ==========================================
    ; 每個方塊由 4 個點組成，每個點有 (x, y) 偏移量
    ; 每個方塊有 4 種旋轉狀態，所以每個方塊佔用 4*2(x,y)*4(rot) = 32 bytes
    shapes      LABEL BYTE
    ; 0: I 形狀
    DB -1,0,  0,0,  1,0,  2,0   ; 旋轉 0
    DB  0,-1, 0,0,  0,1,  0,2   ; 旋轉 1
    DB -1,0,  0,0,  1,0,  2,0   ; 旋轉 2 (重複)
    DB  0,-1, 0,0,  0,1,  0,2   ; 旋轉 3 (重複)
    ; 1: J 形狀
    DB -1,-1, -1,0,  0,0,  1,0
    DB  0,-1,  1,-1, 0,0,  0,1
    DB -1,0,   0,0,  1,0,  1,1
    DB  0,-1,  0,0, -1,1,  0,1
    ; 2: L 形狀
    DB  1,-1, -1,0,  0,0,  1,0
    DB  0,-1,  0,0,  0,1,  1,1
    DB -1,0,   0,0,  1,0, -1,1
    DB -1,-1,  0,-1, 0,0,  0,1
    ; 3: O 形狀 (旋轉不變)
    DB  0,0,  1,0,  0,1,  1,1
    DB  0,0,  1,0,  0,1,  1,1
    DB  0,0,  1,0,  0,1,  1,1
    DB  0,0,  1,0,  0,1,  1,1
    ; 4: S 形狀
    DB  0,0,  1,0, -1,1,  0,1
    DB  0,-1, 0,0,  1,0,  1,1
    DB  0,0,  1,0, -1,1,  0,1
    DB  0,-1, 0,0,  1,0,  1,1
    ; 5: T 形狀
    DB  0,-1, -1,0,  0,0,  1,0
    DB  0,-1,  0,0,  1,0,  0,1
    DB -1,0,   0,0,  1,0,  0,1
    DB  0,-1, -1,0,  0,0,  0,1
    ; 6: Z 形狀
    DB -1,0,  0,0,  0,1,  1,1
    DB  1,-1, 0,0,  1,0,  0,1
    DB -1,0,  0,0,  0,1,  1,1
    DB  1,-1, 0,0,  1,0,  0,1

    ; 對應每個方塊類型的顏色代碼 (DOS VGA 256色或16色模式)
    piece_colors DB 11, 9, 6, 14, 10, 13, 12

.CODE
main PROC
    mov ax, @data
    mov ds, ax

    ; 初始化繪圖模式 (通常是 INT 10h, AX=0013h 進入 320x200 VGA)
    INIT_GRAPHICS_MODE

StartGame:
    call InitGame           ; 初始化變數與清空版面
    call DrawBackground     ; 繪製背景邊框
    call DrawCurrent        ; 繪製第一個方塊
    
    ; 讀取系統時間作為初始 Timer
    mov ax, 0040h           ; ES 指向 BIOS Data Area
    mov es, ax
    mov di, 006Ch           ; 006Ch 存放系統 Timer Tick 計數
    mov ax, es:[di]
    mov last_timer, ax

MainLoop:
    ; --------------------------------------
    ; 1. 檢查鍵盤輸入
    ; --------------------------------------
    mov ah, 01h             ; 檢查鍵盤緩衝區是否有字元
    int 16h
    jz CheckTimer           ; 若無輸入，跳轉去檢查時間(重力)
    
    ; 有輸入，讀取該按鍵
    mov ah, 00h
    int 16h
    
    ; --- 按鍵判斷邏輯 ---
    cmp al, 27      ; ESC 鍵
    je HandleEsc
    cmp al, 'q'     ; q 鍵 (離開)
    je ExitApp
    cmp al, 'w'     ; w 鍵 (旋轉)
    je KeyW
    cmp al, 'W'
    je KeyW
    cmp al, 'a'     ; a 鍵 (左移)
    je KeyA
    cmp al, 'A'
    je KeyA
    cmp al, 'd'     ; d 鍵 (右移)
    je KeyD
    cmp al, 'D'
    je KeyD
    cmp al, 's'     ; s 鍵 (加速下落)
    je KeyS
    cmp al, 'S'
    je KeyS
    
    jmp CheckTimer  ; 處理完按鍵後，繼續檢查時間

HandleEsc:
    call AskExit        ; 顯示詢問視窗
    cmp al, 1           ; 如果 AskExit 回傳 1 (Yes)
    je ExitApp          ; 則離開程式
    
    ; 若選擇取消，恢復畫面並重置計時器
    call RefreshScreen
    mov ax, 0040h
    mov es, ax
    mov di, 006Ch
    mov ax, es:[di]
    mov last_timer, ax  ; 避免暫停時累積了太多時間導致方塊瞬移
    jmp MainLoop

; --- 移動控制邏輯 ---
; 每個動作都遵循：擦除舊圖 -> 嘗試移動 -> 繪製新圖
KeyW:
    call EraseCurrent   ; 擦除當前位置 (畫黑色)
    call TryRotate      ; 計算旋轉並檢查碰撞，若合法則更新座標
    call DrawCurrent    ; 在新位置(或原位置)繪製
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
    call DoDrop         ; 手動加速下落 (只做一次下落邏輯)
    jmp MainLoop

CheckTimer:
    ; --------------------------------------
    ; 2. 處理重力 (自動下落)
    ; --------------------------------------
    mov ax, 0040h
    mov es, ax
    mov di, 006Ch
    mov ax, es:[di]     ; 讀取當前系統 Tick
    
    sub ax, last_timer  ; 計算時間差
    cmp ax, time_limit  ; 比較是否超過下落間隔
    jl MainLoop         ; 若時間未到，回到迴圈開始
    
    ; 時間到了，更新計時器
    mov ax, es:[di]
    mov last_timer, ax
    
    call DoDrop         ; 執行下落邏輯
    
    cmp game_over, 1    ; 檢查是否遊戲結束
    je GameOver
    
    jmp MainLoop

GameOver:
    call ShowGameOver
    jmp StartGame       ; 重新開始

ExitApp:
    EXIT_TEXT_MODE      ; 切回文字模式 (Int 10h, AX=0003h)
    mov ax, 4c00h       ; DOS 退出程式
    int 21h
main ENDP

; =================================================================
; UI 子程式 (彈出視窗、文字顯示)
; =================================================================

AskExit PROC
    call DrawPopupBox   ; 畫出黑底白框
    
    ; 設定游標位置
    mov ah, 02h
    mov bh, 0
    mov dh, 14      ; Row (行)
    mov dl, 32      ; Col (列)
    int 10h
    
    ; 顯示文字
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
    cmp al, 27      ; ESC 視為 No
    je ReturnNo
    
    jmp WaitKey_Ask

ReturnYes:
    mov al, 1
    ret
ReturnNo:
    mov al, 0
    ret
AskExit ENDP

ShowGameOver PROC
    call DrawPopupBox
    
    ; 顯示 "GAME OVER"
    mov ah, 02h
    mov bh, 0
    mov dh, 13
    mov dl, 35
    int 10h
    mov ah, 09h
    lea dx, str_over
    int 21h
    
    ; 顯示 "Press Any Key"
    mov ah, 02h
    mov bh, 0
    mov dh, 15
    mov dl, 33
    int 10h
    mov ah, 09h
    lea dx, str_retry
    int 21h
    
    mov ah, 00h     ; 等待按鍵
    int 16h
    ret
ShowGameOver ENDP

DrawPopupBox PROC
    push ax
    push bx
    push cx
    push dx
    
    ; 1. 畫黑色填充 (清除背景)
    mov draw_color, 0
    mov draw_px, 220
    mov draw_py, 180
    
    mov cx, 80      ; 高度
BoxY:
    push cx
    mov cx, 200     ; 寬度
    mov bx, draw_px
BoxX:
    push cx
    push bx
    DRAW_PIXEL bx, draw_py, draw_color ; 呼叫巨集畫點
    pop bx
    pop cx
    inc bx
    loop BoxX
    inc draw_py
    pop cx
    loop BoxY
    
    ; 2. 畫白色邊框 (上下左右四條線)
    mov draw_color, 15
    
    ; 上邊框
    mov cx, 200
    mov draw_px, 220
    mov draw_py, 180
L1: call PlotPixel
    inc draw_px
    loop L1
    
    ; 下邊框
    mov cx, 200
    mov draw_px, 220
    mov draw_py, 260
L2: call PlotPixel
    inc draw_px
    loop L2
    
    ; 左邊框
    mov cx, 80
    mov draw_px, 220
    mov draw_py, 180
L3: call PlotPixel
    inc draw_py
    loop L3
    
    ; 右邊框
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
    ; 重新繪製整個遊戲畫面 (用於從選單返回時)
    call DrawBackground
    call DrawBoardAll
    call DrawCurrent
    ret
RefreshScreen ENDP

PlotPixel PROC
    ; 封裝繪圖巨集，方便迴圈呼叫
    DRAW_PIXEL draw_px, draw_py, draw_color
    ret
PlotPixel ENDP

; =================================================================
; 遊戲核心邏輯
; =================================================================

DoDrop PROC
    call EraseCurrent   ; 先擦除舊位置
    
    ; 嘗試計算 Y+1 的位置
    mov ax, cur_x
    mov tmp_x, ax
    mov ax, cur_y
    mov tmp_y, ax
    inc tmp_y           ; Y 座標 + 1
    
    mov al, cur_rot
    mov tmp_rot, al
    
    call CheckCollision ; 檢查新位置是否碰撞
    cmp ax, 1
    je Landed           ; 若碰撞 (AX=1)，代表著地
    
    ; 若未碰撞，確認更新 Y 座標
    inc cur_y
    call DrawCurrent
    ret

Landed:
    call DrawCurrent    ; 在原位置重畫一次(確保顯示)
    call LockPiece      ; 將當前位置寫入 board 陣列
    call CheckLines     ; 檢查是否有滿行並消除
    call SpawnPiece     ; 生成新方塊
    
    ; 同步 tmp 變數
    mov ax, cur_x
    mov tmp_x, ax
    mov ax, cur_y
    mov tmp_y, ax
    mov al, cur_rot
    mov tmp_rot, al
    
    call DrawCurrent    ; 繪製新方塊
    
    ; 檢查新方塊剛出生是否就碰撞 (Game Over 判斷)
    call CheckCollision
    cmp ax, 1
    jne DropEnd
    mov game_over, 1    ; 設定遊戲結束旗標
DropEnd:
    ret
DoDrop ENDP

InitGame PROC
    ; 清空 Board 陣列
    lea di, board
    mov cx, 200
    mov al, 0
    rep stosb           ; 將 AL(0) 填入 DI 指向的記憶體 CX 次
    mov game_over, 0
    call SpawnPiece
    ret
InitGame ENDP

SpawnPiece PROC
    ; 簡單的隨機數生成
    mov ax, rand_seed
    add ax, 13
    mov dx, 7
    mul dx              ; AX = AX * 7
    mov es, ax
    
    ; 加入時間擾動
    mov ax, 0040h
    mov es, ax
    mov di, 006Ch
    add ax, es:[di]     ; 加上當前 Timer Tick
    mov rand_seed, ax
    
    ; 取餘數決定方塊類型 (0-6)
    xor dx, dx
    mov bx, 7
    div bx              ; DX = AX % 7
    mov cur_piece, dl
    
    ; 重置初始位置
    mov cur_rot, 0
    mov cur_x, 4
    mov cur_y, 0
    ret
SpawnPiece ENDP

; 嘗試旋轉：計算旋轉後狀態 -> 檢查碰撞 -> 若OK則更新 cur_rot
TryRotate PROC
    mov ax, cur_x
    mov tmp_x, ax
    mov ax, cur_y
    mov tmp_y, ax
    
    mov al, cur_rot
    inc al
    and al, 3           ; 確保旋轉值在 0-3 之間 (Mod 4)
    mov tmp_rot, al
    
    call CheckCollision
    cmp ax, 0
    jne RotEnd          ; 若碰撞 (AX!=0)，不更新
    mov al, tmp_rot
    mov cur_rot, al
RotEnd:
    ret
TryRotate ENDP

; 左移邏輯
TryLeft PROC
    mov ax, cur_x
    mov tmp_x, ax
    dec tmp_x           ; X - 1
    mov ax, cur_y
    mov tmp_y, ax
    mov al, cur_rot
    mov tmp_rot, al
    
    call CheckCollision
    cmp ax, 0
    jne LeftEnd
    dec cur_x           ; 沒碰撞才真的移動
LeftEnd:
    ret
TryLeft ENDP

; 右移邏輯
TryRight PROC
    mov ax, cur_x
    mov tmp_x, ax
    inc tmp_x           ; X + 1
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

; -------------------------------------------------------------
; 碰撞檢測 (核心演算法)
; 輸入: tmp_x, tmp_y, tmp_rot, cur_piece
; 輸出: AX (0:無碰撞, 1:有碰撞)
; -------------------------------------------------------------
CheckCollision PROC
    push bx
    push cx
    push dx
    push si
    push di
    
    ; 計算 shapes 陣列偏移量
    ; Offset = (PieceType * 32) + (Rotation * 8)
    
    xor ax, ax
    mov al, cur_piece
    mov cl, 5
    shl ax, cl          ; AX = Piece * 32 (2^5)
    mov bx, ax
    
    xor ax, ax
    mov al, tmp_rot
    mov cl, 3
    shl ax, cl          ; AX = Rot * 8 (2^3)
    
    lea si, [shapes + bx] ; 取得該方塊類型的起始位址
    add si, ax            ; 加上旋轉偏移，SI 指向具體形狀資料
    
    mov cx, 4           ; 檢查 4 個小方格
ColLoop:
    ; 讀取相對 X，計算絕對 X
    mov al, [si]
    cbw                 ; Convert Byte to Word (擴展符號位)
    add ax, tmp_x
    mov bx, ax          ; BX = 絕對 X
    
    ; 讀取相對 Y，計算絕對 Y
    mov al, [si+1]
    cbw
    add ax, tmp_y
    mov di, ax          ; DI = 絕對 Y
    add si, 2           ; 指向下一個點的資料
    
    ; 1. 邊界檢查
    cmp bx, 0
    jl IsHit            ; X < 0 (超出左邊界)
    cmp bx, BOARD_W
    jge IsHit           ; X >= 10 (超出右邊界)
    cmp di, BOARD_H
    jge IsHit           ; Y >= 20 (超出下底界)
    
    cmp di, 0
    jl NextCol          ; Y < 0 (還在上方未進場，不當作碰撞)
    
    ; 2. 檢查 Board 陣列是否已被佔用
    ; Index = (Y * 10) + X
    mov ax, di
    push cx
    mov cl, 3
    shl ax, cl          ; AX = Y * 8
    shl di, 1           ; DI = Y * 2
    add ax, di          ; AX = Y*8 + Y*2 = Y*10
    pop cx
    add ax, bx          ; AX = (Y*10) + X
    
    push bx
    mov bx, ax
    mov al, board[bx]   ; 讀取 Board 該位置的值
    pop bx
    
    cmp al, 0
    jne IsHit           ; 若不為 0，表示有方塊阻擋

NextCol:
    dec cx
    jnz ColLoop
    
    mov ax, 0           ; 通過所有檢查，無碰撞
    jmp ColEnd
IsHit:
    mov ax, 1           ; 發生碰撞
ColEnd:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
CheckCollision ENDP

; -------------------------------------------------------------
; 鎖定方塊：將當前圖形寫入 Board 陣列
; -------------------------------------------------------------
LockPiece PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; 計算 shapes 偏移 (同碰撞檢測)
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
    
    ; 取得方塊顏色
    mov bl, cur_piece
    xor bh, bh
    mov al, piece_colors[bx]
    mov dl, al          ; DL 存放顏色代碼
    
    mov cx, 4
LockLoop:
    ; 計算絕對座標
    mov al, [si]
    cbw
    add ax, cur_x
    mov bx, ax          ; BX = X
    
    mov al, [si+1]
    cbw
    add ax, cur_y
    mov di, ax          ; DI = Y
    add si, 2
    
    cmp di, 0
    jl SkipLock         ; 如果方塊部分還在頂部外，不寫入
    
    ; 計算 Board Index = Y*10 + X
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
    mov board[bx], dl   ; 將顏色寫入記憶體
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

; -------------------------------------------------------------
; 消行檢查：從底部向上掃描，滿行則消除並下移
; -------------------------------------------------------------
CheckLines PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov dx, 19          ; 從最底層 (Row 19) 開始檢查
CheckLineLoop:
    cmp dx, 0
    jl CheckEnd         ; 檢查到頂端則結束
    
    ; 計算該行起始記憶體位置 SI = DX * 10
    mov ax, dx
    push dx
    mov cl, 3
    shl ax, cl
    shl dx, 1
    add ax, dx
    pop dx
    mov si, ax
    
    ; 檢查該行是否全滿
    mov cx, 10
    mov bl, 0           ; BL = 0 假設是滿的
ScanRow:
    cmp board[si], 0
    je NotFull          ; 只要有一個是 0 (空)，就不是滿行
    inc si
    dec cx
    jnz ScanRow
    jmp FullFound       ; 全都不是 0，跳轉到消除邏輯
NotFull:
    mov bl, 1           ; 標記為未滿
    
FullFound:
    cmp bl, 0
    jne NextRow         ; 若未滿，檢查上一行
    
    ; --- 執行消行 (記憶體搬移) ---
    push dx
    push es
    push ds
    pop es              ; 讓 ES = DS，方便使用 movsb
    
    cld                 ; 清除方向旗標 (正向複製)
MoveLines:
    cmp dx, 0
    je ClearTop         ; 如果已經搬到最頂層 (Row 0)，則只需清空頂層
    
    ; 目標位置 DI = Row DX (當前要被覆蓋的行)
    mov ax, dx
    push dx
    mov dx, 10
    mul dx
    pop dx
    mov di, ax
    add di, OFFSET board
    
    ; 來源位置 SI = Row DX-1 (上一行)
    mov si, di
    sub si, 10
    
    mov cx, 10          ; 搬移 10 bytes
    rep movsb
    
    dec dx              ; 往上處理下一行
    jmp MoveLines
    
ClearTop:
    ; 處理最頂行 (Row 0)，填入 0
    lea di, board
    mov cx, 10
    mov al, 0
    rep stosb
    
    pop es
    pop dx
    
    call DrawBoardAll   ; 記憶體變動後，重繪整個盤面
    ; 注意：不減少 DX，因為當前行被上一行覆蓋後，
    ; 該位置可能仍是滿行 (如果連續多行消除)，需重新檢查當前 DX
    jmp CheckLineLoop
    
NextRow:
    dec dx              ; 檢查上一行
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
    ; 繪製遊戲區左右兩側的灰色直條
    push ax
    push bx
    push cx
    push dx

    ; 1. 畫左牆
    mov ax, GAME_X
    sub ax, BLOCK_SIZE  ; 往左一格
    mov draw_px, ax
    mov cx, BOARD_H
    mov ax, GAME_Y
    mov draw_py, ax
    mov draw_color, 8   ; 灰色
LW: push cx
    call DrawRect       ; 畫方塊
    mov ax, draw_py
    add ax, BLOCK_SIZE  ; Y 往下
    mov draw_py, ax
    pop cx
    loop LW
    
    ; 2. 畫右牆
    mov ax, BOARD_W     ; 板寬 * 20
    mov cl, 4
    shl ax, cl          ; x16
    mov bx, BOARD_W
    mov cl, 2
    shl bx, cl          ; x4
    add ax, bx          ; x20 (Block Size)
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
    mov draw_color, 0   ; 設定黑色 (背景色)
    call DrawPieceCommon
    ret
EraseCurrent ENDP

DrawCurrent PROC
    ; 設定該方塊對應的顏色
    mov bl, cur_piece
    xor bh, bh
    mov al, piece_colors[bx]
    mov draw_color, al
    call DrawPieceCommon
    ret
DrawCurrent ENDP

; 通用繪圖函式：根據 cur_x, cur_y, cur_rot 繪製 4 個方格
DrawPieceCommon PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; 計算 shapes 偏移 (Piece * 32)
    xor ax, ax
    mov al, cur_piece
    mov cl, 5
    shl ax, cl
    mov bx, ax
    
    ; 計算旋轉偏移 (Rot * 8)
    xor ax, ax
    mov al, cur_rot
    mov cl, 3
    shl ax, cl
    
    lea si, [shapes + bx]
    add si, ax
    
    mov cx, 4
DPLoop:
    ; 計算螢幕 X = (GridX + OffsetX) * 20 + GameX
    mov al, [si]
    cbw
    add ax, cur_x
    mov bx, ax
    
    ; 計算螢幕 Y = (GridY + OffsetY) * 20 + GameY
    mov al, [si+1]
    cbw
    add ax, cur_y
    mov dx, ax
    add si, 2
    
    cmp dx, 0           ; 如果還在頂部外，不畫
    jl SkipDP
    
    ; 轉換 Grid 座標到 Pixel 座標 (* 20)
    ; X * 20 = X * 16 + X * 4
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
    
    ; Y * 20
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
    
    call DrawRect       ; 呼叫畫方塊副程式
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

; 遍歷 board 陣列並重繪所有非 0 的格子
DrawBoardAll PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov dx, 0           ; Row Loop (0-19)
DBY:
    mov bx, 0           ; Col Loop (0-9)
DBX:
    ; 計算 Index = DX * 10 + BX
    mov ax, dx
    push dx
    push bx
    
    mov si, dx
    mov cl, 3
    shl si, cl
    shl dx, 1
    add si, dx          ; SI = DX * 10
    pop bx
    add si, bx          ; SI = Index
    
    mov al, board[si]   ; 讀取顏色
    mov draw_color, al
    
    ; 計算 Pixel X (同上，BX * 20 + Base)
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
    
    ; 計算 Pixel Y (同上，DX * 20 + Base)
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
    
    call DrawRect       ; 繪製 (顏色 0 會畫黑色，等於清除)
    
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

; 畫一個實心矩形 (20x20)
DrawRect PROC
    push ax
    push bx
    push cx
    push dx
    
    mov dx, draw_py
    mov bx, 19          ; 高度迴圈 (0-19)
R_Loop:
    mov cx, draw_px
    push bx
    mov bx, 19          ; 寬度迴圈 (0-19)
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