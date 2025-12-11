#!/bin/bash

# master-linux-tool.sh
# A universal interactive Linux administration tool.
# Works across Ubuntu, Debian, RHEL, CentOS, Rocky, Fedora, OpenSUSE, etc.
# Safe for piped execution (e.g., curl ... | bash)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging
LOGFILE="/var/log/master-linux-tool.log"
exec > >(tee -a "$LOGFILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

header() {
    clear
    echo -e "${CYAN}==========================================="
    echo -e "    ${GREEN}Master Linux Script - Interactive Menu${CYAN}"
    echo -e "===========================================${NC}"
    echo -e "${YELLOW}1.${NC} Configure Static IP"
    echo -e "${YELLOW}2.${NC} Restart Network"
    echo -e "${YELLOW}3.${NC} Network Scan"
    echo -e "${YELLOW}4.${NC} SSH Connectivity Check"
    echo -e "${YELLOW}5.${NC} System Information"
    echo -e "${YELLOW}6.${NC} Install Packages"
    echo -e "${YELLOW}7.${NC} Firewall Status"
    echo -e "${YELLOW}8.${NC} Template Readiness Check"
    echo -e "${YELLOW}9.${NC} System Diagnostics"
    echo -e "${YELLOW}0.${NC} Exit"
    echo -e "${CYAN}===========================================${NC}"
}

# Auto-detection variables
DISTRO=""
PKG_MANAGER=""
FIREWALL_BACKEND=""
NETWORK_MANAGER=""

detect_environment() {
    log "Detecting system environment..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        log "Warning: /etc/os-release not found. Using fallback."
        DISTRO="unknown"
    fi

    # Package manager
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
    else
        PKG_MANAGER="unknown"
    fi

    # Firewall: prefer firewalld > ufw > iptables
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        FIREWALL_BACKEND="firewalld"
    elif command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
        FIREWALL_BACKEND="ufw"
    elif command -v iptables >/dev/null; then
        FIREWALL_BACKEND="iptables"
    else
        FIREWALL_BACKEND="none"
    fi

    # Network manager
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        NETWORK_MANAGER="NetworkManager"
    elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then
        NETWORK_MANAGER="systemd-networkd"
    elif command -v nmcli >/dev/null; then
        NETWORK_MANAGER="NetworkManager"
    else
        NETWORK_MANAGER="unknown"
    fi

    log "Detected: Distro=$DISTRO, PKG=$PKG_MANAGER, Firewall=$FIREWALL_BACKEND, NetMgr=$NETWORK_MANAGER"
}

# Signal handling
handle_sigint() {
    echo -e "\n${YELLOW}Interrupt received — returning to menu...${NC}"
    # Do NOT exit, just redraw menu
    show_menu
}
trap handle_sigint SIGINT

# Interactive read safe for piped execution
read_tty() {
    local prompt=${1:-"Enter input: "}
    local varname=${2:-REPLY}
    # Ensure stdin is /dev/tty for interactivity
    read -r -p "$prompt" "$varname" < /dev/tty
}

# ================
# MENU FUNCTIONS
# ================

configure_static_ip() {
    echo -e "${BLUE}=== Configure Static IP ===${NC}"
    echo "Detected network manager: $NETWORK_MANAGER"
    if [[ "$NETWORK_MANAGER" == "NetworkManager" ]]; then
        echo "Available connections:"
        nmcli con show
        echo
        read_tty "Enter connection name: " CONN_NAME
        read_tty "Enter static IP (e.g., 192.168.1.10/24): " IP_CIDR
        read_tty "Enter gateway: " GW
        read_tty "Enter DNS (space-separated, e.g., 8.8.8.8 1.1.1.1): " DNS

        log "Configuring '$CONN_NAME' with IP=$IP_CIDR, GW=$GW, DNS=($DNS)"
        if nmcli con mod "$CONN_NAME" ipv4.method manual ipv4.addresses "$IP_CIDR" ipv4.gateway "$GW" ipv4.dns "$DNS" 2>/dev/null; then
            nmcli con up "$CONN_NAME"
            echo -e "${GREEN}✓ Static IP configured and activated.${NC}"
        else
            echo -e "${RED}✗ Failed to configure IP. Check connection name and syntax.${NC}"
        fi
    elif [[ "$NETWORK_MANAGER" == "systemd-networkd" ]]; then
        echo -e "${YELLOW}⚠ systemd-networkd support is minimal — manual editing recommended (e.g., /etc/systemd/network/*.network).${NC}"
        echo "Use 'ip addr' and 'ip route' to verify current settings."
    else
        echo -e "${RED}✗ Unsupported or unknown network manager.${NC}"
    fi
    read_tty "Press Enter to continue..." _
}

restart_network() {
    echo -e "${BLUE}=== Restart Network ===${NC}"
    case "$NETWORK_MANAGER" in
        NetworkManager)
            log "Restarting NetworkManager..."
            if systemctl restart NetworkManager; then
                echo -e "${GREEN}✓ NetworkManager restarted.${NC}"
            else
                echo -e "${RED}✗ Failed to restart NetworkManager.${NC}"
            fi
            ;;
        systemd-networkd)
            log "Restarting systemd-networkd & systemd-resolved..."
            systemctl restart systemd-networkd systemd-resolved
            echo -e "${GREEN}✓ systemd-networkd restarted.${NC}"
            ;;
        *)
            echo -e "${YELLOW}⚠ Unknown network manager. Trying legacy network service...${NC}"
            if command -v systemctl >/dev/null && systemctl list-units --full --all | grep -q "network.service"; then
                systemctl restart network && echo -e "${GREEN}✓ Legacy 'network' service restarted.${NC}"
            else
                echo -e "${RED}✗ No known network service found to restart.${NC}"
            fi
            ;;
    esac
    read_tty "Press Enter to continue..." _
}

