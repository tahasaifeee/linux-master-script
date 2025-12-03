#!/bin/bash

###############################################################################
# Linux VM Template Readiness Script
# Compatible with: CentOS 6+, Ubuntu 16+, Debian, AlmaLinux, Rocky, Oracle
# Purpose: Prepare Linux VMs for template creation with proper configuration
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration variables
SSH_CONFIG="/etc/ssh/sshd_config"
SSHD_SERVICE="sshd"
UFW_ENABLED=false

###############################################################################
# Utility Functions
###############################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ [SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}✗ [ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ [WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ [INFO]${NC} $1"
}

print_step() {
    echo -e "${CYAN}➜ $1${NC}"
}

print_result() {
    echo -e "${MAGENTA}  → $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Ask yes/no question
ask_yes_no() {
    local question="$1"
    local response
    while true; do
        echo -ne "${YELLOW}$question [y/n]: ${NC}"
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Ask for input with default value
ask_input() {
    local question="$1"
    local default="$2"
    local response
    echo -ne "${YELLOW}$question${NC}"
    if [ -n "$default" ]; then
        echo -ne " ${CYAN}[default: $default]${NC}"
    fi
    echo -ne ": "
    read -r response
    if [ -z "$response" ] && [ -n "$default" ]; then
        echo "$default"
    else
        echo "$response"
    fi
}

###############################################################################
# Distribution Detection
###############################################################################

detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        DISTRO_NAME=$NAME
    elif [ -f /etc/redhat-release ]; then
        if grep -q "CentOS release 6" /etc/redhat-release; then
            DISTRO="centos"
            VERSION="6"
            DISTRO_NAME="CentOS 6"
        elif grep -q "Red Hat Enterprise Linux" /etc/redhat-release; then
            DISTRO="rhel"
            VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d. -f1)
            DISTRO_NAME="Red Hat Enterprise Linux"
        fi
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        VERSION=$(cat /etc/debian_version)
        DISTRO_NAME="Debian"
    else
        DISTRO="unknown"
        VERSION="unknown"
        DISTRO_NAME="Unknown"
    fi

    # Normalize distro names
    case "$DISTRO" in
        rhel|redhat) DISTRO="rhel" ;;
        centos) DISTRO="centos" ;;
        almalinux|alma) DISTRO="almalinux" ;;
        rocky) DISTRO="rocky" ;;
        ol|oracle|oraclelinux) DISTRO="oracle" ;;
        ubuntu) DISTRO="ubuntu" ;;
        debian) DISTRO="debian" ;;
    esac

    # Determine SSH service name
    if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
        SSHD_SERVICE="ssh"
    else
        SSHD_SERVICE="sshd"
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    else
        print_error "No supported package manager found"
        exit 1
    fi
}

###############################################################################
# Package Management Functions
###############################################################################

update_cache() {
    case "$PKG_MANAGER" in
        apt)
            apt-get update -y &> /dev/null
            ;;
        yum|dnf)
            $PKG_MANAGER makecache &> /dev/null
            ;;
    esac
}

install_package() {
    local package=$1
    case "$PKG_MANAGER" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" &> /dev/null
            ;;
        yum|dnf)
            $PKG_MANAGER install -y "$package" &> /dev/null
            ;;
    esac
}

is_package_installed() {
    local package=$1
    case "$PKG_MANAGER" in
        apt)
            dpkg -l | grep -q "^ii.*$package"
            ;;
        yum|dnf)
            rpm -qa | grep -q "$package"
            ;;
    esac
}

###############################################################################
# SSH Configuration Functions
###############################################################################

get_current_ssh_port() {
    local port=$(grep "^Port " "$SSH_CONFIG" 2>/dev/null | awk '{print $2}')
    if [ -z "$port" ]; then
        port="22"
    fi
    echo "$port"
}

get_root_login_status() {
    local status=$(grep "^PermitRootLogin " "$SSH_CONFIG" 2>/dev/null | awk '{print $2}')
    if [ -z "$status" ]; then
        status="yes"  # Default on most systems
    fi
    echo "$status"
}

get_password_auth_status() {
    local status=$(grep "^PasswordAuthentication " "$SSH_CONFIG" 2>/dev/null | awk '{print $2}')
    if [ -z "$status" ]; then
        status="yes"  # Default on most systems
    fi
    echo "$status"
}

