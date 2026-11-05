param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath
)

$ErrorActionPreference = 'Continue'
$AppsTemp = Join-Path $env:TEMP ("pc_audit_apps_{0}.txt" -f [guid]::NewGuid().ToString('N'))
$RecommendationCount = 0
$BasicCategoriesChecked = 0

# Единая функция записи подробного отчёта: строка видна в консоли и сохраняется в файл.
function Write-Log {
    param([AllowEmptyString()][string]$Message = '')
    Write-Host $Message
    Add-Content -LiteralPath $ReportPath -Value $Message -Encoding UTF8
}

function Get-SafeValue {
    param($Value, [string]$Fallback = 'Не удалось получить данные')
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $Fallback
    }
    return [string]$Value
}

try {
    Write-Log '============================================================'
    Write-Log 'СВЕДЕНИЯ О КОМПЬЮТЕРЕ'
    Write-Log '============================================================'
    Write-Log ("Имя компьютера: {0}" -f $env:COMPUTERNAME)
    Write-Log ("Дата и время формирования отчёта: {0}" -f (Get-Date -Format 'dd.MM.yyyy HH:mm:ss'))

    # Каждый запрос изолирован: сбой одного источника не останавливает остальные проверки.
    Write-Log ''
    Write-Log '--- Операционная система ---'
    $os = $null
    try { $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop } catch {}
    Write-Log ("Название: {0}" -f (Get-SafeValue $(if ($os) { $os.Caption } else { $null })))
    Write-Log ("Версия: {0}" -f (Get-SafeValue $(if ($os) { $os.Version } else { $null })))

    Write-Log ''
    Write-Log '--- Процессор ---'
    $cpu = $null
    try { $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1 } catch {}
    Write-Log (Get-SafeValue $(if ($cpu) { $cpu.Name.Trim() } else { $null }))

    Write-Log ''
    Write-Log '--- Оперативная память ---'
    $ramTotal = $null
    $ramFree = $null
    if ($os) {
        if ($os.TotalVisibleMemorySize) { $ramTotal = '{0:N2}' -f ($os.TotalVisibleMemorySize / 1MB) }
        if ($os.FreePhysicalMemory) { $ramFree = '{0:N2}' -f ($os.FreePhysicalMemory / 1MB) }
    }
    Write-Log ("Всего памяти: {0} ГБ" -f (Get-SafeValue $ramTotal))
    Write-Log ("Свободно памяти: {0} ГБ" -f (Get-SafeValue $ramFree))

    Write-Log ''
    Write-Log '--- Локальные диски ---'
    $disks = @()
    try { $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop) } catch {}
    if ($disks.Count -gt 0) {
        foreach ($disk in $disks) {
            if ($disk.Size -gt 0) {
                $total = [math]::Round($disk.Size / 1GB, 2)
                $free = [math]::Round($disk.FreeSpace / 1GB, 2)
                Write-Log ("{0} Общий размер: {1} ГБ; свободно: {2} ГБ" -f $disk.DeviceID, $total, $free)
            }
        }
    } else {
        Write-Log 'Информация о локальных дисках недоступна.'
    }

    # Собираем только DisplayName. Проверяются 64-битная, 32-битная и пользовательские ветки.
    Write-Log ''
    Write-Log '============================================================'
    Write-Log 'УСТАНОВЛЕННЫЕ ПРОГРАММЫ'
    Write-Log '============================================================'
    Write-Log 'Опрос реестра: 64-битные и 32-битные приложения...'

    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $apps = @()
    foreach ($registryPath in $registryPaths) {
        try {
            $entries = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
            foreach ($entry in $entries) {
                if (-not [string]::IsNullOrWhiteSpace([string]$entry.DisplayName)) {
                    $apps += $entry.DisplayName.Trim()
                }
            }
        } catch {
            # Недоступная ветка реестра пропускается.
        }
    }

    $apps = @($apps | Sort-Object -Unique)
    if ($apps.Count -gt 0) {
        $apps | Set-Content -LiteralPath $AppsTemp -Encoding UTF8
        foreach ($app in $apps) { Write-Log (" - {0}" -f $app) }
    } else {
        Set-Content -LiteralPath $AppsTemp -Value '' -Encoding UTF8
        Write-Log 'Список программ пуст или недоступен.'
    }
    Write-Log ("Всего уникальных названий программ: {0}" -f $apps.Count)

    # Если задан тестовый файл, анализируем его вместо реестра.
    # Это позволяет проверить обе ветви рекомендаций, не устанавливая программы.
    if ($env:PC_AUDIT_TEST_APPS -and (Test-Path -LiteralPath $env:PC_AUDIT_TEST_APPS)) {
        $apps = @(Get-Content -LiteralPath $env:PC_AUDIT_TEST_APPS -Encoding UTF8 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() } | Sort-Object -Unique)
        Write-Log ''
        Write-Log '[ТЕСТОВЫЙ РЕЖИМ] Для анализа используется указанный тестовый список программ.'
    }

    Write-Log ''
    Write-Log '============================================================'
    Write-Log 'РЕКОМЕНДАЦИИ: БАЗОВОЕ ОФИСНОЕ ПО'
    Write-Log '============================================================'

    $basicChecks = @(
        [pscustomobject]@{ Name='Офисный пакет'; Pattern='(?i)Office|LibreOffice|OpenOffice|МойОфис'; Advice='Не обнаружен офисный пакет. Рекомендуется установить Microsoft Office, LibreOffice или МойОфис.' },
        [pscustomobject]@{ Name='Браузер'; Pattern='(?i)Chrome|Firefox|Edge|Яндекс.Браузер|Yandex'; Advice='Не обнаружен браузер. Рекомендуется установить браузер, разрешённый организацией.' },
        [pscustomobject]@{ Name='Программа для чтения PDF'; Pattern='(?i)Acrobat|Foxit|SumatraPDF'; Advice='Не обнаружена программа для чтения PDF. Рекомендуется установить Acrobat Reader, Foxit Reader или SumatraPDF.' },
        [pscustomobject]@{ Name='Архиватор'; Pattern='(?i)7-Zip|WinRAR|WinZip'; Advice='Не обнаружен архиватор. Для работы с почтовыми вложениями рекомендуется установить 7-Zip или WinRAR.' },
        [pscustomobject]@{ Name='Антивирус'; Pattern='(?i)Defender|Kaspersky|ESET|Dr\.Web'; Advice='Не обнаружен антивирус по названию программы. Проверьте состояние Microsoft Defender или корпоративного антивируса.' }
    )

    foreach ($check in $basicChecks) {
        $BasicCategoriesChecked++
        $found = @($apps | Where-Object { $_ -match $check.Pattern })
        if ($found.Count -gt 0) {
            Write-Log ("[ВЫПОЛНЕНО] {0}: {1}" -f $check.Name, ($found -join ', '))
            if ($check.Name -eq 'Браузер' -and (($found -join ' ') -match '(?i)Edge')) {
                Write-Log '  Примечание: Edge является компонентом Windows и не подтверждает настройку рабочего места.'
            }
        } else {
            Write-Log ("[РЕКОМЕНДАЦИЯ] {0}" -f $check.Advice)
            $RecommendationCount++
        }
    }

    Write-Log ''
    Write-Log '============================================================'
    Write-Log 'РЕКОМЕНДАЦИИ: ПО ДЛЯ ДОПОЛНИТЕЛЬНОЙ ПРОВЕРКИ'
    Write-Log '============================================================'

    $extraGroups = @(
        [pscustomobject]@{ Name='Игровое ПО и игровые платформы'; Pattern='(?i)Steam|Epic Games|GOG|Origin|Ubisoft Connect|Battle\.net|Riot|game|gaming' },
        [pscustomobject]@{ Name='Торрент-клиенты и файлообменные программы'; Pattern='(?i)torrent|uTorrent|BitTorrent|qBittorrent|Vuze' },
        [pscustomobject]@{ Name='Мессенджеры и приложения для личного общения'; Pattern='(?i)Discord|Telegram|WhatsApp|Viber|Skype' },
        [pscustomobject]@{ Name='Развлечения и оформление'; Pattern='(?i)Wallpaper Engine|OBS|Soundpad|VLC media player|KMPlayer|PotPlayer|Media Player Classic|AIMP' }
    )

    foreach ($group in $extraGroups) {
        Write-Log ''
        Write-Log ("Группа: {0}" -f $group.Name)
        $found = @($apps | Where-Object { $_ -match $group.Pattern })
        if ($found.Count -gt 0) {
            foreach ($app in $found) {
                Write-Log ("[ПРОВЕРИТЬ] {0}" -f $app)
                $RecommendationCount++
            }
        } else {
            Write-Log 'Подходящие программы не обнаружены.'
        }
    }

    Write-Log ''
    Write-Log '============================================================'
    Write-Log 'ИТОГ ПРОВЕРКИ'
    Write-Log '============================================================'
    Write-Log ("Проверено категорий базового ПО: {0}" -f $BasicCategoriesChecked)
    Write-Log ("Количество рекомендаций: {0}" -f $RecommendationCount)
    Write-Log 'Обнаружение программы не означает, что её необходимо удалить.'
    Write-Log 'Скрипт не определяет дату последнего запуска приложений.'
    Write-Log 'Решение о необходимости ПО принимает администратор.'
    exit 0
}
catch {
    Write-Log ("Ошибка при выполнении проверки: {0}" -f $_.Exception.Message)
    exit 1
}
finally {
    if (Test-Path -LiteralPath $AppsTemp) {
        Remove-Item -LiteralPath $AppsTemp -Force -ErrorAction SilentlyContinue
    }
}
