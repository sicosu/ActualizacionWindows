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

# 3. Mostrar información del sistema
Write-Host "`n3. INFORMACIÓN DEL SISTEMA:" -ForegroundColor Yellow
$os = Get-WmiObject -Class Win32_OperatingSystem
$computer = Get-WmiObject -Class Win32_ComputerSystem
Write-Host "Sistema Operativo: $($os.Caption)" -ForegroundColor White
Write-Host "Versión: $($os.Version)" -ForegroundColor White
Write-Host "Último arranque: $($os.ConvertToDateTime($os.LastBootUpTime))" -ForegroundColor White
Write-Host "Tiempo activo: $((Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime))" -ForegroundColor White

# 4. Buscar y mostrar actualizaciones disponibles
Write-Host "`n4. BUSCANDO ACTUALIZACIONES DISPONIBLES..." -ForegroundColor Yellow
Write-Host "Esto puede tomar varios minutos..." -ForegroundColor Cyan

try {
    # Buscar actualizaciones con más detalle
    Write-Host "Buscando actualizaciones de Microsoft Update..." -ForegroundColor Cyan
    $updates = Get-WindowsUpdate -MicrosoftUpdate -Verbose
    
    if ($updates.Count -eq 0) {
        Write-Host "No se encontraron actualizaciones disponibles." -ForegroundColor Green
    } else {
        Write-Host "`n=== ACTUALIZACIONES DISPONIBLES ===" -ForegroundColor Green
        Write-Host "Total: $($updates.Count) actualizaciones encontradas" -ForegroundColor Cyan
        
        # Mostrar cada actualización con todos sus detalles
        $i = 1
        foreach ($update in $updates) {
            Write-Host "`n--- Actualización $i de $($updates.Count) ---" -ForegroundColor Magenta
            
            # Información básica
            if ($update.Title) {
                Write-Host "Título: $($update.Title)" -ForegroundColor Yellow
            }
            
            if ($update.KB) {
                Write-Host "KB: $($update.KB)" -ForegroundColor Cyan
            }
            
            if ($update.Size) {
                Write-Host "Tamaño: $([math]::Round($update.Size/1MB, 2)) MB" -ForegroundColor White
            }
            
            # Categorías y descripción
            if ($update.Categories) {
                Write-Host "Categorías: $($update.Categories -join ', ')" -ForegroundColor Gray
            }
            
            if ($update.Description) {
                Write-Host "Descripción: $($update.Description)" -ForegroundColor Gray
            }
            
            # Fechas e información adicional
            if ($update.MSRCSeverity) {
                Write-Host "Severidad: $($update.MSRCSeverity)" -ForegroundColor Red
            }
            
            if ($update.LastDeploymentChangeTime) {
                Write-Host "Último cambio: $($update.LastDeploymentChangeTime)" -ForegroundColor Gray
            }
            
            $i++
        }
        
        # Resumen por categorías
        Write-Host "`n=== RESUMEN POR TIPO ===" -ForegroundColor Green
        
        $securityUpdates = $updates | Where-Object {
            $_.Categories -like "*Security*" -or 
            $_.Categories -like "*Seguridad*" -or 
            $_.MSRCSeverity -or 
            $_.Title -like "*security*" -or 
            $_.Title -like "*seguridad*" -or
            $_.KB -like "KB*"
        }
        
        $driverUpdates = $updates | Where-Object {
            $_.Categories -like "*Driver*" -or 
            $_.Categories -like "*Controlador*" -or 
            $_.Title -like "*driver*" -or 
            $_.Title -like "*controlador*" -or
            $_.Title -like "*firmware*" -or
            $_.Title -like "*Firmware*"
        }
        
        $otherUpdates = $updates | Where-Object {
            $securityUpdates -notcontains $_ -and 
            $driverUpdates -notcontains $_
        }
        
        if ($securityUpdates.Count -gt 0) {
            Write-Host "`n--- ACTUALIZACIONES DE SEGURIDAD ($($securityUpdates.Count)) ---" -ForegroundColor Red
            $securityUpdates | ForEach-Object {
                $kb = if ($_.KB) { "KB$($_.KB)" } else { "Sin KB" }
                Write-Host "$kb: $($_.Title)" -ForegroundColor Yellow
            }
        }
        
        if ($driverUpdates.Count -gt 0) {
            Write-Host "`n--- CONTROLADORES Y FIRMWARE ($($driverUpdates.Count)) ---" -ForegroundColor Blue
            $driverUpdates | ForEach-Object {
                Write-Host "$($_.Title)" -ForegroundColor Cyan
            }
        }
        
        if ($otherUpdates.Count -gt 0) {
            Write-Host "`n--- OTRAS ACTUALIZACIONES ($($otherUpdates.Count)) ---" -ForegroundColor Magenta
            $otherUpdates | ForEach-Object {
                $kb = if ($_.KB) { "KB$($_.KB)" } else { "Sin KB" }
                Write-Host "$kb: $($_.Title)" -ForegroundColor Gray
            }
        }
        
        # Preguntar si instalar
        Write-Host "`n=== OPCIONES ===" -ForegroundColor Green
        $installChoice = Read-Host "¿Deseas instalar estas actualizaciones? (s/n)"
        
        if ($installChoice -eq 's') {
            Write-Host "Instalando actualizaciones..." -ForegroundColor Cyan
            Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot:$false -Verbose
            Write-Host "`n=== INSTALACIÓN COMPLETADA ===" -ForegroundColor Green
            Write-Host "Revisa si es necesario reiniciar manualmente." -ForegroundColor Yellow
            
            # Mostrar resultado final
            $installedUpdates = Get-WUHistory -Last 50 | Where-Object {$_.Result -eq "Installed"}
            if ($installedUpdates) {
                Write-Host "`n--- ÚLTIMAS ACTUALIZACIONES INSTALADAS ---" -ForegroundColor Green
                $installedUpdates | ForEach-Object {
                    Write-Host "$($_.Title) - $($_.Date)" -ForegroundColor White
                }
            }
        } else {
            Write-Host "Actualizaciones no instaladas. Puedes instalarlas manualmente luego con:" -ForegroundColor Yellow
            Write-Host "Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot:`$false" -ForegroundColor White
        }
    }
}
catch {
    Write-Host "Error al buscar actualizaciones: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Intentando método alternativo..." -ForegroundColor Yellow
    
    # Método alternativo básico
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $searchResult = $searcher.Search("IsInstalled=0")
        
        if ($searchResult.Updates.Count -gt 0) {
            Write-Host "Se encontraron $($searchResult.Updates.Count) actualizaciones (método alternativo):" -ForegroundColor Cyan
            foreach ($update in $searchResult.Updates) {
                Write-Host "- $($update.Title)" -ForegroundColor White
            }
        }
    }
    catch {
        Write-Host "No se pudieron obtener detalles de las actualizaciones." -ForegroundColor Red
    }
}

Write-Host "`n=== PROCESO COMPLETADO ===" -ForegroundColor Green
Write-Host "Script de preparación finalizado." -ForegroundColor Cyan
