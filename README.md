# RustDesk Deployment Scripts for Windows

**Enterprise-grade PowerShell deployment automation for RustDesk and custom-branded MSI packages**

---

## Overview

A comprehensive, production-ready deployment solution designed for enterprise environments using Microsoft Intune, Configuration Manager (SCCM), or any MSI-based deployment system. These scripts provide full lifecycle management with extensive logging, error handling, and compliance-friendly exit codes.

### **Core Components**

| Script | Purpose | Key Features |
|--------|---------|--------------|
| **`install.ps1`** | Installation & Upgrades | MSI property support, config file, CLI arguments |
| **`uninstall.ps1`** | Clean Removal | Auto-detection via WMI, silent operation |
| **`check.ps1`** | Detection & Verification | Standalone operation, ARM support, custom branding |
| **`config.json`** | Default Configuration | Optional centralized settings, CLI override capability |

### **Key Capabilities**

- **Complete MSI lifecycle management** — Install, upgrade, uninstall, and verify
- **Enterprise logging** — Dual-layer logging (script + MSI verbose)
- **Intune-ready exit codes** — Standard compliance codes (0, 3010, 1603, etc.)
- **ARM64 support** — Full detection on ARM-based Windows devices
- **Custom branding** — Support for rebranded MSI packages
- **Centralized configuration** — Optional JSON config with CLI override

---

## 📋 Prerequisites

### **System Requirements**
- **Operating System:** Windows 10/11 or Windows Server 2016+
- **PowerShell:** Version 5.1 or later (64-bit recommended)
- **Permissions:** Administrator privileges required
- **MSI Package:** RustDesk MSI installer (or custom-branded variant)

### **Execution Environment**
```powershell
# Recommended execution context
- Run as: SYSTEM or Administrator
- Architecture: 64-bit PowerShell
- Execution Policy: Bypass or RemoteSigned
```

---

## Repository Structure

```
Deploy-RustDesk/
├── install.ps1              # Installation script with full MSI property support
├── uninstall.ps1            # Uninstallation with auto-detection
├── check.ps1                # Standalone detection script
├── config.json              # Optional default configuration
├── RustDesk-*.msi           # MSI installer (auto-detected if present)
└── README.md                # This documentation
```

### **Deployment Package Structure**
When deploying via Intune or SCCM, package all files together:
- Scripts automatically locate the first `.msi` file in their directory
- Config file is optional but recommended for consistent deployments
- All logs are centralized in `C:\Windows\Temp\RustDeskDeploymentScripts\`

---

## ⚙️ Configuration

### **Configuration File (`config.json`)**

The optional configuration file provides default values for all parameters. Command-line arguments always take precedence.

```json
{
    "INSTALLFOLDER": "",
    "CREATESTARTMENUSHORTCUTS": "",
    "CREATEDESKTOPSHORTCUTS": "",
    "INSTALLPRINTER": "",
    "SILENT": "true",
    "MSIPATH": "",
    "UPGRADE": "false",
    "LOGGING": "true"
}
```

### **Parameter Precedence**
1. **Command-line arguments** (highest priority)
2. **config.json values**
3. **Script defaults** (lowest priority)

### **Boolean Values**
All boolean parameters must be strings: `"true"` or `"false"`
- Invalid values trigger graceful failure with exit code `1603`
- Empty strings are treated as unset (use installer defaults)

---

## Script Reference

### **`install.ps1` — Installation & Upgrade Script**

Performs new installations or in-place upgrades with full MSI property control.

#### **Parameters**

| Parameter | Type | Values | Description |
|-----------|------|--------|-------------|
| **`INSTALLFOLDER`** | String | Path | Custom installation directory |
| **`CREATESTARTMENUSHORTCUTS`** | Boolean | `"true"` / `"false"` | Create Start Menu shortcuts |
| **`CREATEDESKTOPSHORTCUTS`** | Boolean | `"true"` / `"false"` | Create Desktop shortcuts |
| **`INSTALLPRINTER`** | Boolean | `"true"` / `"false"` | Install virtual printer driver |
| **`SILENT`** | Boolean | `"true"` / `"false"` | Silent installation mode |
| **`MSIPATH`** | String | Path | Path to MSI file (auto-detect if empty) |
| **`UPGRADE`** | Boolean | `"true"` / `"false"` | Treat as upgrade installation |
| **`LOGGING`** | Boolean | `"true"` / `"false"` | Enable script transaction logging |

#### **Usage Examples**

```powershell
# Standard silent installation with defaults
.\install.ps1 -SILENT "true" -LOGGING "true"

