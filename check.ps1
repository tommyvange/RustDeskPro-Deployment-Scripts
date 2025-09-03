#Requires -RunAsAdministrator
[CmdletBinding()]
param()

# Initialize variables
$ErrorActionPreference = "Stop"
$scriptName = "RustDesk Installation Check"
$logFolder = "C:\Windows\Temp\RustDeskDeploymentScripts"
$exitCode = 0

# CONFIGURATION - Set these values directly in the script as needed
$enableLogging = $true  # Set to $true to enable logging, $false to disable
$checkRegistryPath = $true  # Check registry for installation
$checkFilePath = $true  # Check file system for installation
$expectedVersion = ""  # Leave empty to check for any version, or specify like "1.2.3"
$customName = ""  # Set to custom installation name, leave empty for "RustDesk"
$expectedInstallPath = "C:\Program Files\%customName%"  # Expected installation path with %customName% placeholder

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    Write-Host $Message -ForegroundColor $Color -NoNewline:$NoNewline
}

# Function to write log
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    if ($enableLogging) {
        Add-Content -Path $logFile -Value $logMessage -Force
    }
    
    switch ($Level) {
        "ERROR" { Write-ColorOutput $logMessage -Color Red }
        "WARNING" { Write-ColorOutput $logMessage -Color Yellow }
        "SUCCESS" { Write-ColorOutput $logMessage -Color Green }
        default { Write-ColorOutput $logMessage -Color White }
    }
}

# Function to replace %customName% placeholder
function Replace-CustomNamePlaceholder {
    param(
        [string]$Path,
        [string]$Name
    )
    
    return $Path -replace '%customName%', $Name
}

# Function to check registry for installation
function Check-RegistryInstallation {
    param(
        [string]$SearchName
    )
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $registryPaths) {
        $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DisplayName -like "*$SearchName*" }
        
        if ($items) {
            return $items[0]
        }
    }
    
    return $null
}

# Function to check WMI for installation
function Check-WMIInstallation {
    param(
        [string]$SearchName
    )
    
    try {
        $product = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | 
                   Where-Object { $_.Name -like "*$SearchName*" }
        
        if ($product) {
            return @{
                Name = $product.Name
                Version = $product.Version
                InstallLocation = $product.InstallLocation
                IdentifyingNumber = $product.IdentifyingNumber
            }
        }
    } catch {
        Write-LogMessage "WMI query failed: $_" -Level WARNING
    }
    
    return $null
}

# Function to check file system for installation
function Check-FileSystemInstallation {
    param(
        [string]$Path,
        [string]$ExecutableName
    )
    
    if (Test-Path $Path) {
        $exePath = Join-Path $Path "$ExecutableName.exe"
        if (Test-Path $exePath) {
            try {
                $fileInfo = Get-Item $exePath
                $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
                return @{
                    Path = $Path
                    ExecutablePath = $exePath
                    FileVersion = $versionInfo.FileVersion
                    ProductVersion = $versionInfo.ProductVersion
                    LastWriteTime = $fileInfo.LastWriteTime
                }
            } catch {
                Write-LogMessage "Failed to get file version info: $_" -Level WARNING
            }
        }
    }
    
    return $null
}

