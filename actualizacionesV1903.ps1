# Script de preparación para actualizaciones de Windows
# Requiere ejecutar PowerShell como Administrador

Write-Host "=== PREPARACIÓN PARA ACTUALIZACIONES DE WINDOWS ===" -ForegroundColor Green
Write-Host "Este script prepara el sistema para buscar e instalar actualizaciones" -ForegroundColor Cyan

# 1. Verificar y habilitar TLS 1.2 si es necesario
Write-Host "`n1. VERIFICANDO TLS 1.2..." -ForegroundColor Yellow

$net40Path = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
$net40WowPath = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
$tlsNeeded = $false

if (Test-Path $net40Path) {
    $schUseStrongCrypto = Get-ItemProperty -Path $net40Path -Name "SchUseStrongCrypto" -ErrorAction SilentlyContinue
    if ($schUseStrongCrypto -eq $null -or $schUseStrongCrypto.SchUseStrongCrypto -ne 1) {
        $tlsNeeded = $true
    }
}

if (Test-Path $net40WowPath) {
    $schUseStrongCryptoWow = Get-ItemProperty -Path $net40WowPath -Name "SchUseStrongCrypto" -ErrorAction SilentlyContinue
    if ($schUseStrongCryptoWow -eq $null -or $schUseStrongCryptoWow.SchUseStrongCrypto -ne 1) {
        $tlsNeeded = $true
    }
}

if ($tlsNeeded) {
    Write-Host "TLS 1.2 no está habilitado. Es necesario habilitarlo." -ForegroundColor Red
    
    # Crear archivo REG
    $regContent = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319]
"SchUseStrongCrypto"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319]
"SchUseStrongCrypto"=dword:00000001
"@
    
    $regPath = "$env:TEMP\Enable_TLS_1.2.reg"
    $regContent | Out-File -FilePath $regPath -Encoding ASCII
    
    Write-Host "Aplicando configuración TLS 1.2..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath "reg.exe" -ArgumentList "import `"$regPath`"" -Wait -NoNewWindow
        Remove-Item -Path $regPath -Force
        Write-Host "TLS 1.2 habilitado permanentemente." -ForegroundColor Green
        Write-Host "SE REQUIERE REINICIO PARA APLICAR LOS CAMBIOS." -ForegroundColor Red
        $reboot = Read-Host "¿Reiniciar ahora? (s/n)"
        if ($reboot -eq 's') {
            Restart-Computer -Force
        }
        exit
    }
    catch {
        Write-Host "Error al aplicar TLS 1.2: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "TLS 1.2 ya está habilitado. Continuando..." -ForegroundColor Green
}

# 2. Configurar PowerShell y instalar módulos necesarios
Write-Host "`n2. CONFIGURANDO POWERSHELL..." -ForegroundColor Yellow

try {
    # Habilitar TLS 1.2 para esta sesión
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    Write-Host "Instalando proveedor NuGet..." -ForegroundColor Cyan
    Install-PackageProvider -Name NuGet -Force -ErrorAction Stop
    Write-Host "NuGet instalado correctamente." -ForegroundColor Green
    
    Write-Host "Configurando políticas de ejecución..." -ForegroundColor Cyan
    Set-ExecutionPolicy Unrestricted -Force -ErrorAction Stop
    
    Write-Host "Configurando repositorio PSGallery..." -ForegroundColor Cyan
    Register-PSRepository -Default -ErrorAction SilentlyContinue
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
    
    Write-Host "Instalando módulo PSWindowsUpdate..." -ForegroundColor Cyan
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
    }
    Import-Module PSWindowsUpdate -Force
    Write-Host "PSWindowsUpdate instalado correctamente." -ForegroundColor Green
}
catch {
    Write-Host "Error en la configuración: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Intentando continuar con métodos alternativos..." -ForegroundColor Yellow
}

# 3. Mostrar información del sistema y actualizaciones disponibles
Write-Host "`n3. INFORMACIÓN DEL SISTEMA:" -ForegroundColor Yellow
$os = Get-WmiObject -Class Win32_OperatingSystem
$computer = Get-WmiObject -Class Win32_ComputerSystem
Write-Host "Sistema Operativo: $($os.Caption)" -ForegroundColor White
Write-Host "Versión: $($os.Version)" -ForegroundColor White
Write-Host "Último arranque: $($os.ConvertToDateTime($os.LastBootUpTime))" -ForegroundColor White
Write-Host "Tiempo activo: $((Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime))" -ForegroundColor White

