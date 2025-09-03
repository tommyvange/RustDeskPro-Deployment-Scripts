
# RustDeskPro Deployment Scripts for Windows

Enterprise-grade PowerShell deployment automation for RustDeskPro and custom-branded MSI packages

Take a look at my script and guide for installing RustDesk Server Pro with websockets (WSS), its called [RustDeskPro-WSS](https://github.com/tommyvange/RustDeskPro-WSS).

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Configuration Files](#configuration-files)
   - [config.json](#configjson)
   - [assignment.json](#assignmentjson)
5. [Scripts Documentation](#scripts-documentation)
   - [install.ps1](#installps1)
   - [uninstall.ps1](#uninstallps1)
   - [check.ps1](#checkps1)
   - [assign.ps1](#assignps1)
6. [Deployment Workflows](#deployment-workflows)
7. [Microsoft Intune Integration](#microsoft-intune-integration)
8. [Assignment Configuration Guide](#assignment-configuration-guide)
9. [Logging and Troubleshooting](#logging-and-troubleshooting)
10. [Security Best Practices](#security-best-practices)
11. [Advanced Scenarios](#advanced-scenarios)
12. [Common Issues and Solutions](#common-issues-and-solutions)
13. [Technical Details](#technical-details)
14. [Support and Contributing](#support-and-contributing)

---

## Overview

This repository provides a comprehensive deployment solution for RustDesk, designed specifically for enterprise environments. The scripts handle the complete lifecycle of RustDesk deployment including installation, configuration, device assignment to groups and address books, uninstallation, and compliance verification.

### Key Features

- **Complete MSI Lifecycle Management**: Automated installation, upgrade, and removal processes
- **Device Assignment Automation**: Automatic assignment to groups and address books post-installation
- **Multi-language Support**: Full UTF-8 support for international characters (Nordic, European, Asian)
- **Custom Branding Support**: Works with rebranded RustDesk MSI packages
- **Enterprise Logging**: Comprehensive dual-layer logging (script logs + MSI verbose logs)
- **Intune Integration**: Designed for Microsoft Intune and Configuration Manager deployments
- **ARM64 Support**: Full support for ARM-based Windows devices
- **Flexible Configuration**: JSON-based configuration with CLI override capabilities

### Components Overview

| Component | Type | Purpose |
|-----------|------|---------|
| **install.ps1** | PowerShell Script | Handles MSI installation with parameters and optional device assignment |
| **uninstall.ps1** | PowerShell Script | Manages clean removal via product code or MSI |
| **check.ps1** | PowerShell Script | Detection script for compliance and verification |
| **assign.ps1** | PowerShell Script | Assigns devices to groups and address books via API |
| **config.json** | Configuration File | Default settings for all scripts |
| **assignment.json** | Configuration File | Defines group and address book assignments |

---

## Prerequisites

### System Requirements

- **Operating System**: Windows 10/11, Windows Server 2016 or later
- **PowerShell**: Version 5.1 or later (64-bit recommended)
- **Privileges**: Administrator rights required
- **Network**: Access to RustDesk server API endpoints

### RustDesk Server Requirements

- **RustDesk Server Pro**: Required for API token functionality
- **Version Requirements**:
  - Server Pro 1.5.8 or later for address book alias support
  - Client 1.4.1 or later for full feature compatibility
- **API Token**: Must be generated with Read/Write permissions for Devices and Groups

### API Token Generation

1. Log into your RustDesk Server Pro web console
2. Navigate to **Settings → Tokens**
3. Click **Create** to generate a new token
4. Set the following permissions:
   - **Devices**: Read/Write
   - **Groups**: Read/Write
5. Copy and securely store the generated token
6. Use this token in the TOKEN parameter of the scripts

---

## Installation

### Quick Start

1. **Download the Scripts**
   ```powershell
   git clone https://github.com/tommyvange/rustdesk-deployment-scripts.git
   cd rustdesk-deployment-scripts
   ```

2. **Place Your MSI File**
   - Copy your RustDesk MSI installer to the scripts directory
   - The script will auto-detect the first .msi file if MSIPATH is not specified

3. **Configure Settings** (Optional)
   - Edit `config.json` for default parameters
   - Edit `assignment.json` for group and address book assignments

4. **Run Installation**
   ```powershell
   .\install.ps1 -SILENT "true" -LOGGING "true"
   ```

### Directory Structure

```
RustDesk-Deployment/
├── install.ps1              # Main installation script
├── uninstall.ps1            # Uninstallation script
├── check.ps1                # Detection/verification script
├── assign.ps1               # Assignment automation script
├── config.json              # Configuration defaults
├── assignment.json          # Assignment definitions
├── RustDesk.msi             # MSI installer (example)
└── README.md                # Documentation
```

---

## Configuration Files

### config.json

The main configuration file that provides default values for all script parameters. Command-line arguments always override these defaults.

**NOTE: When deploying with Intune I recommend setting the TOKEN variable directly as a CLI-argument instead of leaving it in the config.**

#### Configuration Structure

```json
{
    "INSTALLFOLDER": "",
    "CREATESTARTMENUSHORTCUTS": "true",
    "CREATEDESKTOPSHORTCUTS": "false",
    "INSTALLPRINTER": "false",
    "SILENT": "true",
    "MSIPATH": "",
    "UPGRADE": "false",
    "LOGGING": "true",
    "ASSIGN": "false",
    "TOKEN": "",
    "CUSTOMNAME": "",
    "ASSIGNMENTFILE": ""
}
```

#### Configuration Parameters Explained

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **INSTALLFOLDER** | String | Empty | Custom installation directory. If empty, uses MSI default |
| **CREATESTARTMENUSHORTCUTS** | Boolean String | Empty | Create Start Menu shortcuts ("true"/"false") |
| **CREATEDESKTOPSHORTCUTS** | Boolean String | Empty | Create Desktop shortcuts ("true"/"false") |
| **INSTALLPRINTER** | Boolean String | Empty | Install RustDesk virtual printer ("true"/"false") |
| **SILENT** | Boolean String | "true" | Run installation silently without user interaction |
| **MSIPATH** | String | Empty | Full path to MSI file. If empty, auto-detects in script directory |
| **UPGRADE** | Boolean String | "false" | Indicates this is an upgrade installation |
| **LOGGING** | Boolean String | "true" | Enable detailed script logging |
| **ASSIGN** | Boolean String | "false" | Run assignment script after successful installation |
| **TOKEN** | String | Empty | API token for RustDesk server (required for assignments) |
| **CUSTOMNAME** | String | Empty | Custom executable name for branded builds |
| **ASSIGNMENTFILE** | String | Empty | Path to custom assignment.json file |

#### Example Configurations

**Minimal Silent Installation:**
```json
{
    "SILENT": "true",
    "LOGGING": "true"
}
```

**Full Corporate Deployment:**
```json
{
    "INSTALLFOLDER": "",
    "CREATESTARTMENUSHORTCUTS": "true",
    "CREATEDESKTOPSHORTCUTS": "false",
    "INSTALLPRINTER": "false",
    "SILENT": "true",
    "LOGGING": "true",
    "ASSIGN": "true",
    "TOKEN": "your-api-token-here",
    "CUSTOMNAME": "CompanyRemote"
}
```

### assignment.json

Defines the device group and address books to assign after installation. Supports UTF-8 characters for international deployments.

#### Assignment Structure

```json
{
    "group": "Group Name",
    "addressBooks": [
        {
            "addressBook": "Address Book Name",
            "alias": "Optional Display Alias",
            "tags": [
                {
                    "tag": "Tag Name"
                }
            ]
        }
    ]
}
```

#### Assignment Rules and Limitations

- **Group**: Only one group can be assigned per device (RustDesk limitation)
- **Address Books**: Multiple address books can be assigned
- **Alias**: One optional alias per address book (requires Server Pro 1.5.8+)
- **Tags**: Must belong to a parent address book
- **UTF-8 Support**: Full support for international characters

#### Example Assignments

**Simple Department Assignment:**
```json
{
    "group": "IT Support",
    "addressBooks": []
}
```

**Complex Enterprise Structure:**
```json
{
    "group": "Europe Region",
    "addressBooks": [
        {
            "addressBook": "Corporate Directory",
            "alias": "All Employees",
            "tags": [
                {
                    "tag": "Executives"
                },
                {
                    "tag": "Managers"
                },
                {
                    "tag": "Staff"
                }
            ]
        },
        {
            "addressBook": "IT Infrastructure",
            "alias": "Servers & Systems",
            "tags": [
                {
                    "tag": "Windows Servers"
                },
                {
                    "tag": "Linux Servers"
                },
                {
                    "tag": "Network Devices"
                }
            ]
        },
        {
            "addressBook": "Support Queue",
            "tags": []
        }
    ]
}
```

---

## Scripts Documentation

**NOTE: If you set the parameters in the config, they are not needed here.**
**NOTE: Direct CLI-parameters have a higher priority than the variables inside the config.**
**NOTE: The check.ps1 script does not use the config, and only accepts parameters set as variables inside the file itself.**

### install.ps1

The primary installation script that handles MSI deployment with extensive customization options.

#### Parameters

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| INSTALLFOLDER | No | String | Custom installation path |
| CREATESTARTMENUSHORTCUTS | No | Boolean String | Enable/disable Start Menu shortcuts |
| CREATEDESKTOPSHORTCUTS | No | Boolean String | Enable/disable Desktop shortcuts |
| INSTALLPRINTER | No | Boolean String | Install virtual printer driver |
| SILENT | No | Boolean String | Silent installation mode |
| MSIPATH | No | String | Path to MSI file |
| UPGRADE | No | Boolean String | Upgrade mode flag |
| LOGGING | No | Boolean String | Enable script logging |
| ASSIGN | No | Boolean String | Run assignment after installation |
| TOKEN | Conditional | String | API token (required if ASSIGN="true") |
| CUSTOMNAME | No | String | Custom executable name |
| ASSIGNMENTFILE | No | String | Custom assignment file path |

#### Usage Examples

**Basic Installation:**
```powershell
.\install.ps1 -SILENT "true" -LOGGING "true"
```

**Custom Installation Path:**
```powershell
.\install.ps1 `
    -INSTALLFOLDER "D:\Programs\RustDesk" `
    -SILENT "true" `
    -LOGGING "true"
```

**Installation with Assignment:**
```powershell
.\install.ps1 `
    -SILENT "true" `
    -ASSIGN "true" `
    -TOKEN "api_1234567890abcdef" `
    -LOGGING "true"
```

**Full Custom Deployment:**
```powershell
.\install.ps1 `
    -INSTALLFOLDER "C:\Corporate\RemoteAccess" `
    -CREATESTARTMENUSHORTCUTS "true" `
    -CREATEDESKTOPSHORTCUTS "false" `
    -INSTALLPRINTER "false" `
    -SILENT "true" `
    -MSIPATH "\\fileserver\software\RustDesk-1.3.9.msi" `
    -ASSIGN "true" `
    -TOKEN "api_1234567890abcdef" `
    -CUSTOMNAME "CompanyRemote" `
    -ASSIGNMENTFILE ".\configs\production-assignment.json" `
    -LOGGING "true"
```

#### Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | Installation completed successfully |
| 3010 | Success with Reboot | Installation successful, reboot required |
| 1603 | Fatal Error | Installation failed |
| 1619 | Package Error | MSI package could not be opened |
| 1638 | Version Conflict | Another version already installed |

### uninstall.ps1

Handles clean removal of RustDesk installations.

#### Parameters

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| MSIPATH | No | String | MSI path for uninstall (fallback method) |
| INSTALLFOLDER | No | String | Original installation directory |
| SILENT | No | Boolean String | Silent uninstallation |
| LOGGING | No | Boolean String | Enable script logging |

#### Usage Examples

**Standard Uninstall:**
```powershell
.\uninstall.ps1 -SILENT "true" -LOGGING "true"
```

**Uninstall with MSI:**
```powershell
.\uninstall.ps1 `
    -MSIPATH ".\RustDesk-1.3.9.msi" `
    -SILENT "true" `
    -LOGGING "true"
```

### check.ps1

Standalone detection script for verification and compliance checking.

#### Configuration Variables (Edit in Script)

```powershell
$enableLogging = $true                    # Enable/disable logging
$checkRegistryPath = $true                # Check Windows registry
$checkFilePath = $true                    # Check file system
$expectedVersion = ""                     # Expected version (empty = any)
$customName = ""                          # Custom name (empty = "RustDesk")
$expectedInstallPath = "C:\Program Files\%customName%"  # Path with placeholder
```

#### Detection Methods

1. **Registry Check**: Scans uninstall registry keys
2. **WMI Query**: Queries Win32_Product class
3. **File System**: Verifies executable presence and version

#### Usage Example

```powershell
# Run detection
.\check.ps1

# Check for specific version
# Edit script: $expectedVersion = "1.3.9"
.\check.ps1
```

### assign.ps1

Manages device assignment to groups and address books via RustDesk API.

#### Parameters

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| TOKEN | Yes | String | RustDesk API token |
| CUSTOMNAME | No | String | Custom executable name |
| INSTALLFOLDER | No | String | Installation directory |
| LOGGING | No | Boolean String | Enable logging |
| ASSIGNMENTFILE | No | String | Assignment configuration path |

#### Usage Examples

**Basic Assignment:**
```powershell
.\assign.ps1 `
    -TOKEN "api_1234567890abcdef" `
    -LOGGING "true"
```

**Custom Configuration:**
```powershell
.\assign.ps1 `
    -TOKEN "api_1234567890abcdef" `
    -ASSIGNMENTFILE ".\configs\branch-office.json" `
    -CUSTOMNAME "CompanyRemote" `
    -LOGGING "true"
```

#### Assignment Process Flow

1. **Group Assignment**: Assigns single device group (if specified)
2. **Address Book Creation**: Creates/assigns address books
3. **Alias Application**: Sets display aliases for address books
4. **Tag Assignment**: Assigns tags within their parent address books

---

## Deployment Workflows

### Standard Deployment Workflow

1. **Preparation Phase**
   - Download scripts and place in deployment directory
   - Copy RustDesk MSI to the same directory
   - Configure `config.json` with organization defaults
   - Create `assignment.json` with group/address book structure
   - Generate API token from RustDesk server

2. **Testing Phase**
   ```powershell
   # Test installation on single machine
   .\install.ps1 -SILENT "true" -LOGGING "true"
   
   # Verify installation
   .\check.ps1
   
   # Test assignment separately
   .\assign.ps1 -TOKEN "your-token" -LOGGING "true"
   ```

3. **Production Deployment**
   ```powershell
   # Full deployment with assignment
   .\install.ps1 `
       -SILENT "true" `
       -ASSIGN "true" `
       -TOKEN "your-token" `
       -LOGGING "true"
   ```

### Upgrade Workflow

```powershell
# Upgrade existing installation
.\install.ps1 `
    -UPGRADE "true" `
    -SILENT "true" `
    -MSIPATH "\\server\share\RustDesk-NewVersion.msi" `
    -LOGGING "true"
```

### Removal Workflow

```powershell
# Complete removal
.\uninstall.ps1 -SILENT "true" -LOGGING "true"
```

---

## Microsoft Intune Integration

### Creating the Intune Package

1. **Prepare Package Directory**
   ```
   RustDesk-Intune/
   ├── install.ps1
   ├── uninstall.ps1
   ├── check.ps1
   ├── assign.ps1
   ├── config.json
   ├── assignment.json
   └── RustDesk-1.3.9.msi
   ```

2. **Create IntuneWin Package**
   ```powershell
   IntuneWinAppUtil.exe `
       -c ".\RustDesk-Intune" `
       -s "install.ps1" `
       -o ".\Output" `
       -q
   ```

### Intune App Configuration

#### Basic Information
- **Name**: RustDesk Remote Desktop
- **Description**: Enterprise remote desktop solution
- **Publisher**: RustDesk

#### Install Commands

**Without Assignment:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
```

**With Assignment:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -TOKEN "your-token"
```

#### Uninstall Command
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\uninstall.ps1
```

**NOTE: These examples assume you have a valid config.json in the same directory as the scripts.**

#### Detection Rules
- **Type**: Custom script
- **Script**: Upload `check.ps1`
- **Run as**: System
- **Enforce signature check**: No
- **Run in 64-bit**: Yes

#### Return Codes
| Code | Type | Action |
|------|------|--------|
| 0 | Success | Continue |
| 3010 | Soft Reboot | Reboot device |
| 1641 | Hard Reboot | Force reboot |
| 1603 | Retry | Retry installation |

### Assignment Groups

Target the Intune app to appropriate Azure AD groups:
- Device groups for computer-based targeting
- User groups for user-based targeting

---

## Assignment Configuration Guide

### Understanding Assignment Hierarchy

```
Device
├── Group (single)
└── Address Books (multiple)
    ├── Alias (optional)
    └── Tags (multiple)
```

### Building Your Assignment Structure

#### Step 1: Define Your Group
```json
{
    "group": "Department or Location Name"
}
```
**Note**: Only one group per device is supported by RustDesk.

#### Step 2: Add Address Books
```json
{
    "addressBooks": [
        {
            "addressBook": "Primary Directory",
            "alias": "Display Name"
        }
    ]
}
```

#### Step 3: Add Tags to Address Books
```json
{
    "addressBooks": [
        {
            "addressBook": "IT Assets",
            "alias": "All IT Equipment",
            "tags": [
                {"tag": "Servers"},
                {"tag": "Workstations"},
                {"tag": "Network Devices"}
            ]
        }
    ]
}
```

### Real-World Examples

#### Small Business
```json
{
    "group": "Main Office",
    "addressBooks": [
        {
            "addressBook": "All Computers",
            "alias": "Company PCs",
            "tags": [
                {"tag": "Office"},
                {"tag": "Remote"}
            ]
        }
    ]
}
```

#### Multi-Department Organization
```json
{
    "group": "North America",
    "addressBooks": [
        {
            "addressBook": "Finance Department",
            "alias": "Finance Team",
            "tags": [
                {"tag": "Accounting"},
                {"tag": "Payroll"},
                {"tag": "Audit"}
            ]
        },
        {
            "addressBook": "IT Department",
            "alias": "IT Team",
            "tags": [
                {"tag": "Help Desk"},
                {"tag": "Infrastructure"},
                {"tag": "Development"}
            ]
        },
        {
            "addressBook": "Shared Resources",
            "tags": [
                {"tag": "Conference Rooms"},
                {"tag": "Printers"}
            ]
        }
    ]
}
```

#### International Deployment (UTF-8 Example)
```json
{
    "group": "Norge Hovedkontor",
    "addressBooks": [
        {
            "addressBook": "Ansatte Datamaskiner",
            "alias": "Ansattes PCer",
            "tags": [
                {"tag": "Bærbare PCer"},
                {"tag": "Stasjonære PCer"},
                {"tag": "Hjemmekontor"}
            ]
        },
        {
            "addressBook": "Server og Infrastruktur",
            "alias": "IT Systemer",
            "tags": [
                {"tag": "Produksjon"},
                {"tag": "Utvikling"},
                {"tag": "Testmiljø"}
            ]
        }
    ]
}
```

---

## Logging and Troubleshooting

### Log File Locations

All logs are stored in: `C:\Windows\Temp\RustDeskDeploymentScripts\`

| Log Type | File Pattern | Description |
|----------|--------------|-------------|
| MSI Install | `msi_install_YYYYMMDD_HHMMSS.log` | Complete MSI installation log |
| MSI Uninstall | `msi_uninstall_YYYYMMDD_HHMMSS.log` | Complete MSI uninstallation log |
| Script Install | `install_YYYYMMDD_HHMMSS.log` | Installation script execution log |
| Script Uninstall | `uninstall_YYYYMMDD_HHMMSS.log` | Uninstallation script execution log |
| Script Check | `check_YYYYMMDD_HHMMSS.log` | Detection script results |
| Script Assign | `assign_YYYYMMDD_HHMMSS.log` | Assignment operations log |

### Log Analysis Commands

```powershell
# View latest logs
Get-ChildItem "C:\Windows\Temp\RustDeskDeploymentScripts\" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 5

# Search for errors in logs
Get-ChildItem "C:\Windows\Temp\RustDeskDeploymentScripts\*.log" | 
    Select-String -Pattern "ERROR"

# View specific log
Get-Content "C:\Windows\Temp\RustDeskDeploymentScripts\install_20250103_143537.log"
```

### Common Log Entries

**Successful Installation:**
```
[2025-01-03 14:35:37] [INFO] Starting RustDesk installation...
[2025-01-03 14:35:38] [SUCCESS] RustDesk installed successfully!
[2025-01-03 14:35:40] [INFO] Running assignment script...
[2025-01-03 14:35:42] [SUCCESS] Successfully assigned: Group: IT Department
```

**Failed Assignment:**
```
[2025-01-03 14:36:15] [ERROR] Failed to assign: Group: InvalidGroup (Exit Code: 1)
[2025-01-03 14:36:15] [WARNING] Partial success: Some assignments failed
```

### Troubleshooting Steps

1. **Check Script Logs**: Review the script execution log for high-level issues
2. **Check MSI Logs**: Review MSI verbose logs for installation problems
3. **Verify Network**: Ensure RustDesk server API is accessible
4. **Validate Token**: Confirm token has correct permissions and hasn't expired
5. **Test Manually**: Run assignments manually to isolate issues

---

## Security Best Practices

### Token Management

1. **Secure Storage**
   - Never store tokens in plain text in production
   - Use secure credential management systems
   - Consider using Azure Key Vault for Intune deployments

2. **Token Permissions**
   - Create tokens with minimum required permissions
   - Separate tokens for different deployment scenarios
   - Regular token rotation

3. **Token Usage**
   ```powershell
   # Secure token retrieval example
   $secureToken = Get-Secret -Name "RustDeskAPIToken" -Vault "Corporate"
   .\install.ps1 -ASSIGN "true" -TOKEN $secureToken.SecretValueText
   ```

### Network Security

- Use HTTPS exclusively for API communications
- Monitor API access logs

---

## Advanced Scenarios

### Multi-Site Deployment

```powershell
# Site-specific configuration
$sites = @{
    "NYC" = @{config="nyc-config.json"; assignment="nyc-assign.json"}
    "LON" = @{config="lon-config.json"; assignment="lon-assign.json"}
    "TOK" = @{config="tok-config.json"; assignment="tok-assign.json"}
}

# Deploy to specific site
$site = $env:COMPUTERNAME.Substring(0,3)
if ($sites.ContainsKey($site)) {
    Copy-Item $sites[$site].config "config.json" -Force
    Copy-Item $sites[$site].assignment "assignment.json" -Force
    .\install.ps1 -SILENT "true" -ASSIGN "true" -TOKEN $token -LOGGING "true"
}
```

### Conditional Assignment

```powershell
# Assign based on computer type
$computerType = (Get-WmiObject Win32_ComputerSystem).Model

switch -Wildcard ($computerType) {
    "*Laptop*" {
        $assignFile = "laptop-assignment.json"
    }
    "*Desktop*" {
        $assignFile = "desktop-assignment.json"
    }
    "*Server*" {
        $assignFile = "server-assignment.json"
    }
    default {
        $assignFile = "default-assignment.json"
    }
}

.\install.ps1 `
    -SILENT "true" `
    -ASSIGN "true" `
    -TOKEN $token `
    -ASSIGNMENTFILE $assignFile `
    -LOGGING "true"
```

---

## Common Issues and Solutions

### Issue: MSI Not Found
**Symptom**: "No MSI file found in script directory"

**Solutions**:
```powershell
# Solution 1: Specify explicit path
.\install.ps1 -MSIPATH "C:\Deployment\RustDesk.msi"

# Solution 2: Ensure MSI is in script directory
Copy-Item "\\server\software\RustDesk.msi" -Destination ".\"
.\install.ps1
```

### Issue: Assignment Failures
**Symptom**: "Failed to assign: Group: XXX (Exit Code: 1)"

**Diagnostics**:
```powershell
# Test token validity
& "C:\Program Files\RustDesk\RustDesk.exe" --assign --token "your-token" --device_group_name "Test" | Out-String

# Check token permissions in RustDesk server
# Settings → Tokens → Verify Read/Write for Devices and Groups
```

### Issue: UTF-8 Characters Display Incorrectly
**Symptom**: Characters like "æøå" appear as "???"

**Solution**:
- Ensure assignment.json is saved with UTF-8 encoding
- Script automatically handles UTF-8 via `chcp 65001`
- Verify in text editor that file encoding is UTF-8

### Issue: Script Execution Blocked
**Symptom**: "cannot be loaded because running scripts is disabled"

**Solution**:
```powershell
# For testing (temporary)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# For production (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### Issue: Group Not Assigned
**Symptom**: Address books assigned but group missing

**Verification**:
- Confirm only one group in assignment.json (not an array)
- Check group name exists in RustDesk server
- Review assign log for specific error

### Issue: Alias Not Applied
**Symptom**: Address book created but alias missing

**Requirements**:
- RustDesk Server Pro 1.5.8 or later
- RustDesk Client 1.4.1 or later
- Alias must be non-empty string in assignment.json

---

## Technical Details

### MSI Properties

The scripts support all RustDesk MSI public properties:

| Property | Values | Description |
|----------|--------|-------------|
| INSTALLFOLDER | Path | Installation directory |
| CREATESTARTMENUSHORTCUTS | Y/N | Create Start Menu shortcuts |
| CREATEDESKTOPSHORTCUTS | Y/N | Create Desktop shortcuts |
| INSTALLPRINTER | Y/N | Install virtual printer |


### Character Encoding

- **UTF-8 Support**: Full Unicode support via code page 65001
- **File Encoding**: UTF-8 without BOM for all configuration files
- **Console Output**: UTF-8 encoding for proper display

### Exit Code Reference

| Code | Category | Description | Action |
|------|----------|-------------|--------|
| 0 | Success | Operation completed successfully | None |
| 1 | Warning | Version mismatch (check.ps1) | Review |
| 1603 | Error | Fatal error during operation | Investigate logs |
| 1605 | Not Found | Product not installed | Expected for new installs |
| 1619 | Access Error | MSI package could not be opened | Check file permissions |
| 1638 | Version Error | Another version already installed | Uninstall first |
| 3010 | Reboot | Success but reboot required | Schedule reboot |

---

## Support and Contributing

### Getting Help

1. **Documentation**: Review this README and script comments
2. **Logs**: Check logs in `C:\Windows\Temp\RustDeskDeploymentScripts\`
3. **Issues**: Report bugs on GitHub with logs and environment details
4. **Testing**: Always test in non-production environment first

### Contributing

I welcome contributions! Please:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit pull request with detailed description
