#!/bin/bash
#
# Improved Master Linux Tool
# A comprehensive utility for Linux system administration with enhanced security and reliability
#

# Default configuration values
DEFAULT_CONFIG_FILE="/etc/master-linux-tool.conf"
DEFAULT_LOG_FILE="/var/log/master-linux-tool.log"
DEFAULT_LOG_LEVEL="INFO"
DEFAULT_TIMEOUT=10
DEFAULT_MAX_CONCURRENT_JOBS=50

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global variables
CONFIG_FILE=""
LOG_FILE=""
LOG_LEVEL=""
TIMEOUT=""
MAX_CONCURRENT_JOBS=""
VERBOSE=false
DRY_RUN=false

# Function to display usage information
usage() {
    cat << EOF
Improved Master Linux Tool - Comprehensive Linux administration utility

Usage: $0 [OPTIONS]

Options:
    -c, --config FILE       Configuration file (default: $DEFAULT_CONFIG_FILE)
    -l, --log-file FILE     Log file path (default: $DEFAULT_LOG_FILE)
    -L, --log-level LEVEL   Log level (DEBUG, INFO, WARN, ERROR) (default: $DEFAULT_LOG_LEVEL)
    -t, --timeout SECONDS   Timeout for network operations (default: $DEFAULT_TIMEOUT)
    -j, --jobs NUMBER       Max concurrent jobs (default: $DEFAULT_MAX_CONCURRENT_JOBS)
    -v, --verbose           Enable verbose output
    -n, --dry-run           Perform a dry run without making changes
    -h, --help              Show this help message

Examples:
    $0                              # Run with default settings
    $0 -v                           # Run with verbose output
    $0 -c /path/to/config.conf      # Use custom configuration file
    $0 -l /tmp/myscript.log         # Use custom log file

Interactive Menu Options:
    1. Configure Static IP - Set a static IP address for the current system
    2. Restart Network - Restart network services
    3. Network Scan - Scan the network for active hosts
    4. SSH Connectivity Check - Check SSH access to multiple hosts
    5. System Information - Get detailed information about a remote host
    6. Install Packages - Install packages on multiple hosts
    7. Firewall Status - Check firewall status on multiple hosts
    8. Template Readiness Check - Verify if a host is ready to be used as a template
    9. System Diagnostics - Display system information and diagnostics
    0. Exit - Quit the script

EOF
}

# Function to load configuration from file
load_config() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"
    
    if [ -f "$config_file" ]; then
        # Source the config file to load variables
        # Use a safe method to source only specific variables
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove leading/trailing whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            case "$key" in
                LOG_FILE) export LOG_FILE="$value" ;;
                LOG_LEVEL) export LOG_LEVEL="$value" ;;
                TIMEOUT) export TIMEOUT="$value" ;;
                MAX_CONCURRENT_JOBS) export MAX_CONCURRENT_JOBS="$value" ;;
            esac
        done < "$config_file"
        
        log_message "Configuration loaded from $config_file" "DEBUG"
    else
        log_message "Configuration file $config_file not found, using defaults" "WARN"
    fi
}

# Function to initialize default values
init_defaults() {
    : "${LOG_FILE:=$DEFAULT_LOG_FILE}"
    : "${LOG_LEVEL:=$DEFAULT_LOG_LEVEL}"
    : "${TIMEOUT:=$DEFAULT_TIMEOUT}"
    : "${MAX_CONCURRENT_JOBS:=$DEFAULT_MAX_CONCURRENT_JOBS}"
}

# Function to log messages with timestamps and levels
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Only log if the level is appropriate
    case "$LOG_LEVEL" in
        "DEBUG") ;;
        "INFO")  [[ "$level" == "DEBUG" ]] && return ;;
        "WARN")  [[ "$level" == "DEBUG" || "$level" == "INFO" ]] && return ;;
        "ERROR") [[ "$level" != "ERROR" ]] && return ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also print to console if verbose mode is enabled
    if [[ "$VERBOSE" == true || "$level" == "ERROR" ]]; then
        case "$level" in
            "ERROR") echo -e "${RED}[$level] $message${NC}" >&2 ;;
            "WARN")  echo -e "${YELLOW}[$level] $message${NC}" >&2 ;;
            "INFO")  echo -e "${GREEN}[$level] $message${NC}" ;;
            "DEBUG") echo -e "${CYAN}[$level] $message${NC}" ;;
        esac
    fi
}

