@echo off
REM 批次檔參數 %1 代表傳入的檔案名稱 (不含副檔名)
SET ASM_FILE=%1

ECHO --- 正在編譯 %ASM_FILE%.asm ---

REM 1. 編譯 (使用上一層的 ML.EXE)
REM 這裡使用 /c 參數告訴 ML 只編譯，不連結
..\ml /c %ASM_FILE%.asm

REM 檢查編譯是否成功
if errorlevel 1 goto terminate

ECHO --- 正在連結 %ASM_FILE%.obj ---

REM 2. 連結 (使用上一層的 LINK.EXE)
REM 這裡需要指定連結器所需的函式庫，假設是 F:\LIB\Irvine16.LIB
..\link %ASM_FILE%.obj,,NUL,..\LIB\Irvine16.LIB;

REM 檢查連結是否成功
if errorlevel 1 goto terminate

REM 3. 清理中間檔案
del %ASM_FILE%.obj

ECHO.
ECHO --- %ASM_FILE%.EXE 已經建立完成 ---
GOTO end

:terminate
ECHO.
ECHO !!! 編譯或連結失敗，請檢查錯誤訊息 !!!

:end
pause