network_scan() {
    echo -e "${BLUE}=== Network Scan (local subnet) ===${NC}"
    if ! command -v nmap >/dev/null; then
        echo -e "${YELLOW}nmap not found — installing...${NC}"
        install_packages nmap
    fi
    # Detect local IP & subnet
    LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
    if [[ -z "$LOCAL_IP" ]]; then
        echo -e "${RED}✗ Could not determine local IP.${NC}"
        read_tty "Press Enter to continue..." _
        return 1
    fi
    SUBNET=$(echo "$LOCAL_IP" | cut -d. -f1-3).0/24
    echo -e "Scanning $SUBNET (from $LOCAL_IP) — this may take ~30s..."
    log "Running: nmap -sn $SUBNET"
    nmap -sn "$SUBNET" | grep -E "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)|Nmap done"
    read_tty "Press Enter to continue..." _
}

ssh_check() {
    echo -e "${BLUE}=== SSH Connectivity Check ===${NC}"
    read_tty "Enter target host (IP or hostname): " TARGET
    read_tty "Enter SSH port [default 22]: " PORT
    PORT=${PORT:-22}
    echo -e "Testing SSH to ${TARGET}:${PORT} (timeout 5s)..."
    log "Testing SSH: ssh -o ConnectTimeout=5 -o BatchMode=yes -p $PORT $TARGET true"
    if timeout 5 ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$PORT" "$TARGET" true 2>/dev/null; then
        echo -e "${GREEN}✓ SSH connection successful.${NC}"
    else
        echo -e "${RED}✗ SSH connection failed (timeout, refused, or auth needed).${NC}"
    fi
    read_tty "Press Enter to continue..." _
}

system_info() {
    echo -e "${BLUE}=== System Information ===${NC}"
    echo -e "${CYAN}Hostname:${NC} $(hostname)"
    echo -e "${CYAN}Kernel:${NC} $(uname -r)"
    echo -e "${CYAN}Uptime:${NC} $(uptime -p)"
    echo -e "${CYAN}CPU:${NC} $(grep 'model name' /proc/cpuinfo | uniq | sed 's/model name.*: //')"
    echo -e "${CYAN}Memory:${NC} $(free -h | awk '/^Mem:/ {print $2 " total, " $3 " used, " $4 " free"}')"
    echo -e "${CYAN}Disk:${NC} $(df -h / | awk 'NR==2 {print $2 " total, " $3 " used, " $4 " free on " $1}')"
    echo -e "${CYAN}Distro:${NC} $DISTRO ($(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "N/A"))"
    echo -e "${CYAN}Network Manager:${NC} $NETWORK_MANAGER"
    echo -e "${CYAN}Firewall:${NC} $FIREWALL_BACKEND"
    echo
    read_tty "Press Enter to continue..." _
}