# Function to validate IP address
validate_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ $ip =~ $regex ]]; then
        # Additional validation to ensure each octet is 0-255
        local octets
        IFS='.' read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to sanitize input to prevent command injection
sanitize_input() {
    local input="$1"
    # Remove potentially dangerous characters
    input=$(echo "$input" | sed 's/[;&|$`<>]//g')
    echo "$input"
}

# Function to detect the distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$NAME"
        DISTRO_ID="$ID"
        DISTRO_VERSION="$VERSION_ID"
    elif type lsb_release >/dev/null 2>&1; then
        DISTRO=$(lsb_release -si)
        DISTRO_ID=$(echo "$DISTRO" | tr '[:upper:]' '[:lower:]')
        DISTRO_VERSION=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        DISTRO=$(cat /etc/redhat-release)
        DISTRO_ID="redhat"
    elif [ -f /etc/debian_version ]; then
        DISTRO="Debian"
        DISTRO_ID="debian"
        DISTRO_VERSION=$(cat /etc/debian_version)
    else
        DISTRO="Unknown"
        DISTRO_ID="unknown"
        DISTRO_VERSION="unknown"
    fi
    
    log_message "Detected distribution: $DISTRO ($DISTRO_ID $DISTRO_VERSION)" "DEBUG"
}

# Function to detect the package manager
get_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
    else
        PKG_MANAGER="unknown"
    fi
    
    log_message "Detected package manager: $PKG_MANAGER" "DEBUG"
}

# Function to detect the init system
get_init_system() {
    if command -v systemctl >/dev/null 2>&1; then
        INIT_SYSTEM="systemd"
    elif command -v service >/dev/null 2>&1; then
        INIT_SYSTEM="service"
    else
        INIT_SYSTEM="unknown"
    fi
    
    log_message "Detected init system: $INIT_SYSTEM" "DEBUG"
}

# Function to detect the firewall
get_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        FIREWALL="ufw"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        FIREWALL="firewalld"
    elif command -v nft >/dev/null 2>&1; then
        FIREWALL="nftables"
    elif command -v iptables >/dev/null 2>&1; then
        FIREWALL="iptables"
    else
        FIREWALL="none"
    fi
    
    log_message "Detected firewall: $FIREWALL" "DEBUG"
}

# Function to print header
print_header() {
    echo -e "${CYAN}===========================================${NC}"
    echo -e "${CYAN}    Improved Master Linux Tool${NC}"
    echo -e "${CYAN}===========================================${NC}"
    echo -e "${GREEN}1. Configure Static IP${NC}"
    echo -e "${GREEN}2. Restart Network${NC}"
    echo -e "${GREEN}3. Network Scan${NC}"
    echo -e "${GREEN}4. SSH Connectivity Check${NC}"
    echo -e "${GREEN}5. System Information${NC}"
    echo -e "${GREEN}6. Install Packages${NC}"
    echo -e "${GREEN}7. Firewall Status${NC}"
    echo -e "${GREEN}8. Template Readiness Check${NC}"
    echo -e "${GREEN}9. System Diagnostics${NC}"
    echo -e "${RED}0. Exit${NC}"
    echo -e "${CYAN}===========================================${NC}"
}

