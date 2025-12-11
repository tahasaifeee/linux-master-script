# Improved Master Linux Tool

This repository contains an enhanced version of the Master Linux Tool, a comprehensive utility for Linux system administration with enhanced security and reliability.

## Files Included

1. **`improved_master_linux_tool.sh`** - The main improved script with all enhancements
2. **`IMPROVEMENTS.md`** - Detailed documentation of all improvements made
3. **`sample_config.conf`** - Sample configuration file demonstrating configuration options
4. **`README.md`** - Original documentation
5. **`master-linux-tool.sh`** - Original script (for comparison)
6. **`master_linux_script.sh`** - Original script (for comparison)

## Key Improvements

- Enhanced security practices (input sanitization, proper SSH options, root privilege checks)
- Comprehensive error handling and validation
- Configuration file support for customizable behavior
- Command-line interface with multiple options
- Dry-run mode for safe testing
- Improved logging with configurable levels
- Better cross-platform compatibility
- Performance optimizations
- Enhanced user experience with color-coded output
- Detailed help and documentation

## Usage

### Interactive Mode
```bash
./improved_master_linux_tool.sh
```

### With Configuration File
```bash
./improved_master_linux_tool.sh -c /path/to/config.conf
```

### Verbose Mode
```bash
./improved_master_linux_tool.sh -v
```

### Dry-run Mode (Test without making changes)
```bash
./improved_master_linux_tool.sh -n
```

### With Custom Log File
```bash
./improved_master_linux_tool.sh -l /tmp/mylog.log
```

### Full Command Line Options
```bash
./improved_master_linux_tool.sh --help
```

## Features

The script provides the following functionality through an interactive menu:

1. Configure Static IP - Set a static IP address for the current system
2. Restart Network - Restart network services
3. Network Scan - Scan the network for active hosts
4. SSH Connectivity Check - Check SSH access to multiple hosts
5. System Information - Get detailed information about a remote host
6. Install Packages - Install packages on multiple hosts
7. Firewall Status - Check firewall status on multiple hosts
8. Template Readiness Check - Verify if a host is ready to be used as a template
9. System Diagnostics - Display system information and diagnostics

## Security Considerations

- The script includes input sanitization to prevent command injection
- SSH connections use secure options to prevent known host key issues
- Operations requiring root privileges are properly validated
- Network operations include appropriate timeouts to prevent hanging

## Configuration

The script supports configuration files with the following options:
- LOG_FILE: Path to the log file
- LOG_LEVEL: Logging level (DEBUG, INFO, WARN, ERROR)
- TIMEOUT: Timeout for network operations in seconds
- MAX_CONCURRENT_JOBS: Maximum number of concurrent jobs for network scans

## Compatibility

The script is compatible with major Linux distributions including:
- Ubuntu/Debian (with apt and netplan/networking)
- CentOS/RHEL/Rocky/AlmaLinux (with yum/dnf and network/NetworkManager)
- Fedora (with dnf and NetworkManager)
- OpenSUSE (with zypper and wicked)
- Arch Linux (with pacman)

## Testing

The script includes a dry-run mode (`-n` option) that allows you to test operations without making any actual system changes. This is particularly useful for validating your inputs and configuration before applying changes to your system.