install_packages() {
    local pkgs=("$@")
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        echo -e "${BLUE}=== Install Packages ===${NC}"
        read_tty "Enter package(s) to install (space-separated): " INPUT
        read -ra pkgs <<< "$INPUT"
    fi

    if [[ -z "${pkgs[*]}" ]]; then
        echo -e "${YELLOW}No packages specified.${NC}"
        return 0
    fi

    echo -e "Package manager: $PKG_MANAGER"
    case "$PKG_MANAGER" in
        apt)
            log "Running: apt-get update && apt-get install -y ${pkgs[*]}"
            apt-get update && apt-get install -y "${pkgs[@]}"
            ;;
        dnf|yum)
            log "Running: $PKG_MANAGER install -y ${pkgs[*]}"
            "$PKG_MANAGER" install -y "${pkgs[@]}"
            ;;
        zypper)
            log "Running: zypper --non-interactive install ${pkgs[*]}"
            zypper --non-interactive install "${pkgs[@]}"
            ;;
        *)
            echo -e "${RED}✗ Unsupported package manager: $PKG_MANAGER${NC}"
            return 1
            ;;
    esac
    echo -e "${GREEN}✓ Packages installed.${NC}"
    read_tty "Press Enter to continue..." _
}

firewall_status() {
    echo -e "${BLUE}=== Firewall Status ($FIREWALL_BACKEND) ===${NC}"
    case "$FIREWALL_BACKEND" in
        firewalld)
            echo -e "${CYAN}Active zones:${NC}"
            firewall-cmd --get-active-zones
            echo
            echo -e "${CYAN}Services allowed:${NC}"
            firewall-cmd --list-all
            ;;
        ufw)
            ufw status verbose
            ;;
        iptables)
            echo -e "${CYAN}iptables rules (filter table):${NC}"
            iptables -L -n -v | head -20
            echo -e "\n${YELLOW}Note: Full output may be long. Use 'iptables -L -n' manually for more.${NC}"
            ;;
        none)
            echo -e "${YELLOW}⚠ No active firewall detected.${NC}"
            ;;
        *)
            echo -e "${RED}✗ Unknown firewall backend: $FIREWALL_BACKEND${NC}"
            ;;
    esac
    read_tty "Press Enter to continue..." _
}

template_check() {
    echo -e "${BLUE}=== Template Readiness Check ===${NC}"
    echo -e "Checking common prerequisites for deployment templates..."
    local issues=()

    # SSH keys
    if [[ ! -f ~/.ssh/id_rsa ]] && [[ ! -f ~/.ssh/id_ed25519 ]]; then
        issues+=("SSH key missing (~/.ssh/id_*)")
    fi

    # sudo access
    if ! sudo -n true 2>/dev/null; then
        issues+=("Non-interactive sudo not configured")
    fi

    # Required tools
    for tool in curl wget git rsync; do
        if ! command -v "$tool" >/dev/null; then
            issues+=("Missing: $tool")
        fi
    done

    # Cloud-init (optional)
    if [[ -d /var/lib/cloud ]]; then
        echo -e "${GREEN}✓ cloud-init detected${NC}"
    else
        echo -e "${YELLOW}⚠ cloud-init not found (OK for non-cloud systems)${NC}"
    fi

    if [[ ${#issues[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ System ready for templated deployments.${NC}"
    else
        echo -e "${RED}✗ Issues found:${NC}"
        for issue in "${issues[@]}"; do
            echo -e "  • $issue"
        done
    fi
    read_tty "Press Enter to continue..." _
}

diagnostics() {
    echo -e "${BLUE}=== System Diagnostics ===${NC}"
    echo -e "${CYAN}1. Network${NC}"
    echo "   Gateway ping: $(ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && echo 'OK' || echo 'FAIL')"
    echo "   DNS resolution: $(nslookup google.com >/dev/null 2>&1 && echo 'OK' || echo 'FAIL')"

    echo -e "\n${CYAN}2. Disk & Inodes${NC}"
    df -h / | tail -1
    df -i / | tail -1

    echo -e "\n${CYAN}3. Critical Services${NC}"
    for svc in sshd cron; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo "   $svc: ${GREEN}active${NC}"
        else
            echo "   $svc: ${YELLOW}inactive/missing${NC}"
        fi
    done

    echo -e "\n${CYAN}4. Last boot & errors${NC}"
    echo "   Last boot: $(who -b)"
    journalctl -p 3 -xb --no-pager | grep -i "error\|fail\|critical" | tail -5 | sed 's/^/   /'

    read_tty "Press Enter to continue..." _
}

# Main menu loop
show_menu() {
    while true; do
        header
        read_tty "Enter your choice (0-9): " choice

        case "$choice" in
            1) configure_static_ip ;;
            2) restart_network ;;
            3) network_scan ;;
            4) ssh_check ;;
            5) system_info ;;
            6) install_packages ;;
            7) firewall_status ;;
            8) template_check ;;
            9) diagnostics ;;
            0)
                echo -e "${GREEN}Goodbye! Log saved to $LOGFILE${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Ensure log dir exists
mkdir -p "$(dirname "$LOGFILE")"

# Main init
log "=== Script started ==="
detect_environment
show_menu
