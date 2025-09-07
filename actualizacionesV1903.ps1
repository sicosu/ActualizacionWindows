# Script completo para actualizaciones de Windows con verificación TLS 1.2
# Requiere ejecutar PowerShell como Administrador

param(
    [switch]$InstallWingetFirst = $false
)

function Test-TLS12Supported {
    # Verificar si TLS 1.2 está habilitado a nivel de sistema
    $net40Path = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
    $net40WowPath = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
    
    $tlsEnabled = $true
    
    if (Test-Path $net40Path) {
        $schUseStrongCrypto = Get-ItemProperty -Path $net40Path -Name "SchUseStrongCrypto" -ErrorAction SilentlyContinue
        if ($schUseStrongCrypto -eq $null -or $schUseStrongCrypto.SchUseStrongCrypto -ne 1) {
            $tlsEnabled = $false
        }
    }
    
    if (Test-Path $net40WowPath) {
        $schUseStrongCryptoWow = Get-ItemProperty -Path $net40WowPath -Name "SchUseStrongCrypto" -ErrorAction SilentlyContinue
        if ($schUseStrongCryptoWow -eq $null -or $schUseStrongCryptoWow.SchUseStrongCrypto -ne 1) {
            $tlsEnabled = $false
        }
    }
    
    return $tlsEnabled
}

function Enable-TLS12Permanent {
    Write-Host "Habilitando TLS 1.2 permanentemente..." -ForegroundColor Yellow
    
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
    
    # Ejecutar archivo REG
    try {
        Start-Process -FilePath "reg.exe" -ArgumentList "import `"$regPath`"" -Wait -NoNewWindow
        Write-Host "TLS 1.2 habilitado permanentemente en el registro." -ForegroundColor Green
        Remove-Item -Path $regPath -Force
        return $true
    }
    catch {
        Write-Host "Error al aplicar el registro: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Install-NuGetProvider {
    Write-Host "Instalando proveedor NuGet..." -ForegroundColor Cyan
    try {
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop
        Write-Host "Proveedor NuGet instalado correctamente." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error instalando NuGet: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Install-PSWindowsUpdateModule {
    Write-Host "Instalando módulo PSWindowsUpdate..." -ForegroundColor Cyan
    
    try {
        Set-ExecutionPolicy Unrestricted -Force -ErrorAction Stop
        Register-PSRepository -Default -ErrorAction SilentlyContinue
        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Write-Host "Módulo PSWindowsUpdate ya está instalado." -ForegroundColor Green
            return $true
        }
        
        Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
        Import-Module PSWindowsUpdate -Force
        Write-Host "Módulo PSWindowsUpdate instalado correctamente." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error instalando PSWindowsUpdate: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Install-Winget {
    Write-Host "Instalando Winget..." -ForegroundColor Cyan
    try {
        # Intentar instalar winget desde Microsoft Store
        $wingetCheck = Get-Command -Name winget -ErrorAction SilentlyContinue
        if ($wingetCheck) {
            Write-Host "Winget ya está instalado." -ForegroundColor Green
            return $true
        }
        
        # Método alternativo para instalar winget
        Write-Host "Descargando e instalando Winget..." -ForegroundColor Yellow
        $wingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $wingetPath = "$env:TEMP\winget.msixbundle"
        
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetPath -UseBasicParsing
        Add-AppxPackage -Path $wingetPath -ErrorAction Stop
        
        Remove-Item -Path $wingetPath -Force
        Write-Host "Winget instalado correctamente." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error instalando Winget: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Puedes instalar Winget manualmente desde Microsoft Store" -ForegroundColor Yellow
        return $false
    }
}

function Install-WindowsUpdates {
    Write-Host "Iniciando búsqueda e instalación de actualizaciones..." -ForegroundColor Cyan
    
    try {
        # Habilitar TLS 1.2 para esta sesión
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Usar PSWindowsUpdate para mejor visualización del progreso
        Get-WUInstall -MicrosoftUpdate -AcceptAll -AutoReboot:$false -Verbose
        
        Write-Host "Proceso de actualización completado." -ForegroundColor Green
        Write-Host "Por favor, revisa si es necesario reiniciar manualmente." -ForegroundColor Yellow
        return $true
    }
    catch {
        Write-Host "Error durante la actualización: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# --- EJECUCIÓN PRINCIPAL ---
Write-Host "=== SCRIPT DE ACTUALIZACIÓN DE WINDOWS ===" -ForegroundColor Green
Write-Host "Verificando estado del sistema..." -ForegroundColor Cyan

# 1. Verificar TLS 1.2
$tlsSupported = Test-TLS12Supported
if (-not $tlsSupported) {
    Write-Host "TLS 1.2 no está habilitado. Es necesario habilitarlo para continuar." -ForegroundColor Yellow
    $enableTLS = Read-Host "¿Deseas habilitar TLS 1.2 permanentemente? (s/n)"
    
    if ($enableTLS -eq 's') {
        $tlsResult = Enable-TLS12Permanent
        if ($tlsResult) {
            Write-Host "Se requiere reinicio para aplicar los cambios de TLS 1.2." -ForegroundColor Yellow
            $rebootNow = Read-Host "¿Reiniciar ahora? (s/n)"
            if ($rebootNow -eq 's') {
                Restart-Computer -Force
                exit
            }
        }
    } else {
        Write-Host "Continuando con TLS 1.2 temporal para esta sesión..." -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
} else {
    Write-Host "TLS 1.2 ya está habilitado. Continuando..." -ForegroundColor Green
}

# 2. Instalar Winget si se solicita
if ($InstallWingetFirst) {
    Write-Host "Instalando Winget primero..." -ForegroundColor Cyan
    Install-Winget
}

# 3. Configurar entorno PowerShell
Write-Host "Configurando entorno PowerShell..." -ForegroundColor Cyan
Install-NuGetProvider
$moduleResult = Install-PSWindowsUpdateModule

if (-not $moduleResult) {
    Write-Host "No se pudo instalar PSWindowsUpdate. Usando método alternativo..." -ForegroundColor Yellow
    # Aquí podrías agregar el método alternativo del primer script si lo prefieres
}

# 4. Instalar actualizaciones
Write-Host "Iniciando proceso de actualización..." -ForegroundColor Green
Install-WindowsUpdates

Write-Host "`n=== PROCESO COMPLETADO ===" -ForegroundColor Green
Write-Host "Revisa si necesitas reiniciar manualmente." -ForegroundColor Yellow
