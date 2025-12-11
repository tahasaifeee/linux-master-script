#!/bin/bash

# master-linux-tool.sh
# Universal Linux Admin Toolkit — safe for: curl ... | bash
# ✅ Works on Ubuntu, Debian, RHEL, CentOS, Rocky, Fedora, OpenSUSE
# ✅ Survives piped execution via /dev/tty
# ✅ SIGINT (Ctrl+C) returns to menu
# ✅ Auto-detects distro, pkg mgr, firewall, network mgr
# ✅ Logs to /var/log (fallback to /tmp if needed)

# --- SAFE INIT: avoid silent failure on logging/output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOGFILE="/var/log/master-linux-tool.log"
FALLBACK_LOG="/tmp/master-linux-tool.log"

# Ensure log destination is writable
if [[ -w "/var/log" ]] && mkdir -p "/var/log" 2>/dev/null && touch "$LOGFILE" 2>/dev/null; then
    true > "$LOGFILE"
else
    LOGFILE="$FALLBACK_LOG"
    mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null
    true > "$LOGFILE"
fi

# Redirect *after* verifying log works
exec > >(stdbuf -oL tee -a "$LOGFILE") 2>&1
set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}
log "Script started. Log: $LOGFILE"

# --- Detection ---
DISTRO=""
PKG_MANAGER=""
FIREWALL_BACKEND=""
NETWORK_MANAGER=""

