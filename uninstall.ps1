#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter()]
    [string]$MSIPATH,
    
    [Parameter()]
    [string]$INSTALLFOLDER,
    
    [Parameter()]
    [ValidateSet("true", "false")]
    [string]$SILENT,
    
    [Parameter()]
    [ValidateSet("true", "false")]
    [string]$LOGGING
)

# Initialize variables
$ErrorActionPreference = "Stop"
$scriptName = "RustDesk Uninstallation"
$logFolder = "C:\Windows\Temp\RustDeskDeploymentScripts"
$exitCode = 0

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

# Function to validate true/false parameters
function Validate-BooleanParameter {
    param(
        [string]$Value,
        [string]$ParameterName
    )
    
    if ($Value -and $Value -notin @("true", "false")) {
        Write-LogMessage "Invalid value '$Value' for parameter $ParameterName. Expected 'true' or 'false'." -Level ERROR
        exit 1603
    }
}

# Function to get RustDesk product code
function Get-RustDeskProductCode {
    $rustDeskProducts = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*RustDesk*" }
    if ($rustDeskProducts) {
        return $rustDeskProducts[0].IdentifyingNumber
    }
    return $null
}

try {
    Write-ColorOutput "====================================" -Color Cyan
    Write-ColorOutput "  RustDesk Uninstallation Script    " -Color Cyan
    Write-ColorOutput "====================================" -Color Cyan
    Write-Host ""

    # Create log folder if it doesn't exist
    if (!(Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        Write-LogMessage "Created log folder: $logFolder"
    }

    # Load config.json if exists
    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = @{}
    
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            Write-LogMessage "Loaded configuration from config.json"
        } catch {
            Write-LogMessage "Failed to load config.json: $_" -Level WARNING
        }
    }

    # Merge parameters (CLI arguments take precedence)
    if (!$MSIPATH -and $config.MSIPATH) { $MSIPATH = $config.MSIPATH }
    if (!$INSTALLFOLDER -and $config.INSTALLFOLDER) { $INSTALLFOLDER = $config.INSTALLFOLDER }
    if (!$SILENT -and $config.SILENT) { $SILENT = $config.SILENT }
    if (!$LOGGING -and $config.LOGGING) { $LOGGING = $config.LOGGING }

    # Set defaults
    if (!$MSIPATH) {
        $MSIPATH = Get-ChildItem -Path $PSScriptRoot -Filter "*.msi" | Select-Object -First 1 -ExpandProperty FullName
    }

    # Default SILENT to true if not set
    if (!$SILENT) {
        $SILENT = "true"
    }

    # Enable logging
    $enableLogging = $LOGGING -eq "true"
    $logFile = Join-Path $logFolder "uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    if ($enableLogging) {
        Write-LogMessage "Logging enabled. Log file: $logFile"
    }

    # Validate boolean parameters
    Validate-BooleanParameter $SILENT "SILENT"
    Validate-BooleanParameter $LOGGING "LOGGING"

    # Build MSI command
    $msiArgs = @()
    
    # Try to uninstall using product code first
    Write-LogMessage "Searching for installed RustDesk..."
    $productCode = Get-RustDeskProductCode
    
    if ($productCode) {
        Write-LogMessage "Found RustDesk with product code: $productCode"
        $msiArgs = @("/x", $productCode)
    } elseif ($MSIPATH -and (Test-Path $MSIPATH)) {
        Write-LogMessage "Using MSI file for uninstallation: $MSIPATH"
        $msiArgs = @("/x", "`"$MSIPATH`"")
    } else {
        Write-LogMessage "RustDesk installation not found and no valid MSI path provided" -Level ERROR
        exit 1605  # This action is only valid for products that are currently installed
    }

    # Add silent flag if specified
    if ($SILENT -eq "true") {
        $msiArgs += "/qn"
        Write-LogMessage "Silent uninstallation mode enabled"
    } else {
        Write-LogMessage "Interactive uninstallation mode"
    }

    # Add installation folder if specified
    if ($INSTALLFOLDER) {
        $msiArgs += "INSTALLFOLDER=`"$INSTALLFOLDER`""
        Write-LogMessage "Install folder specified: $INSTALLFOLDER"
    }

    # Always add uninstall.log
    $msiLogPath = Join-Path $logFolder "msi_uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $msiArgs += "/l*v", "`"$msiLogPath`""
    Write-LogMessage "MSI log file: $msiLogPath"

    # Execute MSI uninstallation
    Write-LogMessage "Starting RustDesk uninstallation..."
    Write-LogMessage "Command: msiexec.exe $($msiArgs -join ' ')"
    
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode

    # Interpret exit codes
    switch ($exitCode) {
        0 { 
            Write-LogMessage "RustDesk uninstalled successfully!" -Level SUCCESS
        }
        1641 { 
            Write-LogMessage "RustDesk uninstalled successfully. A restart is required to complete the uninstallation." -Level SUCCESS
            $exitCode = 3010  # Standard Intune reboot required code
        }
        3010 { 
            Write-LogMessage "RustDesk uninstalled successfully. A restart is required to complete the uninstallation." -Level SUCCESS
        }
        1603 { 
            Write-LogMessage "Fatal error during uninstallation" -Level ERROR
        }
        1605 { 
            Write-LogMessage "This action is only valid for products that are currently installed" -Level ERROR
        }
        1619 { 
            Write-LogMessage "This installation package could not be opened" -Level ERROR
        }
        default { 
            if ($exitCode -ne 0) {
                Write-LogMessage "Uninstallation failed with exit code: $exitCode" -Level ERROR
            }
        }
    }

    # Verify uninstallation
    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
        Start-Sleep -Seconds 2
        $stillInstalled = Get-RustDeskProductCode
        if (!$stillInstalled) {
            Write-LogMessage "Verification: RustDesk has been successfully removed from the system" -Level SUCCESS
        } else {
            Write-LogMessage "Verification: RustDesk may still be installed. Please check manually." -Level WARNING
        }
    }

} catch {
    Write-LogMessage "An error occurred: $_" -Level ERROR
    $exitCode = 1603
} finally {
    Write-ColorOutput "====================================" -Color Cyan
    Write-LogMessage "Uninstallation script completed with exit code: $exitCode"
    exit $exitCode
}