configure_ssh_port() {
    print_step "Configuring SSH Port"

    local current_port=$(get_current_ssh_port)
    print_result "Current SSH Port: $current_port"

    if ask_yes_no "Do you want to change the SSH port?"; then
        local new_port=$(ask_input "Enter new SSH port" "$current_port")

        # Validate port number
        if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
            print_error "Invalid port number. Keeping current port."
            return
        fi

        # Backup SSH config
        cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"

        # Update or add Port directive
        if grep -q "^Port " "$SSH_CONFIG"; then
            sed -i "s/^Port .*/Port $new_port/" "$SSH_CONFIG"
        else
            echo "Port $new_port" >> "$SSH_CONFIG"
        fi

        print_success "SSH port changed to $new_port"
        SSH_PORT_CHANGED=true
        NEW_SSH_PORT=$new_port
    else
        print_info "SSH port unchanged: $current_port"
        NEW_SSH_PORT=$current_port
    fi
}

configure_root_login() {
    print_step "Configuring Root Login"

    local current_status=$(get_root_login_status)
    print_result "Current Root Login: $current_status"

    if ask_yes_no "Do you want to allow root login via SSH?"; then
        local new_status="yes"
    else
        local new_status="no"
    fi

    # Backup if not already done
    if [ ! -f "${SSH_CONFIG}.bak" ]; then
        cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # Update or add PermitRootLogin directive
    if grep -q "^PermitRootLogin " "$SSH_CONFIG"; then
        sed -i "s/^PermitRootLogin .*/PermitRootLogin $new_status/" "$SSH_CONFIG"
    elif grep -q "^#PermitRootLogin " "$SSH_CONFIG"; then
        sed -i "s/^#PermitRootLogin .*/PermitRootLogin $new_status/" "$SSH_CONFIG"
    else
        echo "PermitRootLogin $new_status" >> "$SSH_CONFIG"
    fi

    print_success "Root login set to: $new_status"
    ROOT_LOGIN_STATUS=$new_status
}

configure_password_auth() {
    print_step "Configuring Password Authentication"

    local current_status=$(get_password_auth_status)
    print_result "Current Password Authentication: $current_status"

    if ask_yes_no "Do you want to enable password authentication?"; then
        local new_status="yes"
    else
        local new_status="no"
    fi

    # Backup if not already done
    if [ ! -f "${SSH_CONFIG}.bak" ]; then
        cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # Update or add PasswordAuthentication directive
    if grep -q "^PasswordAuthentication " "$SSH_CONFIG"; then
        sed -i "s/^PasswordAuthentication .*/PasswordAuthentication $new_status/" "$SSH_CONFIG"
    elif grep -q "^#PasswordAuthentication " "$SSH_CONFIG"; then
        sed -i "s/^#PasswordAuthentication .*/PasswordAuthentication $new_status/" "$SSH_CONFIG"
    else
        echo "PasswordAuthentication $new_status" >> "$SSH_CONFIG"
    fi

    print_success "Password authentication set to: $new_status"
    PASSWORD_AUTH_STATUS=$new_status
}

restart_ssh_service() {
    print_step "Restarting SSH service"

    if command -v systemctl &> /dev/null; then
        systemctl restart "$SSHD_SERVICE"
    elif command -v service &> /dev/null; then
        service "$SSHD_SERVICE" restart
    else
        print_error "Cannot restart SSH service - no service manager found"
        return 1
    fi

    print_success "SSH service restarted successfully"
}

###############################################################################
# Cloud-Init Functions
###############################################################################

check_cloud_init() {
    print_step "Checking Cloud-Init"

    if is_package_installed "cloud-init"; then
        print_result "Cloud-init is installed"

        # Check if services are enabled
        if command -v systemctl &> /dev/null; then
            local enabled_count=0
            for service in cloud-init-local cloud-init cloud-config cloud-final; do
                if systemctl is-enabled "${service}.service" &> /dev/null; then
                    ((enabled_count++))
                fi
            done

            if [ $enabled_count -eq 4 ]; then
                print_success "All cloud-init services are enabled"
                CLOUD_INIT_STATUS="installed_enabled"
            else
                print_warning "Some cloud-init services are not enabled ($enabled_count/4)"
                CLOUD_INIT_STATUS="installed_partial"

                if ask_yes_no "Do you want to enable all cloud-init services?"; then
                    enable_cloud_init_services
                fi
            fi
        else
            print_success "Cloud-init is installed (SysV init - cannot check service status)"
            CLOUD_INIT_STATUS="installed"
        fi
    else
        print_warning "Cloud-init is not installed"
        CLOUD_INIT_STATUS="not_installed"

        if ask_yes_no "Do you want to install cloud-init?"; then
            install_cloud_init
        fi
    fi
}

