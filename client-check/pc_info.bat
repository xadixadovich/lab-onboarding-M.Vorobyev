@echo off
chcp 65001 >nul

REM ============================================================
REM Тема: Диагностика клиентского компьютера
REM Автор: Воробьев М.
REM Дата: 30.10.2026
REM ============================================================

REM Отчёт сохраняется рядом с этим bat-файлом
set "REPORT=%~dp0pc_report.txt"

echo Идёт сбор данных, пожалуйста, подождите...

REM Все сведения формируются в блоке :report и записываются в файл,
REM затем тот же файл выводится в окно - так окно и отчёт совпадают
call :report > "%REPORT%"

cls
type "%REPORT%"

REM --- Сообщение о сохранении ---
echo.
echo Отчёт сохранён
echo %REPORT%
echo.
pause
exit /b


REM ============================================================
:report
REM ============================================================

REM --- Заголовок ---
echo ============================================================
echo                  Диагностика компьютера
echo ============================================================
echo Дата и время: %date% %time%
echo.

REM --- Операционная система ---
REM Вместо устаревшей wmic используется тот же источник данных (CIM/WMI),
REM запрашиваемый короткой командой PowerShell
echo ------------------------------------------------------------
echo Операционная система
echo ------------------------------------------------------------
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"`) do echo Название: %%a
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Version"`) do echo Версия:   %%a
echo.

REM --- Процессор ---
echo ------------------------------------------------------------
echo Процессор
echo ------------------------------------------------------------
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_Processor).Name"`) do echo %%a
echo.

REM --- Оперативная память (значения в КБ, переводим в ГБ: делим на 1048576) ---
echo ------------------------------------------------------------
echo Оперативная память
echo ------------------------------------------------------------
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "[math]::Floor((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1048576)"`) do set "RAM_TOTAL=%%a"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "[math]::Floor((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1048576)"`) do set "RAM_FREE=%%a"
echo Всего памяти:    %RAM_TOTAL% ГБ
echo Свободно памяти: %RAM_FREE% ГБ
echo.

REM --- Диск C (значения в байтах, переводим в ГБ: делим на 1073741824) ---
echo ------------------------------------------------------------
echo Диск C
echo ------------------------------------------------------------
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "[math]::Floor((Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:').Size / 1073741824)"`) do set "DISK_TOTAL=%%a"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "[math]::Floor((Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:').FreeSpace / 1073741824)"`) do set "DISK_FREE=%%a"
echo Общий размер: %DISK_TOTAL% ГБ
echo Свободно:     %DISK_FREE% ГБ
echo.

REM --- Установленные программы (через реестр, 64-битные и 32-битные) ---
echo ------------------------------------------------------------
echo Установленные программы
echo ------------------------------------------------------------
for /f "tokens=2,*" %%a in ('reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s 2^>nul ^| findstr /r /c:"^ *DisplayName  *REG_SZ" ^| sort') do echo  - %%b
for /f "tokens=2,*" %%a in ('reg query "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s 2^>nul ^| findstr /r /c:"^ *DisplayName  *REG_SZ" ^| sort') do echo  - %%b
echo.
echo ============================================================
exit /b