Write-Host "`n4. BUSCANDO ACTUALIZACIONES DISPONIBLES..." -ForegroundColor Yellow
Write-Host "Esto puede tomar varios minutos..." -ForegroundColor Cyan

try {
    # Buscar actualizaciones
    $updates = Get-WUList -MicrosoftUpdate -Verbose
    
    if ($updates.Count -eq 0) {
        Write-Host "No se encontraron actualizaciones disponibles." -ForegroundColor Green
    } else {
        Write-Host "`n=== ACTUALIZACIONES DISPONIBLES ===" -ForegroundColor Green
        Write-Host "Total: $($updates.Count) actualizaciones encontradas" -ForegroundColor Cyan
        
        # Mostrar detalles de las actualizaciones
        $securityUpdates = $updates | Where-Object {$_.Title -like "*seguridad*" -or $_.Title -like "*security*" -or $_.KB -ne ""}
        $driverUpdates = $updates | Where-Object {$_.Title -like "*driver*" -or $_.Title -like "*controlador*" -or $_.Title -like "*firmware*"}
        $otherUpdates = $updates | Where-Object {$securityUpdates -notcontains $_ -and $driverUpdates -notcontains $_}
        
        if ($securityUpdates.Count -gt 0) {
            Write-Host "`n--- ACTUALIZACIONES DE SEGURIDAD ($($securityUpdates.Count)) ---" -ForegroundColor Red
            $securityUpdates | ForEach-Object {
                Write-Host "KB$($_.KB): $($_.Title)" -ForegroundColor Yellow
                Write-Host "  Tamaño: $([math]::Round($_.Size/1MB, 2)) MB - Categoría: $($_.Categories)" -ForegroundColor White
            }
        }
        
        if ($driverUpdates.Count -gt 0) {
            Write-Host "`n--- CONTROLADORES Y FIRMWARE ($($driverUpdates.Count)) ---" -ForegroundColor Blue
            $driverUpdates | ForEach-Object {
                Write-Host "$($_.Title)" -ForegroundColor Cyan
                Write-Host "  Tamaño: $([math]::Round($_.Size/1MB, 2)) MB" -ForegroundColor White
            }
        }
        
        if ($otherUpdates.Count -gt 0) {
            Write-Host "`n--- OTRAS ACTUALIZACIONES ($($otherUpdates.Count)) ---" -ForegroundColor Magenta
            $otherUpdates | ForEach-Object {
                if ($_.KB) {
                    Write-Host "KB$($_.KB): $($_.Title)" -ForegroundColor Gray
                } else {
                    Write-Host "$($_.Title)" -ForegroundColor Gray
                }
                Write-Host "  Tamaño: $([math]::Round($_.Size/1MB, 2)) MB - Categoría: $($_.Categories)" -ForegroundColor White
            }
        }
        
        # Preguntar si instalar
        Write-Host "`n=== OPCIONES ===" -ForegroundColor Green
        $installChoice = Read-Host "¿Deseas instalar estas actualizaciones? (s/n)"
        
        if ($installChoice -eq 's') {
            Write-Host "Instalando actualizaciones..." -ForegroundColor Cyan
            Get-WUInstall -MicrosoftUpdate -AcceptAll -AutoReboot:$false -Verbose
            Write-Host "`n=== INSTALACIÓN COMPLETADA ===" -ForegroundColor Green
            Write-Host "Revisa si es necesario reiniciar manualmente." -ForegroundColor Yellow
        } else {
            Write-Host "Actualizaciones no instaladas. Puedes instalarlas manualmente luego con:" -ForegroundColor Yellow
            Write-Host "Get-WUInstall -MicrosoftUpdate -AcceptAll -AutoReboot:`$false" -ForegroundColor White
        }
    }
}
catch {
    Write-Host "Error al buscar actualizaciones: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== PROCESO COMPLETADO ===" -ForegroundColor Green
Write-Host "Script de preparación finalizado." -ForegroundColor Cyan