# Custom installation with specific options
.\install.ps1 `
    -INSTALLFOLDER "D:\Applications\RustDesk" `
    -CREATEDESKTOPSHORTCUTS "false" `
    -CREATESTARTMENUSHORTCUTS "true" `
    -INSTALLPRINTER "false" `
    -SILENT "true" `
    -LOGGING "true"

# Upgrade existing installation
.\install.ps1 `
    -UPGRADE "true" `
    -SILENT "true" `
    -MSIPATH "\\server\share\RustDesk-1.3.9.msi"
```

#### **Generated Logs**
- **MSI Log:** `msi_install_YYYYMMDD_HHMMSS.log` *(always created)*
- **Script Log:** `install_YYYYMMDD_HHMMSS.log` *(when LOGGING="true")*

---

### **`uninstall.ps1` — Removal Script**

Cleanly removes RustDesk using product code detection or MSI path fallback.

#### **Parameters**

| Parameter | Type | Values | Description |
|-----------|------|--------|-------------|
| **`MSIPATH`** | String | Path | MSI path (fallback if product not found) |
| **`INSTALLFOLDER`** | String | Path | Original installation folder (optional) |
| **`SILENT`** | Boolean | `"true"` / `"false"` | Silent uninstallation mode |
| **`LOGGING`** | Boolean | `"true"` / `"false"` | Enable script transaction logging |

#### **Usage Examples**

```powershell
# Standard silent uninstallation (auto-detect)
.\uninstall.ps1 -SILENT "true" -LOGGING "true"

# Uninstall using specific MSI
.\uninstall.ps1 `
    -MSIPATH "C:\Installers\RustDesk-1.3.9.msi" `
    -SILENT "true"

# Uninstall with original install folder reference
.\uninstall.ps1 `
    -INSTALLFOLDER "D:\Applications\RustDesk" `
    -SILENT "true" `
    -LOGGING "true"
```

#### **Generated Logs**
- **MSI Log:** `msi_uninstall_YYYYMMDD_HHMMSS.log` *(always created)*
- **Script Log:** `uninstall_YYYYMMDD_HHMMSS.log` *(when LOGGING="true")*

---

### **`check.ps1` — Detection Script**

Standalone verification script for deployment validation and compliance checking.

#### **Configuration Variables** *(Edit within script)*

```powershell
# Core Configuration
$enableLogging = $true                              # Enable/disable logging
$checkRegistryPath = $true                          # Check Windows Registry
$checkFilePath = $true                              # Check file system
$expectedVersion = ""                               # Version validation (empty = any)
$customName = ""                                    # Custom brand name (empty = "RustDesk")
$expectedInstallPath = "C:\Program Files\%customName%"  # Installation path with placeholder
```

#### **Detection Methods**

1. **Registry Scan**
   - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
   - `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*`

2. **WMI Query**
   - `Win32_Product` class (read-only query)
   - Product name, version, and GUID extraction

3. **File System Verification**
   - Standard paths: `Program Files`, `Program Files (x86)`
   - ARM paths: `Program Files (Arm)` *(when present)*
   - Executable validation and version extraction

#### **Exit Codes**

| Code | Status | Description |
|------|--------|-------------|
| **0** | Success | Installed (version match if specified) |
| **1** | Warning | Version mismatch |
| **1605** | Not Found | Product not installed |
| **1603** | Error | Fatal error during detection |

#### **Custom Branding Support**

```powershell
# For standard RustDesk
$customName = ""
$expectedInstallPath = "C:\Program Files\%customName%"
# Resolves to: C:\Program Files\RustDesk\RustDesk.exe