try {
    Write-ColorOutput "====================================" -Color Cyan
    Write-ColorOutput "  RustDesk Installation Check       " -Color Cyan
    Write-ColorOutput "====================================" -Color Cyan
    Write-Host ""

    # Set the actual name to search for (fallback to RustDesk if not set)
    $actualName = if ($customName) { $customName } else { "RustDesk" }
    
    # Replace placeholder in expected install path
    $expectedInstallPath = Replace-CustomNamePlaceholder -Path $expectedInstallPath -Name $actualName
    
    Write-ColorOutput "Checking for: $actualName" -Color Yellow
    Write-Host ""

    # Create log folder if it doesn't exist
    if ($enableLogging) {
        if (!(Test-Path $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        }
        $logFile = Join-Path $logFolder "check_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Write-LogMessage "Starting installation check for: $actualName"
        Write-LogMessage "Log file: $logFile"
    }

    $isInstalled = $false
    $installationDetails = @{}

    # Check registry
    if ($checkRegistryPath) {
        Write-LogMessage "Checking registry for $actualName installation..."
        $registryInfo = Check-RegistryInstallation -SearchName $actualName
        
        if ($registryInfo) {
            $isInstalled = $true
            $installationDetails.RegistryName = $registryInfo.DisplayName
            $installationDetails.RegistryVersion = $registryInfo.DisplayVersion
            $installationDetails.RegistryInstallLocation = $registryInfo.InstallLocation
            $installationDetails.RegistryUninstallString = $registryInfo.UninstallString
            
            Write-LogMessage "Found in registry: $($registryInfo.DisplayName) v$($registryInfo.DisplayVersion)" -Level SUCCESS
        } else {
            Write-LogMessage "Not found in registry"
        }
    }

    # Check WMI
    Write-LogMessage "Checking WMI for $actualName installation..."
    $wmiInfo = Check-WMIInstallation -SearchName $actualName
    
    if ($wmiInfo) {
        $isInstalled = $true
        $installationDetails.WMIName = $wmiInfo.Name
        $installationDetails.WMIVersion = $wmiInfo.Version
        $installationDetails.WMIProductCode = $wmiInfo.IdentifyingNumber
        
        Write-LogMessage "Found in WMI: $($wmiInfo.Name) v$($wmiInfo.Version)" -Level SUCCESS
    } else {
        Write-LogMessage "Not found in WMI"
    }

    # Check file system
    if ($checkFilePath) {
        Write-LogMessage "Checking file system for $actualName installation..."
        Write-LogMessage "Expected install path: $expectedInstallPath"
        
        # Check expected path
        $fileInfo = Check-FileSystemInstallation -Path $expectedInstallPath -ExecutableName $actualName
        
        # If not found in expected path, check all possible Program Files locations
        if (!$fileInfo) {
            $alternativePaths = @(
                "${env:ProgramFiles}\$actualName",
                "${env:ProgramFiles(x86)}\$actualName"
            )
            
            # Add ARM Program Files path if it exists
            $armProgramFiles = "${env:SystemDrive}\Program Files (Arm)"
            if (Test-Path $armProgramFiles) {
                $alternativePaths += "$armProgramFiles\$actualName"
                Write-LogMessage "Checking ARM Program Files location..."
            }
            
            # Also check for ARM64 specific paths
            $arm64ProgramFiles = "${env:ProgramFiles(Arm)}"
            if ($arm64ProgramFiles -and (Test-Path $arm64ProgramFiles)) {
                $alternativePaths += "$arm64ProgramFiles\$actualName"
            }
            
            # Also check common variations if custom name is not RustDesk
            if ($actualName -ne "RustDesk") {
                # Still check for RustDesk as fallback
                $alternativePaths += "${env:ProgramFiles}\RustDesk"
                $alternativePaths += "${env:ProgramFiles(x86)}\RustDesk"
                
                if (Test-Path $armProgramFiles) {
                    $alternativePaths += "$armProgramFiles\RustDesk"
                }
                
                if ($arm64ProgramFiles -and (Test-Path $arm64ProgramFiles)) {
                    $alternativePaths += "$arm64ProgramFiles\RustDesk"
                }
            }
            
            foreach ($altPath in $alternativePaths) {
                Write-LogMessage "Checking path: $altPath"
                
                # Determine which executable name to use based on path
                $exeName = if ($altPath -like "*RustDesk*" -and $actualName -ne "RustDesk") {
                    "RustDesk"
                } else {
                    $actualName
                }
                
                $fileInfo = Check-FileSystemInstallation -Path $altPath -ExecutableName $exeName
                if ($fileInfo) {
                    Write-LogMessage "Found installation at: $altPath" -Level SUCCESS
                    if ($exeName -ne $actualName) {
                        Write-LogMessage "Note: Found as '$exeName' instead of '$actualName'" -Level WARNING
                    }
                    break
                }
            }
        }
        
        if ($fileInfo) {
            $isInstalled = $true
            $installationDetails.FilePath = $fileInfo.Path
            $installationDetails.ExecutablePath = $fileInfo.ExecutablePath
            $installationDetails.FileVersion = $fileInfo.FileVersion
            
            Write-LogMessage "Found in file system: $($fileInfo.Path) v$($fileInfo.FileVersion)" -Level SUCCESS
        } else {
            Write-LogMessage "Not found in file system"
        }
    }

    # Version check if specified
    if ($isInstalled -and $expectedVersion) {
        $currentVersion = $installationDetails.RegistryVersion -or $installationDetails.WMIVersion -or $installationDetails.FileVersion
        
        if ($currentVersion -eq $expectedVersion) {
            Write-LogMessage "Version check passed: $currentVersion matches expected version $expectedVersion" -Level SUCCESS
        } else {
            Write-LogMessage "Version mismatch: Current version $currentVersion does not match expected version $expectedVersion" -Level WARNING
            $exitCode = 1  # Non-zero to indicate mismatch
        }
    }

    # Summary
    Write-Host ""
    Write-ColorOutput "====================================" -Color Cyan
    Write-ColorOutput "           SUMMARY                  " -Color Cyan
    Write-ColorOutput "====================================" -Color Cyan
    
    if ($isInstalled) {
        Write-LogMessage "$actualName IS INSTALLED on this system" -Level SUCCESS
        
        # Display details
        if ($installationDetails.RegistryName) {
            Write-LogMessage "  Registry Name: $($installationDetails.RegistryName)"
        }
        if ($installationDetails.RegistryVersion) {
            Write-LogMessage "  Version: $($installationDetails.RegistryVersion)"
        }
        if ($installationDetails.FilePath) {
            Write-LogMessage "  Install Path: $($installationDetails.FilePath)"
        }
        if ($installationDetails.WMIProductCode) {
            Write-LogMessage "  Product Code: $($installationDetails.WMIProductCode)"
        }
        
        # Check if it's an ARM installation
        if ($installationDetails.FilePath -and $installationDetails.FilePath -like "*Arm*") {
            Write-LogMessage "  Architecture: ARM" -Level WARNING
        }
        
        if ($exitCode -eq 0) {
            $exitCode = 0  # Installed and all checks passed
        }
    } else {
        Write-LogMessage "$actualName IS NOT INSTALLED on this system" -Level WARNING
        $exitCode = 1605  # This action is only valid for products that are currently installed
    }

} catch {
    Write-LogMessage "An error occurred during check: $_" -Level ERROR
    $exitCode = 1603
} finally {
    Write-ColorOutput "====================================" -Color Cyan
    if ($enableLogging) {
        Write-LogMessage "Check script completed with exit code: $exitCode"
    } else {
        Write-Host "Check script completed with exit code: $exitCode"
    }
    exit $exitCode
}