detect_environment() {
    log "Detecting environment..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=${ID:-unknown}
    else
        DISTRO="unknown"
    fi

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

    if systemctl is-active --quiet firewalld 2>/dev/null; then
        FIREWALL_BACKEND="firewalld"
    elif command -v ufw >/dev/null && ufw status | grep -q "Status: active" 2>/dev/null; then
        FIREWALL_BACKEND="ufw"
    elif command -v iptables >/dev/null && iptables -L -n 2>/dev/null | grep -q 'ACCEPT\|DROP'; then
        FIREWALL_BACKEND="iptables"
    else
        FIREWALL_BACKEND="none"
    fi

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

# --- Interactive safe read ---
read_tty() {
    local prompt=${1:-"Input: "}
    local varname=${2:-REPLY}
    # Force read from terminal, even when piped
    read -r -p "$prompt" "$varname" < /dev/tty
}

# --- Signal handler ---
handle_sigint() {
    echo -e "\n${YELLOW}→ Interrupt caught. Returning to menu...${NC}"
    sleep 0.5
    show_menu
}
trap handle_sigint SIGINT

# --- Functions ---
configure_static_ip() {
    echo -e "${BLUE}=== Configure Static IP (Wizard) ===${NC}"
    log "Starting static IP wizard"

    # Detect interfaces
    mapfile -t INTERFACES < <(ip -br link show 2>/dev/null | grep -vE '^(lo|docker|veth|br-|virbr|tun|tap)' | awk '$1 !~ /^$/ {print $1}')
    if [[ ${#INTERFACES[@]} -eq 0 ]]; then
        echo -e "${RED}✗ No usable network interfaces found.${NC}"
        read_tty "Press Enter to continue..." _
        return 1
    fi

    echo -e "\n${CYAN}Available interfaces:${NC}"
    for i in "${!INTERFACES[@]}"; do
        local iface="${INTERFACES[$i]}"
        local addrs=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | tr '\n' ', ' | sed 's/, $//')
        [[ -z "$addrs" ]] && addrs="(no IPv4)"
        echo -e "  ${YELLOW}$((i+1))${NC}) $iface → $addrs"
    done
    echo

    local idx
    while true; do
        read_tty "Select interface [1-${#INTERFACES[@]}]: " idx
        if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#INTERFACES[@]} )); then
            break
        fi
        echo -e "${RED}Invalid selection.${NC}"
    done
    local IFACE="${INTERFACES[$((idx-1))]}"
    log "Selected interface: $IFACE"

    # IP/CIDR
    local IP_CIDR
    while true; do
        read_tty "Enter static IP/CIDR (e.g., 192.168.1.10/24): " IP_CIDR
        if [[ "$IP_CIDR" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            local cidr=${IP_CIDR#*/}
            if (( cidr >= 1 && cidr <= 32 )); then
                local ip=${IP_CIDR%/*}
                IFS='.' read -r a b c d <<< "$ip"
                if (( a <= 255 && b <= 255 && c <= 255 && d <= 255 )); then
                    break
                fi
            fi
        fi
        echo -e "${RED}Invalid format. Try 192.168.1.10/24${NC}"
    done

    # Gateway
    local GW
    while true; do
        read_tty "Enter gateway (e.g., 192.168.1.1): " GW
        if [[ "$GW" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            IFS='.' read -r a b c d <<< "$GW"
            if (( a <= 255 && b <= 255 && c <= 255 && d <= 255 )); then
                break
            fi
        fi
        echo -e "${RED}Invalid gateway IP.${NC}"
    done

    # DNS
    local DNS_LIST
    read_tty "Enter DNS (space-separated, e.g., 8.8.8.8 1.1.1.1) [8.8.8.8]: " DNS_LIST
    DNS_LIST=${DNS_LIST:-8.8.8.8}

    echo -e "\n${CYAN}→ Confirm:${NC}"
    echo -e "  Interface: $IFACE"
    echo -e "  IP/CIDR:   $IP_CIDR"
    echo -e "  Gateway:   $GW"
    echo -e "  DNS:       $DNS_LIST"
    echo
    read_tty "Apply? (y/N): " confirm
    [[ "${confirm,,}" != "y" ]] && { echo -e "${YELLOW}Cancelled.${NC}"; read_tty "Press Enter..." _; return 0; }

    if [[ "$NETWORK_MANAGER" == "NetworkManager" ]]; then
        local conn=$(nmcli -t -f NAME,DEVICE con show 2>/dev/null | grep ":$IFACE\$" | head -1 | cut -d: -f1)
        if [[ -z "$conn" ]]; then
            conn="static-$IFACE"
            nmcli con add type ethernet con-name "$conn" ifname "$IFACE" \
                ipv4.method manual ipv4.addresses "$IP_CIDR" ipv4.gateway "$GW" ipv4.dns "$DNS_LIST" >/dev/null
        else
            nmcli con mod "$conn" ipv4.method manual \
                ipv4.addresses "$IP_CIDR" ipv4.gateway "$GW" ipv4.dns "$DNS_LIST" >/dev/null
        fi
        nmcli con up "$conn" >/dev/null
        echo -e "${GREEN}✓ Applied via NetworkManager ($conn).${NC}"

    elif [[ "$NETWORK_MANAGER" == "systemd-networkd" ]]; then
        local CONF_DIR="/etc/systemd/network"
        local CONF_FILE="$CONF_DIR/10-$IFACE-static.network"
        mkdir -p "$CONF_DIR"

        [[ -f "$CONF_FILE" ]] && mv "$CONF_FILE" "$CONF_FILE.bak-$(date +%s)" && log "Backed up $CONF_FILE"

        cat > "$CONF_FILE" <<EOF
[Match]
Name=$IFACE

[Network]
Address=$IP_CIDR
Gateway=$GW
$(printf 'DNS=%s\n' $DNS_LIST)
EOF

        log "Wrote $CONF_FILE"
        echo -e "${CYAN}⚙ Reloading systemd-networkd...${NC}"
        if systemctl is-active --quiet systemd-networkd; then
            networkctl reload 2>/dev/null || systemctl reload systemd-networkd
            networkctl reconfigure "$IFACE" 2>/dev/null || systemctl restart systemd-networkd
        else
            systemctl enable --now systemd-networkd
        fi

        sleep 1
        local cur_ip=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet / {print $2; exit}')
        if [[ "$cur_ip" == "${IP_CIDR%/*}/"* ]]; then
            echo -e "${GREEN}✓ systemd-networkd config applied.${NC}"
        else
            echo -e "${YELLOW}⚠ Applied config, but IP not active. Check: journalctl -u systemd-networkd -b${NC}"
        fi

    else
        echo -e "${RED}✗ Unsupported network manager: $NETWORK_MANAGER${NC}"
        echo -e "${YELLOW}Manual config required (e.g., /etc/network/interfaces, netplan, etc.)${NC}"
    fi

    read_tty "Press Enter to continue..." _
}

restart_network() {
    echo -e "${BLUE}=== Restart Network ===${NC}"
    case "$NETWORK_MANAGER" in
        NetworkManager)
            systemctl restart NetworkManager && echo -e "${GREEN}✓ NetworkManager restarted.${NC}"
            ;;
        systemd-networkd)
            systemctl restart systemd-networkd systemd-resolved && echo -e "${GREEN}✓ systemd-networkd restarted.${NC}"
            ;;
        *)
            if systemctl is-active --quiet network 2>/dev/null; then
                systemctl restart network && echo -e "${GREEN}✓ Legacy 'network' service restarted.${NC}"
            else
                echo -e "${YELLOW}⚠ No known network service restarted.${NC}"
            fi
            ;;
    esac
    read_tty "Press Enter to continue..." _
}

network_scan() {
    echo -e "${BLUE}=== Network Scan (nmap -sn) ===${NC}"
    if ! command -v nmap >/dev/null; then
        echo -e "${YELLOW}nmap not found — installing...${NC}"
        install_packages nmap
    fi
    local ip=$(ip -4 route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}')
    [[ -z "$ip" ]] && { echo -e "${RED}✗ No outbound route detected.${NC}"; read_tty "Press Enter..." _; return 1; }
    local net=$(echo "$ip" | cut -d. -f1-3).0/24
    echo -e "Scanning $net..."
    nmap -sn "$net" | grep -E "([0-9]{1,3}\.){3}[0-9]{1,3}|Nmap done"
    read_tty "Press Enter to continue..." _
}

ssh_check() {
    echo -e "${BLUE}=== SSH Connectivity Check ===${NC}"
    read_tty "Target host (IP/hostname): " host
    read_tty "Port [22]: " port
    port=${port:-22}
    echo -e "Testing SSH to $host:$port (5s timeout)..."
    if timeout 5 ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$port" "$host" true 2>/dev/null; then
        echo -e "${GREEN}✓ SSH connection succeeded.${NC}"
    else
        echo -e "${RED}✗ SSH failed (timeout/refused/auth needed).${NC}"
    fi
    read_tty "Press Enter to continue..." _
}

system_info() {
    echo -e "${BLUE}=== System Information ===${NC}"
    printf "%-15s %s\n" "Hostname:" "$(hostname)"
    printf "%-15s %s\n" "Kernel:" "$(uname -r)"
    printf "%-15s %s\n" "Uptime:" "$(uptime -p)"
    printf "%-15s %s\n" "Distro:" "$DISTRO ($(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "N/A"))"
    printf "%-15s %s\n" "CPU:" "$(grep 'model name' /proc/cpuinfo | uniq | sed 's/.*: //' | head -1)"
    printf "%-15s %s\n" "Memory:" "$(free -h | awk '/^Mem:/ {print $2 " total, " $3 " used"}')"
    printf "%-15s %s\n" "Disk (/):" "$(df -h / | awk 'NR==2 {print $2 " total, " $3 " used"}')"
    printf "%-15s %s\n" "NetworkMgr:" "$NETWORK_MANAGER"
    printf "%-15s %s\n" "Firewall:" "$FIREWALL_BACKEND"
    echo
    read_tty "Press Enter to continue..." _
}

install_packages() {
    local pkgs=()
    if [[ $# -eq 0 ]]; then
        echo -e "${BLUE}=== Install Packages ===${NC}"
        read_tty "Packages (space-separated): " input
        read -ra pkgs <<< "$input"
    else
        pkgs=("$@")
    fi
    [[ ${#pkgs[@]} -eq 0 ]] && { echo -e "${YELLOW}No packages specified.${NC}"; read_tty "Press Enter..." _; return 0; }

    echo -e "Using package manager: $PKG_MANAGER"
    case "$PKG_MANAGER" in
        apt)
            apt-get update -y && apt-get install -y "${pkgs[@]}"
            ;;
        dnf|yum)
            "$PKG_MANAGER" install -y "${pkgs[@]}"
            ;;
        zypper)
            zypper --non-interactive install "${pkgs[@]}"
            ;;
        *)
            echo -e "${RED}✗ Unsupported pkg mgr: $PKG_MANAGER${NC}"
            return 1
            ;;
    esac
    echo -e "${GREEN}✓ Installed: ${pkgs[*]}${NC}"
    read_tty "Press Enter to continue..." _
}

firewall_status() {
    echo -e "${BLUE}=== Firewall Status ($FIREWALL_BACKEND) ===${NC}"
    case "$FIREWALL_BACKEND" in
        firewalld)
            firewall-cmd --get-active-zones
            echo; firewall-cmd --list-all
            ;;
        ufw)
            ufw status verbose
            ;;
        iptables)
            echo "Filter table (top 15 rules):"
            iptables -L -n -v 2>/dev/null | head -15
            ;;
        none)
            echo -e "${YELLOW}⚠ No active firewall detected.${NC}"
            ;;
        *)
            echo -e "${RED}Unknown backend: $FIREWALL_BACKEND${NC}"
            ;;
    esac
    read_tty "Press Enter to continue..." _
}

template_check() {
    echo -e "${BLUE}=== Template Readiness Check ===${NC}"
    local issues=()
    [[ ! -f ~/.ssh/id_rsa ]] && [[ ! -f ~/.ssh/id_ed25519 ]] && issues+=("SSH key missing")
    ! sudo -n true 2>/dev/null && issues+=("Passwordless sudo not configured")
    for t in curl wget git rsync; do ! command -v "$t" >/dev/null && issues+=("Missing: $t"); done

    if [[ ${#issues[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ System ready for templated deployments.${NC}"
    else
        echo -e "${RED}Issues found:${NC}"
        printf "  • %s\n" "${issues[@]}"
    fi
    read_tty "Press Enter to continue..." _
}

diagnostics() {
    echo -e "${BLUE}=== System Diagnostics ===${NC}"
    echo -e "${CYAN}→ Network:${NC}"
    echo "  Gateway ping: $(ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 && echo OK || echo FAIL)"
    echo "  DNS resolve:  $(nslookup -timeout=2 google.com >/dev/null 2>&1 && echo OK || echo FAIL)"
    echo -e "\n${CYAN}→ Disk/Inodes:${NC}"
    df -h / | tail -1
    df -i / | tail -1
    echo -e "\n${CYAN}→ Services:${NC}"
    for s in sshd cron; do systemctl is-active "$s" 2>/dev/null && echo "  $s: ${GREEN}active${NC}" || echo "  $s: ${YELLOW}inactive${NC}"; done
    read_tty "Press Enter to continue..." _
}

# --- Menu ---
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
            0) echo -e "${GREEN}Goodbye! Log: $LOGFILE${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# --- MAIN ---
log "Initializing environment..."
detect_environment
echo -e "${GREEN}✓ Environment detected. Launching menu...${NC}"
sleep 0.5
show_menu