install_cloud_init() {
    print_step "Installing Cloud-Init"

    update_cache

    case "$PKG_MANAGER" in
        apt)
            install_package "cloud-init"
            ;;
        yum|dnf)
            # For RHEL-based systems, may need EPEL repository
            if [ "$DISTRO" = "centos" ] && [ "${VERSION%%.*}" -eq 6 ]; then
                print_info "Installing EPEL repository for CentOS 6..."
                yum install -y epel-release &> /dev/null || rpm -Uvh https://archives.fedoraproject.org/pub/archive/epel/6/x86_64/epel-release-6-8.noarch.rpm &> /dev/null
            elif [ "$DISTRO" = "centos" ] && [ "${VERSION%%.*}" -eq 7 ]; then
                print_info "Installing EPEL repository for CentOS 7..."
                yum install -y epel-release &> /dev/null
            fi
            install_package "cloud-init"
            ;;
    esac

    enable_cloud_init_services
    print_success "Cloud-init installed successfully"
    CLOUD_INIT_STATUS="installed_enabled"
}

enable_cloud_init_services() {
    if command -v systemctl &> /dev/null; then
        systemctl enable cloud-init-local.service &> /dev/null
        systemctl enable cloud-init.service &> /dev/null
        systemctl enable cloud-config.service &> /dev/null
        systemctl enable cloud-final.service &> /dev/null
        print_success "All cloud-init services enabled"
    fi
}

###############################################################################
# QEMU Guest Agent Functions
###############################################################################

check_qemu_agent() {
    print_step "Checking QEMU Guest Agent"

    if is_package_installed "qemu-guest-agent"; then
        print_result "QEMU Guest Agent is installed"

        # Check if service is running
        if command -v systemctl &> /dev/null; then
            if systemctl is-active --quiet qemu-guest-agent 2>/dev/null; then
                print_success "QEMU Guest Agent service is running"
                QEMU_AGENT_STATUS="installed_running"
            else
                print_warning "QEMU Guest Agent is installed but not running"
                QEMU_AGENT_STATUS="installed_not_running"

                if ask_yes_no "Do you want to start and enable QEMU Guest Agent?"; then
                    start_qemu_agent
                fi
            fi
        elif command -v service &> /dev/null; then
            if service qemu-guest-agent status &>/dev/null; then
                print_success "QEMU Guest Agent service is running"
                QEMU_AGENT_STATUS="installed_running"
            else
                print_warning "QEMU Guest Agent is installed but not running"
                QEMU_AGENT_STATUS="installed_not_running"

                if ask_yes_no "Do you want to start QEMU Guest Agent?"; then
                    start_qemu_agent
                fi
            fi
        fi
    else
        print_warning "QEMU Guest Agent is not installed"
        QEMU_AGENT_STATUS="not_installed"

        if ask_yes_no "Do you want to install QEMU Guest Agent?"; then
            install_qemu_agent
        fi
    fi
}

install_qemu_agent() {
    print_step "Installing QEMU Guest Agent"

    update_cache
    install_package "qemu-guest-agent"
    start_qemu_agent

    print_success "QEMU Guest Agent installed and started"
    QEMU_AGENT_STATUS="installed_running"
}

start_qemu_agent() {
    if command -v systemctl &> /dev/null; then
        systemctl start qemu-guest-agent &> /dev/null
        systemctl enable qemu-guest-agent &> /dev/null
        print_success "QEMU Guest Agent started and enabled"
        QEMU_AGENT_STATUS="installed_running"
    elif command -v service &> /dev/null; then
        service qemu-guest-agent start &> /dev/null
        chkconfig qemu-guest-agent on 2>/dev/null || true
        print_success "QEMU Guest Agent started"
        QEMU_AGENT_STATUS="installed_running"
    fi
}

