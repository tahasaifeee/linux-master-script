# Linux Master Script

A universal Linux management tool compatible with all major Linux distributions including legacy systems.

## 🔒 Security Notice

This repository is configured for **private access**. The script includes password authentication to ensure only authorized users can execute administrative operations.

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

### For Private Repository Access

Since this repository is private, you need to authenticate with GitHub. Choose one of the methods below:

#### Method 1: Using Personal Access Token (Recommended)

1. **Create a GitHub Personal Access Token** (if you don't have one):
   - Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token (classic)"
   - Select scope: `repo` (Full control of private repositories)
   - Generate and copy the token

2. **Download and run the script:**

```bash
# Replace YOUR_GITHUB_TOKEN with your actual token
curl -H "Authorization: token YOUR_GITHUB_TOKEN" \
     -H "Accept: application/vnd.github.v3.raw" \
     -fsSL https://api.github.com/repos/tahasaifeee/linux-master-script/contents/linux-master-script.sh \
     -o linux-master-script.sh && chmod +x linux-master-script.sh && sudo ./linux-master-script.sh
```

#### Method 2: Using Git Clone (Alternative)

```bash
# Clone the repository (will prompt for GitHub credentials)
git clone https://github.com/tahasaifeee/linux-master-script.git
cd linux-master-script
chmod +x linux-master-script.sh
sudo ./linux-master-script.sh
```

#### Method 3: Using SSH (For SSH Key Users)

```bash
git clone git@github.com:tahasaifeee/linux-master-script.git
cd linux-master-script
chmod +x linux-master-script.sh
sudo ./linux-master-script.sh
```

### Making the Repository Private

To convert this repository from public to private:

1. Go to your repository on GitHub
2. Click **Settings** (repository settings, not account settings)
3. Scroll down to the **Danger Zone** section
4. Click **Change repository visibility**
5. Select **Make private**
6. Confirm the action

## Password Authentication

The script is protected with password authentication. You will be prompted to enter a password when running the script.

### Default Credentials

- **Default Password:** `LinuxAdmin2024`
- **Maximum Attempts:** 3

⚠️ **IMPORTANT:** Change the default password immediately after first use!

### Changing the Password

To set a custom password:

1. **Generate a new password hash:**

```bash
echo -n "YourNewPassword" | sha256sum | cut -d' ' -f1
```

2. **Edit the script** and replace the hash:

```bash
nano linux-master-script.sh
# Or use your preferred editor
vim linux-master-script.sh
```

3. **Find this line** (around line 26):

```bash
SCRIPT_PASSWORD_HASH="990ef64f2f6d518e4f67ad25cb5f4cf5dc676277c10ccbd530ae34cea0020e5c"
```

4. **Replace it** with your new hash:

```bash
SCRIPT_PASSWORD_HASH="your_new_hash_here"
```

5. **Update the comment** showing the default password (line 24) for your reference

### Security Features

- Password is never stored in plain text (SHA256 hashed)
- Silent password input (characters not displayed)
- Limited login attempts (3 attempts max)
- Script exits automatically after failed authentication
- Authentication required before any operations

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
- Valid authentication password

### Running the Script

```bash
# Make the script executable (if not already)
chmod +x linux-master-script.sh

# Run as root
sudo ./linux-master-script.sh

# Or with sudo
sudo bash linux-master-script.sh
```

### Script Workflow

When you run the script, it will:
1. **Prompt for password** (default: `LinuxAdmin2024`)
2. **Verify authentication** (3 attempts maximum)
3. **Check root privileges**
4. **Detect distribution** and package manager
5. **Display system information**
6. **Present interactive menu**
7. Execute your selected option
8. Return to the menu after completion

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

- **Always run the script as root or with sudo privileges**
- **Change the default password immediately after first use**
- Keep your password hash secure and don't share it
- Store authentication credentials securely
- Internet connection required for updates and installations
- Some operations may require system reboot
- EPEL repository is automatically installed when needed for RHEL-based systems
- For private repository: Ensure your GitHub token has appropriate permissions
- Consider using SSH keys for easier authentication with private repos

## Troubleshooting

### Authentication failed
```bash
# If you forgot the password, you need to edit the script and set a new hash
# Generate new password hash:
echo -n "YourNewPassword" | sha256sum | cut -d' ' -f1

# Edit the script and replace SCRIPT_PASSWORD_HASH with the new hash
nano linux-master-script.sh
```

### Cannot access private repository
```bash
# Make sure you have:
# 1. A valid GitHub Personal Access Token with 'repo' scope
# 2. Or SSH keys configured on your account
# 3. Proper permissions to access the repository

# Test access:
git clone https://github.com/tahasaifeee/linux-master-script.git
```

### Script requires root access
```bash
# Solution: Run with sudo
sudo ./linux-master-script.sh
```

### Package manager not found
This usually means you're running an unsupported distribution. Check that you're using one of the supported distributions listed above.

### Network issues during installation
Ensure your system has internet connectivity and can reach package repositories.

### Maximum authentication attempts exceeded
The script exits after 3 failed password attempts. If you're locked out:
1. Wait and try again
2. Verify you're using the correct password
3. If forgotten, edit the script and set a new password hash

## License

This script is provided as-is for system administration purposes.

## Contributing

Contributions, issues, and feature requests are welcome!
