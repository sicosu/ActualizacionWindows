# Script de actualizaciones de Windows para versiones 1903 y posteriores
# Requiere ejecutar PowerShell como Administrador

Write-Host "=== SCRIPT DE ACTUALIZACIONES DE WINDOWS ===" -ForegroundColor Green
Write-Host "Para versiones 1903 y posteriores - TLS 1.2 no requerido" -ForegroundColor Cyan

# 1. Configurar PowerShell y instalar módulos necesarios
Write-Host "`n1. CONFIGURANDO POWERSHELL..." -ForegroundColor Yellow

try {
    Write-Host "Instalando proveedor NuGet..." -ForegroundColor Cyan
    Install-PackageProvider -Name NuGet -Force -ErrorAction Stop
    Write-Host "NuGet instalado correctamente." -ForegroundColor Green
    
    Write-Host "Configurando políticas de ejecución..." -ForegroundColor Cyan
    Set-ExecutionPolicy Unrestricted -Scope Process -Force -ErrorAction Stop
    
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

# 2. Mostrar información del sistema
Write-Host "`n2. INFORMACIÓN DEL SISTEMA:" -ForegroundColor Yellow
$os = Get-WmiObject -Class Win32_OperatingSystem
$computer = Get-WmiObject -Class Win32_ComputerSystem
Write-Host "Sistema Operativo: $($os.Caption)" -ForegroundColor White
Write-Host "Versión: $($os.Version)" -ForegroundColor White
Write-Host "Último arranque: $($os.ConvertToDateTime($os.LastBootUpTime))" -ForegroundColor White
Write-Host "Tiempo activo: $((Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime))" -ForegroundColor White

# 3. Buscar y mostrar actualizaciones disponibles
Write-Host "`n3. BUSCANDO ACTUALIZACIONES DISPONIBLES..." -ForegroundColor Yellow
Write-Host "Esto puede tomar varios minutos..." -ForegroundColor Cyan

try {
    # Buscar actualizaciones
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
            
            if ($update.Title) {
                Write-Host "Título: $($update.Title)" -ForegroundColor Yellow
            }
            
            if ($update.KB) {
                Write-Host "KB: $($update.KB)" -ForegroundColor Cyan
            }
            
            if ($update.Size) {
                Write-Host "Tamaño: $([math]::Round($update.Size/1MB, 2)) MB" -ForegroundColor White
            }
            
            if ($update.Categories) {
                Write-Host "Categorías: $($update.Categories -join ', ')" -ForegroundColor Gray
            }
            
            if ($update.MSRCSeverity) {
                Write-Host "Severidad: $($update.MSRCSeverity)" -ForegroundColor Red
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
            $_.Title -like "*firmware*"
        }
        
        $otherUpdates = $updates | Where-Object {
            $securityUpdates -notcontains $_ -and 
            $driverUpdates -notcontains $_
        }
        
        if ($securityUpdates.Count -gt 0) {
            Write-Host "`n--- ACTUALIZACIONES DE SEGURIDAD ($($securityUpdates.Count)) ---" -ForegroundColor Red
            $securityUpdates | ForEach-Object {
                $kb = if ($_.KB) { "KB$($_.KB)" } else { "Sin KB" }
                Write-Host "$($kb): $($_.Title)" -ForegroundColor Yellow
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
                Write-Host "$($kb): $($_.Title)" -ForegroundColor Gray
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
        } else {
            Write-Host "Actualizaciones no instaladas. Puedes instalarlas manualmente luego con:" -ForegroundColor Yellow
            Write-Host "Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot:`$false" -ForegroundColor White
        }
    }
}
catch {
    Write-Host "Error al buscar actualizaciones: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== PROCESO COMPLETADO ===" -ForegroundColor Green