###############################################################################
# UFW Firewall Functions
###############################################################################

check_ufw_firewall() {
    print_step "Checking UFW Firewall"

    if command -v ufw &> /dev/null; then
        print_result "UFW is installed"

        local ufw_status=$(ufw status | grep -i "Status:" | awk '{print $2}')

        if [ "$ufw_status" = "active" ]; then
            print_success "UFW is active"
            UFW_ENABLED=true

            # Show current rules
            print_result "Current UFW rules:"
            ufw status numbered | grep -v "Status:" | head -10

            if ask_yes_no "Do you want to add/modify firewall rules?"; then
                configure_ufw_rules
            fi
        else
            print_warning "UFW is installed but not active"
            UFW_ENABLED=false

            if ask_yes_no "Do you want to enable and configure UFW?"; then
                configure_ufw_rules
                ufw --force enable &> /dev/null
                print_success "UFW enabled"
                UFW_ENABLED=true
            fi
        fi
    else
        print_warning "UFW is not installed"

        if ask_yes_no "Do you want to install and configure UFW?"; then
            install_and_configure_ufw
        fi
    fi
}

install_and_configure_ufw() {
    print_step "Installing UFW"

    case "$DISTRO" in
        ubuntu|debian)
            update_cache
            install_package "ufw"
            ;;
        *)
            print_warning "UFW is primarily designed for Debian/Ubuntu systems"
            print_info "For RHEL-based systems, consider using firewalld instead"

            if ask_yes_no "Do you want to install UFW anyway?"; then
                if [ "$DISTRO" = "centos" ] && [ "${VERSION%%.*}" -le 7 ]; then
                    print_info "Installing EPEL repository..."
                    yum install -y epel-release &> /dev/null
                fi
                install_package "ufw"
            else
                return
            fi
            ;;
    esac

    print_success "UFW installed"
    configure_ufw_rules
    ufw --force enable &> /dev/null
    print_success "UFW enabled"
    UFW_ENABLED=true
}

configure_ufw_rules() {
    print_step "Configuring UFW Rules"

    # Allow SSH port
    print_info "Allowing SSH port ($NEW_SSH_PORT)..."
    ufw allow "$NEW_SSH_PORT/tcp" &> /dev/null
    print_success "SSH port $NEW_SSH_PORT allowed"

    # Ask for additional ports
    if ask_yes_no "Do you want to add additional ports?"; then
        while true; do
            local port=$(ask_input "Enter port number (or 'done' to finish)" "")

            if [ "$port" = "done" ] || [ -z "$port" ]; then
                break
            fi

            # Validate port
            if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                print_error "Invalid port number"
                continue
            fi

            # Ask for protocol
            echo -ne "${YELLOW}Protocol for port $port (tcp/udp/both) [tcp]: ${NC}"
            read -r protocol
            protocol=${protocol:-tcp}

            case "$protocol" in
                tcp)
                    ufw allow "$port/tcp" &> /dev/null
                    print_success "Port $port/tcp allowed"
                    ;;
                udp)
                    ufw allow "$port/udp" &> /dev/null
                    print_success "Port $port/udp allowed"
                    ;;
                both)
                    ufw allow "$port/tcp" &> /dev/null
                    ufw allow "$port/udp" &> /dev/null
                    print_success "Port $port/tcp and $port/udp allowed"
                    ;;
                *)
                    print_error "Invalid protocol. Skipping port $port"
                    ;;
            esac
        done
    fi

    # Common ports suggestion
    print_info "Common ports you might want to consider:"
    echo "  - 80 (HTTP)"
    echo "  - 443 (HTTPS)"
    echo "  - 3389 (RDP)"
    echo "  - 5432 (PostgreSQL)"
    echo "  - 3306 (MySQL/MariaDB)"

    if ask_yes_no "Do you want to allow HTTP (80) and HTTPS (443)?"; then
        ufw allow 80/tcp &> /dev/null
        ufw allow 443/tcp &> /dev/null
        print_success "HTTP and HTTPS ports allowed"
    fi
}

###############################################################################
# Summary and Completion
###############################################################################

