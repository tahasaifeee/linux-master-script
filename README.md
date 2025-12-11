# Master Linux Script

A comprehensive all-in-one Linux administration script that combines network scanning, system information gathering, package installation, firewall checking, and template readiness assessment.

## Features

- **Network Scanning**: Discover active hosts on your network
- **SSH Connectivity Check**: Verify SSH access to remote hosts
- **System Information Gathering**: Collect detailed system information from remote hosts
- **Package Installation**: Install packages across multiple hosts
- **Firewall Status Check**: Check firewall configurations on remote hosts
- **Template Readiness Assessment**: Evaluate if a host is ready to be used as a template

## Quick Install

### 1-Click Install Command:
```bash
curl -sSL https://raw.githubusercontent.com/your-repo/master/master_linux_script.sh -o master_linux_script.sh && chmod +x master_linux_script.sh
```

Or alternatively:
```bash
wget https://raw.githubusercontent.com/your-repo/master/master_linux_script.sh -O master_linux_script.sh && chmod +x master_linux_script.sh
```

## Usage

### Help
```bash
./master_linux_script.sh --help
```

### Network Scan
Scan the current network:
```bash
./master_linux_script.sh network-scan
```

Scan a specific network:
```bash
./master_linux_script.sh network-scan 192.168.1.0 eth0
```

### SSH Connectivity Check
Check SSH connectivity to hosts listed in a file:
```bash
./master_linux_script.sh ssh-check /path/to/hosts_file.txt
```

### System Information
Get system information for a specific host:
```bash
./master_linux_script.sh system-info 192.168.1.100
```

### Install Packages
Install packages on multiple hosts:
```bash
./master_linux_script.sh install-packages /path/to/hosts_file.txt "curl vim git"
```

### Firewall Status
Check firewall status on multiple hosts:
```bash
./master_linux_script.sh firewall-status /path/to/hosts_file.txt
```

### Template Readiness
Check if a host is ready to be used as a template:
```bash
./master_linux_script.sh template-readiness 192.168.1.100
```

## Requirements

- Bash shell
- SSH access to target machines
- Network connectivity
- Root or sudo access on target machines (for some operations)

## Subcommands

### `network-scan [NETWORK] [INTERFACE]`
Perform network scan on the specified network using the specified interface.
- If NETWORK is not provided, it will use the current machine's network
- If INTERFACE is not provided, it will auto-detect the primary interface

### `ssh-check HOSTS_FILE`
Check SSH connectivity to hosts listed in HOSTS_FILE

### `system-info HOST`
Get detailed system information for the specified HOST

### `install-packages HOSTS_FILE PACKAGE_LIST`
Install packages on hosts listed in HOSTS_FILE
PACKAGE_LIST should be space-separated list of packages

### `firewall-status HOSTS_FILE`
Check firewall status on hosts listed in HOSTS_FILE

### `template-readiness HOST`
Check if the specified HOST is ready to be used as a template

## Options

- `-h, --help`: Show help message
- `-v, --verbose`: Enable verbose output
- `--log-file PATH`: Specify log file path (default: /tmp/master_linux_script.log)

## Examples

```bash
# Scan current network
./master_linux_script.sh network-scan

# Scan specific network with specific interface
./master_linux_script.sh network-scan 10.0.0.0 ens33

# Check SSH connectivity
./master_linux_script.sh ssh-check ./discovered_hosts.txt

# Get system info from a host
./master_linux_script.sh system-info 192.168.1.50

# Install packages on multiple hosts
./master_linux_script.sh install-packages ./target_hosts.txt "docker docker-compose nginx"

# Check firewall status
./master_linux_script.sh firewall-status ./web_servers.txt

# Check template readiness
./master_linux_script.sh template-readiness 192.168.1.10
```

## Logging

The script logs all activities to `/tmp/master_linux_script.log` by default. You can change this location using the `--log-file` option.

## Security Notes

- The script uses SSH with `StrictHostKeyChecking=no` to avoid host key verification prompts
- Make sure you trust the networks and hosts you're connecting to
- Some operations require elevated privileges on target systems
- Always review the script source before running it in production environments

## License

This project is open source and available under the MIT License.
