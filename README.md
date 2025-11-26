# Linux Master Script

A universal Linux management tool compatible with all major Linux distributions including legacy systems.

## Supported Distributions

- **Red Hat Family**
  - CentOS 6 and above
  - Red Hat Enterprise Linux (RHEL) 6+
  - AlmaLinux 8+
  - Rocky Linux 8+
  - Oracle Linux 6+

- **Debian Family**
  - Ubuntu 16.04 and above
  - Debian 8 (Jessie) and above

## Quick Install (One-Click)

### Option 1: Download and Run (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/linux-master-script.sh -o linux-master-script.sh && chmod +x linux-master-script.sh && sudo ./linux-master-script.sh
```

### Option 2: Using wget

```bash
wget -O linux-master-script.sh https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/linux-master-script.sh && chmod +x linux-master-script.sh && sudo ./linux-master-script.sh
```

### Option 3: Direct Execution (Advanced)

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/linux-master-script.sh)
```

### Option 4: Clone Repository

```bash
git clone https://github.com/tahasaifeee/linux-master-script.git
cd linux-master-script
chmod +x linux-master-script.sh
sudo ./linux-master-script.sh
```

## Features

The script provides an interactive menu with the following options:

### 1. System Update
- Updates all system packages
- Performs distribution upgrades (for apt-based systems)
- Cleans up unnecessary packages
- Checks if system reboot is required

### 2. List Running Services
- Lists all currently running services
- Compatible with both systemd and SysV init systems
- Shows total count of running services

### 3. Install QEMU Guest Agent
- Installs the QEMU guest agent package
- Automatically starts and enables the service
- Checks if already installed and running
- Essential for VM management in virtualized environments

### 4. Install Cloud-Init
- Installs and configures cloud-init
- Automatically installs EPEL repository when needed (CentOS)
- Enables all cloud-init services
- Essential for cloud infrastructure automation

### 5. Display System Information
- Shows distribution name and version
- Displays package manager in use
- Shows kernel version and architecture

## Usage

### Prerequisites

- Root or sudo access
- Internet connection (for updates and installations)

### Running the Script

```bash
# Make the script executable (if not already)
chmod +x linux-master-script.sh

# Run as root
sudo ./linux-master-script.sh

# Or with sudo
sudo bash linux-master-script.sh
```

### Interactive Menu

Once started, the script will:
1. Display system information
2. Present an interactive menu
3. Execute your selected option
4. Return to the menu after completion

Simply enter the number of your choice (1-6) and press Enter.

## Technical Details

### Distribution Detection

The script automatically detects:
- Distribution type (CentOS, Ubuntu, Debian, AlmaLinux, Rocky, Oracle)
- Version information
- Available package manager (apt, yum, or dnf)

### Package Manager Support

- **APT** (Ubuntu, Debian): Uses apt-get for package management
- **YUM** (CentOS 6-7, older RHEL): Uses yum for package management
- **DNF** (CentOS 8+, AlmaLinux, Rocky, newer RHEL): Uses dnf for package management

### Compatibility Features

- Handles legacy systems (CentOS 6, Ubuntu 16.04)
- Supports both systemd and SysV init
- Automatically installs EPEL repository when needed
- Works with older package manager versions

## Examples

### Quick System Update
```bash
sudo ./linux-master-script.sh
# Select option 1
```

### Install QEMU Agent on VM
```bash
sudo ./linux-master-script.sh
# Select option 3
```

### Check Running Services
```bash
sudo ./linux-master-script.sh
# Select option 2
```

## Exit Codes

- `0`: Successful execution
- `1`: Error occurred (not running as root, unsupported system, etc.)

## Color Coding

The script uses color-coded output for better readability:
- **Green**: Success messages
- **Red**: Error messages
- **Yellow**: Warning messages
- **Blue**: Information messages

## Notes

- Always run the script as root or with sudo privileges
- Internet connection required for updates and installations
- Some operations may require system reboot
- EPEL repository is automatically installed when needed for RHEL-based systems

## Troubleshooting

### Script requires root access
```bash
# Solution: Run with sudo
sudo ./linux-master-script.sh
```

### Package manager not found
This usually means you're running an unsupported distribution. Check that you're using one of the supported distributions listed above.

### Network issues during installation
Ensure your system has internet connectivity and can reach package repositories.

## License

This script is provided as-is for system administration purposes.

## Contributing

Contributions, issues, and feature requests are welcome!