# For custom branded "CompanyRemote"
$customName = "CompanyRemote"
$expectedInstallPath = "C:\Program Files\%customName%"
# Resolves to: C:\Program Files\CompanyRemote\CompanyRemote.exe
```

---

## Logging Architecture

### **Log Storage Location**
All logs are centralized in a dedicated Windows temp folder:
```
C:\Windows\Temp\RustDeskDeploymentScripts\
```

### **Log Types and Naming Convention**

| Log Type | File Pattern | Always Created | Contents |
|----------|--------------|----------------|----------|
| **MSI Install** | `msi_install_YYYYMMDD_HHMMSS.log` | Yes | Complete MSI verbose output |
| **MSI Uninstall** | `msi_uninstall_YYYYMMDD_HHMMSS.log` | Yes | Complete MSI verbose output |
| **Script Install** | `install_YYYYMMDD_HHMMSS.log` | When `LOGGING="true"` | Script execution details |
| **Script Uninstall** | `uninstall_YYYYMMDD_HHMMSS.log` | When `LOGGING="true"` | Script execution details |
| **Script Check** | `check_YYYYMMDD_HHMMSS.log` | When `$enableLogging=$true` | Detection results |

### **Log Content Structure**
```
[2025-01-03 14:35:37] [INFO] Starting RustDesk installation...
[2025-01-03 14:35:37] [INFO] MSI Path: C:\Temp\RustDesk-1.3.9.msi
[2025-01-03 14:35:37] [INFO] Install folder: C:\Program Files\RustDesk
[2025-01-03 14:35:38] [SUCCESS] RustDesk installed successfully!
[2025-01-03 14:35:38] [INFO] Exit code: 0
```

---

## Microsoft Intune Deployment

### **Package Creation**

1. **Create Intunewin Package**
   ```powershell
   # Package all files together
   IntuneWinAppUtil.exe -c ".\Deploy-RustDesk" -s "install.ps1" -o ".\Output"
   ```

2. **Configure Install Command**
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -SILENT "true" -LOGGING "true"
   ```

3. **Configure Uninstall Command**
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\uninstall.ps1 -SILENT "true" -LOGGING "true"
   ```

4. **Detection Method**
   - **Type:** Custom script
   - **Script:** Upload `check.ps1`
   - **Run as:** System
   - **Enforce script signature check:** No
   - **Run script in 64-bit:** Yes

### **Return Codes**

| Return Code | Type | Description |
|-------------|------|-------------|
| **0** | Success | Installation completed |
| **3010** | Soft Reboot | Installation completed, reboot required |
| **1641** | Hard Reboot | Installation completed, forced reboot |
| **1603** | Retry | Installation failed |
| **1605** | Retry | Product not found (uninstall only) |

---

## 🔧 Troubleshooting Guide

### **Common Issues and Solutions**

#### **MSI File Not Found**
```powershell
# Solution 1: Specify explicit path
.\install.ps1 -MSIPATH "C:\Installers\RustDesk.msi"

# Solution 2: Place MSI in script directory
# Script auto-detects first *.msi file
```

#### **Installation Not Silent**
```powershell
# Verify SILENT parameter
.\install.ps1 -SILENT "true"  # Correct
.\install.ps1 -SILENT true    # Incorrect (missing quotes)
```

#### **Detection Failures**
```powershell
# Check these variables in check.ps1:
$customName = "RustDesk"  # Must match your MSI brand
$expectedInstallPath = "C:\Program Files\%customName%"
```

#### **ARM64 Device Issues**
- Script automatically checks `C:\Program Files (Arm)\`
- Ensure using 64-bit PowerShell on ARM devices
- Review detection log for path scanning details

#### **WMI Query Timeout**
- WMI queries may be slow on some systems
- Script includes registry and file fallbacks
- Consider disabling WMI check if consistently problematic

### **Debug Commands**

```powershell
# Test detection locally
powershell.exe -ExecutionPolicy Bypass -File .\check.ps1

# View latest logs
Get-ChildItem "C:\Windows\Temp\RustDeskDeploymentScripts\" | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Check MSI properties
msiexec /i "RustDesk.msi" /qn /l*v "test.log" INSTALLFOLDER="C:\Test"
```

---

## Security Considerations

### **Best Practices**

1. **Code Signing**
   ```powershell
   # Sign scripts with enterprise certificate
   Set-AuthenticodeSignature -FilePath .\install.ps1 -Certificate $cert
   ```

2. **Execution Policy**
   ```powershell
   # Recommended for production
   Set-ExecutionPolicy -ExecutionPolicy AllSigned -Scope Process
   ```

3. **Permissions**
   - Run as SYSTEM for Intune deployments
   - Ensure MSI source is trusted and validated
   - Review logs regularly for anomalies

4. **Network Paths**
   - Use UNC paths with appropriate permissions
   - Consider package caching for remote sites
   - Implement hash validation for MSI files

---

## License and Contributions

### **Usage Rights**
These scripts are provided as enterprise deployment tools. Customize freely for your organization's needs.

### **Contributing**
- **Bug Reports:** Open an issue with log excerpts
- **Feature Requests:** Describe use case and expected behavior
- **Pull Requests:** Include testing details and documentation updates

### **Support**
- Review logs in `C:\Windows\Temp\RustDeskDeploymentScripts\`
- Test in sandbox environment before production deployment
- Validate with your specific MSI version and Windows build

---
