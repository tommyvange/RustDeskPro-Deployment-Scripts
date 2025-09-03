#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter()]
    [string]$TOKEN,
    
    [Parameter()]
    [string]$CUSTOMNAME,
    
    [Parameter()]
    [string]$INSTALLFOLDER,
    
    [Parameter()]
    [ValidateSet("true", "false")]
    [string]$LOGGING,
    
    [Parameter()]
    [string]$ASSIGNMENTFILE
)

# Initialize variables
$ErrorActionPreference = "Stop"
$scriptName = "RustDesk Assignment"
$logFolder = "C:\Windows\Temp\RustDeskDeploymentScripts"
$exitCode = 0
$successCount = 0
$failureCount = 0

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

# Function to find RustDesk executable
function Get-RustDeskPath {
    param(
        [string]$CustomName,
        [string]$InstallFolder
    )
    
    $actualName = if ($CustomName) { $CustomName } else { "RustDesk" }
    
    # Check provided install folder first
    if ($InstallFolder) {
        $exePath = Join-Path $InstallFolder "$actualName.exe"
        if (Test-Path $exePath) {
            return $exePath
        }
    }
    
    # Check standard locations
    $searchPaths = @(
        "${env:ProgramFiles}\$actualName\$actualName.exe",
        "${env:ProgramFiles(x86)}\$actualName\$actualName.exe"
    )
    
    # Add ARM paths if they exist
    $armProgramFiles = "${env:SystemDrive}\Program Files (Arm)"
    if (Test-Path $armProgramFiles) {
        $searchPaths += "$armProgramFiles\$actualName\$actualName.exe"
    }
    
    $arm64ProgramFiles = "${env:ProgramFiles(Arm)}"
    if ($arm64ProgramFiles -and (Test-Path $arm64ProgramFiles)) {
        $searchPaths += "$arm64ProgramFiles\$actualName\$actualName.exe"
    }
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # If custom name specified but not found, try RustDesk as fallback
    if ($CustomName -and $CustomName -ne "RustDesk") {
        Write-LogMessage "Custom executable '$CustomName.exe' not found, trying RustDesk.exe as fallback" -Level WARNING
        return Get-RustDeskPath -CustomName "RustDesk" -InstallFolder $InstallFolder
    }
    
    return $null
}

