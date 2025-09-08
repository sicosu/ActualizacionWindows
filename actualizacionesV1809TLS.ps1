# Requiere ejecutar PowerShell como Administrador

# Habilitar TLS 1.2 para la sesión actual de PowerShell (temporal)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Opcional: Habilitar TLS 1.2 permanentemente en el registro (requiere reinicio)
Write-Host "¿Deseas habilitar TLS 1.2 de forma permanente? (s/n)" -ForegroundColor Yellow
$permanent = Read-Host
if ($permanent -eq 's') {
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -Type DWord
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -Type DWord
    Write-Host "TLS 1.2 habilitado permanentemente. Reinicia el sistema para aplicar los cambios." -ForegroundColor Green
}

# Forzar la búsqueda de actualizaciones usando Windows Update Agent API
Write-Host "Buscando actualizaciones..." -ForegroundColor Cyan

try {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

    # Mostrar actualizaciones disponibles
    if ($SearchResult.Updates.Count -eq 0) {
        Write-Host "No hay actualizaciones disponibles." -ForegroundColor Yellow
    } else {
        Write-Host "Encontradas $($SearchResult.Updates.Count) actualizaciones." -ForegroundColor Green
        
        # Crear colección de actualizaciones para instalar
        $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($Update in $SearchResult.Updates) {
            Write-Host "-> $($Update.Title)" -ForegroundColor White
            $UpdatesToInstall.Add($Update) | Out-Null
        }

        # Descargar actualizaciones
        Write-Host "Descargando actualizaciones..." -ForegroundColor Cyan
        $Downloader = $UpdateSession.CreateUpdateDownloader()
        $Downloader.Updates = $UpdatesToInstall
        $DownloadResult = $Downloader.Download()
        
        if ($DownloadResult.ResultCode -eq 2) {
            Write-Host "Descarga completada correctamente." -ForegroundColor Green
            
            # Instalar actualizaciones
            Write-Host "Instalando actualizaciones..." -ForegroundColor Cyan
            $Installer = $UpdateSession.CreateUpdateInstaller()
            $Installer.Updates = $UpdatesToInstall
            $InstallResult = $Installer.Install()
            
            if ($InstallResult.ResultCode -eq 2) {
                Write-Host "Actualizaciones instaladas correctamente." -ForegroundColor Green
                Write-Host "Es posible que necesites reiniciar el sistema." -ForegroundColor Yellow
            } else {
                Write-Host "Error durante la instalación: $($InstallResult.ResultCode)" -ForegroundColor Red
            }
        } else {
            Write-Host "Error durante la descarga: $($DownloadResult.ResultCode)" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Opcional: Usar PowerShell para iniciar Windows Update de forma tradicional
Write-Host "`nTambién puedes intentar con el método tradicional:" -ForegroundColor Cyan
Write-Host "1. Abrir 'Configuración' -> 'Actualizaciones y seguridad'" -ForegroundColor White
Write-Host "2. Hacer clic en 'Buscar actualizaciones'" -ForegroundColor White
Write-Host "3. Instalar manualmente las actualizaciones encontradas" -ForegroundColor White

# Opcional: Reiniciar si es necesario
if ($permanent -eq 's') {
    Write-Host "Reinicia el sistema para aplicar los cambios de TLS 1.2 permanentemente." -ForegroundColor Yellow
}
