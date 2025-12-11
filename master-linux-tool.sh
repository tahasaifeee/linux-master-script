#!/bin/bash
#
# Master Linux Tool
# A comprehensive utility for Linux system administration
#

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/master-linux-tool.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to detect the distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$NAME
        DISTRO_ID=$ID
    elif type lsb_release >/dev/null 2>&1; then
        DISTRO=$(lsb_release -si)
        DISTRO_ID=$(echo $DISTRO | tr '[:upper:]' '[:lower:]')
    else
        DISTRO="Unknown"
        DISTRO_ID="unknown"
    fi
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
    else
        PKG_MANAGER="unknown"
    fi
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
}

# Function to print header
print_header() {
    echo -e "${CYAN}===========================================${NC}"
    echo -e "${CYAN}    Master Linux Script - Interactive Menu${NC}"
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
    
    # Detect network interfaces
    INTERFACES=$(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | awk -F': ' '{print $2}' | head -n 1)
    if [ -z "$INTERFACES" ]; then
        echo -e "${RED}No network interface found.${NC}"
        return 1
    fi
    
    echo "Available interface: $INTERFACES"
    read -p "Interface name (default: $INTERFACES): " INTERFACE
    INTERFACE=${INTERFACE:-$INTERFACES}
    
    read -p "Enter IP address (e.g., 192.168.1.100): " IP_ADDR
    read -p "Enter netmask (e.g., 255.255.255.0 or prefix like /24): " NETMASK
    read -p "Enter gateway (e.g., 192.168.1.1): " GATEWAY
    read -p "Enter DNS server (e.g., 8.8.8.8): " DNS
    
    # Determine if netmask is in CIDR notation
    if [[ $NETMASK == /* ]]; then
        CIDR=$NETMASK
        # Extract network portion from IP
        NETWORK_PART=$(echo $IP_ADDR | cut -d. -f1-3)
    else
        # Convert netmask to CIDR if needed
        CIDR=$(ipcalc -np $IP_ADDR $NETMASK 2>/dev/null | grep -o '/[0-9]*' || echo "/24")
        CIDR=${CIDR:-/24}
    fi
    
    log_message "Configuring static IP for interface $INTERFACE with IP $IP_ADDR$CIDR, gateway $GATEWAY, DNS $DNS"
    
    # Handle different distributions
    case $DISTRO_ID in
        ubuntu|debian)
            # Backup existing config
            if [ -f /etc/netplan/01-netcfg.yaml ]; then
                cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.bak
            fi
            
            cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $IP_ADDR$CIDR
      gateway4: $GATEWAY
      nameservers:
          addresses: [$DNS]
EOF
            
            # Apply netplan
            netplan apply
            ;;
        centos|rhel|rocky|almalinux)
            # Backup existing config
            if [ -f "/etc/sysconfig/network-scripts/ifcfg-$INTERFACE" ]; then
                cp "/etc/sysconfig/network-scripts/ifcfg-$INTERFACE" "/etc/sysconfig/network-scripts/ifcfg-$INTERFACE.bak"
            fi
            
            cat <<EOF > "/etc/sysconfig/network-scripts/ifcfg-$INTERFACE"
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
NAME=$INTERFACE
UUID=$(uuidgen)
DEVICE=$INTERFACE
ONBOOT=yes
IPADDR=$IP_ADDR
PREFIX=${CIDR#/}
GATEWAY=$GATEWAY
DNS1=$DNS
EOF
            
            # Restart network
            systemctl restart network
            ;;
        fedora)
            # Backup existing config
            if [ -f "/etc/sysconfig/network-scripts/ifcfg-$INTERFACE" ]; then
                cp "/etc/sysconfig/network-scripts/ifcfg-$INTERFACE" "/etc/sysconfig/network-scripts/ifcfg-$INTERFACE.bak"
            fi
            
            cat <<EOF > "/etc/sysconfig/network-scripts/ifcfg-$INTERFACE"
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
NAME=$INTERFACE
UUID=$(uuidgen)
DEVICE=$INTERFACE
ONBOOT=yes
IPADDR=$IP_ADDR
PREFIX=${CIDR#/}
GATEWAY=$GATEWAY
DNS1=$DNS
EOF
            
            # Restart NetworkManager
            systemctl restart NetworkManager
            ;;
        opensuse*)
            # For OpenSUSE, we'll use wicked
            if [ -f "/etc/sysconfig/network/ifcfg-$INTERFACE" ]; then
                cp "/etc/sysconfig/network/ifcfg-$INTERFACE" "/etc/sysconfig/network/ifcfg-$INTERFACE.bak"
            fi
            
            cat <<EOF > "/etc/sysconfig/network/ifcfg-$INTERFACE"
STARTMODE='auto'
BOOTPROTO='static'
IPADDR='$IP_ADDR$CIDR'
GATEWAYS='$GATEWAY'
NAMESERVERS='$DNS'
EOF
            
            # Restart network
            systemctl restart wicked
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO_ID${NC}"
            return 1
            ;;
    esac
    
    # Verify new IP
    NEW_IP=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | head -n 1)
    echo -e "${GREEN}New IP configuration: $NEW_IP${NC}"
    echo -e "${GREEN}Static IP configuration completed.${NC}"
}

# Function to restart network
restart_network() {
    echo -e "${YELLOW}Restarting network...${NC}"
    
    log_message "Restarting network services"
    
    case $DISTRO_ID in
        ubuntu|debian)
            # Try netplan first, then traditional networking
            if command -v netplan >/dev/null 2>&1; then
                netplan apply
            elif systemctl is-active --quiet networking; then
                systemctl restart networking
            else
                service networking restart
            fi
            ;;
        centos|rhel|rocky|almalinux)
            if systemctl is-active --quiet network; then
                systemctl restart network
            else
                service network restart
            fi
            ;;
        fedora)
            if systemctl is-active --quiet NetworkManager; then
                systemctl restart NetworkManager
            else
                service NetworkManager restart
            fi
            ;;
        opensuse*)
            if systemctl is-active --quiet wicked; then
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
    
    echo -e "${GREEN}Network restarted successfully.${NC}"
}

# Function to scan network
network_scan() {
    echo -e "${YELLOW}Scanning network...${NC}"
    
    read -p "Enter subnet to scan (e.g., 192.168.1.0/24): " SUBNET
    if [ -z "$SUBNET" ]; then
        echo -e "${RED}Subnet not provided.${NC}"
        return 1
    fi
    
    log_message "Scanning network: $SUBNET"
    
    # Try different methods for network scanning
    if command -v nmap >/dev/null 2>&1; then
        echo -e "${CYAN}Using nmap for network scan...${NC}"
        nmap -sn $SUBNET | grep report | grep -v "Nmap done"
    elif command -v arp-scan >/dev/null 2>&1; then
        echo -e "${CYAN}Using arp-scan for network scan...${NC}"
        arp-scan $SUBNET
    else
        # Fallback to ping sweep
        echo -e "${CYAN}Using ping sweep for network scan...${NC}"
        IFS='/' read -r network prefix <<< "$SUBNET"
        IFS='.' read -r ip1 ip2 ip3 ip4 <<< "$network"
        
        # Calculate host range based on prefix
        case $prefix in
            24) start=1; end=254 ;;
            16) start=1; end=254 ;;
            8) start=1; end=254 ;;
            *) start=1; end=254 ;;
        esac
        
        for i in $(seq $start $end); do
            (
                ping -c 1 -W 1 "$ip1.$ip2.$ip3.$i" >/dev/null 2>&1 && \
                echo "$ip1.$ip2.$ip3.$i is alive"
            ) &
            # Limit concurrent pings to avoid overwhelming the system
            if [ $(jobs -r | wc -l) -gt 10 ]; then
                wait -n
            fi
        done
        wait
    fi
}

# Function to check SSH connectivity
ssh_connectivity_check() {
    echo -e "${YELLOW}Checking SSH connectivity...${NC}"
    
    read -p "Enter hostname/IP to check (or 'file' to read from file): " TARGET
    if [ "$TARGET" = "file" ]; then
        read -p "Enter path to hosts file: " HOSTS_FILE
        if [ ! -f "$HOSTS_FILE" ]; then
            echo -e "${RED}File $HOSTS_FILE does not exist.${NC}"
            return 1
        fi
        
        while IFS= read -r host; do
            host=$(echo $host | xargs)  # Trim whitespace
            if [ -n "$host" ] && [[ ! $host =~ ^# ]]; then  # Skip empty lines and comments
                echo -e "${CYAN}Checking SSH connectivity to $host...${NC}"
                if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no $host exit 2>/dev/null; then
                    echo -e "${GREEN}$host: SSH reachable${NC}"
                    log_message "SSH connectivity to $host: SUCCESS"
                else
                    echo -e "${RED}$host: SSH not reachable${NC}"
                    log_message "SSH connectivity to $host: FAILED"
                fi
            fi
        done < "$HOSTS_FILE"
    else
        if [ -z "$TARGET" ]; then
            echo -e "${RED}Target not provided.${NC}"
            return 1
        fi
        
        echo -e "${CYAN}Checking SSH connectivity to $TARGET...${NC}"
        if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no $TARGET exit 2>/dev/null; then
            echo -e "${GREEN}$TARGET: SSH reachable${NC}"
            log_message "SSH connectivity to $TARGET: SUCCESS"
        else
            echo -e "${RED}$TARGET: SSH not reachable${NC}"
            log_message "SSH connectivity to $TARGET: FAILED"
        fi
    fi
}

# Function to display system information
system_information() {
    echo -e "${YELLOW}System Information:${NC}"
    
    log_message "Displaying system information"
    
    echo -e "${CYAN}Hostname:${NC} $(hostname)"
    echo -e "${CYAN}OS:${NC} $DISTRO ($DISTRO_ID)"
    echo -e "${CYAN}Kernel:${NC} $(uname -r)"
    echo -e "${CYAN}Uptime:${NC} $(uptime -p 2>/dev/null || uptime)"
    echo -e "${CYAN}CPU:${NC} $(nproc) cores"
    echo -e "${CYAN}Memory:${NC} $(free -h | awk 'NR==2{print $2}') total ($(free -m | awk 'NR==2{print $3 "/" $2}' | sed 's/M//g') MB used)"
    
    # Disk usage
    echo -e "${CYAN}Disk Usage:${NC}"
    df -h | grep -E '^/dev/' | awk '{print "  " $1 ": " $5 " used (" $4 " free)"}'
    
    # Network interfaces
    echo -e "${CYAN}Network Interfaces:${NC}"
    ip addr show | grep -E '^[0-9]+:' | grep -v 'lo:' | while read -r line; do
        iface=$(echo $line | awk -F': ' '{print $2}')
        ip_addr=$(ip addr show $iface | grep 'inet ' | awk '{print $2}' | head -n 1)
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
    
    read -p "Enter package name(s) to install (space-separated): " PACKAGES
    if [ -z "$PACKAGES" ]; then
        echo -e "${RED}No packages specified.${NC}"
        return 1
    fi
    
    log_message "Installing packages: $PACKAGES using $PKG_MANAGER"
    
    case $PKG_MANAGER in
        apt)
            apt update
            apt install -y $PACKAGES
            ;;
        yum|dnf)
            $PKG_MANAGER install -y $PACKAGES
            ;;
        zypper)
            zypper install -y $PACKAGES
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
            if systemctl is-active --quiet nftables; then
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
    PASS_COUNT=0
    TOTAL_CHECKS=0
    
    # Check 1: Hostname
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    CURRENT_HOSTNAME=$(hostname)
    if [ -n "$CURRENT_HOSTNAME" ] && [ "$CURRENT_HOSTNAME" != "localhost" ]; then
        echo -e "${GREEN}✓ Hostname: $CURRENT_HOSTNAME${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ Hostname: Not properly set${NC}"
    fi
    
    # Check 2: Time synchronization
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if systemctl is-active --quiet chronyd || systemctl is-active --quiet ntp || systemctl is-active --quiet systemd-timesyncd; then
        TIME_SOURCE=$(timedatectl status 2>/dev/null | grep "NTP service\|System clock synchronized" | head -n 1)
        echo -e "${GREEN}✓ Time sync service: Active (${TIME_SOURCE})${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ Time sync service: Not active${NC}"
    fi
    
    # Check 3: SSH status
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
        echo -e "${GREEN}✓ SSH service: Running${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ SSH service: Not running${NC}"
    fi
    
    # Check 4: /etc/hosts
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ -f /etc/hosts ] && grep -q "127.0.0.1.*$(hostname)" /etc/hosts 2>/dev/null; then
        echo -e "${GREEN}✓ /etc/hosts: Contains hostname entry${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ /etc/hosts: Missing hostname entry${NC}"
    fi
    
    # Check 5: Network interface status
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    ACTIVE_INTERFACES=$(ip link show | grep -E '^[0-9]+:' | grep -v 'lo:' | grep -c 'state UP' 2>/dev/null)
    if [ "$ACTIVE_INTERFACES" -ge 1 ]; then
        echo -e "${GREEN}✓ Network interfaces: At least one active${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ Network interfaces: None active${NC}"
    fi
    
    # Check 6: DHCP lease files
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    DHCP_FILES=$(find /var/lib/dhcp* /var/lib/NetworkManager* -name "*.lease" -o -name "*dhclient*" 2>/dev/null | wc -l)
    if [ "$DHCP_FILES" -eq 0 ]; then
        echo -e "${GREEN}✓ DHCP leases: No leftover lease files${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ DHCP leases: Found $DHCP_FILES lease files${NC}"
    fi
    
    # Summary
    echo ""
    echo -e "${CYAN}Template Readiness Summary:${NC}"
    echo -e "${CYAN}Passed: $PASS_COUNT/$TOTAL_CHECKS checks${NC}"
    
    if [ $PASS_COUNT -eq $TOTAL_CHECKS ]; then
        echo -e "${GREEN}Overall Status: Template is ready!${NC}"
        log_message "Template readiness check: PASSED ($PASS_COUNT/$TOTAL_CHECKS)"
    else
        echo -e "${YELLOW}Overall Status: Template needs attention${NC}"
        log_message "Template readiness check: NEEDS_ATTENTION ($PASS_COUNT/$TOTAL_CHECKS)"
    fi
}

# Function for system diagnostics
system_diagnostics() {
    echo -e "${YELLOW}Running System Diagnostics...${NC}"
    
    log_message "Running system diagnostics"
    
    # CPU Load
    echo -e "${CYAN}CPU Load:${NC}"
    echo "Load average: $(uptime | awk -F'load average:' '{print $2}')"
    
    # Memory usage
    echo -e "${CYAN}Memory Usage:${NC}"
    free -h
    
    # Disk health (if smartctl is available)
    if command -v smartctl >/dev/null 2>&1; then
        echo -e "${CYAN}Disk Health (SMART):${NC}"
        for drive in /dev/sda /dev/sdb /dev/nvme0n1; do
            if [ -b "$drive" ]; then
                echo "Checking $drive:"
                smartctl -H $drive | grep -E "(PASSED|FAILED|overall-health)"
            fi
        done
    else
        echo -e "${CYAN}Disk Health:${NC} smartctl not available"
    fi
    
    # Network connectivity
    echo -e "${CYAN}Network Connectivity:${NC}"
    # Check gateway connectivity
    GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -n 1)
    if [ -n "$GATEWAY_IP" ]; then
        if ping -c 1 -W 3 "$GATEWAY_IP" >/dev/null 2>&1; then
            echo "Gateway ($GATEWAY_IP): Reachable"
        else
            echo "Gateway ($GATEWAY_IP): Unreachable"
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
        ss -tuln | grep LISTEN
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep LISTEN
    else
        echo "ss and netstat not available"
    fi
    
    # Critical services status
    echo -e "${CYAN}Critical Services Status:${NC}"
    SERVICES_TO_CHECK="ssh sshd cron rsyslog"
    for service in $SERVICES_TO_CHECK; do
        if systemctl is-active --quiet $service 2>/dev/null || service $service status >/dev/null 2>&1; then
            echo "$service: Running"
        else
            echo "$service: Not running"
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
                log_message "Invalid menu selection: $choice"
                echo -e "${YELLOW}Press Enter to continue to the main menu...${NC}"
                read </dev/tty
                ;;
        esac
    done
}

# Initialize
detect_distro
get_package_manager
get_init_system
get_firewall

# Create log file if it doesn't exist
touch "$LOG_FILE" 2>/dev/null || echo "Warning: Could not create log file at $LOG_FILE"

# Start the main menu
log_message "Master Linux Tool started"
main_menu