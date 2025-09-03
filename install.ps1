#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter()]
    [string]$INSTALLFOLDER,
    
    [Parameter()]
    [ValidateSet("true", "false")]
    [string]$CREATESTARTMENUSHORTCUTS,
    
    [Parameter()]
    [ValidateSet("true", "false")]
    [string]$CREATEDESKTOPSHORTCUTS,
    
    [Parameter()]
    [ValidateSet("true", "false")]
    [string]$INSTALLPRINTER,
    
    [Parameter()]
    [ValidateSet("true", "false")]
    [string]$SILENT,
    
    [Parameter()]
    [string]$MSIPATH,
    
    [Parameter()]
    [ValidateSet("true", "false")]
    [string]$UPGRADE,
    
    [Parameter()]
    [ValidateSet("true", "false")]
    [string]$LOGGING
)

# Initialize variables
$ErrorActionPreference = "Stop"
$scriptName = "RustDesk Installation"
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

# Function to convert boolean string to MSI value
function Convert-ToMSIValue {
    param(
        [string]$Value
    )
    
    if ($Value -eq "true") {
        return "Y"
    } elseif ($Value -eq "false") {
        return "N"
    }
    return $null
}

try {
    Write-ColorOutput "====================================" -Color Cyan
    Write-ColorOutput "   RustDesk Installation Script     " -Color Cyan
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
    if (!$INSTALLFOLDER -and $config.INSTALLFOLDER) { $INSTALLFOLDER = $config.INSTALLFOLDER }
    if (!$CREATESTARTMENUSHORTCUTS -and $config.CREATESTARTMENUSHORTCUTS) { $CREATESTARTMENUSHORTCUTS = $config.CREATESTARTMENUSHORTCUTS }
    if (!$CREATEDESKTOPSHORTCUTS -and $config.CREATEDESKTOPSHORTCUTS) { $CREATEDESKTOPSHORTCUTS = $config.CREATEDESKTOPSHORTCUTS }
    if (!$INSTALLPRINTER -and $config.INSTALLPRINTER) { $INSTALLPRINTER = $config.INSTALLPRINTER }
    if (!$SILENT -and $config.SILENT) { $SILENT = $config.SILENT }
    if (!$MSIPATH -and $config.MSIPATH) { $MSIPATH = $config.MSIPATH }
    if (!$UPGRADE -and $config.UPGRADE) { $UPGRADE = $config.UPGRADE }
    if (!$LOGGING -and $config.LOGGING) { $LOGGING = $config.LOGGING }

    # Set defaults
    if (!$MSIPATH) {
        $MSIPATH = Get-ChildItem -Path $PSScriptRoot -Filter "*.msi" | Select-Object -First 1 -ExpandProperty FullName
        if (!$MSIPATH) {
            Write-LogMessage "No MSI file found in script directory" -Level ERROR
            exit 1603
        }
    }

    # Enable logging
    $enableLogging = $LOGGING -eq "true"
    $logFile = Join-Path $logFolder "install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    if ($enableLogging) {
        Write-LogMessage "Logging enabled. Log file: $logFile"
    }

    # Validate MSI path
    if (!(Test-Path $MSIPATH)) {
        Write-LogMessage "MSI file not found: $MSIPATH" -Level ERROR
        exit 1603
    }

    Write-LogMessage "MSI Path: $MSIPATH"

    # Validate boolean parameters
    Validate-BooleanParameter $CREATESTARTMENUSHORTCUTS "CREATESTARTMENUSHORTCUTS"
    Validate-BooleanParameter $CREATEDESKTOPSHORTCUTS "CREATEDESKTOPSHORTCUTS"
    Validate-BooleanParameter $INSTALLPRINTER "INSTALLPRINTER"
    Validate-BooleanParameter $SILENT "SILENT"
    Validate-BooleanParameter $UPGRADE "UPGRADE"
    Validate-BooleanParameter $LOGGING "LOGGING"

    # Build MSI command
    $msiArgs = @("/i", "`"$MSIPATH`"")
    
    # Add silent flag if specified
    if ($SILENT -eq "true") {
        $msiArgs += "/qn"
        Write-LogMessage "Silent installation mode enabled"
    }

    # Add installation parameters
    if ($INSTALLFOLDER) {
        $msiArgs += "INSTALLFOLDER=`"$INSTALLFOLDER`""
        Write-LogMessage "Install folder: $INSTALLFOLDER"
    }

    $startMenuValue = Convert-ToMSIValue $CREATESTARTMENUSHORTCUTS
    if ($startMenuValue) {
        $msiArgs += "CREATESTARTMENUSHORTCUTS=`"$startMenuValue`""
        Write-LogMessage "Create start menu shortcuts: $CREATESTARTMENUSHORTCUTS"
    }

    $desktopValue = Convert-ToMSIValue $CREATEDESKTOPSHORTCUTS
    if ($desktopValue) {
        $msiArgs += "CREATEDESKTOPSHORTCUTS=`"$desktopValue`""
        Write-LogMessage "Create desktop shortcuts: $CREATEDESKTOPSHORTCUTS"
    }

    $printerValue = Convert-ToMSIValue $INSTALLPRINTER
    if ($printerValue) {
        $msiArgs += "INSTALLPRINTER=`"$printerValue`""
        Write-LogMessage "Install printer: $INSTALLPRINTER"
    }

    # Always add install.log
    $msiLogPath = Join-Path $logFolder "msi_install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $msiArgs += "/l*v", "`"$msiLogPath`""
    Write-LogMessage "MSI log file: $msiLogPath"

    # Display installation type
    if ($UPGRADE -eq "true") {
        Write-LogMessage "Performing upgrade installation" -Level WARNING
    } else {
        Write-LogMessage "Performing new installation"
    }

    # Execute MSI installation
    Write-LogMessage "Starting RustDesk installation..."
    Write-LogMessage "Command: msiexec.exe $($msiArgs -join ' ')"
    
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode

    # Interpret exit codes
    switch ($exitCode) {
        0 { 
            Write-LogMessage "RustDesk installed successfully!" -Level SUCCESS
        }
        1641 { 
            Write-LogMessage "RustDesk installed successfully. A restart is required to complete the installation." -Level SUCCESS
            $exitCode = 3010  # Standard Intune reboot required code
        }
        3010 { 
            Write-LogMessage "RustDesk installed successfully. A restart is required to complete the installation." -Level SUCCESS
        }
        1603 { 
            Write-LogMessage "Fatal error during installation" -Level ERROR
        }
        1619 { 
            Write-LogMessage "This installation package could not be opened" -Level ERROR
        }
        1638 { 
            Write-LogMessage "Another version of this product is already installed" -Level ERROR
        }
        default { 
            if ($exitCode -ne 0) {
                Write-LogMessage "Installation failed with exit code: $exitCode" -Level ERROR
            }
        }
    }

} catch {
    Write-LogMessage "An error occurred: $_" -Level ERROR
    $exitCode = 1603
} finally {
    Write-ColorOutput "====================================" -Color Cyan
    Write-LogMessage "Installation script completed with exit code: $exitCode"
    exit $exitCode
}