# Function to execute RustDesk assignment command
function Invoke-RustDeskAssignment {
    param(
        [string]$ExePath,
        [string]$Token,
        [hashtable]$Parameters,
        [string]$Description
    )
    
    try {
        # Build command arguments
        $args = @("--assign", "--token", $Token)
        
        foreach ($key in $Parameters.Keys) {
            $args += "--$key"
            $args += $Parameters[$key]
        }
        
        Write-LogMessage "Executing: $Description"
        Write-LogMessage "Command: `"$ExePath`" $($args -join ' ')" 
        
        # Execute with output capture
        $process = Start-Process -FilePath $ExePath -ArgumentList $args -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\rustdesk_output.txt" -RedirectStandardError "$env:TEMP\rustdesk_error.txt"
        
        # Read output
        $output = Get-Content "$env:TEMP\rustdesk_output.txt" -ErrorAction SilentlyContinue
        $errorOutput = Get-Content "$env:TEMP\rustdesk_error.txt" -ErrorAction SilentlyContinue
        
        # Clean up temp files
        Remove-Item "$env:TEMP\rustdesk_output.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\rustdesk_error.txt" -Force -ErrorAction SilentlyContinue
        
        if ($output) {
            Write-LogMessage "Output: $($output -join ' ')"
        }
        
        if ($errorOutput) {
            Write-LogMessage "Error Output: $($errorOutput -join ' ')" -Level WARNING
        }
        
        if ($process.ExitCode -eq 0) {
            Write-LogMessage "Successfully assigned: $Description" -Level SUCCESS
            return $true
        } else {
            Write-LogMessage "Failed to assign: $Description (Exit Code: $($process.ExitCode))" -Level ERROR
            return $false
        }
    } catch {
        Write-LogMessage "Exception during assignment: $Description - $_" -Level ERROR
        return $false
    }
}

try {
    Write-ColorOutput "====================================" -Color Cyan
    Write-ColorOutput "   RustDesk Assignment Script       " -Color Cyan
    Write-ColorOutput "====================================" -Color Cyan
    Write-Host ""

    # Create log folder if it doesn't exist
    if (!(Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
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
    if (!$TOKEN -and $config.TOKEN) { $TOKEN = $config.TOKEN }
    if (!$CUSTOMNAME -and $config.CUSTOMNAME) { $CUSTOMNAME = $config.CUSTOMNAME }
    if (!$INSTALLFOLDER -and $config.INSTALLFOLDER) { $INSTALLFOLDER = $config.INSTALLFOLDER }
    if (!$LOGGING -and $config.LOGGING) { $LOGGING = $config.LOGGING }
    if (!$ASSIGNMENTFILE -and $config.ASSIGNMENTFILE) { $ASSIGNMENTFILE = $config.ASSIGNMENTFILE }

    # Set defaults
    if (!$ASSIGNMENTFILE) {
        $ASSIGNMENTFILE = Join-Path $PSScriptRoot "assignment.json"
    }

    # Enable logging
    $enableLogging = $LOGGING -eq "true"
    $logFile = Join-Path $logFolder "assign_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    if ($enableLogging) {
        Write-LogMessage "Logging enabled. Log file: $logFile"
    }

    # Validate boolean parameters
    Validate-BooleanParameter $LOGGING "LOGGING"

    # Validate TOKEN
    if (!$TOKEN) {
        Write-LogMessage "TOKEN is required but not provided" -Level ERROR
        exit 1603
    }

    Write-LogMessage "Token provided: $(if ($TOKEN) { 'Yes (hidden for security)' } else { 'No' })"

    # Find RustDesk executable
    Write-LogMessage "Searching for RustDesk executable..."
    $rustDeskPath = Get-RustDeskPath -CustomName $CUSTOMNAME -InstallFolder $INSTALLFOLDER
    
    if (!$rustDeskPath) {
        Write-LogMessage "RustDesk executable not found. Please ensure RustDesk is installed." -Level ERROR
        exit 1603
    }

    Write-LogMessage "Found RustDesk at: $rustDeskPath" -Level SUCCESS

    # Load assignment file
    if (!(Test-Path $ASSIGNMENTFILE)) {
        Write-LogMessage "Assignment file not found: $ASSIGNMENTFILE" -Level ERROR
        exit 1603
    }

    try {
        $assignments = Get-Content $ASSIGNMENTFILE -Raw | ConvertFrom-Json
        Write-LogMessage "Loaded assignments from: $ASSIGNMENTFILE" -Level SUCCESS
    } catch {
        Write-LogMessage "Failed to parse assignment file: $_" -Level ERROR
        exit 1603
    }

    # Initialize counters
    $totalAssignments = 0
    $groupCount = 0
    $addressBookCount = 0
    $tagCount = 0

    # Count total assignments
    if ($assignments.groups) {
        $groupCount = $assignments.groups.Count
        $totalAssignments += $groupCount
    }
    
    if ($assignments.addressBooks) {
        foreach ($ab in $assignments.addressBooks) {
            $addressBookCount++
            $totalAssignments++
            if ($ab.tags) {
                $tagCount += $ab.tags.Count
                $totalAssignments += $ab.tags.Count
            }
        }
    }

    Write-LogMessage "Found assignments: $groupCount groups, $addressBookCount address books, $tagCount tags"

    if ($totalAssignments -eq 0) {
        Write-LogMessage "No assignments found in configuration file" -Level WARNING
        exit 0
    }

    Write-Host ""
    Write-ColorOutput "Starting assignments..." -Color Yellow
    Write-Host ""

    # Process Groups
    if ($assignments.groups -and $assignments.groups.Count -gt 0) {
        Write-ColorOutput "=== Processing Groups ===" -Color Cyan
        Write-Host ""
        
        foreach ($groupObj in $assignments.groups) {
            if ($groupObj.group) {
                $params = @{
                    "device_group_name" = $groupObj.group
                }
                
                $success = Invoke-RustDeskAssignment `
                    -ExePath $rustDeskPath `
                    -Token $TOKEN `
                    -Parameters $params `
                    -Description "Group: $($groupObj.group)"
                
                if ($success) {
                    $successCount++
                } else {
                    $failureCount++
                }
                
                Start-Sleep -Milliseconds 500  # Small delay between API calls
            }
        }
        Write-Host ""
    }

    # Process Address Books
    if ($assignments.addressBooks -and $assignments.addressBooks.Count -gt 0) {
        Write-ColorOutput "=== Processing Address Books ===" -Color Cyan
        Write-Host ""
        
        foreach ($addressBookObj in $assignments.addressBooks) {
            if ($addressBookObj.addressBook) {
                # First, assign the address book without tags
                $params = @{
                    "address_book_name" = $addressBookObj.addressBook
                }
                
                $success = Invoke-RustDeskAssignment `
                    -ExePath $rustDeskPath `
                    -Token $TOKEN `
                    -Parameters $params `
                    -Description "Address Book: $($addressBookObj.addressBook)"
                
                if ($success) {
                    $successCount++
                } else {
                    $failureCount++
                }
                
                Start-Sleep -Milliseconds 500
                
                # Then process tags for this address book
                if ($addressBookObj.tags -and $addressBookObj.tags.Count -gt 0) {
                    Write-LogMessage "Processing tags for address book: $($addressBookObj.addressBook)"
                    
                    foreach ($tagObj in $addressBookObj.tags) {
                        if ($tagObj.tag) {
                            $params = @{
                                "address_book_name" = $addressBookObj.addressBook
                                "address_book_tag" = $tagObj.tag
                            }
                            
                            # Add alias if provided (requires server Pro >=1.5.8 and client >=1.4.1)
                            if ($tagObj.alias) {
                                $params["address_book_alias"] = $tagObj.alias
                            }
                            
                            $success = Invoke-RustDeskAssignment `
                                -ExePath $rustDeskPath `
                                -Token $TOKEN `
                                -Parameters $params `
                                -Description "Address Book: $($addressBookObj.addressBook), Tag: $($tagObj.tag)"
                            
                            if ($success) {
                                $successCount++
                            } else {
                                $failureCount++
                            }
                            
                            Start-Sleep -Milliseconds 500
                        }
                    }
                }
            }
        }
        Write-Host ""
    }

    # Summary
    Write-ColorOutput "====================================" -Color Cyan
    Write-ColorOutput "           SUMMARY                  " -Color Cyan
    Write-ColorOutput "====================================" -Color Cyan
    
    Write-LogMessage "Total assignments attempted: $totalAssignments"
    Write-LogMessage "Successful assignments: $successCount" -Level $(if ($successCount -gt 0) { "SUCCESS" } else { "INFO" })
    Write-LogMessage "Failed assignments: $failureCount" -Level $(if ($failureCount -gt 0) { "WARNING" } else { "INFO" })
    
    if ($failureCount -eq 0 -and $successCount -gt 0) {
        Write-LogMessage "All assignments completed successfully!" -Level SUCCESS
        $exitCode = 0
    } elseif ($successCount -eq 0 -and $failureCount -gt 0) {
        Write-LogMessage "All assignments failed!" -Level ERROR
        $exitCode = 1603
    } elseif ($successCount -gt 0 -and $failureCount -gt 0) {
        Write-LogMessage "Partial success: Some assignments failed" -Level WARNING
        $exitCode = 0  # Still return success if at least some worked
    } else {
        Write-LogMessage "No assignments were processed" -Level WARNING
        $exitCode = 0
    }

} catch {
    Write-LogMessage "An error occurred: $_" -Level ERROR
    $exitCode = 1603
} finally {
    Write-ColorOutput "====================================" -Color Cyan
    Write-LogMessage "Assignment script completed with exit code: $exitCode"
    exit $exitCode
}