# Function to configure static IP
configure_static_ip() {
    echo -e "${YELLOW}Configuring Static IP...${NC}"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This operation requires root privileges.${NC}" >&2
        return 1
    fi
    
    # Detect network interfaces
    local interfaces
    interfaces=$(ip link show 2>/dev/null | grep -E "^[0-9]+:" | grep -v "lo:" | awk -F': ' '{print $2}' | head -n 1)
    if [ -z "$interfaces" ]; then
        echo -e "${RED}No network interface found.${NC}"
        return 1
    fi
    
    echo "Available interface: $interfaces"
    read -p "Interface name (default: $interfaces): " interface
    interface=${interface:-$interfaces}
    
    # Validate interface exists
    if ! ip link show "$interface" >/dev/null 2>&1; then
        echo -e "${RED}Interface $interface does not exist.${NC}"
        return 1
    fi
    
    read -p "Enter IP address (e.g., 192.168.1.100): " ip_addr
    read -p "Enter netmask (e.g., 255.255.255.0 or prefix like /24): " netmask
    read -p "Enter gateway (e.g., 192.168.1.1): " gateway
    read -p "Enter DNS server (e.g., 8.8.8.8): " dns
    
    # Validate inputs
    if ! validate_ip "$ip_addr"; then
        echo -e "${RED}Invalid IP address: $ip_addr${NC}"
        return 1
    fi
    
    if ! validate_ip "$gateway"; then
        echo -e "${RED}Invalid gateway: $gateway${NC}"
        return 1
    fi
    
    if ! validate_ip "$dns"; then
        echo -e "${RED}Invalid DNS server: $dns${NC}"
        return 1
    fi
    
    # Determine if netmask is in CIDR notation
    if [[ $netmask == /* ]]; then
        cidr=$netmask
        # Extract network portion from IP
        network_part=$(echo "$ip_addr" | cut -d. -f1-3)
    else
        # Convert netmask to CIDR if needed
        case $netmask in
            "255.255.255.0") cidr="/24" ;;
            "255.255.0.0")   cidr="/16" ;;
            "255.0.0.0")     cidr="/8" ;;
            *) 
                # Try to convert using ipcalc if available
                if command -v ipcalc >/dev/null 2>&1; then
                    cidr=$(ipcalc -np "$ip_addr" "$netmask" 2>/dev/null | grep -o '/[0-9]*' || echo "/24")
                else
                    cidr="/24"
                fi
                ;;
        esac
        cidr=${cidr:-/24}
    fi
    
    log_message "Configuring static IP for interface $interface with IP $ip_addr$cidr, gateway $gateway, DNS $dns"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}DRY RUN: Would configure static IP for $interface${NC}"
        return 0
    fi
    
    # Handle different distributions
    case $DISTRO_ID in
        ubuntu|debian)
            # Check if netplan is available
            if command -v netplan >/dev/null 2>&1; then
                # Backup existing config
                if [ -f /etc/netplan/01-netcfg.yaml ]; then
                    cp /etc/netplan/01-netcfg.yaml "/etc/netplan/01-netcfg.yaml.$(date +%s).bak"
                fi
                
                cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      dhcp4: no
      addresses:
        - $ip_addr$cidr
      gateway4: $gateway
      nameservers:
          addresses: [$dns]
EOF
                
                # Apply netplan
                netplan apply
            else
                # Fallback to traditional networking
                if [ -f /etc/network/interfaces ]; then
                    cp /etc/network/interfaces "/etc/network/interfaces.$(date +%s).bak"
                fi
                
                cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto $interface
iface $interface inet static
address $ip_addr$cidr
gateway $gateway
dns-nameservers $dns
EOF
                
                # Restart networking
                if command -v systemctl >/dev/null 2>&1; then
                    systemctl restart networking
                else
                    service networking restart
                fi
            fi
            ;;
        centos|rhel|rocky|almalinux)
            # Backup existing config
            if [ -f "/etc/sysconfig/network-scripts/ifcfg-$interface" ]; then
                cp "/etc/sysconfig/network-scripts/ifcfg-$interface" "/etc/sysconfig/network-scripts/ifcfg-$interface.$(date +%s).bak"
            fi
            
            cat <<EOF > "/etc/sysconfig/network-scripts/ifcfg-$interface"
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=$interface
DEVICE=$interface
ONBOOT=yes
IPADDR=$ip_addr
PREFIX=${cidr#/}
GATEWAY=$gateway
DNS1=$dns
EOF
            
            # Restart network
            if command -v systemctl >/dev/null 2>&1; then
                systemctl restart network
            else
                service network restart
            fi
            ;;
        fedora)
            # Backup existing config
            if [ -f "/etc/sysconfig/network-scripts/ifcfg-$interface" ]; then
                cp "/etc/sysconfig/network-scripts/ifcfg-$interface" "/etc/sysconfig/network-scripts/ifcfg-$interface.$(date +%s).bak"
            fi
            
            cat <<EOF > "/etc/sysconfig/network-scripts/ifcfg-$interface"
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=$interface
DEVICE=$interface
ONBOOT=yes
IPADDR=$ip_addr
PREFIX=${cidr#/}
GATEWAY=$gateway
DNS1=$dns
EOF
            
            # Restart NetworkManager
            if command -v systemctl >/dev/null 2>&1; then
                systemctl restart NetworkManager
            else
                service NetworkManager restart
            fi
            ;;
        opensuse*)
            # For OpenSUSE, we'll use wicked
            if [ -f "/etc/sysconfig/network/ifcfg-$interface" ]; then
                cp "/etc/sysconfig/network/ifcfg-$interface" "/etc/sysconfig/network/ifcfg-$interface.$(date +%s).bak"
            fi
            
            cat <<EOF > "/etc/sysconfig/network/ifcfg-$interface"
STARTMODE='auto'
BOOTPROTO='static'
IPADDR='$ip_addr$cidr'
GATEWAY='$gateway'
NAMESERVERS='$dns'
EOF
            
            # Restart network
            if command -v systemctl >/dev/null 2>&1; then
                systemctl restart wicked
            else
                service wicked restart
            fi
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO_ID${NC}"
            return 1
            ;;
    esac
    
    # Verify new IP
    sleep 2  # Allow time for network changes to take effect
    local new_ip
    new_ip=$(ip addr show "$interface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | head -n 1)
    echo -e "${GREEN}New IP configuration: $new_ip${NC}"
    echo -e "${GREEN}Static IP configuration completed.${NC}"
    
    log_message "Static IP configured successfully on $interface with IP $new_ip"
}

# Function to restart network
restart_network() {
    echo -e "${YELLOW}Restarting network...${NC}"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This operation requires root privileges.${NC}" >&2
        return 1
    fi
    
    log_message "Restarting network services"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}DRY RUN: Would restart network services${NC}"
        return 0
    fi
    
    case $DISTRO_ID in
        ubuntu|debian)
            # Try netplan first, then traditional networking
            if command -v netplan >/dev/null 2>&1; then
                netplan apply
            elif command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet networking; then
                systemctl restart networking
            elif command -v service >/dev/null 2>&1; then
                service networking restart
            else
                echo -e "${RED}Could not restart network services${NC}"
                return 1
            fi
            ;;
        centos|rhel|rocky|almalinux)
            if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet network; then
                systemctl restart network
            elif command -v service >/dev/null 2>&1; then
                service network restart
            else
                echo -e "${RED}Could not restart network services${NC}"
                return 1
            fi
            ;;
        fedora)
            if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager; then
                systemctl restart NetworkManager
            elif command -v service >/dev/null 2>&1; then
                service NetworkManager restart
            else
                echo -e "${RED}Could not restart network services${NC}"
                return 1
            fi
            ;;
        opensuse*)
            if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet wicked; then
                systemctl restart wicked
            elif command -v service >/dev/null 2>&1; then
                service wicked restart
            else
                echo -e "${RED}Could not restart network services${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO_ID${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}Network restarted successfully.${NC}"
    log_message "Network services restarted successfully"
}

# Function to scan network
network_scan() {
    echo -e "${YELLOW}Scanning network...${NC}"
    
    read -p "Enter subnet to scan (e.g., 192.168.1.0/24): " subnet
    if [ -z "$subnet" ]; then
        echo -e "${RED}Subnet not provided.${NC}"
        return 1
    fi
    
    # Validate subnet format
    if [[ ! $subnet =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo -e "${RED}Invalid subnet format: $subnet${NC}"
        return 1
    fi
    
    log_message "Scanning network: $subnet"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}DRY RUN: Would scan network $subnet${NC}"
        return 0
    fi
    
    # Try different methods for network scanning
    if command -v nmap >/dev/null 2>&1; then
        echo -e "${CYAN}Using nmap for network scan...${NC}"
        nmap -sn "$subnet" | grep report | grep -v "Nmap done"
    elif command -v arp-scan >/dev/null 2>&1; then
        echo -e "${CYAN}Using arp-scan for network scan...${NC}"
        arp-scan "$subnet"
    else
        # Fallback to ping sweep
        echo -e "${CYAN}Using ping sweep for network scan...${NC}"
        IFS='/' read -r network prefix <<< "$subnet"
        IFS='.' read -r ip1 ip2 ip3 ip4 <<< "$network"
        
        # Calculate host range based on prefix
        case $prefix in
            24) start=1; end=254 ;;
            16) start=1; end=254 ;;
            8) start=1; end=254 ;;
            *) start=1; end=254 ;;
        esac
        
        # Get current IP to skip it during scan
        local current_ip
        current_ip=$(hostname -I | awk '{print $1}')
        
        for i in $(seq $start $end); do
            target="$ip1.$ip2.$ip3.$i"
            
            # Skip current IP
            if [ "$target" = "$current_ip" ]; then
                continue
            fi
            
            (
                if ping -c 1 -W 1 "$target" >/dev/null 2>&1; then
                    echo "$target is alive"
                fi
            ) &
            
            # Limit concurrent pings to avoid overwhelming the system
            if [ $(jobs -r | wc -l) -gt "$MAX_CONCURRENT_JOBS" ]; then
                wait -n
            fi
        done
        wait
    fi
}

# Function to check SSH connectivity
ssh_connectivity_check() {
    echo -e "${YELLOW}Checking SSH connectivity...${NC}"
    
    read -p "Enter hostname/IP to check (or 'file' to read from file): " target
    if [ "$target" = "file" ]; then
        read -p "Enter path to hosts file: " hosts_file
        if [ ! -f "$hosts_file" ]; then
            echo -e "${RED}File $hosts_file does not exist.${NC}"
            return 1
        fi
        
        while IFS= read -r host; do
            host=$(echo "$host" | xargs)  # Trim whitespace
            if [ -n "$host" ] && [[ ! $host =~ ^# ]]; then  # Skip empty lines and comments
                echo -e "${CYAN}Checking SSH connectivity to $host...${NC}"
                
                if [[ "$DRY_RUN" == true ]]; then
                    echo -e "${YELLOW}DRY RUN: Would check SSH connectivity to $host${NC}"
                    continue
                fi
                
                if timeout "$TIMEOUT" ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$host" exit 2>/dev/null; then
                    echo -e "${GREEN}$host: SSH reachable${NC}"
                    log_message "SSH connectivity to $host: SUCCESS"
                else
                    echo -e "${RED}$host: SSH not reachable${NC}"
                    log_message "SSH connectivity to $host: FAILED"
                fi
            fi
        done < "$hosts_file"
    else
        if [ -z "$target" ]; then
            echo -e "${RED}Target not provided.${NC}"
            return 1
        fi
        
        echo -e "${CYAN}Checking SSH connectivity to $target...${NC}"
        
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${YELLOW}DRY RUN: Would check SSH connectivity to $target${NC}"
            return 0
        fi
        
        if timeout "$TIMEOUT" ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$target" exit 2>/dev/null; then
            echo -e "${GREEN}$target: SSH reachable${NC}"
            log_message "SSH connectivity to $target: SUCCESS"
        else
            echo -e "${RED}$target: SSH not reachable${NC}"
            log_message "SSH connectivity to $target: FAILED"
        fi
    fi
}

# Function to display system information
system_information() {
    echo -e "${YELLOW}System Information:${NC}"
    
    log_message "Displaying system information"
    
    echo -e "${CYAN}Hostname:${NC} $(hostname)"
    echo -e "${CYAN}OS:${NC} $DISTRO ($DISTRO_ID $DISTRO_VERSION)"
    echo -e "${CYAN}Kernel:${NC} $(uname -r)"
    echo -e "${CYAN}Uptime:${NC} $(uptime -p 2>/dev/null || uptime)"
    echo -e "${CYAN}CPU:${NC} $(nproc 2>/dev/null || echo 'unknown') cores"
    echo -e "${CYAN}Memory:${NC} $(free -h 2>/dev/null | awk 'NR==2{print $2}' 2>/dev/null || echo 'unknown') total ($(free -m 2>/dev/null | awk 'NR==2{print $3 "/" $2}' 2>/dev/null | sed 's/M//g' 2>/dev/null || echo 'unknown') MB used)"
    
    # Disk usage
    echo -e "${CYAN}Disk Usage:${NC}"
    df -h 2>/dev/null | grep -E '^/dev/' 2>/dev/null | awk '{print "  " $1 ": " $5 " used (" $4 " free)"}' 2>/dev/null || echo "  Unable to retrieve disk usage"
    
    # Network interfaces
    echo -e "${CYAN}Network Interfaces:${NC}"
    ip addr show 2>/dev/null | grep -E '^[0-9]+:' 2>/dev/null | grep -v 'lo:' 2>/dev/null | while read -r line; do
        iface=$(echo "$line" | awk -F': ' '{print $2}')
        ip_addr=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' 2>/dev/null | awk '{print $2}' 2>/dev/null | head -n 1)
        if [ -n "$ip_addr" ]; then
            echo "  $iface: $ip_addr"
        fi
    done
}

# Function to install packages
install_packages() {
    echo -e "${YELLOW}Installing packages...${NC}"
    
    get_package_manager
    if [ "$PKG_MANAGER" = "unknown" ]; then
        echo -e "${RED}No supported package manager found.${NC}"
        return 1
    fi
    
    read -p "Enter package name(s) to install (space-separated): " packages
    if [ -z "$packages" ]; then
        echo -e "${RED}No packages specified.${NC}"
        return 1
    fi
    
    # Sanitize package names to prevent command injection
    packages=$(sanitize_input "$packages")
    
    log_message "Installing packages: $packages using $PKG_MANAGER"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}DRY RUN: Would install packages: $packages${NC}"
        return 0
    fi
    
    case $PKG_MANAGER in
        apt)
            apt update
            apt install -y $packages
            ;;
        yum|dnf)
            $PKG_MANAGER install -y $packages
            ;;
        zypper)
            zypper install -y $packages
            ;;
        pacman)
            pacman -Syu --noconfirm $packages
            ;;
        *)
            echo -e "${RED}Unsupported package manager: $PKG_MANAGER${NC}"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Packages installed successfully.${NC}"
        log_message "Package installation completed successfully"
    else
        echo -e "${RED}Package installation failed.${NC}"
        log_message "Package installation failed"
        return 1
    fi
}

# Function to check firewall status
firewall_status() {
    echo -e "${YELLOW}Checking firewall status...${NC}"
    
    get_firewall
    
    log_message "Checking firewall status: $FIREWALL"
    
    case $FIREWALL in
        ufw)
            echo -e "${CYAN}Using UFW (Uncomplicated Firewall)${NC}"
            ufw status verbose
            ;;
        firewalld)
            echo -e "${CYAN}Using Firewalld${NC}"
            firewall-cmd --state
            firewall-cmd --list-all
            ;;
        nftables)
            echo -e "${CYAN}Using Nftables${NC}"
            if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet nftables; then
                nft list ruleset
            else
                echo "nftables service is not active"
            fi
            ;;
        iptables)
            echo -e "${CYAN}Using Iptables${NC}"
            iptables -L -v
            ;;
        none)
            echo -e "${RED}No supported firewall detected.${NC}"
            ;;
        *)
            echo -e "${RED}Unknown firewall: $FIREWALL${NC}"
            ;;
    esac
}

# Function to check template readiness
template_readiness_check() {
    echo -e "${YELLOW}Template Readiness Check:${NC}"
    
    log_message "Performing template readiness check"
    
    # Initialize counters
    pass_count=0
    total_checks=0
    
    # Check 1: Hostname
    total_checks=$((total_checks + 1))
    current_hostname=$(hostname)
    if [ -n "$current_hostname" ] && [ "$current_hostname" != "localhost" ]; then
        echo -e "${GREEN}✓ Hostname: $current_hostname${NC}"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ Hostname: Not properly set${NC}"
    fi
    
    # Check 2: Time synchronization
    total_checks=$((total_checks + 1))
    if command -v systemctl >/dev/null 2>&1 && (systemctl is-active --quiet chronyd || systemctl is-active --quiet ntp || systemctl is-active --quiet systemd-timesyncd); then
        time_source=""
        if systemctl is-active --quiet chronyd 2>/dev/null; then
            time_source="chronyd"
        elif systemctl is-active --quiet ntp 2>/dev/null; then
            time_source="ntp"
        elif systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
            time_source="systemd-timesyncd"
        fi
        echo -e "${GREEN}✓ Time sync service: Active ($time_source)${NC}"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ Time sync service: Not active${NC}"
    fi

    # Check 3: SSH status
    total_checks=$((total_checks + 1))
    if command -v systemctl >/dev/null 2>&1 && (systemctl is-active --quiet ssh || systemctl is-active --quiet sshd); then
        echo -e "${GREEN}✓ SSH service: Running${NC}"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ SSH service: Not running${NC}"
    fi

    # Check 4: /etc/hosts
    total_checks=$((total_checks + 1))
    if [ -f /etc/hosts ] && grep -q "127.0.0.1.*$(hostname)" /etc/hosts 2>/dev/null; then
        echo -e "${GREEN}✓ /etc/hosts: Contains hostname entry${NC}"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ /etc/hosts: Missing hostname entry${NC}"
    fi

    # Check 5: Network interface status
    total_checks=$((total_checks + 1))
    active_interfaces=$(ip link show 2>/dev/null | grep -E '^[0-9]+:' 2>/dev/null | grep -v 'lo:' 2>/dev/null | grep -c 'state UP' 2>/dev/null)
    if [ "${active_interfaces:-0}" -ge 1 ]; then
        echo -e "${GREEN}✓ Network interfaces: At least one active${NC}"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ Network interfaces: None active${NC}"
    fi

    # Check 6: DHCP lease files
    total_checks=$((total_checks + 1))
    dhcp_files=$(find /var/lib/dhcp* /var/lib/NetworkManager* -name "*.lease" -o -name "*dhclient*" 2>/dev/null | wc -l)
    if [ "${dhcp_files:-0}" -eq 0 ]; then
        echo -e "${GREEN}✓ DHCP leases: No leftover lease files${NC}"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ DHCP leases: Found $dhcp_files lease files${NC}"
    fi

    # Summary
    echo ""
    echo -e "${CYAN}Template Readiness Summary:${NC}"
    echo -e "${CYAN}Passed: $pass_count/$total_checks checks${NC}"

    if [ $pass_count -eq $total_checks ]; then
        echo -e "${GREEN}Overall Status: Template is ready!${NC}"
        log_message "Template readiness check: PASSED ($pass_count/$total_checks)"
    else
        echo -e "${YELLOW}Overall Status: Template needs attention${NC}"
        log_message "Template readiness check: NEEDS_ATTENTION ($pass_count/$total_checks)"
    fi
}

# Function for system diagnostics
system_diagnostics() {
    echo -e "${YELLOW}Running System Diagnostics...${NC}"

    log_message "Running system diagnostics"

    # CPU Load
    echo -e "${CYAN}CPU Load:${NC}"
    echo "Load average: $(uptime 2>/dev/null | awk -F'load average:' '{print $2}' 2>/dev/null || echo 'Unable to retrieve')"
    
    # Memory usage
    echo -e "${CYAN}Memory Usage:${NC}"
    free -h 2>/dev/null || echo "Unable to retrieve memory information"

    # Disk health (if smartctl is available)
    if command -v smartctl >/dev/null 2>&1; then
        echo -e "${CYAN}Disk Health (SMART):${NC}"
        for drive in /dev/sda /dev/sdb /dev/nvme0n1; do
            if [ -b "$drive" ]; then
                echo "Checking $drive:"
                smartctl -H "$drive" 2>/dev/null | grep -E "(PASSED|FAILED|overall-health)" 2>/dev/null || echo "  Drive not available or SMART not supported"
            fi
        done
    else
        echo -e "${CYAN}Disk Health:${NC} smartctl not available"
    fi

    # Network connectivity
    echo -e "${CYAN}Network Connectivity:${NC}"
    # Check gateway connectivity
    gateway_ip=$(ip route 2>/dev/null | grep default 2>/dev/null | awk '{print $3}' 2>/dev/null | head -n 1)
    if [ -n "$gateway_ip" ]; then
        if ping -c 1 -W 3 "$gateway_ip" >/dev/null 2>&1; then
            echo "Gateway ($gateway_ip): Reachable"
        else
            echo "Gateway ($gateway_ip): Unreachable"
        fi
    else
        echo "Could not determine gateway"
    fi

    # Check DNS connectivity
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo "External DNS (8.8.8.8): Reachable"
    else
        echo "External DNS (8.8.8.8): Unreachable"
    fi

    # Open ports
    echo -e "${CYAN}Open Ports:${NC}"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln 2>/dev/null | grep LISTEN 2>/dev/null || echo "No listening ports found or ss not available"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln 2>/dev/null | grep LISTEN 2>/dev/null || echo "No listening ports found or netstat not available"
    else
        echo "ss and netstat not available"
    fi

    # Critical services status
    echo -e "${CYAN}Critical Services Status:${NC}"
    services_to_check="ssh sshd cron rsyslog"
    for service in $services_to_check; do
        if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "$service: Running"
        elif command -v service >/dev/null 2>&1; then
            service "$service" status >/dev/null 2>&1 && echo "$service: Running" || echo "$service: Not running"
        else
            echo "$service: Status unknown"
        fi
    done

    echo -e "${GREEN}System diagnostics completed.${NC}"
}

# Function to handle Ctrl+C
handle_sigint() {
    echo -e "\n${YELLOW}Received SIGINT. Exiting...${NC}"
    exit 0
}

# Set trap for SIGINT (Ctrl+C)
trap handle_sigint SIGINT

# Main menu function
main_menu() {
    while true; do
        print_header
        echo -n -e "${CYAN}Enter your choice (0-9): ${NC}"

        # Read input with a timeout to prevent hanging
        read -t 30 choice </dev/tty

        # Check if input was received
        if [ $? -ne 0 ]; then
            echo -e "\n${YELLOW}Timeout reached. Returning to menu...${NC}"
            continue
        fi

        case $choice in
            0)
                echo -e "${GREEN}Exiting...${NC}"
                log_message "Script exited by user"
                exit 0
                ;;
            1)
                configure_static_ip
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
            2)
                restart_network
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
            3)
                network_scan
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
            4)
                ssh_connectivity_check
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
            5)
                system_information
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
            6)
                install_packages
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
            7)
                firewall_status
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
            8)
                template_readiness_check
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
            9)
                system_diagnostics
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
            *)
                echo -e "${RED}Invalid option. Please enter a number between 0 and 9.${NC}"
                log_message "Invalid menu selection: $choice" "WARN"
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
        esac
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -L|--log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -j|--jobs)
            MAX_CONCURRENT_JOBS="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Initialize with defaults first
init_defaults

# Load configuration file if provided
if [ -n "$CONFIG_FILE" ]; then
    load_config "$CONFIG_FILE"
else
    # Try to load default config file
    load_config "$DEFAULT_CONFIG_FILE"
fi

# Initialize with defaults again to fill any missing values after config loading
init_defaults

# Create log file if it doesn't exist
if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Warning: Could not create log file at $LOG_FILE, using /tmp/master-linux-tool.log instead"
    LOG_FILE="/tmp/master-linux-tool.log"
    touch "$LOG_FILE" 2>/dev/null || { echo "Error: Cannot create log file anywhere"; exit 1; }
fi

# Initialize system detection
detect_distro
get_package_manager
get_init_system
get_firewall

# Log startup
log_message "Improved Master Linux Tool started" "INFO"

# Start the main menu
main_menu