display_summary() {
    print_header "Template Readiness Summary"

    echo -e "${CYAN}System Information:${NC}"
    echo -e "  Distribution: ${GREEN}$DISTRO_NAME${NC}"
    echo -e "  Version: ${GREEN}$VERSION${NC}"
    echo ""

    echo -e "${CYAN}SSH Configuration:${NC}"
    echo -e "  SSH Port: ${GREEN}$NEW_SSH_PORT${NC}"
    echo -e "  Root Login: ${GREEN}$ROOT_LOGIN_STATUS${NC}"
    echo -e "  Password Authentication: ${GREEN}$PASSWORD_AUTH_STATUS${NC}"
    echo ""

    echo -e "${CYAN}Services:${NC}"

    case "$CLOUD_INIT_STATUS" in
        installed_enabled)
            echo -e "  Cloud-Init: ${GREEN}✓ Installed and Enabled${NC}"
            ;;
        installed_partial)
            echo -e "  Cloud-Init: ${YELLOW}⚠ Installed (Partial)${NC}"
            ;;
        installed)
            echo -e "  Cloud-Init: ${GREEN}✓ Installed${NC}"
            ;;
        not_installed)
            echo -e "  Cloud-Init: ${RED}✗ Not Installed${NC}"
            ;;
    esac

    case "$QEMU_AGENT_STATUS" in
        installed_running)
            echo -e "  QEMU Guest Agent: ${GREEN}✓ Installed and Running${NC}"
            ;;
        installed_not_running)
            echo -e "  QEMU Guest Agent: ${YELLOW}⚠ Installed but Not Running${NC}"
            ;;
        not_installed)
            echo -e "  QEMU Guest Agent: ${RED}✗ Not Installed${NC}"
            ;;
    esac

    echo ""
    echo -e "${CYAN}Firewall:${NC}"
    if [ "$UFW_ENABLED" = true ]; then
        echo -e "  UFW Status: ${GREEN}✓ Active${NC}"
        echo ""
        print_info "Current UFW Rules:"
        ufw status numbered
    else
        echo -e "  UFW Status: ${YELLOW}⚠ Not Active${NC}"
    fi

    echo ""
    print_header "Template Readiness Complete!"

    if [ "$SSH_PORT_CHANGED" = true ]; then
        print_warning "IMPORTANT: SSH port has been changed to $NEW_SSH_PORT"
        print_warning "Make sure to use the new port for future connections!"
        print_info "Example: ssh -p $NEW_SSH_PORT user@hostname"
    fi

    print_success "Your VM is now ready for template creation!"
    echo ""
}

###############################################################################
# Main Wizard
###############################################################################

main_wizard() {
    clear
    print_header "Linux VM Template Readiness Wizard"

    echo -e "${CYAN}This wizard will help you prepare your Linux VM for template creation.${NC}"
    echo -e "${CYAN}It will configure:${NC}"
    echo "  • SSH settings (port, root login, password auth)"
    echo "  • Cloud-Init services"
    echo "  • QEMU Guest Agent"
    echo "  • UFW Firewall rules"
    echo ""

    if ! ask_yes_no "Do you want to continue?"; then
        print_info "Wizard cancelled"
        exit 0
    fi

    # Display system info
    echo ""
    print_info "Detected System: $DISTRO_NAME $VERSION"
    print_info "Package Manager: $PKG_MANAGER"
    echo ""

    # SSH Configuration
    print_header "Step 1: SSH Configuration"
    configure_ssh_port
    echo ""
    configure_root_login
    echo ""
    configure_password_auth
    echo ""

    # Restart SSH if changes were made
    if [ "$SSH_PORT_CHANGED" = true ] || [ -n "$ROOT_LOGIN_STATUS" ] || [ -n "$PASSWORD_AUTH_STATUS" ]; then
        restart_ssh_service
    fi
    echo ""

    # Cloud-Init
    print_header "Step 2: Cloud-Init Services"
    check_cloud_init
    echo ""

    # QEMU Guest Agent
    print_header "Step 3: QEMU Guest Agent"
    check_qemu_agent
    echo ""

    # UFW Firewall
    print_header "Step 4: UFW Firewall"
    check_ufw_firewall
    echo ""

    # Display summary
    display_summary
}

###############################################################################
# Main Execution
###############################################################################

main() {
    check_root
    detect_distribution
    detect_package_manager
    main_wizard
}

# Run main function
main
