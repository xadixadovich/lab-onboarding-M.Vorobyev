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
echo ------------------------------------------------------------
echo Операционная система
echo ------------------------------------------------------------
for /f "tokens=2 delims==" %%a in ('wmic os get Caption /value ^| find "="') do for /f "delims=" %%b in ("%%a") do echo Название: %%b
for /f "tokens=2 delims==" %%a in ('wmic os get Version /value ^| find "="') do for /f "delims=" %%b in ("%%a") do echo Версия:   %%b
echo.

REM --- Процессор ---
echo ------------------------------------------------------------
echo Процессор
echo ------------------------------------------------------------
for /f "tokens=2 delims==" %%a in ('wmic cpu get Name /value ^| find "="') do for /f "delims=" %%b in ("%%a") do echo %%b
echo.

REM --- Оперативная память (значения в КБ, переводим в ГБ: делим на 1048576) ---
echo ------------------------------------------------------------
echo Оперативная память
echo ------------------------------------------------------------
for /f "tokens=2 delims==" %%a in ('wmic os get TotalVisibleMemorySize /value ^| find "="') do for /f "delims=" %%b in ("%%a") do set /a RAM_TOTAL=%%b/1048576
for /f "tokens=2 delims==" %%a in ('wmic os get FreePhysicalMemory /value ^| find "="') do for /f "delims=" %%b in ("%%a") do set /a RAM_FREE=%%b/1048576
echo Всего памяти:    %RAM_TOTAL% ГБ
echo Свободно памяти: %RAM_FREE% ГБ
echo.

REM --- Диск C (значения в байтах, переводим в ГБ через подпрограмму :bytes2gb) ---
echo ------------------------------------------------------------
echo Диск C
echo ------------------------------------------------------------
for /f "tokens=2 delims==" %%a in ('wmic logicaldisk where "DeviceID='C:'" get Size /value ^| find "="') do for /f "delims=" %%b in ("%%a") do call :bytes2gb %%b DISK_TOTAL
for /f "tokens=2 delims==" %%a in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value ^| find "="') do for /f "delims=" %%b in ("%%a") do call :bytes2gb %%b DISK_FREE
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


REM ============================================================
REM Перевод байт в гигабайты. Вызов: call :bytes2gb ЧИСЛО ИМЯ_ПЕРЕМЕННОЙ
REM set /a работает с 32-битными числами (максимум около 2,1 млрд),
REM а размер диска в байтах больше, поэтому сначала отбрасываем
REM последние 6 цифр (получаем миллионы байт), а потом делим на 1073,74
REM ============================================================
:bytes2gb
set "BYTES=%~1"
set /a MB=%BYTES:~0,-6%
set /a %2=MB*100/107374
exit /b