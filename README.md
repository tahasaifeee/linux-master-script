# Linux Master Script

A universal Linux management toolkit compatible with all major Linux distributions including legacy systems.

## 📦 Available Scripts

This repository contains two powerful scripts:

1. **linux-master-script.sh** - System management and maintenance
2. **template-readiness.sh** - VM template preparation wizard

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

---

## 🚀 Script 1: Linux Master Script

### Quick Install (One-Click)

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

---

## 🔧 Script 2: Template Readiness Wizard

A comprehensive wizard-style script to prepare Linux VMs for template creation.

### Quick Install (One-Click)

#### Option 1: Download and Run (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/template-readiness.sh -o template-readiness.sh && chmod +x template-readiness.sh && sudo ./template-readiness.sh
```

#### Option 2: Using wget

```bash
wget -O template-readiness.sh https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/template-readiness.sh && chmod +x template-readiness.sh && sudo ./template-readiness.sh
```

#### Option 3: Direct Execution (Advanced)

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/tahasaifeee/linux-master-script/main/template-readiness.sh)
```

### Features

The wizard guides you through configuring:

#### 1. SSH Configuration
- **Change SSH Port** - Configure custom SSH port
- **Root Login** - Enable or disable root login via SSH
- **Password Authentication** - Enable or disable password authentication
- Automatic backup of SSH configuration before changes
- Validates port numbers (1-65535)
- Automatically restarts SSH service after changes

#### 2. Cloud-Init Services
- Checks if cloud-init is installed
- Verifies all cloud-init services are enabled
- Offers to install cloud-init if missing
- Enables all required services (cloud-init-local, cloud-init, cloud-config, cloud-final)
- Automatically installs EPEL repository when needed (RHEL/CentOS)

#### 3. QEMU Guest Agent
- Checks if QEMU guest agent is installed
- Verifies service is running
- Offers to install if missing
- Starts and enables the service automatically
- Essential for VM management in virtualized environments

#### 4. UFW Firewall Configuration
- Checks UFW installation and status
- Configures firewall rules interactively
- Automatically allows configured SSH port
- Supports adding custom ports (TCP/UDP)
- Provides suggestions for common ports (HTTP, HTTPS, RDP, etc.)
- Offers quick setup for web server ports (80, 443)
- Installs UFW if not present (with EPEL on RHEL-based systems)

#### 5. Configuration Summary
- Displays complete configuration summary
- Shows all changes made during wizard
- Color-coded status indicators
- Lists current UFW rules
- Provides important warnings (e.g., changed SSH port)

### Wizard Workflow

When you run the script, it will:

1. **Welcome Screen** - Explains what the wizard will configure
2. **System Detection** - Automatically detects distribution and version
3. **SSH Configuration** - Interactive prompts for SSH settings
4. **Cloud-Init Check** - Verifies or installs cloud-init
5. **QEMU Agent Check** - Verifies or installs QEMU guest agent
6. **Firewall Configuration** - Sets up UFW firewall rules
7. **Summary Display** - Shows complete configuration summary

### Usage Example

```bash
# Run the wizard
sudo ./template-readiness.sh

# Follow the interactive prompts:
# - Set SSH port (e.g., 22 or custom)
# - Enable/disable root login
# - Enable/disable password auth
# - Install/check cloud-init
# - Install/check QEMU agent
# - Configure firewall rules
# - Review summary
```

### What Makes This Different?

- **Wizard-Style Interface** - Step-by-step guided configuration
- **Interactive Prompts** - Ask before making changes
- **Smart Defaults** - Suggests sensible default values
- **Comprehensive Checks** - Verifies existing configuration before changes
- **Automatic Backups** - Creates timestamped backups of SSH config
- **Validation** - Validates all user inputs
- **Summary Report** - Shows exactly what was configured
- **Color-Coded Output** - Easy to read status indicators

### Color Coding

- **Green ✓** - Success / Installed / Running / Enabled
- **Yellow ⚠** - Warning / Partial / Not Running
- **Red ✗** - Error / Not Installed
- **Blue ℹ** - Information messages
- **Cyan ➜** - Action steps
- **Magenta →** - Results and details

---

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
